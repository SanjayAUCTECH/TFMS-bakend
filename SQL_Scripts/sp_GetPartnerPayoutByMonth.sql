-- ================================================================
-- FILE   : sp_GetPartnerPayoutByMonth.sql
-- PURPOSE: Get partner-wise payout summary for a date range
--          Data comes from PartnerMonthlyCampPayout table
--          Filter: FromDate <= @ToDate AND ToDate >= @FromDate
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerPayoutByMonth
    @FromDate  DATE,   -- e.g. 2026-07-01
    @ToDate    DATE    -- e.g. 2026-07-31
AS
BEGIN
    SET NOCOUNT ON;

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
        ROUND(pmc.BenefitAmount * pmc.CampPartnerPercentage / 100, 2)
                                AS CampPayoutAmount

    FROM PartnerMonthlyCampPayout pmc
    LEFT JOIN Partners p ON p.Id = pmc.PartnerId AND ISNULL(p.IsDeleted,0) = 0
    LEFT JOIN Camps    c ON c.Id = pmc.CampId    AND ISNULL(c.IsDeleted,0) = 0
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND CAST(pmc.FromDate AS DATE) >= @FromDate
        AND CAST(pmc.ToDate   AS DATE) <= @ToDate
    ORDER BY p.Name, c.Name;


    -- ================================================================
    -- RESULT SET 2: Partner-wise totals (all camps combined)
    -- ================================================================
    SELECT
        pmc.PartnerId,
        ISNULL(p.Name, '')                              AS PartnerName,
        ISNULL(p.Code, '')                              AS PartnerCode,
        SUM(pmc.CampIncome)                             AS TotalIncome,
        SUM(pmc.CampExpense)                            AS TotalCampExpense,
        SUM(pmc.HOExpense)                              AS TotalHOExpense,
        SUM(pmc.TotalExpense)                           AS TotalExpense,
        SUM(pmc.BenefitAmount)                          AS TotalBenefitAmount,
        SUM(ROUND(pmc.BenefitAmount * pmc.CampPartnerPercentage / 100, 2))
                                                        AS TotalPayoutAmount,
        COUNT(DISTINCT pmc.CampId)                      AS TotalCamps

    FROM PartnerMonthlyCampPayout pmc
    LEFT JOIN Partners p ON p.Id = pmc.PartnerId AND ISNULL(p.IsDeleted,0) = 0
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND CAST(pmc.FromDate AS DATE) >= @FromDate
        AND CAST(pmc.ToDate   AS DATE) <= @ToDate
    GROUP BY pmc.PartnerId, p.Name, p.Code
    ORDER BY p.Name;

END
GO

PRINT 'sp_GetPartnerPayoutByMonth updated (FromDate/ToDate filter).';
GO
