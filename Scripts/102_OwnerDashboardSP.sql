-- ============================================================
-- 102: sp_GetOwnerDashboard
-- Owner Dashboard Summary + Recent Transactions
--
-- Summary (from OwnerTransactions WHERE IsDeleted=0):
--   TotalAmount = SUM of Type='DR'  (total payable to owner)
--   TotalPaid   = SUM of Type='CR'  (amount already paid)
--   TotalDue    = TotalAmount - TotalPaid
--
-- Recent Transactions: OwnerTransactions last 20
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetOwnerDashboard
    @OwnerId INT = NULL   -- Optional: NULL = all owners
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Summary ─────────────────────────────────────────────
    SELECT
        -- Owner Info
        ISNULL(o.Id,      0)  AS OwnerId,
        ISNULL(o.Code,   '') AS OwnerCode,
        ISNULL(o.Name,   '') AS OwnerName,
        ISNULL(o.Contact,'') AS OwnerContact,
        ISNULL(o.Email,  '') AS OwnerEmail,
        ISNULL(o.Status, '') AS OwnerStatus,

        -- Total Amount (DR = total rent to be paid to owner)
        ISNULL(SUM(CASE WHEN ot.Type='DR' THEN ot.Amount ELSE 0 END), 0) AS TotalAmount,

        -- Total Paid (CR = amount already paid to owner)
        ISNULL(SUM(CASE WHEN ot.Type='CR' THEN ot.Amount ELSE 0 END), 0) AS TotalPaid,

        -- Total Due = DR - CR
        ISNULL(SUM(CASE WHEN ot.Type='DR' THEN ot.Amount ELSE 0 END), 0)
        - ISNULL(SUM(CASE WHEN ot.Type='CR' THEN ot.Amount ELSE 0 END), 0) AS TotalDue,

        -- Active Contracts count
        ISNULL((
            SELECT COUNT(*)
            FROM OwnerContracts oc
            WHERE oc.IsDeleted=0
              AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
              AND oc.Status='Active'
        ), 0) AS ActiveContracts,

        -- Total Contracts count
        ISNULL((
            SELECT COUNT(*)
            FROM OwnerContracts oc
            WHERE oc.IsDeleted=0
              AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
        ), 0) AS TotalContracts

    FROM Owners o
    LEFT JOIN OwnerTransactions ot
        ON ot.OwnerId = o.Id
        AND ISNULL(ot.IsDeleted, 0) = 0
    WHERE o.IsDeleted = 0
      AND (@OwnerId IS NULL OR o.Id = @OwnerId)
    GROUP BY o.Id, o.Code, o.Name, o.Contact, o.Email, o.Status;

    -- ── 2. Recent Transactions (last 20) ───────────────────────
    SELECT TOP 20
        ot.Id,
        ISNULL(ot.TxnCode,         '') AS TxnCode,
        ot.OwnerContractId,
        ISNULL(ot.OcCode,          '') AS OcCode,
        ot.OwnerId,
        ISNULL(ot.OwnerName,       '') AS OwnerName,
        ot.CampId,
        ISNULL(ot.CampName,        '') AS CampName,
        ISNULL(ot.Type,            '') AS TxnType,
        ot.Amount,
        CONVERT(NVARCHAR(10), ot.Date, 23)  AS TxnDate,
        ISNULL(ot.Description,     '') AS Description,
        ISNULL(ot.InstallmentNos,  '') AS InstallmentNos,
        ot.ExpenseId,
        ot.CreatedAt
    FROM OwnerTransactions ot
    JOIN Owners o ON o.Id = ot.OwnerId AND o.IsDeleted = 0
    WHERE ISNULL(ot.IsDeleted, 0) = 0
      AND (@OwnerId IS NULL OR ot.OwnerId = @OwnerId)
    ORDER BY ot.Id DESC;
END
GO

PRINT '✅ sp_GetOwnerDashboard created';
GO
