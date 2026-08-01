-- ============================================================
-- 131: Fix sp_UpdateStaff — null bheje toh NULL save ho
--      (ISNULL hataya document URLs se, baaki fields bhi direct assign)
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateStaff
    @Id          INT,
    @Name        NVARCHAR(MAX),
    @Designation NVARCHAR(MAX) = NULL,
    @Contact     NVARCHAR(MAX) = NULL,
    @Email       NVARCHAR(MAX) = NULL,
    @Address     NVARCHAR(MAX) = NULL,
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = NULL,
    @LoginAccess NVARCHAR(MAX) = 'enabled',
    @Status      NVARCHAR(MAX) = 'Active',
    @Remarks     NVARCHAR(MAX) = NULL,
    @EmiratesId  NVARCHAR(MAX) = NULL,
    @PassportNo  NVARCHAR(MAX) = NULL,
    @Nationality NVARCHAR(MAX) = NULL,
    @JobTitle    NVARCHAR(MAX) = NULL,
    @MoveInDate  DATETIME2     = NULL,
    @VisaExpiry  DATETIME2     = NULL,
    -- 5 New params
    @LabourCardNo    NVARCHAR(MAX) = NULL,
    @DateOfBirth     DATETIME2     = NULL,
    @FitnessExpireDM DATETIME2     = NULL,
    @IloeNo          NVARCHAR(MAX) = NULL,
    @InsuranceNo     NVARCHAR(MAX) = NULL,
    -- Document dates
    @EmiratesIdIssueDate  DATETIME2     = NULL,
    @EmiratesIdExpiryDate DATETIME2     = NULL,
    @PassportIssueDate    DATETIME2     = NULL,
    @PassportExpiryDate   DATETIME2     = NULL,
    @LabourCardIssueDate  DATETIME2     = NULL,
    @LabourCardExpiryDate DATETIME2     = NULL,
    @IloeIssueDate        DATETIME2     = NULL,
    @IloeExpiryDate       DATETIME2     = NULL,
    @InsuranceIssueDate   DATETIME2     = NULL,
    @InsuranceExpiryDate  DATETIME2     = NULL,
    -- Document URLs — NULL bheja = NULL save karo (ISNULL nahi)
    @EmiratesIdDocument   NVARCHAR(MAX) = NULL,
    @PassportDocument     NVARCHAR(MAX) = NULL,
    @LabourCardDocument   NVARCHAR(MAX) = NULL,
    @IloeDocument         NVARCHAR(MAX) = NULL,
    @InsuranceDocument    NVARCHAR(MAX) = NULL,
    @CompanyId            INT           = NULL,
    @UpdatedBy            INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Staff SET
        Name             = @Name,
        Designation      = @Designation,
        Contact          = @Contact,
        Email            = @Email,
        Address          = @Address,
        -- Username: NULL bheja toh purana rakho (intentional — username blank nahi hona chahiye)
        Username         = ISNULL(@Username, Username),
        LoginAccess      = @LoginAccess,
        Status           = @Status,
        Remarks          = @Remarks,
        EmiratesId       = @EmiratesId,
        PassportNo       = @PassportNo,
        Nationality      = @Nationality,
        JobTitle         = @JobTitle,
        MoveInDate       = @MoveInDate,
        VisaExpiry       = @VisaExpiry,
        LabourCardNo     = @LabourCardNo,
        DateOfBirth      = @DateOfBirth,
        FitnessExpireDM  = @FitnessExpireDM,
        IloeNo           = @IloeNo,
        InsuranceNo      = @InsuranceNo,
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
        -- Document URLs: NULL bheja toh NULL save karo (ISNULL hataya)
        EmiratesIdDocument   = @EmiratesIdDocument,
        PassportDocument     = @PassportDocument,
        LabourCardDocument   = @LabourCardDocument,
        IloeDocument         = @IloeDocument,
        InsuranceDocument    = @InsuranceDocument,
        CompanyId            = @CompanyId,
        UpdatedBy            = @UpdatedBy,
        UpdatedAt            = GETUTCDATE()
    WHERE Id = @Id AND ISNULL(IsDeleted, 0) = 0;

    -- Password: sirf tab update karo jab explicitly bheja gaya ho
    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE Staff SET Password = @Password WHERE Id = @Id;

    -- AppUsers sync
    UPDATE AppUsers SET
        Name        = @Name,
        Contact     = @Contact,
        Email       = @Email,
        LoginAccess = @LoginAccess,
        Status      = @Status,
        UpdatedAt   = GETUTCDATE()
    WHERE Source = 'Staff Master' AND SourceId = @Id;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE AppUsers SET PasswordHash = @Password WHERE Source = 'Staff Master' AND SourceId = @Id;

END
GO

PRINT '✅ 131 - sp_UpdateStaff fixed: null bhejo toh NULL save hoga';
GO
