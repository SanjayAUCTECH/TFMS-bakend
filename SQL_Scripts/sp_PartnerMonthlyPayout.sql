-- ================================================================
-- FILE   : sp_PartnerMonthlyPayout.sql
-- PURPOSE: Save & Delete for PartnerMonthlyPayout table
-- ================================================================

-- ── TVP Type (run once) ───────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.types
    WHERE name = 'PartnerMonthlyPayoutType' AND is_table_type = 1
)
BEGIN
    CREATE TYPE dbo.PartnerMonthlyPayoutType AS TABLE (
        PartnerId             INT,
        CampPartnerPercentage DECIMAL(10,4),
        TotalCampIncome       DECIMAL(18,2),
        TotalCampExpense      DECIMAL(18,2),
        TotalHOExpense        DECIMAL(18,2),
        TotalAllExpense       DECIMAL(18,2),
        TotalBenefitAmount    DECIMAL(18,2),
        PartnerShareAmount    DECIMAL(18,2)
    );
    PRINT 'Type PartnerMonthlyPayoutType created.';
END
GO

-- ================================================================
-- 1. sp_SavePartnerMonthlyPayout
--    Saves partner-wise monthly totals.
--    Re-save safe: soft-deletes old records for same FromDate-ToDate+Partner
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

        -- Soft-delete existing records for same period + same partners
        UPDATE pmp
        SET    IsDeleted  = 1,
               UpdatedBy  = @AddedBy,
               UpdatedAt  = GETDATE()
        FROM   PartnerMonthlyPayout pmp
        INNER JOIN @Rows r ON r.PartnerId = pmp.PartnerId
        WHERE  pmp.FromDate  = @FromDate
          AND  pmp.ToDate    = @ToDate
          AND  pmp.IsDeleted = 0;

        -- Insert new rows
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
            r.TotalCampIncome, r.TotalCampExpense,
            r.TotalHOExpense,  r.TotalAllExpense,
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

PRINT 'sp_SavePartnerMonthlyPayout created.';
GO

-- ================================================================
-- 2. sp_DeletePartnerMonthlyPayout
--    Soft-delete by Month + Year (deletes all partners for that month)
--    OR by specific PartnerId + Month + Year
-- ================================================================
CREATE OR ALTER PROCEDURE sp_DeletePartnerMonthlyPayout
    @Month     INT,
    @Year      INT,
    @PartnerId INT       = NULL,  -- NULL = delete all partners for that month
    @DeletedBy INT       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PartnerMonthlyPayout
    SET    IsDeleted  = 1,
           UpdatedBy  = @DeletedBy,
           UpdatedAt  = GETDATE()
    WHERE
        ISNULL(IsDeleted, 0) = 0
        AND MONTH(FromDate) = @Month
        AND YEAR(FromDate)  = @Year
        AND (@PartnerId IS NULL OR PartnerId = @PartnerId);

    SELECT @@ROWCOUNT AS DeletedCount;
END
GO

PRINT 'sp_DeletePartnerMonthlyPayout created.';
GO

PRINT 'All PartnerMonthlyPayout procedures created successfully.';
GO
