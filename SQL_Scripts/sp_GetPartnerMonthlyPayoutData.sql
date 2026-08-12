-- ================================================================
-- FILE   : sp_GetPartnerMonthlyPayoutData.sql
-- PURPOSE: Camp-wise Income + Expense for a selected month
--          with partner-wise share breakdown
--
-- Income   : ContractRoomsTrns (TxnType='CR', month/year filter)
-- CampExp  : Expenses (Nature='Camp', Head <> 'Partner Profit', date in month)
-- HO Exp   : Expenses (Nature='HO', Head <> 'Partner Profit', date in month)
--            → Total HO expense divided EQUALLY among all Active camps
-- Partners : CampPartners JOIN Partners
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerMonthlyPayoutData
    @Month  INT,    -- 1..12
    @Year   INT     -- e.g. 2026
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Step 1: Total HO Expense for the month ───────────────────────
    DECLARE @TotalHOExpense DECIMAL(18,2);

    SELECT @TotalHOExpense = ISNULL(SUM(Amount), 0)
    FROM Expenses
    WHERE
        ISNULL(IsDeleted, 0) = 0
        AND Nature = 'HO'
        AND ISNULL(Head, '') <> 'Partner Profit'
        AND MONTH([Date]) = @Month
        AND YEAR([Date])  = @Year;

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

        -- Extra info for frontend
        @TotalHOExpense                             AS TotalHOExpenseAllCamps,
        @ActiveCampCount                            AS ActiveCampCount

    FROM Camps c

    INNER JOIN CampPartners cp
           ON cp.CampId = c.Id
          AND ISNULL(cp.IsDeleted, 0) = 0

    INNER JOIN Partners p
           ON p.Id = cp.PartnerId
          AND ISNULL(p.IsDeleted, 0) = 0

    -- Camp Income
    LEFT JOIN (
        SELECT
            CampId,
            SUM(ISNULL(Amount, 0)) AS CampIncome
        FROM ContractRoomsTrns
        WHERE
            TxnType = 'CR'
            AND MONTH(TxnDate) = @Month
            AND YEAR(TxnDate)  = @Year
        GROUP BY CampId
    ) inc ON inc.CampId = c.Id

    -- Camp Expense (Nature=Camp only)
    LEFT JOIN (
        SELECT
            CampId,
            SUM(ISNULL(Amount, 0)) AS CampExpense
        FROM Expenses
        WHERE
            ISNULL(IsDeleted, 0) = 0
            AND Nature = 'Camp'
            AND ISNULL(Head, '') <> 'Partner Profit'
            AND MONTH([Date]) = @Month
            AND YEAR([Date])  = @Year
        GROUP BY CampId
    ) exp ON exp.CampId = c.Id

    WHERE
        ISNULL(c.IsDeleted, 0) = 0
        AND c.Status = 'Active'     -- only active camps

    ORDER BY c.Name, p.Name;


    -- ================================================================
    -- RESULT SET 2: Partner-level totals (all active camps combined)
    -- ================================================================
    SELECT
        p.Id                                        AS PartnerId,
        p.Name                                      AS PartnerName,

        SUM(ISNULL(inc.CampIncome,  0))             AS TotalCampIncome,
        SUM(ISNULL(exp.CampExpense, 0))             AS TotalCampExpense,

        -- Each camp gets equal share of HO expense
        SUM(@HOExpensePerCamp)                      AS TotalHOExpense,

        -- TotalAllExpense = CampExpense + HOExpense (per camp summed)
        SUM(ISNULL(exp.CampExpense, 0))
            + SUM(@HOExpensePerCamp)                AS TotalAllExpense,

        -- TotalBenefit = Income - AllExpense
        SUM(ISNULL(inc.CampIncome, 0))
            - SUM(ISNULL(exp.CampExpense, 0))
            - SUM(@HOExpensePerCamp)                AS TotalBenefitAmount,

        -- Partner's total share across all camps
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
                         AND c.Status = 'Active'    -- only active camps

    LEFT JOIN (
        SELECT CampId, SUM(ISNULL(Amount,0)) AS CampIncome
        FROM ContractRoomsTrns
        WHERE TxnType='CR'
          AND MONTH(TxnDate)=@Month
          AND YEAR(TxnDate) =@Year
        GROUP BY CampId
    ) inc ON inc.CampId = c.Id

    LEFT JOIN (
        SELECT CampId, SUM(ISNULL(Amount,0)) AS CampExpense
        FROM Expenses
        WHERE ISNULL(IsDeleted,0)=0
          AND Nature='Camp'
          AND ISNULL(Head,'')<>'Partner Profit'
          AND MONTH([Date])=@Month
          AND YEAR([Date]) =@Year
        GROUP BY CampId
    ) exp ON exp.CampId = c.Id

    WHERE ISNULL(cp.IsDeleted,0) = 0

    GROUP BY p.Id, p.Name
    ORDER BY p.Name;

END
GO

PRINT 'sp_GetPartnerMonthlyPayoutData updated successfully.';
GO
