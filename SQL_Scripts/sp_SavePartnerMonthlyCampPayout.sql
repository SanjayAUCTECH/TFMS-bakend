-- ================================================================
-- FILE   : sp_SavePartnerMonthlyCampPayout.sql
-- PURPOSE: Insert records into PartnerMonthlyCampPayout table
--          Uses TVP to insert multiple camp-partner rows at once
-- ================================================================

-- ── TVP Type (run once) ───────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.types
    WHERE name = 'PartnerMonthlyCampPayoutType' AND is_table_type = 1
)
BEGIN
    CREATE TYPE dbo.PartnerMonthlyCampPayoutType AS TABLE (
        PartnerId             INT,
        CampId                INT,
        CampPartnerPercentage DECIMAL(10,4),
        CampIncome            DECIMAL(18,2),
        CampExpense           DECIMAL(18,2),
        HOExpense             DECIMAL(18,2),
        TotalExpense          DECIMAL(18,2),
        BenefitAmount         DECIMAL(18,2)
    );
    PRINT 'Type PartnerMonthlyCampPayoutType created.';
END
GO

-- ================================================================
-- sp_SavePartnerMonthlyCampPayout
-- ================================================================
CREATE OR ALTER PROCEDURE sp_SavePartnerMonthlyCampPayout
    @FromDate  DATETIME,
    @ToDate    DATETIME,
    @Date      DATETIME,
    @AddedBy   INT = NULL,
    @Rows      dbo.PartnerMonthlyCampPayoutType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- Soft-delete existing records for same FromDate-ToDate + same Partner+Camp
        -- so re-save is safe (idempotent)
        UPDATE pmc
        SET    IsDeleted   = 1,
               IsDeletedBy = @AddedBy,
               UpdatedAt   = GETDATE()
        FROM   PartnerMonthlyCampPayout pmc
        INNER JOIN @Rows r
               ON r.PartnerId = pmc.PartnerId
              AND r.CampId    = pmc.CampId
        WHERE  pmc.FromDate  = @FromDate
          AND  pmc.ToDate    = @ToDate
          AND  pmc.IsDeleted = 0;

        -- Insert new rows
        INSERT INTO PartnerMonthlyCampPayout (
            FromDate, ToDate, [Date],
            PartnerId, CampId,
            CampPartnerPercentage,
            CampIncome, CampExpense, HOExpense,
            TotalExpense, BenefitAmount,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        SELECT
            @FromDate, @ToDate, @Date,
            r.PartnerId, r.CampId,
            r.CampPartnerPercentage,
            r.CampIncome, r.CampExpense, r.HOExpense,
            r.TotalExpense, r.BenefitAmount,
            @AddedBy, 0, GETDATE(), GETDATE()
        FROM @Rows r;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_SavePartnerMonthlyCampPayout created successfully.';
GO
