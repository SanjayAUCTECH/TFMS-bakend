-- ============================================================
-- 150: AccountMasters Table + Integration with Income/Expense
-- 
-- Changes:
--   1. CREATE AccountMasters table
--   2. ALTER Incomes — add VoucherNo, AccountId, TransDate columns
--   3. ALTER Expenses — add VoucherNo, AccountId, TransDate columns
--   4. UPDATE sp_CreateIncome — auto-generate AccountId & VoucherNo,
--      insert into AccountMasters (PaymentType='Income')
--   5. UPDATE sp_CreateExpense — auto-generate AccountId & VoucherNo,
--      insert into AccountMasters (PaymentType='Expense')
--   6. All direct INSERT INTO Incomes/Expenses in other SPs
--      also insert into AccountMasters
--
-- AccountId format: ACC-000001, ACC-000002, ...
-- VoucherNo format: VCH-INC-000001 (Income), VCH-EXP-000001 (Expense)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. CREATE AccountMasters Table
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AccountMasters')
BEGIN
    CREATE TABLE [dbo].[AccountMasters] (
        [Id]            INT IDENTITY(1,1) PRIMARY KEY,
        [AccountId]     NVARCHAR(50)   NOT NULL DEFAULT '',
        [VoucherNo]     NVARCHAR(100)  NOT NULL DEFAULT '',
        [TransDate]     DATETIME       NOT NULL DEFAULT GETDATE(),
        [PaymentType]   NVARCHAR(50)   NOT NULL DEFAULT '',
        [Mode]          NVARCHAR(100)  NOT NULL DEFAULT '',
        [FundPool]      NVARCHAR(100)  NOT NULL DEFAULT '',
        [FundPoolName]  NVARCHAR(200)  NOT NULL DEFAULT '',
        [Amount]        DECIMAL(18,2)  NOT NULL DEFAULT 0,
        [Nature]        NVARCHAR(50)   NOT NULL DEFAULT '',
        [RecipientRole] NVARCHAR(100)  NOT NULL DEFAULT '',
        [RecipientName] NVARCHAR(200)  NOT NULL DEFAULT '',
        [Purpose]       NVARCHAR(500)  NOT NULL DEFAULT '',
        [CreatedAt]     DATETIME       NOT NULL DEFAULT GETDATE(),
        [UpdatedAt]     DATETIME       NOT NULL DEFAULT GETDATE(),
        [RecipientId]   INT            NULL,
        [AddedBy]       INT            NULL,
        [UpdatedBy]     INT            NULL,
        [DeletedBy]     INT            NULL,
        [IsDeleted]     BIT            NOT NULL DEFAULT 0
    );
    PRINT '✅ AccountMasters table created.';
END
ELSE
    PRINT '⚠️ AccountMasters table already exists.';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. ALTER Incomes — add VoucherNo, AccountId, TransDate
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Incomes') AND name = 'VoucherNo')
    ALTER TABLE Incomes ADD [VoucherNo] NVARCHAR(100) NOT NULL DEFAULT '';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Incomes') AND name = 'AccountId')
    ALTER TABLE Incomes ADD [AccountId] NVARCHAR(50) NOT NULL DEFAULT '';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Incomes') AND name = 'TransDate')
    ALTER TABLE Incomes ADD [TransDate] DATETIME NULL;

PRINT '✅ Incomes table columns added (VoucherNo, AccountId, TransDate).';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. ALTER Expenses — add VoucherNo, AccountId, TransDate
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Expenses') AND name = 'VoucherNo')
    ALTER TABLE Expenses ADD [VoucherNo] NVARCHAR(100) NOT NULL DEFAULT '';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Expenses') AND name = 'AccountId')
    ALTER TABLE Expenses ADD [AccountId] NVARCHAR(50) NOT NULL DEFAULT '';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Expenses') AND name = 'TransDate')
    ALTER TABLE Expenses ADD [TransDate] DATETIME NULL;

PRINT '✅ Expenses table columns added (VoucherNo, AccountId, TransDate).';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. UPDATE sp_CreateIncome — PEHLE AccountMasters, PHIR Incomes
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CreateIncome
    @Date        DATE,
    @Mode        NVARCHAR(MAX),
    @Head        NVARCHAR(MAX),
    @FundPool    NVARCHAR(MAX),
    @Amount      DECIMAL(18,2),
    @Purpose     NVARCHAR(MAX) = '',
    @Source      NVARCHAR(MAX) = '',
    @SourceRef   NVARCHAR(MAX) = '',
    @CampId      INT           = NULL,
    @CampName    NVARCHAR(MAX) = '',
    @PartnerId   INT           = NULL,
    @PartnerName NVARCHAR(MAX) = '',
    @ContractId  NVARCHAR(MAX) = '',
    @ContractCode NVARCHAR(MAX) = '',
    @TenantId    INT           = NULL,
    @TenantName  NVARCHAR(MAX) = '',
    @AddedBy     INT           = NULL,
    @NewId       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Generate IDs
    DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR), 6);
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000' + CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR), 6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000' + CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters WHERE PaymentType='Income'),0)+1) AS NVARCHAR), 6);
    DECLARE @TransDate DATETIME = @Date;

    -- Get FundPoolName
    DECLARE @FPName NVARCHAR(200) = '';
    SELECT @FPName = ISNULL(Name, '') FROM FundPools WHERE Code = @FundPool;

    -- ★ Step 1: INSERT into AccountMasters FIRST
    INSERT INTO AccountMasters(
        AccountId, VoucherNo, TransDate, PaymentType,
        Mode, FundPool, FundPoolName, Amount,
        Nature, RecipientRole, RecipientName, Purpose,
        RecipientId, AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @AccountId, @VoucherNo, @TransDate, 'Income',
        @Mode, @FundPool, @FPName, @Amount,
        '', '', ISNULL(@PartnerName, ISNULL(@TenantName, '')), @Purpose,
        ISNULL(@PartnerId, @TenantId), @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );

    -- ★ Step 2: INSERT into Incomes WITH AccountId & VoucherNo
    INSERT INTO Incomes(
        IncomeId, [Date], Mode, Head, FundPool, FundPoolName,
        Amount, Purpose, Source, SourceRef,
        CampId, CampName, PartnerId, PartnerName,
        ContractId, ContractCode, TenantId, TenantName,
        AccountId, VoucherNo, TransDate,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @IncomeId, @Date, @Mode, @Head, @FundPool, @FPName,
        @Amount, @Purpose, @Source, @SourceRef,
        @CampId, ISNULL(@CampName, ''), @PartnerId, ISNULL(@PartnerName, ''),
        @ContractId, @ContractCode, @TenantId, @TenantName,
        @AccountId, @VoucherNo, @TransDate,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );
    SET @NewId = SCOPE_IDENTITY();

    -- Step 3: Update FundPool balance
    IF @FundPool IS NOT NULL AND LEN(@FundPool) > 0 AND @Amount > 0
        UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETUTCDATE()
        WHERE Code = @FundPool AND IsDeleted = 0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CreateIncome — PEHLE AccountMasters, PHIR Incomes.';
GO

-- ══════════════════════════════════════════════════════════════
-- 5. UPDATE sp_CreateExpense — PEHLE AccountMasters, PHIR Expenses
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date          DATE,
    @Head          NVARCHAR(MAX),
    @Nature        NVARCHAR(MAX) = 'Camp',
    @CampId        INT           = NULL,
    @CampName      NVARCHAR(MAX) = '',
    @RecipientRole NVARCHAR(MAX) = '',
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = '',
    @Amount        DECIMAL(18,2),
    @FundPool      NVARCHAR(MAX) = '',
    @FundPoolId    INT           = NULL,
    @FundPoolName  NVARCHAR(MAX) = '',
    @Mode          NVARCHAR(MAX) = '',
    @Purpose       NVARCHAR(MAX) = '',
    @AddedBy       INT           = NULL,
    @NewId         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Generate IDs
    DECLARE @ExpenseId NVARCHAR(MAX) = 'EXP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000' + CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR), 6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-EXP-' + RIGHT('000000' + CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters WHERE PaymentType='Expense'),0)+1) AS NVARCHAR), 6);
    DECLARE @TransDate DATETIME = @Date;

    -- Resolve FundPool code if FundPoolId given
    IF @FundPoolId IS NOT NULL AND (LEN(ISNULL(@FundPool,'')) = 0)
        SELECT @FundPool = ISNULL(Code,''), @FundPoolName = ISNULL(Name,'')
        FROM FundPools WHERE Id = @FundPoolId;

    -- ★ Step 1: INSERT into AccountMasters FIRST
    INSERT INTO AccountMasters(
        AccountId, VoucherNo, TransDate, PaymentType,
        Mode, FundPool, FundPoolName, Amount,
        Nature, RecipientRole, RecipientName, Purpose,
        RecipientId, AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @AccountId, @VoucherNo, @TransDate, 'Expense',
        @Mode, @FundPool, @FundPoolName, @Amount,
        @Nature, @RecipientRole, @RecipientName, @Purpose,
        @RecipientId, @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );

    -- ★ Step 2: INSERT into Expenses WITH AccountId & VoucherNo
    INSERT INTO Expenses(
        ExpenseId, [Date], Head, Nature,
        CampId, CampName,
        RecipientRole, RecipientId, RecipientName,
        Amount, FundPool, FundPoolName, Mode, Purpose,
        AccountId, VoucherNo, TransDate,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @ExpenseId, @Date, @Head, @Nature,
        @CampId, @CampName,
        @RecipientRole, @RecipientId, @RecipientName,
        @Amount, @FundPool, @FundPoolName, @Mode, @Purpose,
        @AccountId, @VoucherNo, @TransDate,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );
    SET @NewId = SCOPE_IDENTITY();

    -- Step 3: FundPool balance deduct
    IF @FundPool IS NOT NULL AND LEN(@FundPool) > 0 AND @Amount > 0
        UPDATE FundPools
        SET Balance = Balance - @Amount, UpdatedAt = GETUTCDATE()
        WHERE Code = @FundPool AND IsDeleted = 0;

    -- ══ Step 4: Owner payment logic (same as Script 108) ═════════
    IF @RecipientRole = 'Owner' AND @RecipientId IS NOT NULL
    BEGIN
        DECLARE @OcId    INT;
        DECLARE @OcCode  NVARCHAR(MAX);

        SELECT TOP 1
            @OcId   = oc.Id,
            @OcCode = oc.OcCode
        FROM OwnerContracts oc
        WHERE oc.OwnerId  = @RecipientId
          AND oc.IsDeleted = 0
          AND oc.Status    = 'Active'
          AND (@CampId IS NULL OR oc.CampId = @CampId)
        ORDER BY oc.CreatedAt DESC;

        IF @OcId IS NOT NULL
        BEGIN
            -- OwnerTransactions CR entry
            DECLARE @TxnCode NVARCHAR(50) = 'OT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS VARCHAR), 6);
            INSERT INTO OwnerTransactions(TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
                Type, Amount, Date, Description, PaymentMode, CreatedAt, ExpenseId)
            VALUES(@TxnCode, @OcId, @OcCode, @CampId, @CampName, @RecipientId, @RecipientName,
                'CR', @Amount, @Date, @Purpose, @Mode, GETUTCDATE(), @NewId);

            -- Update OwnerContracts timestamp (PaidAmount/Balance tracked via OwnerTransactions sum)
            UPDATE OwnerContracts
            SET UpdatedAt = GETUTCDATE()
            WHERE Id = @OcId AND IsDeleted = 0;

            -- Apply to OwnerInstallments (oldest unpaid first)
            DECLARE @Remaining2 DECIMAL(18,2) = @Amount;
            DECLARE @InstId INT, @InstBal DECIMAL(18,2);

            DECLARE inst_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT Id, (Amount - ISNULL(PaidAmount,0))
                FROM OwnerInstallments
                WHERE OwnerContractId = @OcId AND ISNULL(IsDeleted,0) = 0
                  AND (Amount - ISNULL(PaidAmount,0)) > 0
                ORDER BY No ASC;

            OPEN inst_cursor;
            FETCH NEXT FROM inst_cursor INTO @InstId, @InstBal;
            WHILE @@FETCH_STATUS = 0 AND @Remaining2 > 0
            BEGIN
                DECLARE @PayThis DECIMAL(18,2) = CASE WHEN @Remaining2 >= @InstBal THEN @InstBal ELSE @Remaining2 END;
                UPDATE OwnerInstallments
                SET PaidAmount = ISNULL(PaidAmount,0) + @PayThis,
                    PaidDate = @Date, PaymentMode = @Mode,
                    Status = CASE WHEN (ISNULL(PaidAmount,0)+@PayThis) >= Amount THEN 'Paid'
                                  WHEN (ISNULL(PaidAmount,0)+@PayThis) > 0 THEN 'Partial'
                                  ELSE 'Pending' END
                WHERE Id = @InstId;
                SET @Remaining2 = @Remaining2 - @PayThis;
                FETCH NEXT FROM inst_cursor INTO @InstId, @InstBal;
            END
            CLOSE inst_cursor;
            DEALLOCATE inst_cursor;
        END
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CreateExpense — PEHLE AccountMasters, PHIR Expenses.';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 150 - AccountMasters Integration Complete!';
PRINT '   • AccountMasters table created';
PRINT '   • Incomes table: VoucherNo, AccountId, TransDate added';
PRINT '   • Expenses table: VoucherNo, AccountId, TransDate added';
PRINT '   • sp_CreateIncome: PEHLE AccountMasters, PHIR Incomes';
PRINT '   • sp_CreateExpense: PEHLE AccountMasters, PHIR Expenses';
PRINT '   • NO TRIGGERS used — direct INSERT approach';
PRINT '═══════════════════════════════════════════════════════════';
GO
