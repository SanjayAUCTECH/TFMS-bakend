-- ================================================================
-- FILE   : PartnerReleasePayout_Table.sql
-- PURPOSE: Create PartnerReleasePayout table
-- Run this in SSMS against your database
-- ================================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerReleasePayout'
)
BEGIN
    CREATE TABLE PartnerReleasePayout (
        Id                    INT IDENTITY(1,1)  PRIMARY KEY,

        [Date]                DATETIME           NOT NULL DEFAULT GETDATE(),  -- Entry date
        ReleaseDate           DATETIME           NOT NULL,                    -- Actual release date

        PartnerId             INT                NOT NULL,             -- FK → Partners.Id

        CampPartnerPercentage DECIMAL(10,4)      NOT NULL DEFAULT 0,   -- e.g. 30.0000 %

        -- Summary (copied from PartnerMonthlyPayout)
        TotalCampIncome       DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalCampExpense      DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalHOExpense        DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalAllExpense       DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalCampExpense + TotalHOExpense
        TotalBenefitAmount    DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalCampIncome - TotalAllExpense
        PartnerShareAmount    DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalBenefitAmount x CampPartnerPercentage / 100

        -- Release
        ReleaseAmount         DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- Amount released this time
        BalanceAmount         DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- PartnerShareAmount - ReleaseAmount

        -- Audit
        AddedBy               INT                NULL,
        UpdatedBy             INT                NULL,
        IsDeleted             BIT                NOT NULL DEFAULT 0,
        CreatedAt             DATETIME           NOT NULL DEFAULT GETDATE(),
        UpdatedAt             DATETIME           NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerReleasePayout table created successfully.';
END
ELSE
    PRINT 'PartnerReleasePayout already exists.';
GO
