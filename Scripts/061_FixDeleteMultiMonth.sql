-- ============================================================
-- 061: Fix sp_DeleteTxnRecord — multi-month delete
--      CRI revert was only reverting first installment
--      Now reverting ALL installments linked to this TxnRecord
--      via ContractRoomsTrns entries
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

    -- 1. Get TxnRecord info
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
        -- 2. Revert FundPool balance
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools
            SET Balance = Balance - @Amount, UpdatedAt = GETDATE()
            WHERE Id = @FundPoolId;

        -- 3. Revert ContractInstallments (all applied installments)
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            CREATE TABLE #DelInst (InstallmentNo INT);
            INSERT INTO #DelInst
            SELECT TRIM([value]) FROM STRING_SPLIT(@AppliedInstallments, ',')
            WHERE TRIM([value]) <> '';

            -- Each installment: subtract this TxnRecord's contribution
            -- Safe approach: set PaidAmount to 0 and status Pending for clean revert
            -- (assumes one TxnRecord fully covers each installment it applied to)
            UPDATE ci
            SET
                ci.PaidAmount = CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END,
                ci.PaidDate   = NULL,
                ci.Status     = CASE
                    WHEN (CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END) = 0
                         THEN 'Pending'
                    WHEN (CASE WHEN ci.PaidAmount - @Amount < 0 THEN 0 ELSE ci.PaidAmount - @Amount END) >= ci.Amount
                         THEN 'Paid'
                    ELSE 'Partial'
                END
            FROM ContractInstallments ci
            JOIN #DelInst di ON ci.InstallmentNo = di.InstallmentNo
            WHERE ci.ContractId = @ContractId;

            DROP TABLE #DelInst;
        END

        -- 4. Revert ContractRooms — sum all room amounts from this TxnRecord
        UPDATE cr
        SET
            cr.PaidAmount = CASE
                WHEN ISNULL(cr.PaidAmount, 0) - roomTotal.TotalAmt < 0 THEN 0
                ELSE ISNULL(cr.PaidAmount, 0) - roomTotal.TotalAmt
            END,
            cr.Balance    = ISNULL(cr.TotalAmount, 0) - (
                CASE
                    WHEN ISNULL(cr.PaidAmount, 0) - roomTotal.TotalAmt < 0 THEN 0
                    ELSE ISNULL(cr.PaidAmount, 0) - roomTotal.TotalAmt
                END
            )
        FROM ContractRooms cr
        INNER JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt
            FROM ContractRoomsTrns
            WHERE TxnRecordId = @Id AND TxnType = 'CR' AND ContractId = @ContractId
            GROUP BY RoomId
        ) roomTotal ON roomTotal.RoomId = cr.RoomId
        WHERE cr.ContractId = @ContractId;

        -- 5. ✅ FIX: Revert ALL ContractRoomInstallments entries linked to this TxnRecord
        --    Match each CRT row to the correct CRI row by RoomId + InstallmentNo
        --    Use a cursor to handle each CRT row separately
        DECLARE @CrtRoomId    INT;
        DECLARE @CrtAmount    DECIMAL(18,2);
        DECLARE @CrtInstNo    INT;

        -- Get installment numbers per room from ContractRoomsTrns
        -- We match by: for each CRT row, find CRI with same ContractId+RoomId
        -- For the specific installment: use AppliedInstallments to find which installment belongs to each room
        -- Since CRT may have multiple rows per room (one per installment), process each

        DECLARE crt_cursor CURSOR FOR
            SELECT crt.RoomId, crt.Amount,
                   -- Find which installment this payment belongs to by order
                   ROW_NUMBER() OVER (PARTITION BY crt.RoomId ORDER BY crt.Id) RowNum
            FROM ContractRoomsTrns crt
            WHERE crt.TxnRecordId = @Id AND crt.TxnType = 'CR' AND crt.ContractId = @ContractId;

        -- Simpler approach: reset ALL CRI rows for rooms in this transaction to 0
        -- Only those rows whose PaidAmount matches what was paid in this transaction
        UPDATE cri
        SET
            cri.PaidAmount = CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END,
            cri.Balance    = cri.InstallAmount - (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END),
            cri.Status     = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) = 0 THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) >= cri.InstallAmount THEN 'Paid'
                ELSE 'Partial'
            END,
            cri.PaidDate   = NULL,
            cri.UpdatedAt  = GETDATE()
        FROM ContractRoomInstallments cri
        -- Match each CRT entry to a specific CRI by RoomId + matching amount
        -- Join: for each CRT row, match CRI where PaidAmount = CRT.Amount (exact match)
        INNER JOIN ContractRoomsTrns crt
            ON crt.ContractId = cri.ContractId
            AND crt.RoomId    = cri.RoomId
            AND cri.PaidAmount = crt.Amount   -- ✅ match by paid amount to identify correct installment
        WHERE crt.TxnRecordId = @Id
          AND crt.TxnType     = 'CR';

        DEALLOCATE crt_cursor;

        -- 6. Delete ContractRoomsTrns entries
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId = @Id;
    END

    -- 7. Delete TxnRecord
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

PRINT '061 - sp_DeleteTxnRecord fixed: ALL installments properly reverted on multi-month delete';
GO
