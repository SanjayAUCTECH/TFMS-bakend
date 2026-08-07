-- ============================================================
-- 155: Tenant Security Deposit — AccountMasters Integration
-- 
-- Fix:
--   1. sp_ReceiveSecurityDeposit → AccountMasters INSERT FIRST → Income
--      Nature = 'Camp' (from ContractCamps)
--   2. sp_SettleSecurityDeposit → 
--      Refund: AccountMasters INSERT FIRST → Expense
--      Forfeit: AccountMasters INSERT (PaymentType='Income', Head='SD Penalty')
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- We patch the INCOME INSERT section in sp_ReceiveSecurityDeposit
-- and EXPENSE INSERT section in sp_SettleSecurityDeposit
-- by adding AccountMasters INSERT before each.
--
-- Since these SPs are complex (rooms, cursors etc.), 
-- simplest approach: ADD AccountMasters code into the SP
-- right before the Income/Expense INSERT.
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- APPROACH: Patch sp_ReceiveSecurityDeposit
-- Find: INSERT INTO Incomes section
-- Add BEFORE it: INSERT INTO AccountMasters
-- ──────────────────────────────────────────────────────────────

-- Since we can't easily ALTER just one section of a complex SP,
-- we'll create a wrapper SP that the controller calls AFTER 
-- sp_ReceiveSecurityDeposit runs:

CREATE OR ALTER PROCEDURE sp_SyncSDReceiveToAccountMaster
    @ContractId   NVARCHAR(MAX),
    @Amount       DECIMAL(18,2),
    @PaidDate     DATE,
    @PaymentMode  NVARCHAR(MAX) = 'Cash',
    @FundPoolId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Find the latest Income for this contract with empty AccountId
    DECLARE @IncomeId INT, @FundPool NVARCHAR(100), @FundPoolName NVARCHAR(200),
            @TenantName NVARCHAR(200), @TenantId INT, @CampId INT, @CampName NVARCHAR(200),
            @Purpose NVARCHAR(MAX);

    SELECT TOP 1 @IncomeId=Id, @FundPool=ISNULL(FundPool,''), @FundPoolName=ISNULL(FundPoolName,''),
        @TenantName=ISNULL(TenantName,''), @TenantId=TenantId, @CampId=CampId,
        @CampName=ISNULL(CampName,''), @Purpose=ISNULL(Purpose,'')
    FROM Incomes
    WHERE ContractId=@ContractId AND Head='Security Deposit'
      AND ISNULL(AccountId,'')='' AND IsDeleted=0
    ORDER BY Id DESC;

    IF @IncomeId IS NULL RETURN;

    -- Generate AccountId & VoucherNo
    DECLARE @Seq INT = ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1;
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);

    -- INSERT AccountMasters (Nature='Camp')
    INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,
        Mode,FundPool,FundPoolName,Amount,Nature,RecipientRole,RecipientName,
        Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AccountId,@VoucherNo,@PaidDate,'Income',
        @PaymentMode,@FundPool,@FundPoolName,@Amount,
        'Camp','Tenant',@TenantName,@Purpose,@TenantId,NULL,0,GETDATE(),GETDATE());

    -- UPDATE Income with AccountId, VoucherNo, TransDate
    UPDATE Incomes SET AccountId=@AccountId, VoucherNo=@VoucherNo, TransDate=@PaidDate
    WHERE Id=@IncomeId;
END
GO

PRINT '✅ sp_SyncSDReceiveToAccountMaster created.';
GO

-- ──────────────────────────────────────────────────────────────
-- SP for SD Settle — Refund case (Expense)
-- ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_SyncSDRefundToAccountMaster
    @ContractId   NVARCHAR(MAX),
    @Amount       DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Find latest Expense for SD Refund with empty AccountId
    DECLARE @ExpenseId INT, @FundPool NVARCHAR(100), @FundPoolName NVARCHAR(200),
            @TenantName NVARCHAR(200), @TenantId INT, @CampId INT, @CampName NVARCHAR(200),
            @Purpose NVARCHAR(MAX);

    SELECT TOP 1 @ExpenseId=Id, @FundPool=ISNULL(FundPool,''), @FundPoolName=ISNULL(FundPoolName,''),
        @TenantName=ISNULL(RecipientName,''), @TenantId=RecipientId, @CampId=CampId,
        @CampName=ISNULL(CampName,''), @Purpose=ISNULL(Purpose,'')
    FROM Expenses
    WHERE Head IN ('Security Deposit Refund','SD') AND ISNULL(AccountId,'')='' AND IsDeleted=0
      AND Amount=@Amount
    ORDER BY Id DESC;

    IF @ExpenseId IS NULL RETURN;

    DECLARE @Seq INT = ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1;
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-EXP-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);

    INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,
        Mode,FundPool,FundPoolName,Amount,Nature,RecipientRole,RecipientName,
        Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AccountId,@VoucherNo,GETDATE(),'Expense',
        'System',@FundPool,@FundPoolName,@Amount,
        'Camp','Tenant',@TenantName,@Purpose,@TenantId,NULL,0,GETDATE(),GETDATE());

    UPDATE Expenses SET AccountId=@AccountId, VoucherNo=@VoucherNo, TransDate=GETDATE()
    WHERE Id=@ExpenseId;
END
GO

PRINT '✅ sp_SyncSDRefundToAccountMaster created.';
GO

-- ──────────────────────────────────────────────────────────────
-- SP for SD Settle — Forfeit/Penalty case (Income — company keeps it)
-- ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_SyncSDForfeitToAccountMaster
    @ContractId    NVARCHAR(MAX),
    @ForfeitAmount DECIMAL(18,2),
    @FundPoolId    INT = NULL,
    @FundPoolName  NVARCHAR(200) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- Get contract info
    DECLARE @TenantId INT, @TenantName NVARCHAR(200), @CampId INT, @CampName NVARCHAR(200),
            @FundPoolCode NVARCHAR(100) = '';

    SELECT @TenantId=c.TenantId, @TenantName=ISNULL(t.Name,''),
           @CampId=ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId=@ContractId ORDER BY Id),0)
    FROM Contracts c LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE c.ContractId=@ContractId;

    SELECT @CampName=ISNULL(Name,'') FROM Camps WHERE Id=@CampId;

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=ISNULL(Code,''), @FundPoolName=ISNULL(Name,'') FROM FundPools WHERE Id=@FundPoolId;

    -- Generate AccountId & VoucherNo
    DECLARE @Seq INT = ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1;
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);

    -- INSERT AccountMasters (Forfeit = Income for company, Nature='Camp')
    INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,
        Mode,FundPool,FundPoolName,Amount,Nature,RecipientRole,RecipientName,
        Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AccountId,@VoucherNo,GETDATE(),'Income',
        'Penalty',@FundPoolCode,@FundPoolName,@ForfeitAmount,
        'Camp','Tenant',@TenantName,
        'SD Penalty - Contract: '+@ContractId+' - Tenant: '+@TenantName,
        @TenantId,NULL,0,GETDATE(),GETDATE());

    -- Also INSERT into Incomes (Head='SD Penalty')
    DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
    INSERT INTO Incomes(IncomeId,[Date],Mode,Head,FundPool,FundPoolName,Amount,
        Purpose,Source,SourceRef,CampId,CampName,TenantId,TenantName,
        ContractId,AccountId,VoucherNo,TransDate,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@IncomeId,GETDATE(),'Penalty','SD Penalty',@FundPoolCode,@FundPoolName,@ForfeitAmount,
        'SD Penalty - Contract: '+@ContractId+' - Tenant: '+@TenantName,
        'SecurityDeposit',@ContractId,@CampId,@CampName,@TenantId,@TenantName,
        @ContractId,@AccountId,@VoucherNo,GETDATE(),0,GETDATE(),GETDATE());
END
GO

PRINT '✅ sp_SyncSDForfeitToAccountMaster created.';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 155 - Tenant SD → AccountMasters Fix Complete!';
PRINT '';
PRINT '   SD Receive: Call sp_SyncSDReceiveToAccountMaster AFTER sp_ReceiveSecurityDeposit';
PRINT '   SD Refund:  Call sp_SyncSDRefundToAccountMaster AFTER sp_SettleSecurityDeposit';
PRINT '   SD Forfeit: Call sp_SyncSDForfeitToAccountMaster AFTER sp_SettleSecurityDeposit';
PRINT '═══════════════════════════════════════════════════════════';
GO
