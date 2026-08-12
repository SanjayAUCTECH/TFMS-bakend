-- ============================================================
-- FILE   : PartnerTrans_Setup.sql
-- PURPOSE: Create PartnerTrans table only
-- ============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables WHERE name = 'PartnerTrans'
)
BEGIN
    CREATE TABLE PartnerTrans (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        PartnerId     INT            NOT NULL,
        PaymentMode   NVARCHAR(100)  NULL,
        [Type]        NVARCHAR(50)   NOT NULL,          -- e.g. 'Income' | 'Expense'
        AccountHead   NVARCHAR(200)  NULL,
        Amount        DECIMAL(18,2)  NOT NULL DEFAULT 0,
        AccountId     NVARCHAR(100)  NULL,
        Remark        NVARCHAR(500)  NULL,
        AddedBy       INT            NULL,
        UpdatedBy     INT            NULL,
        IsDeletedBy   INT            NULL,
        IsDeleted     BIT            NOT NULL DEFAULT 0,
        CreatedAt     DATETIME       NOT NULL DEFAULT GETDATE(),
        UpdatedAt     DATETIME       NOT NULL DEFAULT GETDATE()
    );

    PRINT 'PartnerTrans table created successfully.';
END
ELSE
BEGIN
    PRINT 'PartnerTrans table already exists – skipped.';
END
GO
