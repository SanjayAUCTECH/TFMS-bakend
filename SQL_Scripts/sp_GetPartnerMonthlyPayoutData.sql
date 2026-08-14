-- ================================================================
-- FILE   : sp_GetPartnerMonthlyPayoutData.sql
-- PURPOSE: Camp-wise Income + Expense for a date range (FromDate..ToDate)
--          with partner-wise share breakdown
--
-- Income   : ContractRoomsTrns (TxnType='CR', TxnDate BETWEEN @FromDate AND @ToDate)
-- CampExp  : Expenses (Nature='Camp', Head <> 'Partner Profit', Date BETWEEN range)
-- HO Exp   : Expenses (Nature='HO',  Head <> 'Partner Profit', Date BETWEEN range)
--            → Total HO expense divided EQUALLY among all Active camps
-- Partners : CampPartners JOIN Partners
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerMonthlyPayoutData
    @FromDate  DATE,   -- e.g. 2026-01-01
    @ToDate    DATE    -- e.g. 2026-01-31
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Step 1: Total HO Expense for the date range ──────────────────
    DECLARE @TotalHOExpense DECIMAL(18,2);

    SELECT @TotalHOExpense = ISNULL(SUM(Amount), 0)
    FROM Expenses
    WHERE
        ISNULL(IsDeleted, 0) = 0
        AND Nature = 'HO'
        AND ISNULL(Head, '') <> 'Partner Profit'
        AND CAST([Date] AS DATE) >= @FromDate
        AND CAST([Date] AS DATE) <= @ToDate;

    -- ── Step 2: Count of Active camps ────────────────────────────────
    DECLARE @ActiveCampCount INT;

    SELECT @ActiveCampCount = COUNT(*)
    FROM Camps
    WHERE Status = 'Active' AND ISNULL(IsDeleted, 0) = 0;

    -- Avoid divide by zero
    IF @ActiveCampCount = 0 SET @ActiveCampCount = 1;

    -- ── Step 3: HO expense per camp (equally distributed) ────────────
    DECLARE @HOExpensePerCamp DECIMAL(18,2);
    SET @HOExpensePerCamp = ROUND(@TotalHOExpense / @ActiveCampCount, 2);

    -- ================================================================
    -- RESULT SET 1: Camp-wise breakdown per partner
    -- ================================================================
    SELECT
        c.Id                                        AS CampId,
        c.Name                                      AS CampName,

        -- Income from ContractRoomsTrns
        ISNULL(inc.CampIncome,  0)                  AS CampIncome,

        -- Camp Expense (Nature=Camp, Head <> 'Partner Profit')
        ISNULL(exp.CampExpense, 0)                  AS CampExpense,

        -- HO Expense equally distributed per active camp
        @HOExpensePerCamp                           AS HOExpense,

        -- TotalExpense = CampExpense + HOExpense per camp
        ISNULL(exp.CampExpense, 0)
            + @HOExpensePerCamp                     AS TotalExpense,

        -- BenefitAmount = CampIncome - TotalExpense
        ISNULL(inc.CampIncome, 0)
            - ISNULL(exp.CampExpense, 0)
            - @HOExpensePerCamp                     AS BenefitAmount,

        -- Partner info
        cp.Id                                       AS CampPartnerId,
        cp.PartnerId,
        p.Name                                      AS PartnerName,
        cp.ShareType,
        cp.ShareValue                               AS CampPartnerPercentage,

        -- Partner share on this camp's benefit
        CASE
            WHEN cp.ShareType = 'percentage' THEN
                ROUND(
                    (ISNULL(inc.CampIncome, 0)
                     - ISNULL(exp.CampExpense, 0)
                     - @HOExpensePerCamp)
                    * cp.ShareValue / 100
                , 2)
            ELSE cp.ShareValue
        END                                         AS PartnerShareAmount,

        -- Extra info for frontend transparency
        @TotalHOExpense                             AS TotalHOExpenseAllCamps,
        @ActiveCampCount                            AS ActiveCampCount

    FROM Camps c

    INNER JOIN CampPartners cp
           ON cp.CampId = c.Id
          AND ISNULL(cp.IsDeleted, 0) = 0

    INNER JOIN Partners p
           ON p.Id = cp.PartnerId
          AND ISNULL(p.IsDeleted, 0) = 0

    -- Camp Income: TxnDate BETWEEN @FromDate AND @ToDate
    LEFT JOIN (
        SELECT
            CampId,
            SUM(ISNULL(Amount, 0)) AS CampIncome
        FROM ContractRoomsTrns
        WHERE
            TxnType = 'CR'
            AND CAST(TxnDate AS DATE) >= @FromDate
            AND CAST(TxnDate AS DATE) <= @ToDate
        GROUP BY CampId
    ) inc ON inc.CampId = c.Id

    -- Camp Expense: Date BETWEEN @FromDate AND @ToDate
    LEFT JOIN (
        SELECT
            CampId,
            SUM(ISNULL(Amount, 0)) AS CampExpense
        FROM Expenses
        WHERE
            ISNULL(IsDeleted, 0) = 0
            AND Nature = 'Camp'
            AND ISNULL(Head, '') <> 'Partner Profit'
            AND CAST([Date] AS DATE) >= @FromDate
            AND CAST([Date] AS DATE) <= @ToDate
        GROUP BY CampId
    ) exp ON exp.CampId = c.Id

    WHERE
        ISNULL(c.IsDeleted, 0) = 0
        AND c.Status = 'Active'

    ORDER BY c.Name, p.Name;


    -- ================================================================
    -- RESULT SET 2: Partner-level totals (all active camps combined)
    -- ================================================================
    SELECT
        p.Id                                        AS PartnerId,
        p.Name                                      AS PartnerName,

        SUM(ISNULL(inc.CampIncome,  0))             AS TotalCampIncome,
        SUM(ISNULL(exp.CampExpense, 0))             AS TotalCampExpense,

        SUM(@HOExpensePerCamp)                      AS TotalHOExpense,

        SUM(ISNULL(exp.CampExpense, 0))
            + SUM(@HOExpensePerCamp)                AS TotalAllExpense,

        SUM(ISNULL(inc.CampIncome, 0))
            - SUM(ISNULL(exp.CampExpense, 0))
            - SUM(@HOExpensePerCamp)                AS TotalBenefitAmount,

        SUM(
            CASE
                WHEN cp.ShareType = 'percentage' THEN
                    ROUND(
                        (ISNULL(inc.CampIncome, 0)
                         - ISNULL(exp.CampExpense, 0)
                         - @HOExpensePerCamp)
                        * cp.ShareValue / 100
                    , 2)
                ELSE cp.ShareValue
            END
        )                                           AS PartnerShareAmount

    FROM CampPartners cp
    INNER JOIN Partners p ON p.Id = cp.PartnerId AND ISNULL(p.IsDeleted,0) = 0
    INNER JOIN Camps    c ON c.Id = cp.CampId
                         AND ISNULL(c.IsDeleted,0) = 0
                         AND c.Status = 'Active'

    LEFT JOIN (
        SELECT CampId, SUM(ISNULL(Amount,0)) AS CampIncome
        FROM ContractRoomsTrns
        WHERE TxnType = 'CR'
          AND CAST(TxnDate AS DATE) >= @FromDate
          AND CAST(TxnDate AS DATE) <= @ToDate
        GROUP BY CampId
    ) inc ON inc.CampId = c.Id

    LEFT JOIN (
        SELECT CampId, SUM(ISNULL(Amount,0)) AS CampExpense
        FROM Expenses
        WHERE ISNULL(IsDeleted,0) = 0
          AND Nature = 'Camp'
          AND ISNULL(Head,'') <> 'Partner Profit'
          AND CAST([Date] AS DATE) >= @FromDate
          AND CAST([Date] AS DATE) <= @ToDate
        GROUP BY CampId
    ) exp ON exp.CampId = c.Id

    WHERE ISNULL(cp.IsDeleted,0) = 0

    GROUP BY p.Id, p.Name
    ORDER BY p.Name;

END
GO

PRINT 'sp_GetPartnerMonthlyPayoutData updated successfully (FromDate/ToDate).';
GO
