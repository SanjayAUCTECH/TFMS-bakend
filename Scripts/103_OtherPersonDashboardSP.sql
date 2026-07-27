-- ============================================================
-- 103: sp_GetOtherPersonDashboard
-- Other Accounts Dashboard
--
-- Summary:
--   TotalIncome = SUM(Expenses.Amount)
--                WHERE RecipientRole='OtherPerson' AND RecipientId=@PersonId
--                (Company expense = OtherPerson credit/income)
--
-- Recent Transactions:
--   Expenses WHERE RecipientRole='OtherPerson'
--   TxnType = 'Credit' (OtherPerson perspective)
--
-- All filters: IsDeleted=0
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetOtherPersonDashboard
    @PersonId INT = NULL   -- Optional: NULL = all other persons
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Summary ─────────────────────────────────────────────
    SELECT
        -- OtherPerson Info
        ISNULL(op.Id,          0)  AS PersonId,
        ISNULL(op.Code,       '') AS PersonCode,
        ISNULL(op.Name,       '') AS PersonName,
        ISNULL(op.Designation,'') AS Designation,
        ISNULL(op.Mobile,     '') AS Mobile,
        ISNULL(op.Email,      '') AS Email,
        ISNULL(op.Address,    '') AS Address,
        ISNULL(op.Status,     '') AS Status,

        -- Total Income (company expense = OtherPerson credit)
        ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0) = 0
              AND e.RecipientRole = 'OtherPerson'
              AND (@PersonId IS NULL OR e.RecipientId = @PersonId)
        ), 0) AS TotalIncome,

        -- Total Transactions count
        ISNULL((
            SELECT COUNT(*)
            FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0) = 0
              AND e.RecipientRole = 'OtherPerson'
              AND (@PersonId IS NULL OR e.RecipientId = @PersonId)
        ), 0) AS TotalTransactions

    FROM OtherPersons op
    WHERE op.IsDeleted = 0
      AND (@PersonId IS NULL OR op.Id = @PersonId);

    -- ── 2. Recent Transactions (last 30) ───────────────────────
    -- Company expense to OtherPerson = Credit for OtherPerson
    SELECT TOP 30
        e.Id,
        e.ExpenseId                     AS TxnRefId,
        'Credit'                        AS TxnType,   -- OtherPerson perspective: credit
        CONVERT(NVARCHAR(10), e.Date, 23) AS Date,
        e.Amount,
        ISNULL(e.Head,        '')       AS Head,
        ISNULL(e.Mode,        '')       AS Mode,
        ISNULL(e.FundPoolName,'')       AS FundPoolName,
        ISNULL(e.Purpose,     '')       AS Purpose,
        ISNULL(e.CampId,      0)        AS CampId,
        ISNULL(e.CampName,    '')       AS CampName,
        ISNULL(e.RecipientId, 0)        AS RecipientId,
        ISNULL(e.RecipientName,'')      AS RecipientName,
        e.CreatedAt
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted, 0) = 0
      AND e.RecipientRole = 'OtherPerson'
      AND (@PersonId IS NULL OR e.RecipientId = @PersonId)
    ORDER BY e.CreatedAt DESC;
END
GO

PRINT '✅ sp_GetOtherPersonDashboard created';
GO
