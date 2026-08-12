-- ================================================================
-- FILE   : PartnerMonthlyCampPayout_Table.sql
-- PURPOSE: Create PartnerMonthlyCampPayout table
-- Run this in SSMS against your database
-- ================================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerMonthlyCampPayout'
)
BEGIN
    CREATE TABLE PartnerMonthlyCampPayout (
        Id                    INT IDENTITY(1,1)  PRIMARY KEY,

        FromDate              DATETIME           NOT NULL,             -- Period start
        ToDate                DATETIME           NOT NULL,             -- Period end
        [Date]                DATETIME           NOT NULL DEFAULT GETDATE(),  -- Entry date

        PartnerId             INT                NOT NULL,             -- FK → Partners.Id
        CampId                INT                NOT NULL,             -- FK → Camps.Id

        CampPartnerPercentage DECIMAL(10,4)      NOT NULL DEFAULT 0,   -- e.g. 30.0000 %

        CampIncome            DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- Tenant + Manual Income
        CampExpense           DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- Camp level expenses
        HOExpense             DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- Head Office expenses
        TotalExpense          DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- CampExpense + HOExpense
        BenefitAmount         DECIMAL(18,2)      NOT NULL DEFAULT 0,   -- CampIncome - TotalExpense

        AddedBy               INT                NULL,
        UpdatedBy             INT                NULL,
        IsDeletedBy           INT                NULL,
        IsDeleted             BIT                NOT NULL DEFAULT 0,
        CreatedAt             DATETIME           NOT NULL DEFAULT GETDATE(),
        UpdatedAt             DATETIME           NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerMonthlyCampPayout table created successfully.';
END
ELSE
    PRINT 'PartnerMonthlyCampPayout already exists.';
GO
