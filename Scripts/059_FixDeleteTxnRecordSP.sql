-- ============================================================
-- 059: Fix sp_DeleteTxnRecord — full revert on delete
--      Revert: ContractInstallments, FundPools, ContractRooms,
--              ContractRoomsTrns, ContractRoomInstallments
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

    -- Only revert for CR (payment) type
    IF @TxnType = 'CR'
    BEGIN
        -- 2. Revert FundPool balance
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools
            SET Balance = Balance - @Amount, UpdatedAt = GETDATE()
            WHERE Id = @FundPoolId;

        -- 3. Revert ContractInstallments
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

        -- 4. Revert ContractRooms (from ContractRoomsTrns)
        UPDATE cr
        SET
            cr.PaidAmount = CASE WHEN ISNULL(cr.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount,0) - crt.Amount END,
            cr.Balance    = ISNULL(cr.TotalAmount,0) - (CASE WHEN ISNULL(cr.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount,0) - crt.Amount END)
        FROM ContractRooms cr
        INNER JOIN ContractRoomsTrns crt ON crt.ContractId = cr.ContractId AND crt.RoomId = cr.RoomId
        WHERE crt.TxnRecordId = @Id AND crt.TxnType = 'CR';

        -- 5. Revert ContractRoomInstallments
        -- For each room entry in ContractRoomsTrns linked to this TxnRecord,
        -- find matching CRI and subtract
        UPDATE cri
        SET
            cri.PaidAmount = CASE WHEN ISNULL(cri.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount,0) - crt.Amount END,
            cri.Balance    = cri.InstallAmount - (CASE WHEN ISNULL(cri.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount,0) - crt.Amount END),
            cri.Status     = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount,0) - crt.Amount END) = 0 THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount,0) - crt.Amount END) >= cri.InstallAmount THEN 'Paid'
                ELSE 'Partial'
            END,
            cri.PaidDate   = NULL,
            cri.UpdatedAt  = GETDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt ON crt.ContractId = cri.ContractId
            AND crt.RoomId = cri.RoomId
        WHERE crt.TxnRecordId = @Id AND crt.TxnType = 'CR'
          AND cri.InstallmentNo = (
              SELECT TOP 1 tr2.InstallmentNo FROM TxnRecords tr2 WHERE tr2.Id = @Id
          );

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

PRINT '059 - sp_DeleteTxnRecord: full revert on all tables before delete';
GO
