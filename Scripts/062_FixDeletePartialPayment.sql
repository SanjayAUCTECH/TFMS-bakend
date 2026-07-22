-- ============================================================
-- 062: Fix sp_DeleteTxnRecord — partial payment delete
--      CRI revert: subtract CRT.Amount from CRI.PaidAmount
--      (not match by amount — that breaks for partial payments)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ContractId          NVARCHAR(MAX),
            @Amount              DECIMAL(18,2),
            @FundPoolId          INT,
            @AppliedInstallments NVARCHAR(MAX),
            @TxnType             NVARCHAR(20);

    SELECT
        @ContractId          = ContractId,
        @Amount              = Amount,
        @FundPoolId          = FundPoolId,
        @AppliedInstallments = AppliedInstallments,
        @TxnType             = TxnType
    FROM TxnRecords WHERE Id = @Id;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord not found.', 16, 1); RETURN; END

    IF @TxnType = 'CR'
    BEGIN
        -- 1. Revert FundPool
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools SET Balance = Balance - @Amount, UpdatedAt = GETDATE()
            WHERE Id = @FundPoolId;

        -- 2. Revert ContractInstallments
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            CREATE TABLE #DelInst (InstallmentNo INT);
            INSERT INTO #DelInst
            SELECT TRIM([value]) FROM STRING_SPLIT(@AppliedInstallments, ',')
            WHERE TRIM([value]) <> '';

            UPDATE ci
            SET
                ci.PaidAmount = CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END,
                ci.PaidDate   = CASE WHEN ci.PaidAmount - @Amount <= 0 THEN NULL ELSE ci.PaidDate END,
                ci.Status     = CASE
                    WHEN (CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END) = 0 THEN 'Pending'
                    WHEN (CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END) >= ci.Amount THEN 'Paid'
                    ELSE 'Partial'
                END
            FROM ContractInstallments ci
            JOIN #DelInst di ON ci.InstallmentNo = di.InstallmentNo
            WHERE ci.ContractId = @ContractId;

            DROP TABLE #DelInst;
        END

        -- 3. Revert ContractRooms — subtract sum of all CRT rows for this TxnRecord
        UPDATE cr
        SET
            cr.PaidAmount = CASE
                WHEN ISNULL(cr.PaidAmount, 0) - rt.TotalAmt < 0 THEN 0
                ELSE ISNULL(cr.PaidAmount, 0) - rt.TotalAmt
            END,
            cr.Balance = ISNULL(cr.TotalAmount, 0) - (
                CASE
                    WHEN ISNULL(cr.PaidAmount, 0) - rt.TotalAmt < 0 THEN 0
                    ELSE ISNULL(cr.PaidAmount, 0) - rt.TotalAmt
                END
            )
        FROM ContractRooms cr
        INNER JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt
            FROM ContractRoomsTrns
            WHERE TxnRecordId = @Id AND TxnType = 'CR' AND ContractId = @ContractId
            GROUP BY RoomId
        ) rt ON rt.RoomId = cr.RoomId
        WHERE cr.ContractId = @ContractId;

        -- 4. ✅ FIX: Revert ContractRoomInstallments — SUBTRACT CRT.Amount from CRI.PaidAmount
        --    This works correctly for partial payments (multiple TxnRecords on same CRI)
        UPDATE cri
        SET
            cri.PaidAmount = CASE
                WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0
                ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount
            END,
            cri.Balance = cri.InstallAmount - (
                CASE
                    WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0
                    ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount
                END
            ),
            cri.Status = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) = 0 THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) >= cri.InstallAmount THEN 'Paid'
                ELSE 'Partial'
            END,
            cri.PaidDate  = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) = 0 THEN NULL
                ELSE cri.PaidDate
            END,
            cri.UpdatedAt = GETDATE()
        FROM ContractRoomInstallments cri
        -- Join to the SUM of CRT amounts per room for this TxnRecord
        INNER JOIN (
            SELECT RoomId, SUM(Amount) Amount
            FROM ContractRoomsTrns
            WHERE TxnRecordId = @Id AND TxnType = 'CR' AND ContractId = @ContractId
            GROUP BY RoomId
        ) crt ON crt.RoomId = cri.RoomId
        WHERE cri.ContractId = @ContractId
          AND cri.PaidAmount > 0;   -- only revert rows that have been paid

        -- 5. Delete ContractRoomsTrns
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId = @Id;
    END

    -- 6. Delete TxnRecord
    DELETE FROM TxnRecords WHERE Id = @Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#DelInst') IS NOT NULL DROP TABLE #DelInst;
        THROW;
    END CATCH
END
GO

PRINT '062 - sp_DeleteTxnRecord: SUBTRACT approach for CRI revert (works for partial payments)';
GO
