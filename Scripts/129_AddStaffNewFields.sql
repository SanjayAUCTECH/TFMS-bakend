-- ============================================================
-- 129: Add 5 New Fields to Staff table
-- Fields: LabourCardNo, DateOfBirth, FitnessExpireDM, IloeNo, InsuranceNo
-- Date: July 31, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: Add columns ───────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'LabourCardNo')
    ALTER TABLE Staff ADD LabourCardNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'DateOfBirth')
    ALTER TABLE Staff ADD DateOfBirth DATETIME2 NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'FitnessExpireDM')
    ALTER TABLE Staff ADD FitnessExpireDM DATETIME2 NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'IloeNo')
    ALTER TABLE Staff ADD IloeNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Staff') AND name = 'InsuranceNo')
    ALTER TABLE Staff ADD InsuranceNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

PRINT '✅ 5 new columns added to Staff table';
GO

-- ── Step 2: sp_GetStaff — include new fields ──────────────────
CREATE OR ALTER PROCEDURE sp_GetStaff
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC',
    @Status        NVARCHAR(MAX) = NULL,
    @CompanyId     INT           = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM Staff s
    WHERE ISNULL(s.IsDeleted, 0) = 0
      AND (@Status    IS NULL OR s.Status    = @Status)
      AND (@CompanyId IS NULL OR s.CompanyId = @CompanyId)
      AND (@SearchText IS NULL
           OR s.Name         LIKE '%' + @SearchText + '%'
           OR s.StaffId      LIKE '%' + @SearchText + '%'
           OR s.Username     LIKE '%' + @SearchText + '%'
           OR s.Contact      LIKE '%' + @SearchText + '%'
           OR s.Designation  LIKE '%' + @SearchText + '%'
           OR s.LabourCardNo LIKE '%' + @SearchText + '%'
           OR s.IloeNo       LIKE '%' + @SearchText + '%');

    SELECT
        s.Id, s.StaffId, s.Name, s.Role, s.Designation, s.Contact, s.Email, s.Address,
        s.Username, s.Password, s.LoginAccess, s.Status, s.Remarks,
        s.EmiratesId, s.PassportNo, s.Nationality, s.JobTitle,
        s.MoveInDate, s.VisaExpiry,
        s.LabourCardNo, s.DateOfBirth, s.FitnessExpireDM, s.IloeNo, s.InsuranceNo,
        s.EmiratesIdIssueDate,  s.EmiratesIdExpiryDate,
        s.PassportIssueDate,    s.PassportExpiryDate,
        s.LabourCardIssueDate,  s.LabourCardExpiryDate,
        s.IloeIssueDate,        s.IloeExpiryDate,
        s.InsuranceIssueDate,   s.InsuranceExpiryDate,
        s.EmiratesIdDocument, s.PassportDocument, s.LabourCardDocument,
        s.IloeDocument, s.InsuranceDocument,
        s.CompanyId,
        ISNULL(c.CompanyName, '') AS CompanyName,
        s.CreatedAt, s.UpdatedAt
    FROM Staff s
    LEFT JOIN Companies c ON c.Id = s.CompanyId AND c.IsDeleted = 0
    WHERE ISNULL(s.IsDeleted, 0) = 0
      AND (@Status    IS NULL OR s.Status    = @Status)
      AND (@CompanyId IS NULL OR s.CompanyId = @CompanyId)
      AND (@SearchText IS NULL
           OR s.Name         LIKE '%' + @SearchText + '%'
           OR s.StaffId      LIKE '%' + @SearchText + '%'
           OR s.Username     LIKE '%' + @SearchText + '%'
           OR s.Contact      LIKE '%' + @SearchText + '%'
           OR s.Designation  LIKE '%' + @SearchText + '%'
           OR s.LabourCardNo LIKE '%' + @SearchText + '%'
           OR s.IloeNo       LIKE '%' + @SearchText + '%')
    ORDER BY
        CASE WHEN @SortBy = 'Name' AND @SortDirection = 'ASC'  THEN s.Name END ASC,
        CASE WHEN @SortBy = 'Name' AND @SortDirection = 'DESC' THEN s.Name END DESC,
        s.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Step 3: sp_GetStaffById ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetStaffById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.Id, s.StaffId, s.Name, s.Role, s.Designation, s.Contact, s.Email, s.Address,
        s.Username, s.Password, s.LoginAccess, s.Status, s.Remarks,
        s.EmiratesId, s.PassportNo, s.Nationality, s.JobTitle,
        s.MoveInDate, s.VisaExpiry,
        s.LabourCardNo, s.DateOfBirth, s.FitnessExpireDM, s.IloeNo, s.InsuranceNo,
        s.EmiratesIdIssueDate,  s.EmiratesIdExpiryDate,
        s.PassportIssueDate,    s.PassportExpiryDate,
        s.LabourCardIssueDate,  s.LabourCardExpiryDate,
        s.IloeIssueDate,        s.IloeExpiryDate,
        s.InsuranceIssueDate,   s.InsuranceExpiryDate,
        s.EmiratesIdDocument, s.PassportDocument, s.LabourCardDocument,
        s.IloeDocument, s.InsuranceDocument,
        s.CompanyId,
        ISNULL(c.CompanyName, '') AS CompanyName,
        s.CreatedAt, s.UpdatedAt
    FROM Staff s
    LEFT JOIN Companies c ON c.Id = s.CompanyId AND c.IsDeleted = 0
    WHERE s.Id = @Id AND ISNULL(s.IsDeleted, 0) = 0;
END
GO

-- ── Step 4: sp_CreateStaff ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateStaff
    @Name        NVARCHAR(MAX),
    @Designation NVARCHAR(MAX) = '',
    @Contact     NVARCHAR(MAX) = '',
    @Email       NVARCHAR(MAX) = '',
    @Address     NVARCHAR(MAX) = '',
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = 'Pass@123',
    @LoginAccess NVARCHAR(MAX) = 'enabled',
    @Status      NVARCHAR(MAX) = 'Active',
    @Remarks     NVARCHAR(MAX) = '',
    @EmiratesId  NVARCHAR(MAX) = '',
    @PassportNo  NVARCHAR(MAX) = '',
    @Nationality NVARCHAR(MAX) = '',
    @JobTitle    NVARCHAR(MAX) = '',
    @MoveInDate  DATETIME2     = NULL,
    @VisaExpiry  DATETIME2     = NULL,
    -- 5 New params
    @LabourCardNo    NVARCHAR(MAX) = '',
    @DateOfBirth     DATETIME2     = NULL,
    @FitnessExpireDM DATETIME2     = NULL,
    @IloeNo          NVARCHAR(MAX) = '',
    @InsuranceNo     NVARCHAR(MAX) = '',
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
    -- Document URLs
    @EmiratesIdDocument   NVARCHAR(MAX) = NULL,
    @PassportDocument     NVARCHAR(MAX) = NULL,
    @LabourCardDocument   NVARCHAR(MAX) = NULL,
    @IloeDocument         NVARCHAR(MAX) = NULL,
    @InsuranceDocument    NVARCHAR(MAX) = NULL,
    @CompanyId            INT           = NULL,
    @AddedBy              NVARCHAR(MAX) = NULL,
    @NewId                INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StaffId NVARCHAR(MAX) =
        'STF-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Staff) AS NVARCHAR(10)), 6);

    INSERT INTO Staff (
        StaffId, Name, Role, Designation, Contact, Email, Address,
        Username, Password, LoginAccess, Status, Remarks,
        EmiratesId, PassportNo, Nationality, JobTitle,
        MoveInDate, VisaExpiry,
        LabourCardNo, DateOfBirth, FitnessExpireDM, IloeNo, InsuranceNo,
        EmiratesIdIssueDate,  EmiratesIdExpiryDate,
        PassportIssueDate,    PassportExpiryDate,
        LabourCardIssueDate,  LabourCardExpiryDate,
        IloeIssueDate,        IloeExpiryDate,
        InsuranceIssueDate,   InsuranceExpiryDate,
        EmiratesIdDocument, PassportDocument, LabourCardDocument,
        IloeDocument, InsuranceDocument,
        CompanyId, CreatedAt, UpdatedAt
    )
    VALUES (
        @StaffId, @Name, 'Staff', @Designation, @Contact, @Email, @Address,
        ISNULL(@Username, @StaffId), @Password, @LoginAccess, @Status, @Remarks,
        @EmiratesId, @PassportNo, @Nationality, @JobTitle,
        @MoveInDate, @VisaExpiry,
        @LabourCardNo, @DateOfBirth, @FitnessExpireDM, @IloeNo, @InsuranceNo,
        @EmiratesIdIssueDate,  @EmiratesIdExpiryDate,
        @PassportIssueDate,    @PassportExpiryDate,
        @LabourCardIssueDate,  @LabourCardExpiryDate,
        @IloeIssueDate,        @IloeExpiryDate,
        @InsuranceIssueDate,   @InsuranceExpiryDate,
        ISNULL(@EmiratesIdDocument, ''), ISNULL(@PassportDocument, ''),
        ISNULL(@LabourCardDocument, ''), ISNULL(@IloeDocument, ''),
        ISNULL(@InsuranceDocument, ''),
        @CompanyId, GETUTCDATE(), GETUTCDATE()
    );

    SET @NewId = SCOPE_IDENTITY();

    DECLARE @AppUsername NVARCHAR(MAX) = ISNULL(@Username, @StaffId);
    IF NOT EXISTS (SELECT 1 FROM AppUsers WHERE Username = @AppUsername)
    BEGIN
        DECLARE @UserId NVARCHAR(MAX) = 'TFMS' + RIGHT('00000' + CAST(@NewId AS NVARCHAR(10)), 5);
        INSERT INTO AppUsers (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
            Contact, Email, LoginAccess, Status, MenuAccess, IsAdmin, CreatedAt, UpdatedAt)
        VALUES (@UserId, @Name, @AppUsername, @Password, 'Staff', 'Staff Master', @NewId,
            @Contact, @Email, @LoginAccess, @Status, '[]', 0, GETUTCDATE(), GETUTCDATE());
    END
END
GO

-- ── Step 5: sp_UpdateStaff ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateStaff
    @Id          INT,
    @Name        NVARCHAR(MAX),
    @Designation NVARCHAR(MAX) = '',
    @Contact     NVARCHAR(MAX) = '',
    @Email       NVARCHAR(MAX) = '',
    @Address     NVARCHAR(MAX) = '',
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = NULL,
    @LoginAccess NVARCHAR(MAX) = 'enabled',
    @Status      NVARCHAR(MAX) = 'Active',
    @Remarks     NVARCHAR(MAX) = '',
    @EmiratesId  NVARCHAR(MAX) = '',
    @PassportNo  NVARCHAR(MAX) = '',
    @Nationality NVARCHAR(MAX) = '',
    @JobTitle    NVARCHAR(MAX) = '',
    @MoveInDate  DATETIME2     = NULL,
    @VisaExpiry  DATETIME2     = NULL,
    -- 5 New params
    @LabourCardNo    NVARCHAR(MAX) = '',
    @DateOfBirth     DATETIME2     = NULL,
    @FitnessExpireDM DATETIME2     = NULL,
    @IloeNo          NVARCHAR(MAX) = '',
    @InsuranceNo     NVARCHAR(MAX) = '',
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
    -- Document URLs
    @EmiratesIdDocument   NVARCHAR(MAX) = NULL,
    @PassportDocument     NVARCHAR(MAX) = NULL,
    @LabourCardDocument   NVARCHAR(MAX) = NULL,
    @IloeDocument         NVARCHAR(MAX) = NULL,
    @InsuranceDocument    NVARCHAR(MAX) = NULL,
    @CompanyId            INT           = NULL,
    @UpdatedBy            NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Staff SET
        Name             = @Name,
        Designation      = @Designation,
        Contact          = @Contact,
        Email            = @Email,
        Address          = @Address,
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
        EmiratesIdDocument   = ISNULL(@EmiratesIdDocument, EmiratesIdDocument),
        PassportDocument     = ISNULL(@PassportDocument,   PassportDocument),
        LabourCardDocument   = ISNULL(@LabourCardDocument, LabourCardDocument),
        IloeDocument         = ISNULL(@IloeDocument,       IloeDocument),
        InsuranceDocument    = ISNULL(@InsuranceDocument,  InsuranceDocument),
        CompanyId            = @CompanyId,
        UpdatedAt            = GETUTCDATE()
    WHERE Id = @Id AND ISNULL(IsDeleted, 0) = 0;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE Staff SET Password = @Password WHERE Id = @Id;

    UPDATE AppUsers SET
        Name = @Name, Contact = @Contact, Email = @Email,
        LoginAccess = @LoginAccess, Status = @Status, UpdatedAt = GETUTCDATE()
    WHERE Source = 'Staff Master' AND SourceId = @Id;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE AppUsers SET PasswordHash = @Password
        WHERE Source = 'Staff Master' AND SourceId = @Id;
END
GO

PRINT '✅ 129 - Staff: LabourCardNo, DateOfBirth, FitnessExpireDM, IloeNo, InsuranceNo added';
GO
