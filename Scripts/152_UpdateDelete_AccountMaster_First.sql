-- ============================================================
-- 152: Update & Delete SPs — AccountMasters FIRST Pattern
-- 
-- ONLY for Account Management module (Income/Expense pages):
--   1. sp_UpdateIncome → Pehle AccountMasters UPDATE, phir Income UPDATE
--   2. sp_DeleteIncome → Pehle AccountMasters IsDeleted=1, phir Income IsDeleted=1
--   3. sp_UpdateExpense → Pehle AccountMasters UPDATE, phir Expense UPDATE
--   4. sp_DeleteExpense → Pehle AccountMasters IsDeleted=1, phir Expense IsDeleted=1
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. sp_UpdateIncome — AccountMasters UPDATE FIRST
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateIncome
    @Id          INT,
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
    @UpdatedBy   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2), @OldPool NVARCHAR(MAX), @AccountId NVARCHAR(50);

    SELECT @OldAmount=Amount, @OldPool=FundPool, @AccountId=ISNULL(AccountId,'')
    FROM Incomes WHERE Id=@Id;

    -- Get FundPoolName
    DECLARE @FPName NVARCHAR(200) = '';
    SELECT @FPName = ISNULL(Name,'') FROM FundPools WHERE Code=@FundPool;

    -- ★ Step 1: UPDATE AccountMasters FIRST (if AccountId exists)
    IF @AccountId != ''
    BEGIN
        UPDATE AccountMasters
        SET TransDate=@Date, Mode=@Mode, FundPool=@FundPool, FundPoolName=@FPName,
            Amount=@Amount, Purpose=@Purpose,
            RecipientName=ISNULL(@PartnerName,''),
            RecipientId=@PartnerId,
            UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
        WHERE AccountId=@AccountId AND IsDeleted=0;
    END

    -- ★ Step 2: UPDATE Income
    UPDATE Incomes SET
        [Date]=@Date, Mode=@Mode, Head=@Head, FundPool=@FundPool, FundPoolName=@FPName,
        Amount=@Amount, Purpose=@Purpose, Source=@Source, SourceRef=@SourceRef,
        CampId=@CampId, CampName=ISNULL(@CampName,''),
        PartnerId=@PartnerId, PartnerName=ISNULL(@PartnerName,''),
        TransDate=@Date, UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- Step 3: FundPool balance adjust (revert old, apply new)
    IF @OldPool IS NOT NULL AND @OldPool != '' AND @OldAmount > 0
        UPDATE FundPools SET Balance=Balance-@OldAmount, UpdatedAt=GETUTCDATE() WHERE Code=@OldPool AND IsDeleted=0;
    IF @FundPool IS NOT NULL AND @FundPool != '' AND @Amount > 0
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE() WHERE Code=@FundPool AND IsDeleted=0;
END
GO

PRINT '✅ sp_UpdateIncome — AccountMasters UPDATE FIRST, then Income UPDATE.';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_DeleteIncome — AccountMasters DELETE FIRST
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_DeleteIncome
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(18,2), @FundPool NVARCHAR(MAX), @AccountId NVARCHAR(50);

    SELECT @Amount=Amount, @FundPool=FundPool, @AccountId=ISNULL(AccountId,'')
    FROM Incomes WHERE Id=@Id AND IsDeleted=0;

    IF @Amount IS NULL RETURN;

    -- ★ Step 1: Soft-delete AccountMasters FIRST
    IF @AccountId != ''
    BEGIN
        UPDATE AccountMasters SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
        WHERE AccountId=@AccountId AND IsDeleted=0;
    END

    -- ★ Step 2: Soft-delete Income
    UPDATE Incomes SET IsDeleted=1, UpdatedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- Step 3: Revert FundPool balance
    IF @FundPool IS NOT NULL AND LEN(@FundPool)>0 AND @Amount>0
        UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE()
        WHERE Code=@FundPool AND IsDeleted=0;
END
GO

PRINT '✅ sp_DeleteIncome — AccountMasters DELETE FIRST, then Income DELETE.';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_UpdateExpense — AccountMasters UPDATE FIRST
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id            INT,
    @Date          DATE,
    @Mode          NVARCHAR(MAX) = '',
    @Head          NVARCHAR(MAX),
    @FundPool      NVARCHAR(MAX) = '',
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX) = 'Camp',
    @CampId        INT           = NULL,
    @CampName      NVARCHAR(MAX) = '',
    @RecipientRole NVARCHAR(MAX) = '',
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = '',
    @Purpose       NVARCHAR(MAX) = '',
    @UpdatedBy     INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2), @OldPool NVARCHAR(MAX), @AccountId NVARCHAR(50);

    SELECT @OldAmount=Amount, @OldPool=FundPool, @AccountId=ISNULL(AccountId,'')
    FROM Expenses WHERE Id=@Id;

    DECLARE @FPName NVARCHAR(200) = '';
    IF @FundPool IS NOT NULL AND LEN(@FundPool)>0
        SELECT @FPName=ISNULL(Name,'') FROM FundPools WHERE Code=@FundPool;

    -- ★ Step 1: UPDATE AccountMasters FIRST
    IF @AccountId != ''
    BEGIN
        UPDATE AccountMasters
        SET TransDate=@Date, Mode=@Mode, FundPool=@FundPool, FundPoolName=@FPName,
            Amount=@Amount, Nature=@Nature,
            RecipientRole=@RecipientRole, RecipientId=@RecipientId,
            RecipientName=@RecipientName, Purpose=@Purpose,
            UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
        WHERE AccountId=@AccountId AND IsDeleted=0;
    END

    -- ★ Step 2: UPDATE Expense
    UPDATE Expenses SET
        [Date]=@Date, Mode=@Mode, Head=@Head, FundPool=@FundPool, FundPoolName=@FPName,
        Amount=@Amount, Nature=@Nature,
        CampId=@CampId, CampName=ISNULL(@CampName,''),
        RecipientRole=@RecipientRole, RecipientId=@RecipientId,
        RecipientName=@RecipientName, Purpose=@Purpose,
        TransDate=@Date, UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- Step 3: FundPool balance adjust
    IF @OldPool IS NOT NULL AND @OldPool != '' AND @OldAmount > 0
        UPDATE FundPools SET Balance=Balance+@OldAmount, UpdatedAt=GETUTCDATE() WHERE Code=@OldPool AND IsDeleted=0;
    IF @FundPool IS NOT NULL AND @FundPool != '' AND @Amount > 0
        UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE() WHERE Code=@FundPool AND IsDeleted=0;
END
GO

PRINT '✅ sp_UpdateExpense — AccountMasters UPDATE FIRST, then Expense UPDATE.';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_DeleteExpense — AccountMasters DELETE FIRST
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_DeleteExpense
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(18,2), @FundPool NVARCHAR(MAX), @AccountId NVARCHAR(50);

    SELECT @Amount=Amount, @FundPool=FundPool, @AccountId=ISNULL(AccountId,'')
    FROM Expenses WHERE Id=@Id AND IsDeleted=0;

    IF @Amount IS NULL RETURN;

    -- ★ Step 1: Soft-delete AccountMasters FIRST
    IF @AccountId != ''
    BEGIN
        UPDATE AccountMasters SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
        WHERE AccountId=@AccountId AND IsDeleted=0;
    END

    -- ★ Step 2: Soft-delete Expense
    UPDATE Expenses SET IsDeleted=1, UpdatedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- Step 3: Revert FundPool balance
    IF @FundPool IS NOT NULL AND LEN(@FundPool)>0 AND @Amount>0
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE()
        WHERE Code=@FundPool AND IsDeleted=0;
END
GO

PRINT '✅ sp_DeleteExpense — AccountMasters DELETE FIRST, then Expense DELETE.';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 152 - Update & Delete SPs Complete!';
PRINT '   Only Account Management (Income/Expense pages) affected.';
PRINT '   Pattern: AccountMasters FIRST → then Income/Expense';
PRINT '';
PRINT '   ADD:    Script 150 (sp_CreateIncome, sp_CreateExpense)';
PRINT '   UPDATE: Script 152 (sp_UpdateIncome, sp_UpdateExpense)';
PRINT '   DELETE: Script 152 (sp_DeleteIncome, sp_DeleteExpense)';
PRINT '═══════════════════════════════════════════════════════════';
GO
