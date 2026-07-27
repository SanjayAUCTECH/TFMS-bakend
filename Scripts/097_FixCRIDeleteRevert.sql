-- ============================================================
-- 097: Fix ContractRoomInstallments revert on Payment Delete
--
-- ROOT CAUSE:
--   ContractRoomsTrns had no InstallmentNo/CriId columns, so
--   delete revert could not find the exact CRI row to reset.
--   It matched only by RoomId — wrong rows got updated.
--
-- FIX:
--   1. Add CriId + InstallmentNo columns to ContractRoomsTrns
--   2. Store them on INSERT (payment record time)
--   3. Use CriId for exact match on delete/edit revert
--   4. Fix sp_DeleteTxnRecord CRI revert using CriId
--   5. Fix sp_UpdateTxnRecord CRI revert using CriId
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: Add CriId + InstallmentNo to ContractRoomsTrns ───
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='CriId')
    ALTER TABLE ContractRoomsTrns ADD CriId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='InstallmentNo')
    ALTER TABLE ContractRoomsTrns ADD InstallmentNo INT NULL;
GO
PRINT 'ContractRoomsTrns: CriId + InstallmentNo columns added';
GO

-- ── Step 2: Fix sp_DeleteTxnRecord — exact CRI revert ────────
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ContractId NVARCHAR(MAX), @Amount DECIMAL(18,2),
            @FundPoolId INT, @AppliedInstallments NVARCHAR(MAX),
            @TxnType NVARCHAR(20), @TxnId NVARCHAR(MAX);

    SELECT @ContractId=ContractId, @Amount=Amount, @FundPoolId=FundPoolId,
           @AppliedInstallments=AppliedInstallments, @TxnType=TxnType, @TxnId=TxnId
    FROM TxnRecords WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found or already deleted.',16,1,@Id); RETURN; END

    IF @TxnType = 'CR'
    BEGIN
        -- 1. FundPool revert
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE()
            WHERE Id=@FundPoolId;

        -- 2. ContractInstallments — reset each applied installment to 0/Pending
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            UPDATE ci
            SET ci.PaidAmount=0, ci.PaidDate=NULL, ci.Status='Pending',
                ci.PaymentMode='', ci.PaymentModeId=NULL, ci.ChequeNumber='',
                ci.ClearanceDate='', ci.Description='', ci.ReceivedBy='',
                ci.ReceivedContact='', ci.FundPoolId=NULL, ci.FundPoolName='', ci.IssuedBy=''
            FROM ContractInstallments ci
            INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
                ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
            WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0;

            -- Re-mark overdue if past due date
            UPDATE ContractInstallments
            SET Status='Overdue'
            WHERE ContractId=@ContractId AND Status='Pending'
              AND DueDate < CAST(GETUTCDATE() AS DATE)
              AND ISNULL(IsDeleted,0)=0
              AND InstallmentNo IN (
                  SELECT CAST(TRIM(value) AS INT)
                  FROM STRING_SPLIT(@AppliedInstallments,',') WHERE TRIM(value)<>'');
        END

        -- 3. ContractRooms revert (sum per room from ContractRoomsTrns)
        UPDATE cr
        SET
            cr.PaidAmount = CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt < 0 THEN 0
                            ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END,
            cr.Balance    = ISNULL(cr.TotalAmount,0) - (
                CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt < 0 THEN 0
                ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END)
        FROM ContractRooms cr
        INNER JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt
            FROM ContractRoomsTrns
            WHERE TxnRecordId=@Id AND TxnType='CR' AND ContractId=@ContractId
            GROUP BY RoomId
        ) rt ON rt.RoomId=cr.RoomId
        WHERE cr.ContractId=@ContractId;

        -- 4. ContractRoomInstallments — EXACT revert using CriId (new) or fallback InstallmentNo+RoomId
        -- Method A: CriId stored in ContractRoomsTrns (new rows after this fix)
        UPDATE cri
        SET
            cri.PaidAmount  = 0,
            cri.Balance     = cri.InstallAmount,
            cri.Status      = CASE WHEN cri.DueDate < CAST(GETUTCDATE() AS DATE) THEN 'Pending' ELSE 'Pending' END,
            cri.PaidDate    = NULL,
            cri.PaymentMode = '',
            cri.ReferenceNo = '',
            cri.UpdatedAt   = GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt
            ON crt.CriId = cri.Id
        WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR';

        -- Method B: Fallback for old rows without CriId — use ContractId+RoomId+InstallmentNo match
        UPDATE cri
        SET
            cri.PaidAmount  = CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount < 0 THEN 0
                              ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END,
            cri.Balance     = cri.InstallAmount - (
                              CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount < 0 THEN 0
                              ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END),
            cri.Status      = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END) = 0 THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END) >= cri.InstallAmount THEN 'Paid'
                ELSE 'Partial' END,
            cri.PaidDate    = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END) = 0 THEN NULL
                ELSE cri.PaidDate END,
            cri.UpdatedAt   = GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt
            ON crt.ContractId  = cri.ContractId
            AND crt.RoomId     = cri.RoomId
            AND (crt.InstallmentNo = cri.InstallmentNo OR crt.InstallmentNo IS NULL)
        WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR'
          AND crt.CriId IS NULL;   -- only for old rows (CriId not set)

        -- 5. Delete ContractRoomsTrns
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId=@Id;

        -- 6. Incomes soft delete — exact match by TxnRecordId
        UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
        WHERE TxnRecordId=@Id AND ISNULL(IsDeleted,0)=0;

        -- Fallback: TxnId in Purpose
        IF @@ROWCOUNT=0 AND @TxnId IS NOT NULL AND LEN(@TxnId)>0
            UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
            WHERE ContractId=@ContractId AND Source='Tenant'
              AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;
    END

    -- 7. Soft delete TxnRecord
    UPDATE TxnRecords
    SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT 'sp_DeleteTxnRecord: exact CRI revert via CriId + fallback InstallmentNo+RoomId';
GO

-- ── Step 3: Fix sp_UpdateTxnRecord — exact CRI revert ────────
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

    SELECT @ContractId=ContractId, @OldAmount=Amount, @OldFundPoolId=FundPoolId,
           @AppliedInstallments=AppliedInstallments, @TxnId=TxnId
    FROM TxnRecords WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found.',16,1,@Id); RETURN; END

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId;

    -- 1. Update TxnRecord
    UPDATE TxnRecords
    SET Amount=@Amount, PaidDate=@TxnDate, PaymentMode=@PaymentMode,
        PaymentModeId=@PaymentModeId, FundPoolId=@FundPoolId,
        FundPoolName=@FundPoolName, Description=@Description,
        ReceivedBy=@ReceivedBy, ChequeNumber=ISNULL(NULLIF(@ChequeNumber,''),ChequeNumber),
        UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- 2. FundPool: revert old, apply new
    IF @OldFundPoolId IS NOT NULL AND @OldAmount > 0
        UPDATE FundPools SET Balance=Balance-@OldAmount, UpdatedAt=GETUTCDATE() WHERE Id=@OldFundPoolId;
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;

    -- 3. ContractInstallments: reset → re-apply
    IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
    BEGIN
        -- Reset all applied installments to 0/Pending
        UPDATE ci
        SET ci.PaidAmount=0, ci.PaidDate=NULL, ci.Status='Pending',
            ci.PaymentMode='', ci.PaymentModeId=NULL, ci.FundPoolId=NULL,
            ci.FundPoolName='', ci.Description='', ci.ReceivedBy=''
        FROM ContractInstallments ci
        INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
            ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
        WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0;

        -- Re-apply new amount across same installments
        DECLARE @Remaining DECIMAL(18,2) = @Amount;
        DECLARE @InstNo INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(MAX);

        DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT ci.InstallmentNo, ci.Amount, ci.PaidAmount
            FROM ContractInstallments ci
            INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
                ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
            WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0
            ORDER BY ci.InstallmentNo;

        OPEN inst_cur;
        FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;
        WHILE @@FETCH_STATUS=0 AND @Remaining>0
        BEGIN
            DECLARE @InstDue DECIMAL(18,2) = @InstAmt - @InstPaid;
            SET @ToApply   = CASE WHEN @Remaining>=@InstDue THEN @InstDue ELSE @Remaining END;
            SET @NewPaid   = @InstPaid + @ToApply;
            SET @NewStatus = CASE WHEN @NewPaid>=@InstAmt THEN 'Paid' WHEN @NewPaid>0 THEN 'Partial' ELSE 'Pending' END;
            UPDATE ContractInstallments
            SET PaidAmount=@NewPaid, PaidDate=@TxnDate, Status=@NewStatus,
                PaymentMode=@PaymentMode, PaymentModeId=@PaymentModeId,
                FundPoolId=@FundPoolId, FundPoolName=@FundPoolName,
                Description=@Description, ReceivedBy=@ReceivedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@InstNo AND ISNULL(IsDeleted,0)=0;
            SET @Remaining=@Remaining-@ToApply;
            FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;
        END;
        CLOSE inst_cur; DEALLOCATE inst_cur;
    END

    -- 4. ContractRoomInstallments — reset via CriId (exact) then re-apply from TxnDate/PaymentMode
    --    Method A: CriId available
    UPDATE cri
    SET cri.PaidAmount=0, cri.Balance=cri.InstallAmount,
        cri.Status='Pending', cri.PaidDate=NULL,
        cri.PaymentMode='', cri.ReferenceNo='', cri.UpdatedAt=GETUTCDATE()
    FROM ContractRoomInstallments cri
    INNER JOIN ContractRoomsTrns crt ON crt.CriId=cri.Id
    WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR';

    --    Method B: Fallback for old rows (InstallmentNo+RoomId)
    UPDATE cri
    SET cri.PaidAmount  = CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END,
        cri.Balance     = cri.InstallAmount-(CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END),
        cri.Status      = CASE
            WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END)=0 THEN 'Pending'
            WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END)>=cri.InstallAmount THEN 'Paid'
            ELSE 'Partial' END,
        cri.PaidDate    = NULL, cri.UpdatedAt=GETUTCDATE()
    FROM ContractRoomInstallments cri
    INNER JOIN ContractRoomsTrns crt
        ON crt.ContractId=cri.ContractId AND crt.RoomId=cri.RoomId
        AND (crt.InstallmentNo=cri.InstallmentNo OR crt.InstallmentNo IS NULL)
    WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR' AND crt.CriId IS NULL;

    -- 5. Incomes update
    UPDATE Incomes
    SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode), Amount=@Amount,
        FundPool=ISNULL(NULLIF(@FundPoolCode,''),FundPool),
        FundPoolName=ISNULL(NULLIF(@FundPoolName,''),FundPoolName),
        Purpose='Rent received - Inst: '+ISNULL(@AppliedInstallments,'')+' | Contract: '+@ContractId,
        UpdatedAt=GETUTCDATE()
    WHERE TxnRecordId=@Id AND ISNULL(IsDeleted,0)=0;

    IF @@ROWCOUNT=0 AND @TxnId IS NOT NULL AND LEN(@TxnId)>0
        UPDATE Incomes
        SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode), Amount=@Amount,
            Purpose='Rent received - Inst: '+ISNULL(@AppliedInstallments,'')+' | Contract: '+@ContractId,
            UpdatedAt=GETUTCDATE()
        WHERE ContractId=@ContractId AND Source='Tenant'
          AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT 'sp_UpdateTxnRecord: exact CRI revert via CriId + fallback';
GO

PRINT '=== 097 ALL DONE ===';
PRINT '1. ContractRoomsTrns: CriId + InstallmentNo columns added';
PRINT '2. sp_DeleteTxnRecord: CRI revert via CriId (exact) + fallback';
PRINT '3. sp_UpdateTxnRecord: CRI revert via CriId (exact) + fallback';
GO
