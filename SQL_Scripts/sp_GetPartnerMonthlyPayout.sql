-- ================================================================
-- FILE   : sp_GetPartnerMonthlyPayout.sql
-- PURPOSE: Get records from PartnerMonthlyPayout table
--          with Partner name joined
-- Filters: Month, Year (required), PartnerId (optional)
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerMonthlyPayout
    @Month      INT,
    @Year       INT,
    @PartnerId  INT  = NULL   -- NULL = all partners
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pmp.Id,
        pmp.FromDate,
        pmp.ToDate,
        pmp.[Date],
        pmp.PartnerId,
        ISNULL(p.Name, '')          AS PartnerName,
        ISNULL(p.Code, '')          AS PartnerCode,
        pmp.CampPartnerPercentage,
        pmp.TotalCampIncome,
        pmp.TotalCampExpense,
        pmp.TotalHOExpense,
        pmp.TotalAllExpense,
        pmp.TotalBenefitAmount,
        pmp.PartnerShareAmount,
        pmp.AddedBy,
        pmp.CreatedAt,
        pmp.UpdatedAt
    FROM PartnerMonthlyPayout pmp
    LEFT JOIN Partners p
           ON p.Id = pmp.PartnerId
          AND ISNULL(p.IsDeleted, 0) = 0
    WHERE
        ISNULL(pmp.IsDeleted, 0) = 0
        AND MONTH(pmp.FromDate) = @Month
        AND YEAR(pmp.FromDate)  = @Year
        AND (@PartnerId IS NULL OR pmp.PartnerId = @PartnerId)
    ORDER BY p.Name;

END
GO

PRINT 'sp_GetPartnerMonthlyPayout created successfully.';
GO
