-- ============================================================
-- 151: AccountMasters Integration — NO TRIGGERS
-- 
-- Approach: PEHLE AccountMasters mein data jaaye (AccountId &
-- VoucherNo generate), PHIR Income/Expense mein jaaye with
-- AccountId & VoucherNo already set.
--
-- 1. DROP old triggers (if any)
-- 2. Update sp_RecordPayment
-- 3. Update sp_ReceiveSecurityDeposit references
-- 4. Update sp_SettleSecurityDeposit references
-- 5. Update sp_PayOwnerSecurityDeposit references
-- 6. Update sp_SettleOwnerSecurityDeposit references
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- DROP TRIGGERS (if previously created)
-- ══════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_Incomes_InsertAccountMaster')
    DROP TRIGGER trg_Incomes_InsertAccountMaster;
GO
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_Expenses_InsertAccountMaster')
    DROP TRIGGER trg_Expenses_InsertAccountMaster;
GO

PRINT '✅ Old triggers dropped (if existed).';
GO

-- ══════════════════════════════════════════════════════════════
-- UPDATE sp_RecordPayment — AccountMaster FIRST, then Income
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId      NVARCHAR(MAX),
    @InstallmentNo   INT           = 0,
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATETIME      = NULL,
    @PaymentModeId   INT           = NULL,
    @PaymentMode     NVARCHAR(MAX) = '',
    @ChequeNumber    NVARCHAR(MAX) = '',
    @ClearanceDate   NVARCHAR(MAX) = '',
    @Description     NVARCHAR(MAX) = '',
    @ReceivedBy      NVARCHAR(MAX) = '',
    @ReceivedContact NVARCHAR(MAX) = '',
    @FundPoolId      INT           = NULL,
    @FundPoolName    NVARCHAR(MAX) = '',
    @IssuedBy        NVARCHAR(MAX) = '',
    @AddedBy         INT           = NULL,
    @NewTxnRecordId  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0)
    BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

    -- Get tenant/camp/fundpool info
    DECLARE @TenantId   INT=0, @TenantName NVARCHAR(MAX)='',
            @CampId     INT=0, @CampName   NVARCHAR(MAX)='',
            @FPCode     NVARCHAR(MAX)='';

    SELECT @TenantId=TenantId FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0;
    SELECT @TenantName=ISNULL(Name,'') FROM Tenants WHERE Id=@TenantId AND IsDeleted=0;
    SELECT TOP 1 @CampId=cc.CampId, @CampName=ISNULL(ca.Name,'')
    FROM ContractCamps cc JOIN Camps ca ON ca.Id=cc.CampId AND ca.IsDeleted=0
    WHERE cc.ContractId=@ContractId AND ISNULL(cc.IsDeleted,0)=0 ORDER BY cc.Id;
    IF @FundPoolId IS NOT NULL
        SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId AND IsDeleted=0;

    -- ── Load pending installments ────────────────────────────────
    CREATE TABLE #Pending (
        InstallmentNo INT,
        Amount        DECIMAL(18,2),
        PaidAmount    DECIMAL(18,2),
        Due           DECIMAL(18,2)
    );

    INSERT INTO #Pending
    SELECT InstallmentNo, Amount, ISNULL(PaidAmount,0), Amount - ISNULL(PaidAmount,0)
    FROM ContractInstallments
    WHERE ContractId=@ContractId
      AND ISNULL(IsDeleted,0)=0
      AND Status IN ('Pending','Partial','Overdue')
      AND Amount - ISNULL(PaidAmount,0) > 0
      AND (@InstallmentNo=0 OR InstallmentNo >= @InstallmentNo)
    ORDER BY InstallmentNo;

    IF NOT EXISTS (SELECT 1 FROM #Pending)
    BEGIN
        DROP TABLE #Pending;
        RAISERROR('No pending installments for contract %s.',16,1,@ContractId);
        RETURN;
    END

    -- ── Distribute payment across installments (FIFO) ────────────
    DECLARE @Remaining   DECIMAL(18,2) = @PaidAmount;
    DECLARE @AppliedList NVARCHAR(MAX) = '';
    DECLARE @CurNo  INT; DECLARE @CurAmt DECIMAL(18,2);
    DECLARE @CurPaid DECIMAL(18,2); DECLARE @CurDue DECIMAL(18,2);
    DECLARE @ToApply DECIMAL(18,2); DECLARE @NewPaid DECIMAL(18,2);
    DECLARE @NewStatus NVARCHAR(MAX);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT InstallmentNo, Amount, PaidAmount, Due FROM #Pending ORDER BY InstallmentNo;
    OPEN cur;
    FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;

    WHILE @@FETCH_STATUS=0 AND @Remaining>0
    BEGIN
        SET @ToApply   = CASE WHEN @Remaining >= @CurDue THEN @CurDue ELSE @Remaining END;
        SET @NewPaid   = @CurPaid + @ToApply;
        SET @NewStatus = CASE
            WHEN @NewPaid >= @CurAmt THEN 'Paid'
            WHEN @NewPaid  > 0       THEN 'Partial'
            ELSE 'Pending' END;

        UPDATE ContractInstallments
        SET PaidAmount=@NewPaid, PaidDate=@PaidDate, Status=@NewStatus,
            PaymentMode=ISNULL(@PaymentMode,''), PaymentModeId=@PaymentModeId,
            ChequeNumber=ISNULL(@ChequeNumber,''), ClearanceDate=ISNULL(@ClearanceDate,''),
            Description=ISNULL(@Description,''), ReceivedBy=ISNULL(@ReceivedBy,''),
            ReceivedContact=ISNULL(@ReceivedContact,''), FundPoolId=@FundPoolId,
            FundPoolName=ISNULL(@FundPoolName,''), IssuedBy=ISNULL(@IssuedBy,''),
            AddedBy=ISNULL(AddedBy,@AddedBy)
        WHERE ContractId=@ContractId AND InstallmentNo=@CurNo AND ISNULL(IsDeleted,0)=0;

        SET @AppliedList = CASE WHEN @AppliedList=''
            THEN CAST(@CurNo AS NVARCHAR)
            ELSE @AppliedList+','+CAST(@CurNo AS NVARCHAR) END;
        SET @Remaining = @Remaining - @ToApply;
        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
    END;
    CLOSE cur; DEALLOCATE cur; DROP TABLE #Pending;

    -- ── FundPool balance update ───────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @PaidAmount>0
        UPDATE FundPools SET Balance=Balance+@PaidAmount, UpdatedAt=GETUTCDATE()
        WHERE Id=@FundPoolId AND IsDeleted=0;

    -- ── TxnRecord INSERT ──────────────────────────────────────────
    DECLARE @TxnId NVARCHAR(50) = CONCAT('TXN-',
        RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),5));
    DECLARE @Unalloc DECIMAL(18,2) = CASE WHEN @Remaining>0 THEN @Remaining ELSE 0 END;
    DECLARE @FirstInstNo INT = NULL;
    IF CHARINDEX(',',@AppliedList)>0
        SET @FirstInstNo=CAST(LEFT(@AppliedList,CHARINDEX(',',@AppliedList)-1) AS INT);
    ELSE IF @AppliedList<>''
        SET @FirstInstNo=CAST(@AppliedList AS INT);

    INSERT INTO TxnRecords(
        TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
        TotalAmount,Amount,TxnDate,PaymentMode,PaymentModeId,ChequeNumber,
        FundPoolId,FundPoolName,Description,ReceivedBy,ReceivedContact,IssuedBy,
        InstallmentNo,AppliedInstallments,Unallocated,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt
    )
    VALUES(
        @TxnId,'CR',@ContractId,@ContractId,ISNULL(@TenantId,0),ISNULL(@CampId,0),
        @PaidAmount,@PaidAmount,
        ISNULL(@PaidDate,GETUTCDATE()),
        ISNULL(@PaymentMode,''),@PaymentModeId,ISNULL(@ChequeNumber,''),
        @FundPoolId,ISNULL(@FundPoolName,''),ISNULL(@Description,''),
        ISNULL(@ReceivedBy,''),ISNULL(@ReceivedContact,''),ISNULL(@IssuedBy,''),
        @FirstInstNo,@AppliedList,@Unalloc,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE()
    );
    SET @NewTxnRecordId=SCOPE_IDENTITY();

    -- ══════════════════════════════════════════════════════════════
    -- ★★★ PEHLE AccountMasters mein INSERT (AccountId & VoucherNo generate) ★★★
    -- ★★★ PHIR Incomes mein INSERT (with AccountId & VoucherNo)            ★★★
    -- ══════════════════════════════════════════════════════════════
    IF @FundPoolId IS NOT NULL
    BEGIN
        -- Step A: Generate AccountId & VoucherNo
        DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000' + 
            CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR), 6);
        DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000' + 
            CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters WHERE PaymentType='Income'),0)+1) AS NVARCHAR), 6);
        DECLARE @TransDate DATETIME = ISNULL(@PaidDate, GETUTCDATE());

        -- Step B: INSERT into AccountMasters FIRST
        INSERT INTO AccountMasters(
            AccountId, VoucherNo, TransDate, PaymentType,
            Mode, FundPool, FundPoolName, Amount,
            Nature, RecipientRole, RecipientName, Purpose,
            RecipientId, AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            @AccountId, @VoucherNo, @TransDate, 'Income',
            ISNULL(@PaymentMode,'Cash'), ISNULL(@FPCode,''), ISNULL(@FundPoolName,''),
            @PaidAmount, '', 'Tenant', ISNULL(@TenantName,''),
            CONCAT('Rent received - Inst: ',@AppliedList,' | Contract: ',@ContractId),
            @TenantId, @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
        );

        -- Step C: INSERT into Incomes WITH AccountId & VoucherNo
        DECLARE @IncId NVARCHAR(50)=CONCAT('INC-',
            RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),5));

        INSERT INTO Incomes(
            IncomeId,[Date],Mode,Head,FundPool,FundPoolName,Amount,
            Purpose,Source,SourceRef,CampName,TenantName,
            CampId,ContractId,ContractCode,TxnRecordId,
            AccountId,VoucherNo,TransDate,
            AddedBy,IsDeleted,CreatedAt,UpdatedAt
        )
        VALUES(
            @IncId, CAST(@TransDate AS DATE),
            ISNULL(@PaymentMode,'Cash'), 'RENTAL COLLECTION',
            ISNULL(@FPCode,''), ISNULL(@FundPoolName,''), @PaidAmount,
            CONCAT('Rent received - Inst: ',@AppliedList,' | Contract: ',@ContractId),
            'Tenant', @ContractId, ISNULL(@CampName,''), ISNULL(@TenantName,''),
            ISNULL(@CampId,0), @ContractId, @ContractId, @NewTxnRecordId,
            @AccountId, @VoucherNo, @TransDate,
            @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
        );
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_RecordPayment updated — AccountMasters FIRST, then Incomes.';
GO

-- ══════════════════════════════════════════════════════════════
-- NOTE for OwnerPaymentRepository.cs (C# direct INSERT):
-- The C# code in PayOwnerAsync() directly INSERTs into Expenses.
-- Update that code to:
--   1. First INSERT into AccountMasters (generate AccountId/VoucherNo)
--   2. Then INSERT into Expenses WITH AccountId & VoucherNo
-- See updated C# code in OwnerPaymentRepository.cs
-- ══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════
-- For sp_PayOwnerSecurityDeposit, sp_SettleOwnerSecurityDeposit,
-- sp_ReceiveSecurityDeposit, sp_SettleSecurityDeposit:
-- Same pattern applies — PEHLE AccountMasters, PHIR Income/Expense
-- These SPs should be updated similarly.
-- Below is the pattern to follow in each SP:
-- ══════════════════════════════════════════════════════════════

-- ── PATTERN (copy into each SP where Income/Expense INSERT happens):
--
--   -- Step A: Generate AccountId & VoucherNo
--   DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000' +
--       CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR), 6);
--   DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000' +
--       CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters WHERE PaymentType='Income'),0)+1) AS NVARCHAR), 6);
--   -- (Use 'VCH-EXP-' for Expense)
--   DECLARE @TransDate DATETIME = @PaidDate;
--
--   -- Step B: INSERT into AccountMasters FIRST
--   INSERT INTO AccountMasters(...) VALUES(...);
--
--   -- Step C: INSERT into Incomes/Expenses WITH AccountId & VoucherNo
--   INSERT INTO Incomes(..., AccountId, VoucherNo, TransDate) VALUES(..., @AccountId, @VoucherNo, @TransDate);
--

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 151 - AccountMaster Integration (NO TRIGGERS) Complete!';
PRINT '';
PRINT '   Flow: AccountMasters FIRST → then Income/Expense';
PRINT '';
PRINT '   Updated SPs:';
PRINT '     • sp_RecordPayment (tenant rent)';
PRINT '     • sp_CreateIncome (Script 150)';
PRINT '     • sp_CreateExpense (Script 150)';
PRINT '';
PRINT '   Remaining to update (same pattern):';
PRINT '     • sp_ReceiveSecurityDeposit';
PRINT '     • sp_SettleSecurityDeposit';
PRINT '     • sp_PayOwnerSecurityDeposit';
PRINT '     • sp_SettleOwnerSecurityDeposit';
PRINT '     • OwnerPaymentRepository.cs (C# code)';
PRINT '═══════════════════════════════════════════════════════════';
GO
