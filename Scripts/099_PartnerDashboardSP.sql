-- ============================================================
-- 099: sp_GetPartnerDashboard
-- Partner Dashboard — summary + recent transactions
--
-- Summary:
--   TotalIncome   = SUM(Incomes.Amount) WHERE PartnerId=@PartnerId
--   TotalExpense  = SUM(Expenses.Amount) WHERE RecipientRole='Partner' AND RecipientId=@PartnerId
--   NetBalance    = TotalIncome - TotalExpense
--   AssignedCamps = COUNT of CampPartners
--   TotalRooms / OccupiedRooms / VacantRooms from Rooms
--
-- Recent Transactions:
--   UNION of Incomes (type=Income) + Expenses (type=Expense)
--   Filtered by PartnerId
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerDashboard
    @PartnerId INT = NULL   -- Optional: NULL = all partners
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Summary ─────────────────────────────────────────────
    SELECT
        -- Partner Info
        ISNULL(p.Id, 0)      AS PartnerId,
        ISNULL(p.Name, '')   AS PartnerName,
        ISNULL(p.Code, '')   AS PartnerCode,
        ISNULL(p.Contact,'') AS PartnerContact,
        ISNULL(p.Email,'')   AS PartnerEmail,
        ISNULL(p.Status,'')  AS PartnerStatus,

        -- Income: from Incomes table where PartnerId matches
        ISNULL((
            SELECT SUM(i.Amount)
            FROM Incomes i
            WHERE ISNULL(i.IsDeleted,0)=0
              AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)
        ), 0) AS TotalIncome,

        -- Expense: from Expenses where RecipientRole=Partner
        ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0)=0
              AND e.RecipientRole='Partner'
              AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)
        ), 0) AS TotalExpense,

        -- Net Balance
        ISNULL((
            SELECT SUM(i.Amount) FROM Incomes i
            WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)
        ), 0)
        - ISNULL((
            SELECT SUM(e.Amount) FROM Expenses e
            WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner'
              AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)
        ), 0) AS NetBalance,

        -- Assigned Camps
        ISNULL((
            SELECT COUNT(DISTINCT cp.CampId)
            FROM CampPartners cp
            WHERE ISNULL(cp.IsDeleted,0)=0
              AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
        ), 0) AS AssignedCamps,

        -- Total Rooms across partner's camps
        ISNULL((
            SELECT COUNT(DISTINCT r.Id)
            FROM Rooms r
            JOIN CampPartners cp ON cp.CampId=r.CampId
            WHERE r.IsDeleted=0
              AND ISNULL(cp.IsDeleted,0)=0
              AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
        ), 0) AS TotalRooms,

        -- Occupied Rooms
        ISNULL((
            SELECT COUNT(DISTINCT r.Id)
            FROM Rooms r
            JOIN CampPartners cp ON cp.CampId=r.CampId
            WHERE r.IsDeleted=0 AND r.Occupied=1
              AND ISNULL(cp.IsDeleted,0)=0
              AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
        ), 0) AS OccupiedRooms,

        -- Vacant Rooms
        ISNULL((
            SELECT COUNT(DISTINCT r.Id)
            FROM Rooms r
            JOIN CampPartners cp ON cp.CampId=r.CampId
            WHERE r.IsDeleted=0 AND r.Occupied=0
              AND ISNULL(cp.IsDeleted,0)=0
              AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
        ), 0) AS VacantRooms

    FROM Partners p
    WHERE p.IsDeleted=0
      AND (@PartnerId IS NULL OR p.Id=@PartnerId);

    -- ── 2. Assigned Camps Detail ────────────────────────────────
    SELECT
        cp.PartnerId,
        cp.CampId,
        ISNULL(ca.Name,'')                          AS CampName,
        ISNULL(ca.Code,'')                          AS CampCode,
        cp.ShareType,
        cp.ShareValue,
        ISNULL(ca.Status,'')                        AS CampStatus,
        CONVERT(NVARCHAR(10), ca.StartDate, 23)     AS FromDate,
        CONVERT(NVARCHAR(10), ca.EndDate,   23)     AS ToDate,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0)                   AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=1) AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=0) AS VacantRooms
    FROM CampPartners cp
    JOIN Camps ca ON ca.Id=cp.CampId AND ca.IsDeleted=0
    WHERE ISNULL(cp.IsDeleted,0)=0
      AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
    ORDER BY ca.Name;

    -- ── 3. Recent Transactions (Income + Expense, last 20 each combined) ──
    SELECT TOP 30
        TxnType, TxnRefId, Date, Amount, Head, Mode,
        FundPoolName, Purpose, CampId, CampName, CreatedAt
    FROM (
        -- Income rows
        SELECT
            'Income'               AS TxnType,
            i.IncomeId             AS TxnRefId,
            i.Date,
            i.Amount,
            ISNULL(i.Head,'')      AS Head,
            ISNULL(i.Mode,'')      AS Mode,
            ISNULL(i.FundPoolName,'') AS FundPoolName,
            ISNULL(i.Purpose,'')   AS Purpose,
            ISNULL(i.CampId,0)     AS CampId,
            ISNULL(i.CampName,'')  AS CampName,
            i.CreatedAt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted,0)=0
          AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)

        UNION ALL

        -- Expense rows
        SELECT
            'Expense'              AS TxnType,
            e.ExpenseId            AS TxnRefId,
            e.Date,
            e.Amount,
            ISNULL(e.Head,'')      AS Head,
            ISNULL(e.Mode,'')      AS Mode,
            ISNULL(e.FundPoolName,'') AS FundPoolName,
            ISNULL(e.Purpose,'')   AS Purpose,
            ISNULL(e.CampId,0)     AS CampId,
            ISNULL(e.CampName,'')  AS CampName,
            e.CreatedAt
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted,0)=0
          AND e.RecipientRole='Partner'
          AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)
    ) txn
    ORDER BY txn.CreatedAt DESC;
END
GO

PRINT '✅ sp_GetPartnerDashboard created';
GO
