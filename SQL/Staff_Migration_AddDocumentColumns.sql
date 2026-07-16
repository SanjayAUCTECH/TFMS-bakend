-- ============================================================
-- Staff Table Migration: Add document date + Cloudinary URL columns
-- Run this once on the database
-- ============================================================

-- Add document date columns (if not already exist)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'EmiratesIdIssueDate')
    ALTER TABLE Staff ADD EmiratesIdIssueDate  DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'EmiratesIdExpiryDate')
    ALTER TABLE Staff ADD EmiratesIdExpiryDate DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'PassportIssueDate')
    ALTER TABLE Staff ADD PassportIssueDate    DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'PassportExpiryDate')
    ALTER TABLE Staff ADD PassportExpiryDate   DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'LabourCardIssueDate')
    ALTER TABLE Staff ADD LabourCardIssueDate  DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'LabourCardExpiryDate')
    ALTER TABLE Staff ADD LabourCardExpiryDate DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'IloeIssueDate')
    ALTER TABLE Staff ADD IloeIssueDate        DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'IloeExpiryDate')
    ALTER TABLE Staff ADD IloeExpiryDate       DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'InsuranceIssueDate')
    ALTER TABLE Staff ADD InsuranceIssueDate   DATE NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'InsuranceExpiryDate')
    ALTER TABLE Staff ADD InsuranceExpiryDate  DATE NULL;

-- Add document URL columns (Cloudinary)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'EmiratesIdDocument')
    ALTER TABLE Staff ADD EmiratesIdDocument  NVARCHAR(1000) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'PassportDocument')
    ALTER TABLE Staff ADD PassportDocument    NVARCHAR(1000) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'LabourCardDocument')
    ALTER TABLE Staff ADD LabourCardDocument  NVARCHAR(1000) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'IloeDocument')
    ALTER TABLE Staff ADD IloeDocument        NVARCHAR(1000) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'InsuranceDocument')
    ALTER TABLE Staff ADD InsuranceDocument   NVARCHAR(1000) NULL;

GO

-- ============================================================
-- sp_CreateStaff — recreate with all new columns
-- ============================================================
IF OBJECT_ID('sp_CreateStaff', 'P') IS NOT NULL DROP PROCEDURE sp_CreateStaff;
GO

CREATE PROCEDURE sp_CreateStaff
    @Name                 NVARCHAR(200),
    @Designation          NVARCHAR(200)  = '',
    @Contact              NVARCHAR(50),
    @Email                NVARCHAR(200)  = '',
    @Address              NVARCHAR(500)  = '',
    @Username             NVARCHAR(100)  = NULL,
    @Password             NVARCHAR(200)  = '',
    @LoginAccess          NVARCHAR(20)   = 'enabled',
    @Status               NVARCHAR(20)   = 'Active',
    @Remarks              NVARCHAR(1000) = '',
    @EmiratesId           NVARCHAR(50)   = '',
    @PassportNo           NVARCHAR(50)   = '',
    @Nationality          NVARCHAR(100)  = '',
    @JobTitle             NVARCHAR(200)  = '',
    @MoveInDate           DATE           = NULL,
    @VisaExpiry           DATE           = NULL,
    @EmiratesIdIssueDate  DATE           = NULL,
    @EmiratesIdExpiryDate DATE           = NULL,
    @PassportIssueDate    DATE           = NULL,
    @PassportExpiryDate   DATE           = NULL,
    @LabourCardIssueDate  DATE           = NULL,
    @LabourCardExpiryDate DATE           = NULL,
    @IloeIssueDate        DATE           = NULL,
    @IloeExpiryDate       DATE           = NULL,
    @InsuranceIssueDate   DATE           = NULL,
    @InsuranceExpiryDate  DATE           = NULL,
    @EmiratesIdDocument   NVARCHAR(1000) = NULL,
    @PassportDocument     NVARCHAR(1000) = NULL,
    @LabourCardDocument   NVARCHAR(1000) = NULL,
    @IloeDocument         NVARCHAR(1000) = NULL,
    @InsuranceDocument    NVARCHAR(1000) = NULL,
    @NewId                INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StaffId NVARCHAR(20);
    DECLARE @NextNum INT;
    SELECT @NextNum = ISNULL(MAX(Id), 0) + 1 FROM Staff;
    SET @StaffId = 'STF-' + RIGHT('000000' + CAST(@NextNum AS NVARCHAR), 6);

    INSERT INTO Staff (
        StaffId, Name, Designation, Contact, Email, Address,
        Username, Password, LoginAccess, Status, Remarks,
        EmiratesId, PassportNo, Nationality, JobTitle,
        MoveInDate, VisaExpiry,
        EmiratesIdIssueDate, EmiratesIdExpiryDate,
        PassportIssueDate, PassportExpiryDate,
        LabourCardIssueDate, LabourCardExpiryDate,
        IloeIssueDate, IloeExpiryDate,
        InsuranceIssueDate, InsuranceExpiryDate,
        EmiratesIdDocument, PassportDocument, LabourCardDocument,
        IloeDocument, InsuranceDocument,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @StaffId, @Name, @Designation, @Contact, @Email, @Address,
        @Username, @Password, @LoginAccess, @Status, @Remarks,
        @EmiratesId, @PassportNo, @Nationality, @JobTitle,
        @MoveInDate, @VisaExpiry,
        @EmiratesIdIssueDate, @EmiratesIdExpiryDate,
        @PassportIssueDate, @PassportExpiryDate,
        @LabourCardIssueDate, @LabourCardExpiryDate,
        @IloeIssueDate, @IloeExpiryDate,
        @InsuranceIssueDate, @InsuranceExpiryDate,
        @EmiratesIdDocument, @PassportDocument, @LabourCardDocument,
        @IloeDocument, @InsuranceDocument,
        GETDATE(), GETDATE()
    );

    SET @NewId = SCOPE_IDENTITY();
END
GO

-- ============================================================
-- sp_UpdateStaff — recreate with all new columns
-- ============================================================
IF OBJECT_ID('sp_UpdateStaff', 'P') IS NOT NULL DROP PROCEDURE sp_UpdateStaff;
GO

CREATE PROCEDURE sp_UpdateStaff
    @Id                   INT,
    @Name                 NVARCHAR(200),
    @Designation          NVARCHAR(200)  = '',
    @Contact              NVARCHAR(50),
    @Email                NVARCHAR(200)  = '',
    @Address              NVARCHAR(500)  = '',
    @Username             NVARCHAR(100)  = NULL,
    @Password             NVARCHAR(200)  = NULL,
    @LoginAccess          NVARCHAR(20)   = 'enabled',
    @Status               NVARCHAR(20)   = 'Active',
    @Remarks              NVARCHAR(1000) = '',
    @EmiratesId           NVARCHAR(50)   = '',
    @PassportNo           NVARCHAR(50)   = '',
    @Nationality          NVARCHAR(100)  = '',
    @JobTitle             NVARCHAR(200)  = '',
    @MoveInDate           DATE           = NULL,
    @VisaExpiry           DATE           = NULL,
    @EmiratesIdIssueDate  DATE           = NULL,
    @EmiratesIdExpiryDate DATE           = NULL,
    @PassportIssueDate    DATE           = NULL,
    @PassportExpiryDate   DATE           = NULL,
    @LabourCardIssueDate  DATE           = NULL,
    @LabourCardExpiryDate DATE           = NULL,
    @IloeIssueDate        DATE           = NULL,
    @IloeExpiryDate       DATE           = NULL,
    @InsuranceIssueDate   DATE           = NULL,
    @InsuranceExpiryDate  DATE           = NULL,
    @EmiratesIdDocument   NVARCHAR(1000) = NULL,
    @PassportDocument     NVARCHAR(1000) = NULL,
    @LabourCardDocument   NVARCHAR(1000) = NULL,
    @IloeDocument         NVARCHAR(1000) = NULL,
    @InsuranceDocument    NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Staff SET
        Name                 = @Name,
        Designation          = @Designation,
        Contact              = @Contact,
        Email                = @Email,
        Address              = @Address,
        Username             = @Username,
        Password             = CASE WHEN @Password IS NOT NULL AND LEN(@Password) > 0 THEN @Password ELSE Password END,
        LoginAccess          = @LoginAccess,
        Status               = @Status,
        Remarks              = @Remarks,
        EmiratesId           = @EmiratesId,
        PassportNo           = @PassportNo,
        Nationality          = @Nationality,
        JobTitle             = @JobTitle,
        MoveInDate           = @MoveInDate,
        VisaExpiry           = @VisaExpiry,
        EmiratesIdIssueDate  = @EmiratesIdIssueDate,
        EmiratesIdExpiryDate = @EmiratesIdExpiryDate,
        PassportIssueDate    = @PassportIssueDate,
        PassportExpiryDate   = @PassportExpiryDate,
        LabourCardIssueDate  = @LabourCardIssueDate,
        LabourCardExpiryDate = @LabourCardExpiryDate,
        IloeIssueDate        = @IloeIssueDate,
        IloeExpiryDate       = @IloeExpiryDate,
        InsuranceIssueDate   = @InsuranceIssueDate,
        InsuranceExpiryDate  = @InsuranceExpiryDate,
        -- Only update document URL if a new one was uploaded (not NULL)
        EmiratesIdDocument   = ISNULL(@EmiratesIdDocument, EmiratesIdDocument),
        PassportDocument     = ISNULL(@PassportDocument,   PassportDocument),
        LabourCardDocument   = ISNULL(@LabourCardDocument, LabourCardDocument),
        IloeDocument         = ISNULL(@IloeDocument,       IloeDocument),
        InsuranceDocument    = ISNULL(@InsuranceDocument,  InsuranceDocument),
        UpdatedAt            = GETDATE()
    WHERE Id = @Id;
END
GO

-- ============================================================
-- sp_GetStaffById — recreate to include new columns
-- ============================================================
IF OBJECT_ID('sp_GetStaffById', 'P') IS NOT NULL DROP PROCEDURE sp_GetStaffById;
GO

CREATE PROCEDURE sp_GetStaffById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Staff WHERE Id = @Id;
END
GO
