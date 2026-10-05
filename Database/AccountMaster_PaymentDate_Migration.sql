-- ═══════════════════════════════════════════════════════════════════
-- AccountMaster PaymentDate Column Addition & Stored Procedures Update
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- STEP 1: Add PaymentDate column to AccountMasters table
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'dbo.AccountMasters') 
    AND name = 'PaymentDate'
)
BEGIN
    ALTER TABLE dbo.AccountMasters
    ADD PaymentDate DATETIME NULL;
    
    PRINT '✓ PaymentDate column added to AccountMasters table';
END
ELSE
BEGIN
    PRINT '• PaymentDate column already exists in AccountMasters table';
END
GO

-- ─────────────────────────────────────────────────────────────────
-- STEP 2: Update sp_CreateAccountMaster
-- ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.sp_CreateAccountMaster', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateAccountMaster;
GO

CREATE PROCEDURE dbo.sp_CreateAccountMaster
(
    @TransDate      DATETIME,
    @PaymentDate    DATETIME        = NULL,
    @Mode           NVARCHAR(100)   = '',
    @VoucherNo      NVARCHAR(100)   = NULL,
    @FundPool       NVARCHAR(50)    = '',
    @FundPoolName   NVARCHAR(200)   = '',
    @Nature         NVARCHAR(50)    = '',
    @CampId         INT             = NULL,
    @CampName       NVARCHAR(200)   = '',
    @RecipientRole  NVARCHAR(100)   = '',
    @RecipientId    INT             = NULL,
    @RecipientName  NVARCHAR(200)   = '',
    @Purpose        NVARCHAR(MAX)   = '',
    @AddedBy        INT             = NULL,
    @Heads          dbo.AccountMasterHeadType READONLY,
    @NewId          INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Generate unique AccountId ──
        DECLARE @accountId NVARCHAR(50);
        DECLARE @seq INT;
        DECLARE @attempt INT = 0;
        WHILE 1=1
        BEGIN
            SET @seq = NEXT VALUE FOR seq_AccountMaster;
            SET @accountId = 'ACC' + RIGHT('000000' + CAST(@seq AS NVARCHAR), 6);
            IF NOT EXISTS(SELECT 1 FROM AccountMasters WHERE AccountId=@accountId)
                BREAK;
            SET @attempt = @attempt + 1;
            IF @attempt > 10
                RAISERROR('Failed to generate unique AccountId after 10 attempts.', 16, 1);
        END;

        -- ── 2. Generate or validate VoucherNo ──
        DECLARE @voucherNoFinal NVARCHAR(100);
        IF @VoucherNo IS NULL OR LTRIM(RTRIM(@VoucherNo)) = ''
        BEGIN
            -- Auto-generate unique VoucherNo
            DECLARE @vseq INT;
            DECLARE @vattempt INT = 0;
            WHILE 1=1
            BEGIN
                SET @vseq = NEXT VALUE FOR seq_VoucherNo;
                SET @voucherNoFinal = 'V' + FORMAT(GETDATE(), 'yyyyMMdd') + '-' + RIGHT('00000' + CAST(@vseq AS NVARCHAR), 5);
                IF NOT EXISTS(SELECT 1 FROM AccountMasters WHERE VoucherNo=@voucherNoFinal)
                    BREAK;
                SET @vattempt = @vattempt + 1;
                IF @vattempt > 10
                    RAISERROR('Failed to generate unique VoucherNo after 10 attempts.', 16, 1);
            END;
        END
        ELSE
        BEGIN
            SET @voucherNoFinal = LTRIM(RTRIM(@VoucherNo));
            -- Check if VoucherNo already exists
            IF EXISTS(SELECT 1 FROM AccountMasters WHERE VoucherNo=@voucherNoFinal)
                RAISERROR('VOUCHER_EXISTS', 16, 1);
        END;

        -- ── 3. Compute total amount ──
        DECLARE @totalAmount DECIMAL(18,2) = 0;
        SELECT @totalAmount = SUM(Amount) FROM @Heads;

        -- ── 4. Determine PaymentType (first head item) ──
        DECLARE @paymentType NVARCHAR(50) = '';
        SELECT TOP 1 @paymentType = PaymentType FROM @Heads ORDER BY PaymentType;

        -- ── 5. Insert AccountMaster record ──
        INSERT INTO AccountMasters (
            AccountId, VoucherNo, TransDate, PaymentDate, PaymentType, 
            Mode, FundPool, FundPoolName, Amount, 
            Nature, CampId, CampName, 
            RecipientRole, RecipientId, RecipientName, Purpose, 
            CreatedAt, UpdatedAt, AddedBy, IsDeleted
        )
        VALUES (
            @accountId, @voucherNoFinal, @TransDate, @PaymentDate, @paymentType, 
            @Mode, @FundPool, @FundPoolName, @totalAmount, 
            @Nature, @CampId, @CampName, 
            @RecipientRole, @RecipientId, @RecipientName, @Purpose, 
            GETDATE(), GETDATE(), @AddedBy, 0
        );

        SET @NewId = SCOPE_IDENTITY();

        -- ── 6. Insert Heads → Incomes or Expenses ──
        -- Income heads
        INSERT INTO Incomes (
            IncomeId, AccountId, Head, Amount, Purpose, 
            Date, TransDate, Mode, FundPool, FundPoolName, 
            Nature, CampId, CampName, 
            RecipientRole, RecipientId, RecipientName, 
            CreatedAt, UpdatedAt, AddedBy, IsDeleted
        )
        SELECT 
            CONCAT('INC', @accountId, '-', ROW_NUMBER() OVER(ORDER BY (SELECT NULL))),
            @accountId,
            Head, Amount, Purpose,
            @TransDate, @TransDate, @Mode, @FundPool, @FundPoolName,
            @Nature, @CampId, @CampName,
            @RecipientRole, @RecipientId, @RecipientName,
            GETDATE(), GETDATE(), @AddedBy, 0
        FROM @Heads
        WHERE PaymentType = 'Income';

        -- Expense heads
        INSERT INTO Expenses (
            ExpenseId, AccountId, Head, Amount, Purpose, 
            Date, TransDate, Mode, FundPool, FundPoolName, 
            Nature, CampId, CampName, 
            RecipientRole, RecipientId, RecipientName, 
            CreatedAt, UpdatedAt, AddedBy, IsDeleted
        )
        SELECT 
            CONCAT('EXP', @accountId, '-', ROW_NUMBER() OVER(ORDER BY (SELECT NULL))),
            @accountId,
            Head, Amount, Purpose,
            @TransDate, @TransDate, @Mode, @FundPool, @FundPoolName,
            @Nature, @CampId, @CampName,
            @RecipientRole, @RecipientId, @RecipientName,
            GETDATE(), GETDATE(), @AddedBy, 0
        FROM @Heads
        WHERE PaymentType = 'Expense';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '✓ sp_CreateAccountMaster procedure updated with PaymentDate parameter';
GO

-- ─────────────────────────────────────────────────────────────────
-- STEP 3: Update sp_UpdateAccountMaster
-- ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.sp_UpdateAccountMaster', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateAccountMaster;
GO

CREATE PROCEDURE dbo.sp_UpdateAccountMaster
(
    @Id             INT,
    @TransDate      DATETIME,
    @PaymentDate    DATETIME        = NULL,
    @Mode           NVARCHAR(100)   = '',
    @FundPool       NVARCHAR(50)    = '',
    @FundPoolName   NVARCHAR(200)   = '',
    @Nature         NVARCHAR(50)    = '',
    @CampId         INT             = NULL,
    @CampName       NVARCHAR(200)   = '',
    @RecipientRole  NVARCHAR(100)   = '',
    @RecipientId    INT             = NULL,
    @RecipientName  NVARCHAR(200)   = '',
    @Purpose        NVARCHAR(MAX)   = '',
    @UpdatedBy      INT             = NULL,
    @Heads          dbo.AccountMasterHeadType READONLY
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Check if record exists ──
        DECLARE @accountId NVARCHAR(50);
        SELECT @accountId = AccountId
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @accountId IS NULL
            RAISERROR('RECORD_NOT_FOUND', 16, 1);

        -- ── 2. Compute total amount ──
        DECLARE @totalAmount DECIMAL(18,2) = 0;
        SELECT @totalAmount = SUM(Amount) FROM @Heads;

        -- ── 3. Determine PaymentType (first head item) ──
        DECLARE @paymentType NVARCHAR(50) = '';
        SELECT TOP 1 @paymentType = PaymentType FROM @Heads ORDER BY PaymentType;

        -- ── 4. Update AccountMaster record ──
        UPDATE AccountMasters
        SET 
            TransDate     = @TransDate,
            PaymentDate   = @PaymentDate,
            PaymentType   = @paymentType,
            Mode          = @Mode,
            FundPool      = @FundPool,
            FundPoolName  = @FundPoolName,
            Amount        = @totalAmount,
            Nature        = @Nature,
            CampId        = @CampId,
            CampName      = @CampName,
            RecipientRole = @RecipientRole,
            RecipientId   = @RecipientId,
            RecipientName = @RecipientName,
            Purpose       = @Purpose,
            UpdatedAt     = GETDATE(),
            UpdatedBy     = @UpdatedBy
        WHERE Id = @Id;

        -- ── 5. Delete existing heads ──
        UPDATE Incomes  SET IsDeleted=1, UpdatedAt=GETDATE(), UpdatedBy=@UpdatedBy WHERE AccountId=@accountId;
        UPDATE Expenses SET IsDeleted=1, UpdatedAt=GETDATE(), UpdatedBy=@UpdatedBy WHERE AccountId=@accountId;

        -- ── 6. Insert new Heads ──
        -- Income heads
        INSERT INTO Incomes (
            IncomeId, AccountId, Head, Amount, Purpose, 
            Date, TransDate, Mode, FundPool, FundPoolName, 
            Nature, CampId, CampName, 
            RecipientRole, RecipientId, RecipientName, 
            CreatedAt, UpdatedAt, AddedBy, IsDeleted
        )
        SELECT 
            CONCAT('INC', @accountId, '-', ROW_NUMBER() OVER(ORDER BY (SELECT NULL))),
            @accountId,
            Head, Amount, Purpose,
            @TransDate, @TransDate, @Mode, @FundPool, @FundPoolName,
            @Nature, @CampId, @CampName,
            @RecipientRole, @RecipientId, @RecipientName,
            GETDATE(), GETDATE(), @UpdatedBy, 0
        FROM @Heads
        WHERE PaymentType = 'Income';

        -- Expense heads
        INSERT INTO Expenses (
            ExpenseId, AccountId, Head, Amount, Purpose, 
            Date, TransDate, Mode, FundPool, FundPoolName, 
            Nature, CampId, CampName, 
            RecipientRole, RecipientId, RecipientName, 
            CreatedAt, UpdatedAt, AddedBy, IsDeleted
        )
        SELECT 
            CONCAT('EXP', @accountId, '-', ROW_NUMBER() OVER(ORDER BY (SELECT NULL))),
            @accountId,
            Head, Amount, Purpose,
            @TransDate, @TransDate, @Mode, @FundPool, @FundPoolName,
            @Nature, @CampId, @CampName,
            @RecipientRole, @RecipientId, @RecipientName,
            GETDATE(), GETDATE(), @UpdatedBy, 0
        FROM @Heads
        WHERE PaymentType = 'Expense';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '✓ sp_UpdateAccountMaster procedure updated with PaymentDate parameter';
GO

-- ─────────────────────────────────────────────────────────────────
-- STEP 4: sp_DeleteAccountMaster (No changes needed, just recreate)
-- ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.sp_DeleteAccountMaster', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_DeleteAccountMaster;
GO

CREATE PROCEDURE dbo.sp_DeleteAccountMaster
(
    @Id         INT,
    @DeletedBy  INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Check if record exists ──
        DECLARE @accountId NVARCHAR(50);
        SELECT @accountId = AccountId
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @accountId IS NULL
            RAISERROR('RECORD_NOT_FOUND', 16, 1);

        -- ── 2. Soft delete AccountMaster ──
        UPDATE AccountMasters
        SET IsDeleted  = 1,
            UpdatedAt  = GETDATE(),
            DeletedBy  = @DeletedBy
        WHERE Id = @Id;

        -- ── 3. Soft delete associated heads ──
        UPDATE Incomes
        SET IsDeleted  = 1,
            UpdatedAt  = GETDATE(),
            UpdatedBy  = @DeletedBy
        WHERE AccountId = @accountId;

        UPDATE Expenses
        SET IsDeleted  = 1,
            UpdatedAt  = GETDATE(),
            UpdatedBy  = @DeletedBy
        WHERE AccountId = @accountId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '✓ sp_DeleteAccountMaster procedure recreated';
GO

-- ─────────────────────────────────────────────────────────────────
-- MIGRATION COMPLETE
-- ─────────────────────────────────────────────────────────────────
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'AccountMaster PaymentDate Migration Completed Successfully!';
PRINT '═══════════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'Changes Applied:';
PRINT '  1. PaymentDate column added to AccountMasters table';
PRINT '  2. sp_CreateAccountMaster updated with @PaymentDate parameter';
PRINT '  3. sp_UpdateAccountMaster updated with @PaymentDate parameter';
PRINT '  4. sp_DeleteAccountMaster recreated';
PRINT '';
PRINT 'Next Steps:';
PRINT '  - Restart your backend API';
PRINT '  - Test the API endpoints with PaymentDate in payload';
PRINT '  - Use PaymentDateFrom and PaymentDateTo filters in GET requests';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
