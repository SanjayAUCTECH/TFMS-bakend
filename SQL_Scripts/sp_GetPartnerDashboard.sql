SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerDashboard
    @PartnerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Variables for wallet calculations ─────────────────────────
    -- Latest payout date for this partner
    DECLARE @LastPayoutDate DATE;
    SELECT @LastPayoutDate = MAX(CAST([Date] AS DATE))
    FROM PartnerMonthlyPayout
    WHERE ISNULL(IsDeleted,0)=0
      AND (@PartnerId IS NULL OR PartnerId=@PartnerId);

    -- Opening Balance: All Payout amounts BEFORE latest payout (exclude current)
    DECLARE @OpeningBalance DECIMAL(18,2) = 0;
    DECLARE @OpeningBalanceUpToDate DATE = NULL;

    -- Opening balance is calculated up to (but not including) the last payout date
    SET @OpeningBalanceUpToDate = DATEADD(DAY, -1, @LastPayoutDate);

    SELECT @OpeningBalance = ISNULL(SUM(
        CASE WHEN pt.Type = 'Payout' THEN pt.Amount ELSE 0 END
      - CASE WHEN pt.Type = 'Expense' THEN pt.Amount ELSE 0 END
    ), 0)
    FROM PartnerTrans pt
    WHERE ISNULL(pt.IsDeleted,0)=0
      AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId)
      AND (@LastPayoutDate IS NULL OR CAST(pt.CreatedAt AS DATE) < @LastPayoutDate);

    -- Profit Generate: Latest payout amount & date
    DECLARE @ProfitGenerate DECIMAL(18,2) = 0;
    DECLARE @ProfitGenerateDate DATE = NULL;
    SELECT TOP 1
        @ProfitGenerate = ISNULL(pm.PartnerShareAmount, 0),
        @ProfitGenerateDate = CAST(pm.[Date] AS DATE)
    FROM PartnerMonthlyPayout pm
    WHERE ISNULL(pm.IsDeleted,0)=0
      AND (@PartnerId IS NULL OR pm.PartnerId=@PartnerId)
    ORDER BY pm.[Date] DESC, pm.CreatedAt DESC;

    -- Total OP Amount: Opening Balance + Profit Generate
    DECLARE @TotalOPAmount DECIMAL(18,2) = @OpeningBalance + @ProfitGenerate;

    -- Paid: From last payout month to today, Type='Expense' total
    DECLARE @Paid DECIMAL(18,2) = 0;
    SELECT @Paid = ISNULL(SUM(pt.Amount), 0)
    FROM PartnerTrans pt
    WHERE ISNULL(pt.IsDeleted,0)=0
      AND pt.Type = 'Expense'
      AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId)
      AND (@LastPayoutDate IS NULL OR CAST(pt.CreatedAt AS DATE) >= @LastPayoutDate);

    -- Closing Balance: Total OP Amount - Paid
    DECLARE @ClosingBalance DECIMAL(18,2) = @TotalOPAmount - @Paid;

    -- Total Profit: All time sum of Payout amounts
    DECLARE @TotalProfit DECIMAL(18,2) = 0;
    SELECT @TotalProfit = ISNULL(SUM(pt.Amount), 0)
    FROM PartnerTrans pt
    WHERE ISNULL(pt.IsDeleted,0)=0
      AND pt.Type = 'Payout'
      AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId);

    -- Total Received: All time Type='Expense' total
    DECLARE @TotalReceived DECIMAL(18,2) = 0;
    SELECT @TotalReceived = ISNULL(SUM(pt.Amount), 0)
    FROM PartnerTrans pt
    WHERE ISNULL(pt.IsDeleted,0)=0
      AND pt.Type = 'Expense'
      AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId);

    -- Total Balance: Total Profit - Total Received
    DECLARE @TotalBalance DECIMAL(18,2) = @TotalProfit - @TotalReceived;

    -- Last Paid Date: last Type='Expense' in PartnerTrans
    DECLARE @LastPaidDate DATE = NULL;
    SELECT @LastPaidDate = MAX(CAST(pt.CreatedAt AS DATE))
    FROM PartnerTrans pt
    WHERE ISNULL(pt.IsDeleted,0)=0
      AND pt.Type = 'Expense'
      AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId);

    -- ── Result Set 1: Summary ─────────────────────────────────────
    SELECT
        ISNULL(p.Id,0) AS PartnerId, ISNULL(p.Name,'') AS PartnerName,
        ISNULL(p.Code,'') AS PartnerCode, ISNULL(p.Contact,'') AS PartnerContact,
        ISNULL(p.Email,'') AS PartnerEmail, ISNULL(p.Status,'') AS PartnerStatus,

        -- Existing fields
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)),0) AS TotalIncome,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner' AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)),0) AS TotalExpense,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)),0)
        - ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner' AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)),0) AS NetBalance,
        ISNULL((SELECT COUNT(DISTINCT cp.CampId) FROM CampPartners cp WHERE ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS AssignedCamps,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS TotalRooms,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND r.Occupied=1 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS OccupiedRooms,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND r.Occupied=0 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS VacantRooms,

        -- NEW wallet keys
        @OpeningBalance           AS OpeningBalance,
        @OpeningBalanceUpToDate   AS OpeningBalanceUpToDate,
        @ProfitGenerate           AS ProfitGenerate,
        @ProfitGenerateDate       AS ProfitGenerateDate,
        @TotalOPAmount            AS TotalOPAmount,
        @Paid                     AS Paid,
        @ClosingBalance           AS ClosingBalance,
        @TotalProfit              AS TotalProfit,
        @TotalReceived            AS TotalReceived,
        @TotalBalance             AS TotalBalance,
        @LastPaidDate             AS LastPaidDate

    FROM Partners p WHERE p.IsDeleted=0 AND (@PartnerId IS NULL OR p.Id=@PartnerId);

    -- ── Result Set 2: Assigned Camps ─────────────────────────────
    SELECT cp.PartnerId, cp.CampId,
        ISNULL(ca.Name,'') AS CampName, ISNULL(ca.Code,'') AS CampCode,
        cp.ShareType, cp.ShareValue,
        ISNULL(ca.Status,'') AS CampStatus,
        CONVERT(NVARCHAR(10), ca.StartDate, 23) AS FromDate,
        CONVERT(NVARCHAR(10), ca.EndDate,   23) AS ToDate,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0) AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=1) AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=0) AS VacantRooms
    FROM CampPartners cp
    JOIN Camps ca ON ca.Id=cp.CampId AND ca.IsDeleted=0
    WHERE ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
    ORDER BY ca.Name;

    -- ── Result Set 3: Recent Transactions (Incomes + Expenses + PartnerTrans) ──
    SELECT TOP 50 TxnType, TxnRefId, Date, Amount, Head,
        Mode, FundPoolName, Purpose, CampId, CampName, CreatedAt
    FROM (
        SELECT 'Income' AS TxnType, i.IncomeId AS TxnRefId, i.Date, i.Amount,
               ISNULL(i.Head,'') AS Head, ISNULL(i.Mode,'') AS Mode,
               ISNULL(i.FundPoolName,'') AS FundPoolName, ISNULL(i.Purpose,'') AS Purpose,
               ISNULL(i.CampId,0) AS CampId, ISNULL(i.CampName,'') AS CampName, i.CreatedAt
        FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)

        UNION ALL

        SELECT 'Expense', e.ExpenseId, e.Date, e.Amount,
               ISNULL(e.Head,''), ISNULL(e.Mode,''),
               ISNULL(e.FundPoolName,''), ISNULL(e.Purpose,''),
               ISNULL(e.CampId,0), ISNULL(e.CampName,''), e.CreatedAt
        FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner'
          AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)

        UNION ALL

        SELECT 'Payout' AS TxnType,
               CAST(pt.Id AS NVARCHAR(50)) AS TxnRefId,
               pt.CreatedAt AS Date,
               pt.Amount,
               ISNULL(pt.AccountHead,'') AS Head,
               ISNULL(pt.PaymentMode,'') AS Mode,
               '' AS FundPoolName,
               ISNULL(pt.Remark,'') AS Purpose,
               0 AS CampId,
               '' AS CampName,
               pt.CreatedAt
        FROM PartnerTrans pt
        WHERE ISNULL(pt.IsDeleted,0)=0
          AND (@PartnerId IS NULL OR pt.PartnerId=@PartnerId)
    ) txn ORDER BY txn.CreatedAt DESC;
END
GO

PRINT 'sp_GetPartnerDashboard updated with wallet calculations.';
GO
