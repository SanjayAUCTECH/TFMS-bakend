-- ============================================================
-- 115: Fix sp_UpdateTxnRecord - overflow distribute to next installments
-- Bug: Re-apply only went to AppliedInstallments, overflow lost
-- Fix: After applying to original installments, remaining goes to
--      next pending installments (same as sp_RecordPayment)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id             INT,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @PaymentMode    NVARCHAR(MAX) = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(MAX) = '',
    @Description    NVARCHAR(MAX) = '',
    @ReceivedBy     NVARCHAR(MAX) = '',
    @ChequeNumber   NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ContractId NVARCHAR(MAX), @OldAmount DECIMAL(18,2),
            @OldFundPoolId INT, @AppliedInstallments NVARCHAR(MAX), @TxnId NVARCHAR(MAX);
    DECLARE @FundPoolCode NVARCHAR(MAX) = '';
    DECLARE @FirstAppliedNo INT = NULL;

    SELECT @ContractId=ContractId, @OldAmount=Amount, @OldFundPoolId=FundPoolId,
           @AppliedInstallments=AppliedInstallments, @TxnId=TxnId
    FROM TxnRecords WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found.',16,1,@Id); RETURN; END

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId AND IsDeleted=0;

    -- Get first applied installment number (to determine where to start re-apply)
    IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments)>0
    BEGIN
        IF CHARINDEX(',',@AppliedInstallments)>0
            SET @FirstAppliedNo=CAST(LEFT(@AppliedInstallments,CHARINDEX(',',@AppliedInstallments)-1) AS INT);
        ELSE
            SET @FirstAppliedNo=CAST(@AppliedInstallments AS INT);
    END

    -- 1. Update TxnRecord
    UPDATE TxnRecords
    SET Amount=@Amount, PaidDate=@TxnDate, PaymentMode=@PaymentMode,
        PaymentModeId=@PaymentModeId, FundPoolId=@FundPoolId,
        FundPoolName=@FundPoolName, Description=@Description,
        ReceivedBy=@ReceivedBy, ChequeNumber=ISNULL(NULLIF(@ChequeNumber,''),ChequeNumber),
        UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- 2. FundPool: revert old, apply new
    IF @OldFundPoolId IS NOT NULL AND @OldAmount>0
        UPDATE FundPools SET Balance=Balance-@OldAmount, UpdatedAt=GETUTCDATE() WHERE Id=@OldFundPoolId AND IsDeleted=0;
    IF @FundPoolId IS NOT NULL AND @Amount>0
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId AND IsDeleted=0;

    -- 3. ContractInstallments: reset applied installments → re-apply with overflow
    IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments)>0
    BEGIN
        -- Step A: Revert only THIS TxnRecord's contribution (subtract old amount)
        --         NOT reset to 0 — other TxnRecords may have also paid this installment
        UPDATE ci
        SET ci.PaidAmount = CASE WHEN ci.PaidAmount - @OldAmount < 0 THEN 0
                            ELSE ci.PaidAmount - @OldAmount END,
            ci.PaidDate   = CASE WHEN ci.PaidAmount - @OldAmount <= 0 THEN NULL ELSE ci.PaidDate END,
            ci.Status     = CASE
                WHEN (CASE WHEN ci.PaidAmount-@OldAmount<0 THEN 0 ELSE ci.PaidAmount-@OldAmount END)=0 THEN 'Pending'
                WHEN (CASE WHEN ci.PaidAmount-@OldAmount<0 THEN 0 ELSE ci.PaidAmount-@OldAmount END)>=ci.Amount THEN 'Paid'
                ELSE 'Partial' END,
            ci.PaymentMode='', ci.PaymentModeId=NULL,
            ci.FundPoolId=NULL, ci.FundPoolName='',
            ci.Description='', ci.ReceivedBy=''
        FROM ContractInstallments ci
        INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
            ON ci.InstallmentNo=CAST(TRIM(s.value) AS INT)
        WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0;

        -- Step B: Re-apply new amount starting from first applied installment
        --         Overflow goes to next pending installments automatically
        CREATE TABLE #ReApply (InstallmentNo INT, Amount DECIMAL(18,2), PaidAmount DECIMAL(18,2), Due DECIMAL(18,2));

        INSERT INTO #ReApply
        SELECT InstallmentNo, Amount, ISNULL(PaidAmount,0), Amount-ISNULL(PaidAmount,0)
        FROM ContractInstallments
        WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0
          AND Status IN('Pending','Partial','Overdue')
          AND Amount-ISNULL(PaidAmount,0)>0
          AND (@FirstAppliedNo IS NULL OR InstallmentNo>=@FirstAppliedNo)
        ORDER BY InstallmentNo;

        DECLARE @Remaining DECIMAL(18,2) = @Amount;
        DECLARE @NewAppliedList NVARCHAR(MAX) = '';
        DECLARE @CurNo INT; DECLARE @CurAmt DECIMAL(18,2);
        DECLARE @CurPaid DECIMAL(18,2); DECLARE @CurDue DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2); DECLARE @NewPaid DECIMAL(18,2);
        DECLARE @NewStatus NVARCHAR(MAX);

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Due FROM #ReApply ORDER BY InstallmentNo;
        OPEN cur;
        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;

        WHILE @@FETCH_STATUS=0 AND @Remaining>0
        BEGIN
            SET @ToApply   = CASE WHEN @Remaining>=@CurDue THEN @CurDue ELSE @Remaining END;
            SET @NewPaid   = @CurPaid + @ToApply;
            SET @NewStatus = CASE WHEN @NewPaid>=@CurAmt THEN 'Paid' WHEN @NewPaid>0 THEN 'Partial' ELSE 'Pending' END;

            UPDATE ContractInstallments
            SET PaidAmount=@NewPaid, PaidDate=@TxnDate, Status=@NewStatus,
                PaymentMode=@PaymentMode, PaymentModeId=@PaymentModeId,
                FundPoolId=@FundPoolId, FundPoolName=@FundPoolName,
                Description=@Description, ReceivedBy=@ReceivedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@CurNo AND ISNULL(IsDeleted,0)=0;

            SET @NewAppliedList = CASE WHEN @NewAppliedList='' THEN CAST(@CurNo AS NVARCHAR)
                                  ELSE @NewAppliedList+','+CAST(@CurNo AS NVARCHAR) END;
            SET @Remaining = @Remaining - @ToApply;
            FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
        END;
        CLOSE cur; DEALLOCATE cur; DROP TABLE #ReApply;

        -- Update TxnRecord with new AppliedInstallments list
        UPDATE TxnRecords SET AppliedInstallments=@NewAppliedList
        WHERE Id=@Id;
    END

    -- 4. Incomes update (by TxnRecordId exact match)
    UPDATE Incomes
    SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode), Amount=@Amount,
        FundPool=ISNULL(NULLIF(@FundPoolCode,''),FundPool),
        FundPoolName=ISNULL(NULLIF(@FundPoolName,''),FundPoolName),
        UpdatedAt=GETUTCDATE()
    WHERE TxnRecordId=@Id AND ISNULL(IsDeleted,0)=0;

    -- Fallback: TxnId match in Purpose
    IF @@ROWCOUNT=0 AND @TxnId IS NOT NULL AND LEN(@TxnId)>0
        UPDATE Incomes
        SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode), Amount=@Amount,
            UpdatedAt=GETUTCDATE()
        WHERE ContractId=@ContractId AND Source='Tenant'
          AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#ReApply') IS NOT NULL DROP TABLE #ReApply;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_UpdateTxnRecord fixed - overflow distributes to next installments';
GO
