-- ================================================================
-- FILE   : PartnerMonthlyPayout_Table.sql
-- PURPOSE: Create PartnerMonthlyPayout table
-- Run this in SSMS against your database
-- ================================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerMonthlyPayout'
)
BEGIN
    CREATE TABLE PartnerMonthlyPayout (
        Id                    INT IDENTITY(1,1)  PRIMARY KEY,

        FromDate              DATETIME           NOT NULL,             -- Period start
        ToDate                DATETIME           NOT NULL,             -- Period end
        [Date]                DATETIME           NOT NULL DEFAULT GETDATE(),  -- Entry date

        PartnerId             INT                NOT NULL,             -- FK → Partners.Id

        CampPartnerPercentage DECIMAL(10,4)      NOT NULL DEFAULT 0,   -- e.g. 30.0000 %

        -- Financials (all camps combined)
        TotalCampIncome       DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalCampExpense      DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalHOExpense        DECIMAL(18,2)      NOT NULL DEFAULT 0,
        TotalAllExpense       DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalCampExpense + TotalHOExpense
        TotalBenefitAmount    DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalCampIncome - TotalAllExpense
        PartnerShareAmount    DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- TotalBenefitAmount x CampPartnerPercentage / 100

        -- Audit
        AddedBy               INT                NULL,
        UpdatedBy             INT                NULL,
        IsDeleted             BIT                NOT NULL DEFAULT 0,
        CreatedAt             DATETIME           NOT NULL DEFAULT GETDATE(),
        UpdatedAt             DATETIME           NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerMonthlyPayout table created successfully.';
END
ELSE
    PRINT 'PartnerMonthlyPayout already exists.';
GO
