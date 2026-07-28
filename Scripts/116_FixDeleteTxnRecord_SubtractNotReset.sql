-- ============================================================
-- 116: Fix sp_DeleteTxnRecord
-- Bug: CI revert was setting PaidAmount=0 (wiping other payments)
-- Fix: SUBTRACT this TxnRecord's @Amount from PaidAmount
--      (other TxnRecord contributions stay intact)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

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
            WHERE Id=@FundPoolId AND IsDeleted=0;

        -- 2. ContractInstallments — SUBTRACT this txn's amount (not reset to 0)
        --    This preserves other TxnRecord contributions
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            -- Distribute the subtraction across applied installments in order
            -- Each installment: subtract proportionally what was applied to it
            CREATE TABLE #AppliedNos (InstNo INT);
            INSERT INTO #AppliedNos
            SELECT CAST(TRIM(value) AS INT) FROM STRING_SPLIT(@AppliedInstallments,',')
            WHERE TRIM(value)<>'';

            DECLARE @TotalApplied DECIMAL(18,2) = @Amount;
            DECLARE @CurNo INT; DECLARE @CurPaid DECIMAL(18,2); DECLARE @CurAmt DECIMAL(18,2);
            DECLARE @ToSubtract DECIMAL(18,2); DECLARE @NewPaid DECIMAL(18,2);
            DECLARE @NewStatus NVARCHAR(MAX);

            -- Process installments in order — subtract from each
            DECLARE sub_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT ci.InstallmentNo, ci.PaidAmount, ci.Amount
                FROM ContractInstallments ci
                JOIN #AppliedNos a ON a.InstNo=ci.InstallmentNo
                WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0
                ORDER BY ci.InstallmentNo;

            OPEN sub_cur;
            FETCH NEXT FROM sub_cur INTO @CurNo, @CurPaid, @CurAmt;

            WHILE @@FETCH_STATUS=0 AND @TotalApplied>0
            BEGIN
                -- Subtract up to what this installment has paid
                SET @ToSubtract = CASE WHEN @TotalApplied >= @CurPaid THEN @CurPaid ELSE @TotalApplied END;
                SET @NewPaid    = CASE WHEN @CurPaid - @ToSubtract < 0 THEN 0 ELSE @CurPaid - @ToSubtract END;
                SET @NewStatus  = CASE
                    WHEN @NewPaid=0 THEN 'Pending'
                    WHEN @NewPaid>=@CurAmt THEN 'Paid'
                    ELSE 'Partial'
                END;

                UPDATE ContractInstallments
                SET PaidAmount=@NewPaid, Status=@NewStatus,
                    PaidDate=CASE WHEN @NewPaid=0 THEN NULL ELSE PaidDate END
                WHERE ContractId=@ContractId AND InstallmentNo=@CurNo AND ISNULL(IsDeleted,0)=0;

                -- Re-mark overdue if past due and now pending
                UPDATE ContractInstallments
                SET Status='Overdue'
                WHERE ContractId=@ContractId AND InstallmentNo=@CurNo
                  AND Status='Pending' AND DueDate<CAST(GETUTCDATE() AS DATE) AND ISNULL(IsDeleted,0)=0;

                SET @TotalApplied = @TotalApplied - @ToSubtract;
                FETCH NEXT FROM sub_cur INTO @CurNo, @CurPaid, @CurAmt;
            END;
            CLOSE sub_cur; DEALLOCATE sub_cur;
            DROP TABLE #AppliedNos;
        END

        -- 3. ContractRooms revert (sum per room)
        UPDATE cr
        SET cr.PaidAmount=CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END,
            cr.Balance=ISNULL(cr.TotalAmount,0)-(CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END)
        FROM ContractRooms cr
        INNER JOIN (SELECT RoomId,SUM(Amount) TotalAmt FROM ContractRoomsTrns
                    WHERE TxnRecordId=@Id AND TxnType='CR' AND ContractId=@ContractId GROUP BY RoomId) rt
        ON rt.RoomId=cr.RoomId WHERE cr.ContractId=@ContractId;

        -- 4. ContractRoomInstallments revert — exact via CriId
        UPDATE cri
        SET cri.PaidAmount=0, cri.Balance=cri.InstallAmount,
            cri.Status='Pending', cri.PaidDate=NULL, cri.PaymentMode='', cri.UpdatedAt=GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt ON crt.CriId=cri.Id
        WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR';

        -- Fallback: old rows without CriId
        UPDATE cri
        SET cri.PaidAmount=CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END,
            cri.Balance=cri.InstallAmount-(CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-crt.Amount END),
            cri.Status=CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<=0 THEN 'Pending'
                            WHEN ISNULL(cri.PaidAmount,0)-crt.Amount>=cri.InstallAmount THEN 'Paid'
                            ELSE 'Partial' END,
            cri.PaidDate=CASE WHEN ISNULL(cri.PaidAmount,0)-crt.Amount<=0 THEN NULL ELSE cri.PaidDate END,
            cri.UpdatedAt=GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt ON crt.ContractId=cri.ContractId AND crt.RoomId=cri.RoomId
            AND (crt.InstallmentNo=cri.InstallmentNo OR crt.InstallmentNo IS NULL)
        WHERE crt.TxnRecordId=@Id AND crt.TxnType='CR' AND crt.CriId IS NULL;

        -- 5. Delete ContractRoomsTrns
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId=@Id;

        -- 6. Incomes soft delete
        UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
        WHERE TxnRecordId=@Id AND ISNULL(IsDeleted,0)=0;
        IF @@ROWCOUNT=0 AND @TxnId IS NOT NULL AND LEN(@TxnId)>0
            UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
            WHERE ContractId=@ContractId AND Source='Tenant'
              AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;
    END

    -- 7. Soft delete TxnRecord
    UPDATE TxnRecords SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#AppliedNos') IS NOT NULL DROP TABLE #AppliedNos;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_DeleteTxnRecord - subtract not reset, preserves other payment contributions';
GO
