-- ================================================================
-- FILE   : sp_SavePartnerMonthlyPayout.sql
-- PURPOSE: Save partner-wise monthly payout totals
--          into PartnerMonthlyPayout table using TVP
-- ================================================================

CREATE OR ALTER PROCEDURE sp_SavePartnerMonthlyPayout
    @FromDate  DATETIME,
    @ToDate    DATETIME,
    @Date      DATETIME,
    @AddedBy   INT = NULL,
    @Rows      dbo.PartnerMonthlyPayoutType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- Soft-delete existing active records for same period + same Partner
        UPDATE pm
        SET    IsDeleted = 1,
               UpdatedAt = GETDATE()
        FROM   PartnerMonthlyPayout pm
        INNER JOIN @Rows r ON r.PartnerId = pm.PartnerId
        WHERE  CAST(pm.FromDate AS DATE) = CAST(@FromDate AS DATE)
          AND  CAST(pm.ToDate   AS DATE) = CAST(@ToDate   AS DATE)
          AND  pm.IsDeleted = 0;

        -- Insert fresh rows
        INSERT INTO PartnerMonthlyPayout (
            FromDate, ToDate, [Date],
            PartnerId,
            CampPartnerPercentage,
            TotalCampIncome, TotalCampExpense,
            TotalHOExpense,  TotalAllExpense,
            TotalBenefitAmount, PartnerShareAmount,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        SELECT
            @FromDate, @ToDate, @Date,
            r.PartnerId,
            r.CampPartnerPercentage,
            r.TotalCampIncome,  r.TotalCampExpense,
            r.TotalHOExpense,   r.TotalAllExpense,
            r.TotalBenefitAmount, r.PartnerShareAmount,
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

PRINT 'sp_SavePartnerMonthlyPayout created successfully.';
GO
