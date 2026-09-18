-- =============================================
-- Stored Procedure: sp_UpdateAccountMaster
-- Modified: 2026-09-17
-- Purpose: Update Account Master with UPDATED FundPool logic
-- 
-- NEW FundPool Logic:
-- Income Type:  Positive Amount → Add to FundPool (+), Negative Amount → Subtract from FundPool (-)
-- Expense Type: Positive Amount → Subtract from FundPool (-), Negative Amount → Add to FundPool (+)
-- 
-- Update Strategy:
-- 1. Reverse old FundPool adjustments
-- 2. Apply new FundPool adjustments
-- =============================================

ALTER PROCEDURE [dbo].[sp_UpdateAccountMaster]
    @Id             INT,
    @TransDate      DATETIME,
    @Mode           NVARCHAR(100),
    @FundPool       NVARCHAR(50)    = '',
    @FundPoolName   NVARCHAR(200)   = '',
    @Nature         NVARCHAR(50)    = '',
    @CampId         INT             = NULL,
    @CampName       NVARCHAR(200)   = '',
    @RecipientRole  NVARCHAR(100)   = '',
    @RecipientId    INT             = NULL,
    @RecipientName  NVARCHAR(200)   = '',
    @Purpose        NVARCHAR(500)   = '',
    @UpdatedBy      INT             = NULL,
    @Heads          dbo.AccountMasterHeadType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- ========================================
        -- Step 1: Get existing record details
        -- ========================================
        DECLARE @AccountId      NVARCHAR(20);
        DECLARE @VoucherNo      NVARCHAR(100);
        DECLARE @OldFundPool    NVARCHAR(50);

        SELECT @AccountId = AccountId, 
               @VoucherNo = VoucherNo,
               @OldFundPool = FundPool
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END

        -- ========================================
        -- Step 2: Reverse OLD FundPool adjustments
        -- ========================================
        IF @OldFundPool IS NOT NULL AND @OldFundPool != ''
        BEGIN
            DECLARE @OldIncomeTotal  DECIMAL(18,2) = 0;
            DECLARE @OldExpenseTotal DECIMAL(18,2) = 0;

            -- Get old Income totals
            SELECT @OldIncomeTotal = ISNULL(SUM(Amount), 0)
            FROM Incomes
            WHERE AccountId = @AccountId AND IsDeleted = 0;

            -- Get old Expense totals
            SELECT @OldExpenseTotal = ISNULL(SUM(Amount), 0)
            FROM Expenses
            WHERE AccountId = @AccountId AND IsDeleted = 0;

            -- Calculate old adjustment (using NEW logic)
            DECLARE @OldAdjustment DECIMAL(18,2);
            -- Income adds, Expense subtracts
            SET @OldAdjustment = @OldIncomeTotal - @OldExpenseTotal;

            -- REVERSE the old adjustment
            UPDATE FundPools
            SET Balance = ISNULL(Balance, 0) - @OldAdjustment,
                UpdatedAt = GETDATE()
            WHERE Code = @OldFundPool
              AND ISNULL(IsDeleted, 0) = 0;

            PRINT 'Old FundPool Adjustment Reversed: ' + CAST(-@OldAdjustment AS NVARCHAR(50));
        END

        -- ========================================
        -- Step 3: Calculate new totals & PaymentType
        -- ========================================
        DECLARE @TotalAmount  DECIMAL(18,2);
        DECLARE @PaymentType  NVARCHAR(20);
        DECLARE @IncomeCount  INT;
        DECLARE @ExpenseCount INT;

        SELECT @TotalAmount  = ISNULL(SUM(Amount), 0) FROM @Heads;
        SELECT @IncomeCount  = COUNT(*) FROM @Heads WHERE PaymentType = 'Income';
        SELECT @ExpenseCount = COUNT(*) FROM @Heads WHERE PaymentType = 'Expense';

        SET @PaymentType = CASE
            WHEN @IncomeCount  > 0 AND @ExpenseCount = 0 THEN 'Income'
            WHEN @ExpenseCount > 0 AND @IncomeCount  = 0 THEN 'Expense'
            ELSE 'Mixed'
        END;

        -- ========================================
        -- Step 4: UPDATE AccountMasters
        -- ========================================
        UPDATE AccountMasters SET
            TransDate     = @TransDate,
            PaymentType   = @PaymentType,
            Mode          = @Mode,
            FundPool      = @FundPool,
            FundPoolName  = @FundPoolName,
            Amount        = @TotalAmount,
            Nature        = @Nature,
            RecipientRole = @RecipientRole,
            RecipientId   = @RecipientId,
            RecipientName = @RecipientName,
            Purpose       = @Purpose,
            UpdatedBy     = @UpdatedBy,
            UpdatedAt     = GETDATE()
        WHERE Id = @Id;

        -- ========================================
        -- Step 5: Soft-delete old linked records
        -- ========================================
        UPDATE Incomes
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        UPDATE Expenses
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        -- ========================================
        -- Step 6: Re-insert new Heads
        -- ========================================
        DECLARE @HeadPaymentType2 NVARCHAR(20);
        DECLARE @HeadHead2        NVARCHAR(200);
        DECLARE @HeadAmount2      DECIMAL(18,2);
        DECLARE @HeadPurpose2     NVARCHAR(500);

        DECLARE head_cursor2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

        OPEN head_cursor2;
        FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @HeadPaymentType2 = 'Income'
            BEGIN
                DECLARE @IncomeId2 NVARCHAR(20);
                SELECT @IncomeId2 = 'INC-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Incomes;

                INSERT INTO Incomes (
                    IncomeId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Purpose, Source, SourceRef,
                    CampId, CampName, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @IncomeId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName,
                    @HeadAmount2, ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), 'Manual', '',
                    @CampId, @CampName, @AccountId, @VoucherNo, @TransDate,
                    @UpdatedBy, 0, GETDATE(), GETDATE()
                );
            END
            ELSE IF @HeadPaymentType2 = 'Expense'
            BEGIN
                DECLARE @ExpenseId2 NVARCHAR(20);
                SELECT @ExpenseId2 = 'EXP-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Expenses;

                INSERT INTO Expenses (
                    ExpenseId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Nature, CampId, CampName,
                    RecipientRole, RecipientId, RecipientName,
                    Purpose, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @ExpenseId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName,
                    @HeadAmount2, @Nature, @CampId, @CampName,
                    @RecipientRole, @RecipientId, @RecipientName,
                    ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), @AccountId, @VoucherNo, @TransDate,
                    @UpdatedBy, 0, GETDATE(), GETDATE()
                );
            END

            FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;
        END

        CLOSE head_cursor2;
        DEALLOCATE head_cursor2;

        -- ========================================
        -- Step 7: Sync PartnerTrans if Role = 'Partner'
        -- ========================================
        IF @RecipientRole = 'Partner'
           AND @RecipientId IS NOT NULL
           AND @RecipientId > 0
        BEGIN
            -- Soft-delete old PartnerTrans linked to this AccountId
            UPDATE PartnerTrans
            SET IsDeleted = 1, UpdatedAt = GETDATE()
            WHERE AccountId = @AccountId AND IsDeleted = 0;

            -- Re-insert updated heads
            DECLARE @HeadPaymentTypeP2 NVARCHAR(20);
            DECLARE @HeadHeadP2        NVARCHAR(200);
            DECLARE @HeadAmountP2      DECIMAL(18,2);
            DECLARE @HeadPurposeP2     NVARCHAR(500);

            DECLARE partner_cursor2 CURSOR LOCAL FAST_FORWARD FOR
                SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

            OPEN partner_cursor2;
            FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO PartnerTrans (
                    PartnerId, PaymentMode, [Type], AccountHead,
                    Amount, AccountId, Remark,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @RecipientId,
                    @Mode,
                    @HeadPaymentTypeP2,
                    @HeadHeadP2,
                    @HeadAmountP2,
                    @AccountId,
                    ISNULL(NULLIF(@HeadPurposeP2,''), @Purpose),
                    @UpdatedBy,
                    0,
                    GETDATE(),
                    GETDATE()
                );

                FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;
            END

            CLOSE partner_cursor2;
            DEALLOCATE partner_cursor2;
        END
        ELSE
        BEGIN
            -- Role changed (was Partner, now something else) → soft-delete old records
            UPDATE PartnerTrans
            SET IsDeleted = 1, UpdatedAt = GETDATE()
            WHERE AccountId = @AccountId AND IsDeleted = 0;
        END

        -- ========================================
        -- Step 8: Apply NEW FundPool adjustments
        -- ========================================
        IF @FundPool IS NOT NULL AND @FundPool != ''
        BEGIN
            DECLARE @NewFundPoolAdjustment DECIMAL(18,2) = 0;
            DECLARE @NewHeadAmount DECIMAL(18,2);
            DECLARE @NewHeadType NVARCHAR(20);

            -- Calculate new adjustments based on new heads
            DECLARE newfundpool_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT PaymentType, Amount FROM @Heads;

            OPEN newfundpool_cursor;
            FETCH NEXT FROM newfundpool_cursor INTO @NewHeadType, @NewHeadAmount;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @NewHeadType = 'Income'
                BEGIN
                    -- Income: Positive adds (+), Negative subtracts (-)
                    SET @NewFundPoolAdjustment = @NewFundPoolAdjustment + @NewHeadAmount;
                END
                ELSE IF @NewHeadType = 'Expense'
                BEGIN
                    -- Expense: Positive subtracts (-), Negative adds (+)
                    SET @NewFundPoolAdjustment = @NewFundPoolAdjustment - @NewHeadAmount;
                END

                FETCH NEXT FROM newfundpool_cursor INTO @NewHeadType, @NewHeadAmount;
            END

            CLOSE newfundpool_cursor;
            DEALLOCATE newfundpool_cursor;

            -- Apply the new adjustment
            UPDATE FundPools
            SET Balance = ISNULL(Balance, 0) + @NewFundPoolAdjustment,
                UpdatedAt = GETDATE()
            WHERE Code = @FundPool
              AND ISNULL(IsDeleted, 0) = 0;

            PRINT 'New FundPool Adjustment Applied: ' + CAST(@NewFundPoolAdjustment AS NVARCHAR(50));
        END

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Cleanup cursors if still open
        IF CURSOR_STATUS('local','head_cursor2') >= 0
        BEGIN
            CLOSE head_cursor2;
            DEALLOCATE head_cursor2;
        END
        
        IF CURSOR_STATUS('local','partner_cursor2') >= 0
        BEGIN
            CLOSE partner_cursor2;
            DEALLOCATE partner_cursor2;
        END
        
        IF CURSOR_STATUS('local','newfundpool_cursor') >= 0
        BEGIN
            CLOSE newfundpool_cursor;
            DEALLOCATE newfundpool_cursor;
        END

        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================
-- DEPLOYMENT INSTRUCTIONS
-- =============================================
/*
1. Backup current procedure:
   EXEC sp_helptext 'sp_UpdateAccountMaster'
   -- Save output to file

2. Execute this ALTER statement in your database

3. Test update scenarios:
   - Update from positive to negative income
   - Update from positive to negative expense
   - Change FundPool
   - Verify FundPool balances are correctly adjusted

4. Monitor the PRINT statements in SQL Server Messages tab for debugging
*/
