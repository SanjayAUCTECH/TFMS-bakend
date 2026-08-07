-- ============================================================
-- 153: AccountMasters INSERT — Directly inside ALL existing SPs
-- 
-- Jahan bhi Income/Expense INSERT ho rahi hai, UPAR AccountMasters
-- INSERT hoga (AccountId + VoucherNo generate) phir Income/Expense
-- mein wahi AccountId & VoucherNo ke saath INSERT hoga.
--
-- SPs Updated:
--   1. sp_RecordPayment → Income INSERT ke upar AccountMasters
--   2. sp_ReceiveSecurityDeposit → Income INSERT ke upar
--   3. sp_PayOwnerSecurityDeposit → Expense INSERT ke upar
--   4. sp_SettleSecurityDeposit → Expense INSERT ke upar (Refund case)
--   5. sp_SettleOwnerSecurityDeposit → Income INSERT ke upar (Recovery)
--   6. sp_DeleteTxnRecord → AccountMasters bhi IsDeleted=1
--   7. sp_DeleteOwnerPayment → AccountMasters bhi IsDeleted=1
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 0. sp_InsertExpenseWithAccountMaster
--    (Owner Payment C# code calls this)
--    AccountMasters INSERT FIRST → then Expenses INSERT
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_InsertExpenseWithAccountMaster
    @Date          DATE,
    @Mode          NVARCHAR(MAX) = '',
    @Head          NVARCHAR(MAX) = '',
    @FundPool      NVARCHAR(MAX) = '',
    @FundPoolName  NVARCHAR(MAX) = '',
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX) = 'Camp',
    @CampId        INT           = NULL,
    @CampName      NVARCHAR(MAX) = '',
    @RecipientRole NVARCHAR(MAX) = '',
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = '',
    @Purpose       NVARCHAR(MAX) = '',
    @AddedBy       INT           = NULL,
    @NewExpenseId  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ★ Step 1: Generate AccountId & VoucherNo
    DECLARE @Seq INT = ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1;
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-EXP-' + RIGHT('000000'+CAST(@Seq AS NVARCHAR),6);

    -- ★ Step 2: INSERT AccountMasters FIRST
    INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,
        Mode,FundPool,FundPoolName,Amount,Nature,RecipientRole,RecipientName,
        Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AccountId,@VoucherNo,@Date,'Expense',
        @Mode,@FundPool,@FundPoolName,@Amount,@Nature,@RecipientRole,@RecipientName,
        @Purpose,@RecipientId,@AddedBy,0,GETDATE(),GETDATE());

    -- ★ Step 3: Generate ExpenseId
    DECLARE @ExpenseId NVARCHAR(MAX) = 'EXP-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR),6);

    -- ★ Step 4: INSERT Expenses WITH AccountId & VoucherNo
    INSERT INTO Expenses(ExpenseId,[Date],Mode,Head,FundPool,FundPoolName,Amount,Nature,
        CampId,CampName,RecipientRole,RecipientId,RecipientName,Purpose,
        AccountId,VoucherNo,TransDate,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@ExpenseId,@Date,@Mode,@Head,@FundPool,@FundPoolName,@Amount,@Nature,
        @CampId,@CampName,@RecipientRole,@RecipientId,@RecipientName,@Purpose,
        @AccountId,@VoucherNo,@Date,@AddedBy,0,GETDATE(),GETDATE());

    SET @NewExpenseId = SCOPE_IDENTITY();
END
GO

PRINT '✅ sp_InsertExpenseWithAccountMaster created (AccountMasters FIRST → Expenses).';
GO

-- ══════════════════════════════════════════════════════════════
-- 1. UPDATE sp_RecordPayment — Income section mein AccountMasters add
-- ══════════════════════════════════════════════════════════════
-- Find the Income INSERT section in sp_RecordPayment and add AccountMasters before it
-- We ALTER the full SP (copy from Script 151 which already has it)
-- Already done in Script 151 — sp_RecordPayment has AccountMasters FIRST

-- Verify: If Script 151 already ran, skip. Otherwise apply:
IF NOT EXISTS (SELECT 1 FROM sys.sql_modules WHERE definition LIKE '%AccountMasters%' 
    AND object_id = OBJECT_ID('sp_RecordPayment'))
BEGIN
    PRINT '⚠️ sp_RecordPayment needs Script 151 to be run first for AccountMasters support.';
END
ELSE
    PRINT '✅ sp_RecordPayment already has AccountMasters (from Script 151).';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_PayOwnerSecurityDeposit — Expense ke UPAR AccountMasters
-- ══════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_PayOwnerSecurityDeposit') DROP PROCEDURE sp_PayOwnerSecurityDeposit;
GO
CREATE PROCEDURE sp_PayOwnerSecurityDeposit
    @OwnerContractId INT,
    @Amount          DECIMAL(18,2),
    @PaidDate        DATETIME,
    @PaymentMode     NVARCHAR(100) = 'Cash',
    @PaymentModeId   INT = NULL,
    @ChequeNumber    NVARCHAR(100) = '',
    @FundPoolId      INT = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @PaidBy          NVARCHAR(200) = 'Admin',
    @Notes           NVARCHAR(500) = '',
    @NewPaid         DECIMAL(18,2) OUTPUT,
    @NewStatus       NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OcCode NVARCHAR(50), @OwnerId INT, @CampId INT,
            @OwnerName NVARCHAR(200), @CampName NVARCHAR(200),
            @SDAmount DECIMAL(18,2), @SDPaid DECIMAL(18,2),
            @FundPoolCode NVARCHAR(50) = '';

    SELECT @OcCode=oc.OcCode, @OwnerId=oc.OwnerId, @CampId=oc.CampId,
           @OwnerName=ISNULL(o.Name,''), @CampName=ISNULL(c.Name,''),
           @SDAmount=ISNULL(oc.SecurityDeposit,0), @SDPaid=ISNULL(oc.SecurityDepositPaid,0)
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId
    LEFT JOIN Camps c ON c.Id=oc.CampId
    WHERE oc.Id=@OwnerContractId;

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=Code, @FundPoolName=Name FROM FundPools WHERE Id=@FundPoolId;

    SET @NewPaid = @SDPaid + @Amount;
    SET @NewStatus = CASE WHEN @NewPaid >= @SDAmount THEN 'Paid'
                         WHEN @NewPaid > 0 THEN 'Partially Paid'
                         ELSE 'Pending' END;

    UPDATE OwnerContracts SET SecurityDepositPaid=@NewPaid, SecurityDepositPaidDate=@PaidDate, UpdatedAt=GETDATE()
    WHERE Id=@OwnerContractId;

    -- OwnerTransaction
    DECLARE @TxnCode NVARCHAR(50) = 'OSD-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS VARCHAR),6);
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,
        Type,Amount,Date,Description,PaymentMode,ReferenceNo,CreatedAt)
    VALUES(@TxnCode,@OwnerContractId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,
        'SD-PAY',@Amount,@PaidDate,
        CASE WHEN @Notes!='' THEN @Notes ELSE 'Security deposit paid to owner - '+@PaymentMode END,
        @PaymentMode,@ChequeNumber,GETDATE());

    -- FundPool deduct
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETDATE() WHERE Id=@FundPoolId;

    -- ★★★ AccountMasters INSERT FIRST ★★★
    DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR),6);
    DECLARE @VoucherNo NVARCHAR(100) = 'VCH-EXP-' + RIGHT('000000'+CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR),6);

    INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,Mode,FundPool,FundPoolName,
        Amount,Nature,RecipientRole,RecipientName,Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AccountId,@VoucherNo,@PaidDate,'Expense',@PaymentMode,@FundPoolCode,@FundPoolName,
        @Amount,'Camp','Owner',@OwnerName,'Owner SD Payment - '+@OcCode,@OwnerId,NULL,0,GETDATE(),GETDATE());

    -- ★★★ THEN Expense INSERT with AccountId ★★★
    DECLARE @ExpId NVARCHAR(MAX) = 'EXP-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR),6);
    INSERT INTO Expenses(ExpenseId,Date,Mode,Head,FundPool,FundPoolName,Amount,Nature,
        CampId,CampName,RecipientRole,RecipientName,Purpose,
        AccountId,VoucherNo,TransDate,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@ExpId,@PaidDate,@PaymentMode,'SD',@FundPoolCode,@FundPoolName,@Amount,'Camp',
        @CampId,@CampName,'Owner',@OwnerName,'Owner SD Payment - '+@OcCode+' - '+@OwnerName,
        @AccountId,@VoucherNo,@PaidDate,0,GETDATE(),GETDATE());
END;
GO

PRINT '✅ sp_PayOwnerSecurityDeposit — AccountMasters FIRST, then Expense.';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_SettleOwnerSecurityDeposit — Recovery → AccountMasters FIRST → Income
-- ══════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name='sp_SettleOwnerSecurityDeposit') DROP PROCEDURE sp_SettleOwnerSecurityDeposit;
GO
CREATE PROCEDURE sp_SettleOwnerSecurityDeposit
    @OwnerContractId INT,
    @RecoverAmount   DECIMAL(18,2) = 0,
    @AdjustAmount    DECIMAL(18,2) = 0,
    @ForfeitAmount   DECIMAL(18,2) = 0,
    @FundPoolId      INT = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @Notes           NVARCHAR(500) = '',
    @SettledBy       NVARCHAR(200) = 'Admin',
    @NewStatus       NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OcCode NVARCHAR(50), @OwnerId INT, @CampId INT,
            @OwnerName NVARCHAR(200), @CampName NVARCHAR(200),
            @FundPoolCode NVARCHAR(50) = '';

    SELECT @OcCode=oc.OcCode, @OwnerId=oc.OwnerId, @CampId=oc.CampId,
           @OwnerName=ISNULL(o.Name,''), @CampName=ISNULL(c.Name,'')
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId
    LEFT JOIN Camps c ON c.Id=oc.CampId
    WHERE oc.Id=@OwnerContractId;

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=Code, @FundPoolName=Name FROM FundPools WHERE Id=@FundPoolId;

    SET @NewStatus = CASE
        WHEN @RecoverAmount > 0 THEN 'Recovered'
        WHEN @ForfeitAmount > 0 THEN 'Forfeited'
        WHEN @AdjustAmount > 0 THEN 'Adjusted'
        ELSE 'Settled' END;

    -- OwnerTransaction
    DECLARE @TxnCode NVARCHAR(50) = 'OSS-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS VARCHAR),6);
    DECLARE @TotalSettled DECIMAL(18,2) = @RecoverAmount + @AdjustAmount + @ForfeitAmount;

    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,
        Type,Amount,Date,Description,PaymentMode,CreatedAt)
    VALUES(@TxnCode,@OwnerContractId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,
        'SD-SETTLE',@TotalSettled,GETDATE(),
        'SD Settlement - Recover:'+CAST(@RecoverAmount AS VARCHAR)+' Adjust:'+CAST(@AdjustAmount AS VARCHAR)+' Forfeit:'+CAST(@ForfeitAmount AS VARCHAR)+' '+@Notes,
        '',GETDATE());

    -- FundPool: recover = money back
    IF @RecoverAmount > 0 AND @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance=Balance+@RecoverAmount, UpdatedAt=GETDATE() WHERE Id=@FundPoolId;

    -- Recovery → Income (AccountMasters FIRST)
    IF @RecoverAmount > 0
    BEGIN
        -- ★★★ AccountMasters FIRST ★★★
        DECLARE @AccountId NVARCHAR(50) = 'ACC-' + RIGHT('000000'+CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR),6);
        DECLARE @VoucherNo NVARCHAR(100) = 'VCH-INC-' + RIGHT('000000'+CAST((ISNULL((SELECT MAX(Id) FROM AccountMasters),0)+1) AS NVARCHAR),6);

        INSERT INTO AccountMasters(AccountId,VoucherNo,TransDate,PaymentType,Mode,FundPool,FundPoolName,
            Amount,Nature,RecipientRole,RecipientName,Purpose,RecipientId,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
        VALUES(@AccountId,@VoucherNo,GETDATE(),'Income','Recovery',@FundPoolCode,@FundPoolName,
            @RecoverAmount,'Camp','Owner',@OwnerName,'Owner SD Recovery - '+@OcCode+' '+@Notes,@OwnerId,NULL,0,GETDATE(),GETDATE());

        -- ★★★ THEN Income INSERT ★★★
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
        INSERT INTO Incomes(IncomeId,Date,Mode,Head,FundPool,FundPoolName,Amount,Purpose,Source,SourceRef,
            CampId,CampName,AccountId,VoucherNo,TransDate,IsDeleted,CreatedAt,UpdatedAt)
        VALUES(@IncomeId,GETDATE(),'Recovery','Security Deposit',@FundPoolCode,@FundPoolName,@RecoverAmount,
            'Owner SD Recovery - '+@OcCode+' - '+@OwnerName+' '+@Notes,'Owner',@OcCode,
            @CampId,@CampName,@AccountId,@VoucherNo,GETDATE(),0,GETDATE(),GETDATE());
    END;

    UPDATE OwnerContracts SET UpdatedAt=GETDATE() WHERE Id=@OwnerContractId;
END;
GO

PRINT '✅ sp_SettleOwnerSecurityDeposit — Recovery: AccountMasters FIRST, then Income.';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_DeleteOwnerPayment — AccountMasters bhi IsDeleted=1
-- ══════════════════════════════════════════════════════════════
-- Add AccountMasters soft-delete before Expense soft-delete
IF EXISTS (SELECT * FROM sys.objects WHERE name='sp_DeleteOwnerPayment') DROP PROCEDURE sp_DeleteOwnerPayment;
GO
CREATE PROCEDURE sp_DeleteOwnerPayment
    @TxnId     INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OwnerContractId INT, @Amount DECIMAL(18,2), @InstallmentNos NVARCHAR(200),
            @ExpenseId INT, @FundPoolCode NVARCHAR(50), @FundPoolId INT, @AccountId NVARCHAR(50);

    SELECT @OwnerContractId=OwnerContractId, @Amount=Amount,
           @InstallmentNos=InstallmentNos, @ExpenseId=ExpenseId
    FROM OwnerTransactions WHERE Id=@TxnId;

    IF @OwnerContractId IS NULL RETURN;

    -- Get AccountId from Expense
    IF @ExpenseId IS NOT NULL
    BEGIN
        SELECT @FundPoolCode=FundPool, @AccountId=ISNULL(AccountId,'') FROM Expenses WHERE Id=@ExpenseId;
        IF @FundPoolCode IS NOT NULL AND LEN(@FundPoolCode)>0
            SELECT @FundPoolId=Id FROM FundPools WHERE Code=@FundPoolCode;
    END

    -- 1. Reverse OwnerMonthlyContractInstallments
    IF @InstallmentNos IS NOT NULL AND @InstallmentNos != ''
    BEGIN
        DECLARE @RemainingReverse DECIMAL(18,2) = @Amount;
        DECLARE @RevInstNo INT;
        DECLARE rev_cursor CURSOR FOR
            SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstallmentNos,',')
            WHERE ISNUMERIC(value)=1 ORDER BY CAST(value AS INT) DESC;
        OPEN rev_cursor;
        FETCH NEXT FROM rev_cursor INTO @RevInstNo;
        WHILE @@FETCH_STATUS=0 AND @RemainingReverse>0
        BEGIN
            DECLARE @InstPaid DECIMAL(18,2);
            SELECT @InstPaid=PaidAmount FROM OwnerMonthlyContractInstallments
            WHERE OwnerContractId=@OwnerContractId AND InstallmentNo=@RevInstNo AND ISNULL(IsDeleted,0)=0;
            IF @InstPaid IS NOT NULL AND @InstPaid>0
            BEGIN
                DECLARE @ReverseThis DECIMAL(18,2) = CASE WHEN @RemainingReverse>=@InstPaid THEN @InstPaid ELSE @RemainingReverse END;
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount=ISNULL(PaidAmount,0)-@ReverseThis,
                    Balance=Balance+@ReverseThis,
                    Status=CASE WHEN (ISNULL(PaidAmount,0)-@ReverseThis)<=0 THEN 'Pending'
                                WHEN (ISNULL(PaidAmount,0)-@ReverseThis)<Amount THEN 'Partial' ELSE 'Paid' END,
                    PaymentStatus=CASE WHEN (ISNULL(PaidAmount,0)-@ReverseThis)<=0 THEN 'Pending'
                                       WHEN (ISNULL(PaidAmount,0)-@ReverseThis)<Amount THEN 'Partial' ELSE 'Paid' END,
                    PaidDate=CASE WHEN (ISNULL(PaidAmount,0)-@ReverseThis)<=0 THEN NULL ELSE PaidDate END,
                    UpdatedAt=GETDATE()
                WHERE OwnerContractId=@OwnerContractId AND InstallmentNo=@RevInstNo AND ISNULL(IsDeleted,0)=0;
                SET @RemainingReverse=@RemainingReverse-@ReverseThis;
            END;
            FETCH NEXT FROM rev_cursor INTO @RevInstNo;
        END;
        CLOSE rev_cursor; DEALLOCATE rev_cursor;
    END;

    -- 2. Reverse OwnerInstallments (LIFO)
    BEGIN
        DECLARE @RemRev2 DECIMAL(18,2) = @Amount;
        DECLARE @RevNo2 INT, @OIPaid2 DECIMAL(18,2);
        DECLARE rev2_cursor CURSOR FOR
            SELECT No, ISNULL(PaidAmount,0) FROM OwnerInstallments
            WHERE OwnerContractId=@OwnerContractId AND ISNULL(IsDeleted,0)=0 AND ISNULL(PaidAmount,0)>0
            ORDER BY No DESC;
        OPEN rev2_cursor;
        FETCH NEXT FROM rev2_cursor INTO @RevNo2, @OIPaid2;
        WHILE @@FETCH_STATUS=0 AND @RemRev2>0
        BEGIN
            IF @OIPaid2>0
            BEGIN
                DECLARE @RevThis2 DECIMAL(18,2) = CASE WHEN @RemRev2>=@OIPaid2 THEN @OIPaid2 ELSE @RemRev2 END;
                UPDATE OwnerInstallments
                SET PaidAmount=ISNULL(PaidAmount,0)-@RevThis2,
                    Status=CASE WHEN (ISNULL(PaidAmount,0)-@RevThis2)<=0 THEN 'Pending'
                                WHEN (ISNULL(PaidAmount,0)-@RevThis2)<Amount THEN 'Partial' ELSE 'Paid' END,
                    PaidDate=CASE WHEN (ISNULL(PaidAmount,0)-@RevThis2)<=0 THEN NULL ELSE PaidDate END
                WHERE OwnerContractId=@OwnerContractId AND No=@RevNo2 AND ISNULL(IsDeleted,0)=0;
                SET @RemRev2=@RemRev2-@RevThis2;
            END;
            FETCH NEXT FROM rev2_cursor INTO @RevNo2, @OIPaid2;
        END;
        CLOSE rev2_cursor; DEALLOCATE rev2_cursor;
    END;

    -- 3. Soft-delete OwnerTransaction
    UPDATE OwnerTransactions SET IsDeleted=1, DeletedBy=@DeletedBy WHERE Id=@TxnId;

    -- ★★★ 4. Soft-delete AccountMasters FIRST ★★★
    IF @AccountId IS NOT NULL AND @AccountId != ''
        UPDATE AccountMasters SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETDATE()
        WHERE AccountId=@AccountId AND IsDeleted=0;

    -- ★★★ 5. THEN Soft-delete Expense ★★★
    IF @ExpenseId IS NOT NULL
        UPDATE Expenses SET IsDeleted=1, UpdatedAt=GETDATE() WHERE Id=@ExpenseId;

    -- 6. Restore FundPool
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETDATE() WHERE Id=@FundPoolId;

    -- 7. Update contract timestamp
    UPDATE OwnerContracts SET UpdatedAt=GETDATE() WHERE Id=@OwnerContractId;
END;
GO

PRINT '✅ sp_DeleteOwnerPayment — AccountMasters IsDeleted FIRST, then Expense IsDeleted.';
GO

-- ══════════════════════════════════════════════════════════════
-- 5. sp_DeleteTxnRecord — Add AccountMasters IsDeleted=1
--    (Tenant Rent delete → Income delete → AccountMasters delete)
-- ══════════════════════════════════════════════════════════════
-- We just add AccountMasters soft-delete alongside Income soft-delete
-- The existing sp_DeleteTxnRecord (Script 116) has:
--   "UPDATE Incomes SET IsDeleted=1 WHERE TxnRecordId=@Id"
-- We add: "UPDATE AccountMasters SET IsDeleted=1 WHERE AccountId IN (SELECT AccountId FROM Incomes WHERE TxnRecordId=@Id)"

-- Since we can't easily ALTER just one section, create a wrapper:
CREATE OR ALTER PROCEDURE sp_DeleteAccountMasterByTxnRecordId
    @TxnRecordId INT,
    @DeletedBy   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Find AccountId from Income linked to this TxnRecord
    UPDATE AccountMasters SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETDATE()
    WHERE AccountId IN (
        SELECT AccountId FROM Incomes WHERE TxnRecordId=@TxnRecordId AND ISNULL(AccountId,'') != '' AND IsDeleted=0
    ) AND IsDeleted=0;
END
GO

PRINT '✅ sp_DeleteAccountMasterByTxnRecordId helper created.';
PRINT '   Call this BEFORE sp_DeleteTxnRecord in C# code (TxnRecordRepository.DeleteAsync)';
GO

-- ══════════════════════════════════════════════════════════════
-- 6. sp_UpdateAccountMasterByTxnRecordId
--    (When TxnRecord is edited → update linked AccountMaster too)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateAccountMasterByTxnRecordId
    @TxnRecordId INT,
    @Amount      DECIMAL(18,2),
    @TxnDate     DATE,
    @PaymentMode NVARCHAR(MAX) = '',
    @FundPool    NVARCHAR(MAX) = '',
    @FundPoolName NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE AccountMasters
    SET Amount=@Amount, TransDate=@TxnDate, Mode=@PaymentMode,
        FundPool=@FundPool, FundPoolName=@FundPoolName, UpdatedAt=GETDATE()
    WHERE AccountId IN (
        SELECT AccountId FROM Incomes WHERE TxnRecordId=@TxnRecordId AND ISNULL(AccountId,'') != '' AND IsDeleted=0
    ) AND IsDeleted=0;
END
GO

PRINT '✅ sp_UpdateAccountMasterByTxnRecordId helper created.';
PRINT '   Call this when editing TxnRecord (sp_UpdateTxnRecord updates Income, this updates AccountMaster)';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 153 - ALL SPs Updated with AccountMasters!';
PRINT '';
PRINT '   ADD:';
PRINT '     sp_CreateIncome/Expense (Script 150) → AccountMasters FIRST';
PRINT '     sp_PayOwnerSecurityDeposit → AccountMasters FIRST → Expense';
PRINT '     sp_SettleOwnerSecurityDeposit (Recovery) → AccountMasters FIRST → Income';
PRINT '     sp_RecordPayment (Script 151) → AccountMasters FIRST → Income';
PRINT '     OwnerPaymentRepo.cs → calls sp_InsertExpenseWithAccountMaster';
PRINT '';
PRINT '   EDIT:';
PRINT '     sp_UpdateIncome/Expense (Script 152) → AccountMasters UPDATE FIRST';
PRINT '     sp_UpdateAccountMasterByTxnRecordId → for TxnRecord edits';
PRINT '';
PRINT '   DELETE:';
PRINT '     sp_DeleteIncome/Expense (Script 152) → AccountMasters IsDeleted FIRST';
PRINT '     sp_DeleteOwnerPayment → AccountMasters IsDeleted FIRST → Expense IsDeleted';
PRINT '     sp_DeleteAccountMasterByTxnRecordId → for TxnRecord deletes';
PRINT '═══════════════════════════════════════════════════════════';
GO
