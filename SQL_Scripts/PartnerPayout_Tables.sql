-- ================================================================
-- FILE   : PartnerPayout_Tables.sql
-- PURPOSE: Partner Payout related tables
--          1. PartnerMonthlyCampPayout  → Camp-wise breakdown
--          2. PartnerMonthlyPayout      → Partner total monthly summary
--          3. PartnerReleasePayout      → Actual cash release to partner
-- ================================================================

-- ================================================================
-- TABLE 1: PartnerMonthlyCampPayout
-- Purpose: Ek partner ka ek camp ka date-range wise calculation
-- ================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerMonthlyCampPayout'
)
BEGIN
    CREATE TABLE PartnerMonthlyCampPayout (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,

        -- Date range
        FromDate                DATETIME        NOT NULL,
        ToDate                  DATETIME        NOT NULL,
        [Date]                  DATETIME        NOT NULL DEFAULT GETDATE(),  -- entry date

        -- Partner & Camp
        PartnerId               INT             NOT NULL,   -- FK → Partners.Id
        CampId                  INT             NOT NULL,   -- FK → Camps.Id

        -- Partner's share % in this camp
        CampPartnerPercentage   DECIMAL(10,4)   NOT NULL DEFAULT 0,  -- e.g. 30.00

        -- Financials
        CampIncome              DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- Tenant + Manual Income
        CampExpense             DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- Camp Expenses (Owner rent etc.)
        HOExpense               DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- HO (Head Office) Expenses
        TotalExpense            DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- CampExpense + HOExpense
        BenefitAmount           DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- CampIncome - TotalExpense

        -- Audit
        AddedBy                 INT             NULL,
        UpdatedBy               INT             NULL,
        IsDeletedBy             INT             NULL,
        IsDeleted               BIT             NOT NULL DEFAULT 0,
        CreatedAt               DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt               DATETIME        NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerMonthlyCampPayout table created.';
END
ELSE
    PRINT 'PartnerMonthlyCampPayout already exists – skipped.';
GO

-- ================================================================
-- TABLE 2: PartnerMonthlyPayout
-- Purpose: Ek partner ka total monthly payout summary (all camps combined)
-- ================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerMonthlyPayout'
)
BEGIN
    CREATE TABLE PartnerMonthlyPayout (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,

        -- Date range
        FromDate                DATETIME        NOT NULL,
        ToDate                  DATETIME        NOT NULL,
        [Date]                  DATETIME        NOT NULL DEFAULT GETDATE(),  -- entry date

        -- Partner
        PartnerId               INT             NOT NULL,   -- FK → Partners.Id

        -- Partner's overall share % (weighted avg or as entered)
        CampPartnerPercentage   DECIMAL(10,4)   NOT NULL DEFAULT 0,

        -- Financials (totals across all camps)
        TotalCampIncome         DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalCampExpense        DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalHOExpense          DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalAllExpense         DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- TotalCampExpense + TotalHOExpense
        TotalBenefitAmount      DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- TotalCampIncome - TotalAllExpense
        PartnerShareAmount      DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- TotalBenefitAmount × CampPartnerPercentage / 100

        -- Audit
        AddedBy                 INT             NULL,
        UpdatedBy               INT             NULL,
        IsDeleted               BIT             NOT NULL DEFAULT 0,
        CreatedAt               DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt               DATETIME        NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerMonthlyPayout table created.';
END
ELSE
    PRINT 'PartnerMonthlyPayout already exists – skipped.';
GO

-- ================================================================
-- TABLE 3: PartnerReleasePayout
-- Purpose: Actual cash release to partner
--          Multiple releases possible against one PartnerMonthlyPayout
-- ================================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerReleasePayout'
)
BEGIN
    CREATE TABLE PartnerReleasePayout (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,

        -- Dates
        [Date]                  DATETIME        NOT NULL DEFAULT GETDATE(),  -- entry date
        ReleaseDate             DATETIME        NOT NULL,                    -- actual release date

        -- Partner
        PartnerId               INT             NOT NULL,   -- FK → Partners.Id

        -- Link to monthly payout (optional — for tracking)
        PartnerMonthlyPayoutId  INT             NULL,       -- FK → PartnerMonthlyPayout.Id

        -- Partner's share % (copied from monthly payout)
        CampPartnerPercentage   DECIMAL(10,4)   NOT NULL DEFAULT 0,

        -- Financials (summary copied from PartnerMonthlyPayout)
        TotalCampIncome         DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalCampExpense        DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalHOExpense          DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalAllExpense         DECIMAL(18,2)   NOT NULL DEFAULT 0,
        TotalBenefitAmount      DECIMAL(18,2)   NOT NULL DEFAULT 0,
        PartnerShareAmount      DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- total share due

        -- Release specific
        PaymentMode             NVARCHAR(100)   NOT NULL DEFAULT 'Cash',
        ReferenceNo             NVARCHAR(200)   NULL,
        FundPoolId              INT             NULL,
        FundPoolName            NVARCHAR(200)   NULL,
        Remark                  NVARCHAR(500)   NULL,
        ReleaseAmount           DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- amount released this time
        BalanceAmount           DECIMAL(18,2)   NOT NULL DEFAULT 0,   -- remaining after this release

        -- Linked to Expenses + AccountMasters (auto on release)
        ExpenseId               INT             NULL,
        AccountId               NVARCHAR(100)   NULL,

        -- Audit
        AddedBy                 INT             NULL,
        UpdatedBy               INT             NULL,
        IsDeletedBy             INT             NULL,
        IsDeleted               BIT             NOT NULL DEFAULT 0,
        CreatedAt               DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt               DATETIME        NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerReleasePayout table created.';
END
ELSE
    PRINT 'PartnerReleasePayout already exists – skipped.';
GO

-- ================================================================
-- DONE
-- ================================================================
PRINT 'All PartnerPayout tables created successfully.';
GO
