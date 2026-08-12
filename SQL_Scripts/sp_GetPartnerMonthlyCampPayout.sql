-- ================================================================
-- FILE   : sp_GetPartnerMonthlyCampPayout.sql
-- PURPOSE: Get records from PartnerMonthlyCampPayout table
--          with Partner name and Camp name joined
-- Filters: PartnerId (optional), FromDate (optional), ToDate (optional)
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetPartnerMonthlyCampPayout
    @PartnerId  INT      = NULL,
    @FromDate   DATETIME = NULL,
    @ToDate     DATETIME = NULL,
    @PageNumber INT      = 1,
    @PageSize   INT      = 50,
    @TotalRecords INT    OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Total count
    SELECT @TotalRecords = COUNT(*)
    FROM PartnerMonthlyCampPayout pmc
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND (@PartnerId IS NULL OR pmc.PartnerId = @PartnerId)
        AND (@FromDate  IS NULL OR pmc.FromDate  >= @FromDate)
        AND (@ToDate    IS NULL OR pmc.ToDate    <= @ToDate);

    -- Paged data
    SELECT
        pmc.Id,
        pmc.FromDate,
        pmc.ToDate,
        pmc.[Date],
        pmc.PartnerId,
        ISNULL(p.Name, '')      AS PartnerName,
        pmc.CampId,
        ISNULL(c.Name, '')      AS CampName,
        pmc.CampPartnerPercentage,
        pmc.CampIncome,
        pmc.CampExpense,
        pmc.HOExpense,
        pmc.TotalExpense,
        pmc.BenefitAmount,
        pmc.AddedBy,
        pmc.CreatedAt,
        pmc.UpdatedAt
    FROM PartnerMonthlyCampPayout pmc
    LEFT JOIN Partners p ON p.Id = pmc.PartnerId AND ISNULL(p.IsDeleted, 0) = 0
    LEFT JOIN Camps    c ON c.Id = pmc.CampId    AND ISNULL(c.IsDeleted, 0) = 0
    WHERE
        ISNULL(pmc.IsDeleted, 0) = 0
        AND (@PartnerId IS NULL OR pmc.PartnerId = @PartnerId)
        AND (@FromDate  IS NULL OR pmc.FromDate  >= @FromDate)
        AND (@ToDate    IS NULL OR pmc.ToDate    <= @ToDate)
    ORDER BY pmc.FromDate DESC, p.Name, c.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

END
GO

PRINT 'sp_GetPartnerMonthlyCampPayout created successfully.';
GO
