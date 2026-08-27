SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ══════════════════════════════════════════════════════════════════════════
-- sp_DeleteSecurityDeposit
-- Deletes ONE security deposit receipt (identified by TxnRecordId).
-- Reverts everything that sp_ReceiveSecurityDeposit did:
--   UPDATE reverts:
--     • Contracts.SecurityDepositPaid  -= amount   → status recalculated
--     • FundPools.Balance              -= amount
--     • ContractRooms.SecurityPaidAmount -= proportional (per room)
--   INSERT deletes:
--     • TxnRecords     (this SD-CR record)
--     • Incomes        (matching TxnRecordId)
--     • ContractRoomsTrns (matching TxnRecordId, SD-CR)
-- ══════════════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_DeleteSecurityDeposit
    @TxnRecordId  INT,
    @DeletedBy    INT           = NULL,
    @NewPaid      DECIMAL(18,2) OUTPUT,
    @NewStatus    NVARCHAR(50)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Step 1: Fetch the SD transaction ──────────────────────────────────
    DECLARE @ContractId NVARCHAR(450),
            @Amount      DECIMAL(18,2),
            @FundPoolId  INT;

    SELECT
        @ContractId = ContractId,
        @Amount     = Amount,
        @FundPoolId = FundPoolId
    FROM TxnRecords
    WHERE Id = @TxnRecordId
      AND TxnType = 'SD-CR'
      AND ISNULL(IsDeleted, 0) = 0;

    IF @ContractId IS NULL
    BEGIN
        RAISERROR('Security deposit transaction not found or already deleted.', 16, 1);
        RETURN;
    END

    -- ── Step 2: Revert Contracts (SD paid & status) ───────────────────────
    DECLARE @DepositAmount DECIMAL(18,2), @CurrentPaid DECIMAL(18,2);
    SELECT
        @DepositAmount = ISNULL(SecurityDeposit, 0),
        @CurrentPaid   = ISNULL(SecurityDepositPaid, 0)
    FROM Contracts WHERE ContractId = @ContractId;

    SET @NewPaid = @CurrentPaid - @Amount;
    IF @NewPaid < 0 SET @NewPaid = 0;

    SET @NewStatus = CASE
        WHEN @NewPaid <= 0                  THEN 'Pending'
        WHEN @NewPaid >= @DepositAmount     THEN 'Received'
        ELSE 'Partially Received'
    END;

    UPDATE Contracts
    SET SecurityDepositPaid   = @NewPaid,
        SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    -- ── Step 3: Revert FundPool balance ───────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools
        SET Balance   = Balance - @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

    -- ── Step 4: Revert ContractRooms (per-room paid & due) ─────────────────
    --   Reverse using the per-room amounts recorded in ContractRoomsTrns
    UPDATE cr
    SET
        cr.SecurityPaidAmount = CASE
            WHEN ISNULL(cr.SecurityPaidAmount,0) - crt.Amount < 0 THEN 0
            ELSE ISNULL(cr.SecurityPaidAmount,0) - crt.Amount
        END,
        cr.SecurityDueAmount  = CASE
            WHEN ISNULL(cr.SecurityAmount,0)
                 - (CASE WHEN ISNULL(cr.SecurityPaidAmount,0) - crt.Amount < 0 THEN 0
                         ELSE ISNULL(cr.SecurityPaidAmount,0) - crt.Amount END) < 0
            THEN 0
            ELSE ISNULL(cr.SecurityAmount,0)
                 - (CASE WHEN ISNULL(cr.SecurityPaidAmount,0) - crt.Amount < 0 THEN 0
                         ELSE ISNULL(cr.SecurityPaidAmount,0) - crt.Amount END)
        END,
        cr.UpdatedAt = GETDATE()
    FROM ContractRooms cr
    INNER JOIN ContractRoomsTrns crt
        ON  crt.ContractId  = cr.ContractId
        AND crt.RoomId      = cr.RoomId
        AND crt.TxnRecordId = @TxnRecordId
        AND crt.TxnType     = 'SD-CR'
        AND ISNULL(crt.IsDeleted,0) = 0
    WHERE cr.ContractId = @ContractId
      AND ISNULL(cr.IsDeleted,0) = 0;

    -- ── Step 5: DELETE ContractRoomsTrns (per-room SD-CR) ──────────────────
    UPDATE ContractRoomsTrns
    SET IsDeleted = 1,
        DeletedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE TxnRecordId = @TxnRecordId
      AND TxnType = 'SD-CR'
      AND ISNULL(IsDeleted,0) = 0;

    -- ── Step 6: DELETE Incomes (SD-CR income entry) ────────────────────────
    UPDATE Incomes
    SET IsDeleted = 1,
        DeletedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE TxnRecordId = @TxnRecordId
      AND ISNULL(IsDeleted,0) = 0;

    -- ── Step 7: DELETE TxnRecords (main SD-CR record) ──────────────────────
    UPDATE TxnRecords
    SET IsDeleted = 1,
        DeletedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @TxnRecordId
      AND ISNULL(IsDeleted,0) = 0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'sp_DeleteSecurityDeposit created successfully.';
GO
