-- =============================================
-- Stored Procedure: sp_CreateAccountMaster
-- Modified: 2026-09-17
-- Purpose: Create Account Master with correct FundPool logic
-- 
-- FundPool Logic:
-- Income Type:  Positive Amount → Add to FundPool, Negative Amount → Subtract from FundPool
-- Expense Type: Positive Amount → Subtract from FundPool, Negative Amount → Add to FundPool
-- =============================================

ALTER PROCEDURE [dbo].[sp_CreateAccountMaster]
    @TransDate DATE,
    @Mode NVARCHAR(50),
    @VoucherNo NVARCHAR(50) = NULL,
    @FundPool NVARCHAR(50),
    @FundPoolName NVARCHAR(100),
    @Nature NVARCHAR(50),
    @CampId INT = NULL,
    @CampName NVARCHAR(100),
    @RecipientRole NVARCHAR(50),
    @RecipientId INT = NULL,
    @RecipientName NVARCHAR(100),
    @Purpose NVARCHAR(500),
    @AddedBy INT = NULL,
    @Heads AccountMasterHeadType READONLY,
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        -- ========================================
        -- 1. Check VoucherNo uniqueness
        -- ========================================
        IF @VoucherNo IS NOT NULL AND @VoucherNo != '' AND EXISTS (
            SELECT 1 FROM AccountMasters 
            WHERE VoucherNo = @VoucherNo 
            AND ISNULL(IsDeleted, 0) = 0
        )
        BEGIN
            THROW 50001, 'VOUCHER_EXISTS', 1;
        END

        -- ========================================
        -- 2. Generate VoucherNo if not provided
        -- ========================================
        IF @VoucherNo IS NULL OR @VoucherNo = ''
        BEGIN
            DECLARE @NextNum INT;
            
            SELECT @NextNum = ISNULL(MAX(
                CASE 
                    WHEN VoucherNo LIKE 'VCH%' AND ISNUMERIC(SUBSTRING(VoucherNo, 4, LEN(VoucherNo))) = 1
                    THEN CAST(SUBSTRING(VoucherNo, 4, LEN(VoucherNo)) AS INT)
                    ELSE 0
                END
            ), 0) + 1
            FROM AccountMasters
            WHERE ISNULL(IsDeleted, 0) = 0;
            
            SET @VoucherNo = 'VCH' + RIGHT('00000' + CAST(@NextNum AS NVARCHAR), 5);
        END

        -- ========================================
        -- 3. Insert AccountMaster record
        -- ========================================
        INSERT INTO AccountMasters (
            TransDate, Mode, VoucherNo, FundPool, FundPoolName, 
            Nature, CampId, CampName, RecipientRole, RecipientId, 
            RecipientName, Purpose, AddedBy, CreatedAt, UpdatedAt
        )
        VALUES (
            @TransDate, @Mode, @VoucherNo, @FundPool, @FundPoolName,
            @Nature, @CampId, @CampName, @RecipientRole, @RecipientId,
            @RecipientName, @Purpose, @AddedBy, GETDATE(), GETDATE()
        );

        SET @NewId = SCOPE_IDENTITY();

        -- ========================================
        -- 4. Process each head and update FundPool
        -- ========================================
        DECLARE @PaymentType NVARCHAR(20);
        DECLARE @Amount DECIMAL(18,2);
        DECLARE @Head NVARCHAR(100);
        DECLARE @FundPoolAdjustment DECIMAL(18,2);

        DECLARE head_cursor CURSOR FOR
        SELECT PaymentType, Amount, Head FROM @Heads;

        OPEN head_cursor;
        FETCH NEXT FROM head_cursor INTO @PaymentType, @Amount, @Head;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- ========================================
            -- 4.1 Insert Income or Expense record
            -- ========================================
            IF @PaymentType = 'Income'
            BEGIN
                INSERT INTO Incomes (
                    AccountId, Head, Amount, TransDate, 
                    AddedBy, CreatedAt, UpdatedAt
                )
                VALUES (
                    @NewId, @Head, @Amount, @TransDate,
                    @AddedBy, GETDATE(), GETDATE()
                );

                -- Income: Positive adds (+), Negative subtracts (-)
                SET @FundPoolAdjustment = @Amount;
            END
            ELSE IF @PaymentType = 'Expense'
            BEGIN
                INSERT INTO Expenses (
                    AccountId, Head, Amount, TransDate, CampId,
                    AddedBy, CreatedAt, UpdatedAt
                )
                VALUES (
                    @NewId, @Head, @Amount, @TransDate, @CampId,
                    @AddedBy, GETDATE(), GETDATE()
                );

                -- Expense: Positive subtracts (-), Negative adds (+)
                -- Reverse the sign
                SET @FundPoolAdjustment = -@Amount;
            END

            -- ========================================
            -- 4.2 Update FundPool Balance
            -- ========================================
            IF @FundPool IS NOT NULL AND @FundPool != ''
            BEGIN
                UPDATE FundPools
                SET Balance = Balance + @FundPoolAdjustment,
                    UpdatedAt = GETDATE()
                WHERE Code = @FundPool 
                AND ISNULL(IsDeleted, 0) = 0;

                -- Check if FundPool exists
                IF @@ROWCOUNT = 0
                BEGIN
                    PRINT 'Warning: FundPool with code ' + @FundPool + ' not found or deleted.';
                END
            END

            FETCH NEXT FROM head_cursor INTO @PaymentType, @Amount, @Head;
        END

        CLOSE head_cursor;
        DEALLOCATE head_cursor;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Re-throw the error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

-- =============================================
-- Test Cases
-- =============================================

/*
-- Test 1: Normal Income (Positive) - Should add to FundPool
DECLARE @NewId INT;
DECLARE @Heads AccountMasterHeadType;
INSERT INTO @Heads (PaymentType, Amount, Head) VALUES ('Income', 1000, 'Room Rent');

EXEC sp_CreateAccountMaster
    @TransDate = '2026-09-17',
    @Mode = 'Cash',
    @FundPool = 'POOL001',
    @FundPoolName = 'Main Pool',
    @Nature = 'Regular',
    @RecipientRole = 'Tenant',
    @RecipientName = 'John Doe',
    @Purpose = 'Monthly rent',
    @Heads = @Heads,
    @NewId = @NewId OUTPUT;

SELECT @NewId AS NewAccountId;
-- Expected: FundPool Balance += 1000

-- Test 2: Negative Income (Refund) - Should subtract from FundPool
DECLARE @NewId2 INT;
DECLARE @Heads2 AccountMasterHeadType;
INSERT INTO @Heads2 (PaymentType, Amount, Head) VALUES ('Income', -500, 'Refund');

EXEC sp_CreateAccountMaster
    @TransDate = '2026-09-17',
    @Mode = 'Cash',
    @FundPool = 'POOL001',
    @FundPoolName = 'Main Pool',
    @Nature = 'Reversal',
    @RecipientRole = 'Tenant',
    @RecipientName = 'John Doe',
    @Purpose = 'Refund amount',
    @Heads = @Heads2,
    @NewId = @NewId2 OUTPUT;

SELECT @NewId2 AS NewAccountId;
-- Expected: FundPool Balance -= 500

-- Test 3: Normal Expense (Positive) - Should subtract from FundPool
DECLARE @NewId3 INT;
DECLARE @Heads3 AccountMasterHeadType;
INSERT INTO @Heads3 (PaymentType, Amount, Head) VALUES ('Expense', 800, 'Electricity');

EXEC sp_CreateAccountMaster
    @TransDate = '2026-09-17',
    @Mode = 'Bank',
    @FundPool = 'POOL001',
    @FundPoolName = 'Main Pool',
    @Nature = 'Regular',
    @CampId = 1,
    @RecipientRole = 'Vendor',
    @RecipientName = 'Electric Company',
    @Purpose = 'Monthly bill',
    @Heads = @Heads3,
    @NewId = @NewId3 OUTPUT;

SELECT @NewId3 AS NewAccountId;
-- Expected: FundPool Balance -= 800

-- Test 4: Negative Expense (Reversal) - Should add to FundPool
DECLARE @NewId4 INT;
DECLARE @Heads4 AccountMasterHeadType;
INSERT INTO @Heads4 (PaymentType, Amount, Head) VALUES ('Expense', -300, 'Cancelled Payment');

EXEC sp_CreateAccountMaster
    @TransDate = '2026-09-17',
    @Mode = 'Cash',
    @FundPool = 'POOL001',
    @FundPoolName = 'Main Pool',
    @Nature = 'Reversal',
    @CampId = 1,
    @RecipientRole = 'Vendor',
    @RecipientName = 'Supplier',
    @Purpose = 'Payment cancelled',
    @Heads = @Heads4,
    @NewId = @NewId4 OUTPUT;

SELECT @NewId4 AS NewAccountId;
-- Expected: FundPool Balance += 300
*/
