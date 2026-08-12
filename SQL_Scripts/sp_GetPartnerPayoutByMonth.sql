-- ================================================================
-- FILE   : sp_GetPartnerPayoutByMonth.sql
-- PURPOSE: Get partner-wise payout summary for a selected month
--          Data comes from PartnerMonthlyCampPayout table
--          Each partner gets: camp-wise breakdown + totals
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerPayoutByMonth
    @Month  INT,   -- 1..12
    @Year   INT    -- e.g. 2026
AS
BEGIN
    SET NOCOUNT ON;

    -- Compute date boundaries
    DECLARE @FromDate DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @ToDate   DATE = EOMONTH(DATEFROMPARTS(@Year, @Month, 1));

    -- ================================================================
    -- RESULT SET 1: Camp-wise breakdown per partner
    -- ================================================================
    SELECT
        pmc.Id,
        pmc.PartnerId,
        ISNULL(p.Name,  '')     AS PartnerName,
        ISNULL(p.Code,  '')     AS PartnerCode,
        pmc.CampId,
        ISNULL(c.Name,  '')     AS CampName,
        pmc.FromDate,
        pmc.ToDate,
        pmc.CampPartnerPercentage,
        pmc.CampIncome,
        pmc.CampExpense,
        pmc.HOExpense,
        pmc.TotalExpense,
        pmc.BenefitAmount,

        -- Camp Payout = BenefitAmount × CampPartnerPercentage / 100
        -- (can be positive or negative)
        ROUND(pmc.BenefitAmount * pmc.CampPartnerPercentage / 100, 2)
                                AS CampPayoutAmount

    FROM PartnerMonthlyCampPayout pmc
    LEFT JOIN Partners p ON p.Id = pmc.PartnerId AND ISNULL(p.IsDeleted,0) = 0
    LEFT JOIN Camps    c ON c.Id = pmc.CampId    AND ISNULL(c.IsDeleted,0) = 0
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND MONTH(pmc.FromDate) = @Month
        AND YEAR(pmc.FromDate)  = @Year
    ORDER BY p.Name, c.Name;


    -- ================================================================
    -- RESULT SET 2: Partner-wise totals (all camps combined)
    -- ================================================================
    SELECT
        pmc.PartnerId,
        ISNULL(p.Name, '')                              AS PartnerName,
        ISNULL(p.Code, '')                              AS PartnerCode,

        -- Totals across all camps
        SUM(pmc.CampIncome)                             AS TotalIncome,
        SUM(pmc.CampExpense)                            AS TotalCampExpense,
        SUM(pmc.HOExpense)                              AS TotalHOExpense,
        SUM(pmc.TotalExpense)                           AS TotalExpense,
        SUM(pmc.BenefitAmount)                          AS TotalBenefitAmount,

        -- Total Partner Payout = sum of all camp payouts
        -- (positive = profit share, negative = loss share)
        SUM(ROUND(pmc.BenefitAmount * pmc.CampPartnerPercentage / 100, 2))
                                                        AS TotalPayoutAmount,

        COUNT(DISTINCT pmc.CampId)                      AS TotalCamps

    FROM PartnerMonthlyCampPayout pmc
    LEFT JOIN Partners p ON p.Id = pmc.PartnerId AND ISNULL(p.IsDeleted,0) = 0
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND MONTH(pmc.FromDate) = @Month
        AND YEAR(pmc.FromDate)  = @Year
    GROUP BY pmc.PartnerId, p.Name, p.Code
    ORDER BY p.Name;

END
GO

PRINT 'sp_GetPartnerPayoutByMonth created successfully.';
GO
