-- ================================================================
-- FILE   : sp_DeletePartnerMonthlyCampPayout.sql
-- PURPOSE: Soft-delete PartnerMonthlyCampPayout rows by date range
--          Optional: filter by partnerId
-- ================================================================

CREATE OR ALTER PROCEDURE sp_DeletePartnerMonthlyCampPayout
    @FromDate   DATE,
    @ToDate     DATE,
    @PartnerId  INT  = NULL,   -- optional: delete specific partner only
    @DeletedBy  INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PartnerMonthlyCampPayout
    SET
        IsDeleted = 1,
        UpdatedAt = GETDATE()
    WHERE
        ISNULL(IsDeleted, 0) = 0
        AND CAST(FromDate AS DATE) >= @FromDate
        AND CAST(ToDate   AS DATE) <= @ToDate
        AND (@PartnerId IS NULL OR PartnerId = @PartnerId);

    SELECT @@ROWCOUNT AS DeletedCount;
END
GO

PRINT 'sp_DeletePartnerMonthlyCampPayout created successfully.';
GO
