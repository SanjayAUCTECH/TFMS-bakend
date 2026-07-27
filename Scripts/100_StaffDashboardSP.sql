-- ============================================================
-- 100: sp_GetStaffDashboard
-- Staff Dashboard Summary + Recent Transactions
--
-- Summary:
--   TotalIncome  = SUM(Expenses.Amount) WHERE RecipientRole='Staff'
--                  (Company ke liye expense, staff ke liye income/credit)
--   RecentTransactions = Expenses WHERE RecipientRole='Staff'
--                        Type = 'Credit' (staff perspective)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetStaffDashboard
    @StaffId INT = NULL   -- Optional: NULL = all staff
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Summary ─────────────────────────────────────────────
    SELECT
        -- Staff Info
        ISNULL(s.Id, 0)           AS StaffId,
        ISNULL(s.StaffId, '')     AS StaffCode,
        ISNULL(s.Name, '')        AS StaffName,
        ISNULL(s.Role, '')        AS Role,
        ISNULL(s.Designation, '') AS Designation,
        ISNULL(s.JobTitle, '')    AS JobTitle,
        ISNULL(s.Contact, '')     AS Contact,
        ISNULL(s.Email, '')       AS Email,
        ISNULL(s.Status, '')      AS Status,

        -- Total Income (from company expense = staff credit)
        ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0) = 0
              AND e.RecipientRole = 'Staff'
              AND (@StaffId IS NULL OR e.RecipientId = @StaffId)
        ), 0) AS TotalIncome,

        -- Total Transactions count
        ISNULL((
            SELECT COUNT(*)
            FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0) = 0
              AND e.RecipientRole = 'Staff'
              AND (@StaffId IS NULL OR e.RecipientId = @StaffId)
        ), 0) AS TotalTransactions

    FROM Staff s
    WHERE s.IsDeleted = 0
      AND (@StaffId IS NULL OR s.Id = @StaffId);

    -- ── 2. Recent Transactions (last 30) ───────────────────────
    -- Expenses WHERE RecipientRole='Staff' = staff income (Credit for staff)
    SELECT TOP 30
        e.Id,
        e.ExpenseId             AS TxnRefId,
        'Credit'                AS TxnType,     -- Staff perspective: credit/income
        CONVERT(NVARCHAR(10), e.Date, 23) AS Date,
        e.Amount,
        ISNULL(e.Head, '')      AS Head,
        ISNULL(e.Mode, '')      AS Mode,
        ISNULL(e.FundPoolName, '') AS FundPoolName,
        ISNULL(e.Purpose, '')   AS Purpose,
        ISNULL(e.CampId, 0)     AS CampId,
        ISNULL(e.CampName, '')  AS CampName,
        ISNULL(e.RecipientId, 0)    AS RecipientId,
        ISNULL(e.RecipientName, '') AS RecipientName,
        e.CreatedAt
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted, 0) = 0
      AND e.RecipientRole = 'Staff'
      AND (@StaffId IS NULL OR e.RecipientId = @StaffId)
    ORDER BY e.CreatedAt DESC;
END
GO

PRINT '✅ sp_GetStaffDashboard created';
GO
