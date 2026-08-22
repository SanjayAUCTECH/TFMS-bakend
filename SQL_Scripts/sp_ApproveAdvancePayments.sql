SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ============================================================
-- sp_ApproveAdvancePayments
-- Approves advanced payments for a selected month by:
--   1. ContractRoomInstallments:
--        Advanced       → Paid
--        AdvancedPartial → PaidPartial
--        PaidDate       → @PaymentDate
--   2. ContractRoomsTrns:
--        PaymentStatus  → same mapped value
--        TxnDate        → @PaymentDate
--
-- Filter: only records where Month = @Month (format: 'Jul26')
--         Optional: @ContractId, @CampId, @RoomId for targeted approval
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ApproveAdvancePayments
    @PaymentDate  DATE,           -- new PaidDate / TxnDate
    @Month        NVARCHAR(10),   -- e.g. 'Jul26'
    @ContractId   NVARCHAR(50) = NULL,   -- optional: single contract
    @CampId       INT          = NULL,   -- optional: single camp
    @RoomId       INT          = NULL,   -- optional: single room
    @ApprovedBy   INT          = NULL,   -- userId from JWT
    @UpdatedCount INT          OUTPUT    -- total CRI rows updated
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Step 1: Update ContractRoomInstallments ─────────────────
    UPDATE cri
    SET
        Status    = CASE
                        WHEN cri.Status = 'Advanced'        THEN 'Paid'
                        WHEN cri.Status = 'AdvancedPartial' THEN 'PaidPartial'
                        ELSE cri.Status   -- safety: don't touch others
                    END,
        PaidDate  = @PaymentDate,
        UpdatedBy = @ApprovedBy,
        UpdatedAt = GETDATE()
    FROM ContractRoomInstallments cri
    WHERE ISNULL(cri.IsDeleted, 0) = 0
      AND cri.Month  = @Month
      AND cri.Status IN ('Advanced', 'AdvancedPartial')
      AND (@ContractId IS NULL OR cri.ContractId = @ContractId)
      AND (@CampId     IS NULL OR cri.CampId     = @CampId)
      AND (@RoomId     IS NULL OR cri.RoomId     = @RoomId);

    SET @UpdatedCount = @@ROWCOUNT;

    -- ── Step 2: Update ContractRoomsTrns (matching CriId) ───────
    UPDATE crt
    SET
        PaymentStatus = CASE
                            WHEN cri2.Status = 'Paid'        THEN 'Paid'
                            WHEN cri2.Status = 'PaidPartial' THEN 'PaidPartial'
                            ELSE crt.PaymentStatus
                        END,
        TxnDate   = @PaymentDate,
        UpdatedBy = @ApprovedBy,
        UpdatedAt = GETDATE()
    FROM ContractRoomsTrns crt
    INNER JOIN ContractRoomInstallments cri2
           ON cri2.Id     = crt.CriId
          AND cri2.Month  = @Month
          AND cri2.Status IN ('Paid', 'PaidPartial')   -- already updated in Step 1
          AND ISNULL(cri2.IsDeleted, 0) = 0
    WHERE ISNULL(crt.IsDeleted, 0) = 0
      AND crt.PaymentStatus IN ('Advanced', 'AdvancedPartial')
      AND (@ContractId IS NULL OR crt.ContractId = @ContractId)
      AND (@CampId     IS NULL OR crt.CampId     = @CampId)
      AND (@RoomId     IS NULL OR crt.RoomId     = @RoomId);

    -- ── Step 3: Return updated rows detail ──────────────────────
    SELECT
        cri3.Id               AS CriId,
        cri3.ContractId,
        cri3.CampId,
        cri3.CampName,
        cri3.RoomId,
        cri3.RoomNo,
        cri3.InstallmentNo,
        cri3.Month,
        cri3.InstallAmount,
        cri3.PaidAmount,
        cri3.Status           AS NewStatus,
        cri3.PaidDate         AS NewPaidDate
    FROM ContractRoomInstallments cri3
    WHERE ISNULL(cri3.IsDeleted, 0) = 0
      AND cri3.Month  = @Month
      AND cri3.Status IN ('Paid', 'PaidPartial')
      AND cri3.PaidDate = @PaymentDate
      AND (@ContractId IS NULL OR cri3.ContractId = @ContractId)
      AND (@CampId     IS NULL OR cri3.CampId     = @CampId)
      AND (@RoomId     IS NULL OR cri3.RoomId     = @RoomId)
    ORDER BY cri3.ContractId, cri3.RoomId, cri3.InstallmentNo;
END;
GO

PRINT 'sp_ApproveAdvancePayments created successfully.';
GO
