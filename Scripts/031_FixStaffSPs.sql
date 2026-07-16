-- ============================================================
-- Script 031: Fix Staff Stored Procedures
-- Missing columns: Designation, EmiratesId, PassportNo,
--   Nationality, JobTitle, MoveInDate, VisaExpiry,
--   10x document dates, 5x document URLs
-- Also fixes INSERT column/value order bug in sp_CreateStaff
-- ============================================================

-- ── 1. Add missing columns to Staff table (if not exist) ─────
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='Designation')
    ALTER TABLE Staff ADD Designation NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='EmiratesId')
    ALTER TABLE Staff ADD EmiratesId NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='PassportNo')
    ALTER TABLE Staff ADD PassportNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='Nationality')
    ALTER TABLE Staff ADD Nationality NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='JobTitle')
    ALTER TABLE Staff ADD JobTitle NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='MoveInDate')
    ALTER TABLE Staff ADD MoveInDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='VisaExpiry')
    ALTER TABLE Staff ADD VisaExpiry DATETIME2 NULL;
GO

-- Document dates
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='EmiratesIdIssueDate')
    ALTER TABLE Staff ADD EmiratesIdIssueDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='EmiratesIdExpiryDate')
    ALTER TABLE Staff ADD EmiratesIdExpiryDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='PassportIssueDate')
    ALTER TABLE Staff ADD PassportIssueDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='PassportExpiryDate')
    ALTER TABLE Staff ADD PassportExpiryDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='LabourCardIssueDate')
    ALTER TABLE Staff ADD LabourCardIssueDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='LabourCardExpiryDate')
    ALTER TABLE Staff ADD LabourCardExpiryDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='IloeIssueDate')
    ALTER TABLE Staff ADD IloeIssueDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='IloeExpiryDate')
    ALTER TABLE Staff ADD IloeExpiryDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='InsuranceIssueDate')
    ALTER TABLE Staff ADD InsuranceIssueDate DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='InsuranceExpiryDate')
    ALTER TABLE Staff ADD InsuranceExpiryDate DATETIME2 NULL;
GO

-- Document URLs (Cloudinary)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='EmiratesIdDocument')
    ALTER TABLE Staff ADD EmiratesIdDocument NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='PassportDocument')
    ALTER TABLE Staff ADD PassportDocument NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='LabourCardDocument')
    ALTER TABLE Staff ADD LabourCardDocument NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='IloeDocument')
    ALTER TABLE Staff ADD IloeDocument NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='Staff' AND COLUMN_NAME='InsuranceDocument')
    ALTER TABLE Staff ADD InsuranceDocument NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

PRINT 'Staff table columns verified/added.';
GO

-- ── 2. Fix sp_GetStaff — include all columns ─────────────────
CREATE OR ALTER PROCEDURE sp_GetStaff
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC',
    @Status        NVARCHAR(MAX) = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*) FROM Staff
    WHERE (@Status IS NULL OR Status = @Status)
      AND (@SearchText IS NULL
           OR Name       LIKE '%' + @SearchText + '%'
           OR StaffId    LIKE '%' + @SearchText + '%'
           OR Username   LIKE '%' + @SearchText + '%'
           OR Contact    LIKE '%' + @SearchText + '%'
           OR Designation LIKE '%' + @SearchText + '%');

    SELECT
        Id, StaffId, Name, Role, Designation, Contact, Email, Address,
        Username, Password, LoginAccess, Status, Remarks,
        EmiratesId, PassportNo, Nationality, JobTitle,
        MoveInDate, VisaExpiry,
        EmiratesIdIssueDate,  EmiratesIdExpiryDate,
        PassportIssueDate,    PassportExpiryDate,
        LabourCardIssueDate,  LabourCardExpiryDate,
        IloeIssueDate,        IloeExpiryDate,
        InsuranceIssueDate,   InsuranceExpiryDate,
        EmiratesIdDocument, PassportDocument, LabourCardDocument,
        IloeDocument, InsuranceDocument,
        CreatedAt, UpdatedAt
    FROM Staff
    WHERE (@Status IS NULL OR Status = @Status)
      AND (@SearchText IS NULL
           OR Name       LIKE '%' + @SearchText + '%'
           OR StaffId    LIKE '%' + @SearchText + '%'
           OR Username   LIKE '%' + @SearchText + '%'
           OR Contact    LIKE '%' + @SearchText + '%'
           OR Designation LIKE '%' + @SearchText + '%')
    ORDER BY
        CASE WHEN @SortBy = 'Name' AND @SortDirection = 'ASC'  THEN Name END ASC,
        CASE WHEN @SortBy = 'Name' AND @SortDirection = 'DESC' THEN Name END DESC,
        CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── 3. Fix sp_GetStaffById — include all columns ─────────────
CREATE OR ALTER PROCEDURE sp_GetStaffById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        Id, StaffId, Name, Role, Designation, Contact, Email, Address,
        Username, Password, LoginAccess, Status, Remarks,
        EmiratesId, PassportNo, Nationality, JobTitle,
        MoveInDate, VisaExpiry,
        EmiratesIdIssueDate,  EmiratesIdExpiryDate,
        PassportIssueDate,    PassportExpiryDate,
        LabourCardIssueDate,  LabourCardExpiryDate,
        IloeIssueDate,        IloeExpiryDate,
        InsuranceIssueDate,   InsuranceExpiryDate,
        EmiratesIdDocument, PassportDocument, LabourCardDocument,
        IloeDocument, InsuranceDocument,
        CreatedAt, UpdatedAt
    FROM Staff
    WHERE Id = @Id;
END
GO

-- ── 4. Fix sp_CreateStaff — add all params + fix INSERT order ─
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
    -- Document dates
    @EmiratesIdIssueDate  DATETIME2 = NULL,
    @EmiratesIdExpiryDate DATETIME2 = NULL,
    @PassportIssueDate    DATETIME2 = NULL,
    @PassportExpiryDate   DATETIME2 = NULL,
    @LabourCardIssueDate  DATETIME2 = NULL,
    @LabourCardExpiryDate DATETIME2 = NULL,
    @IloeIssueDate        DATETIME2 = NULL,
    @IloeExpiryDate       DATETIME2 = NULL,
    @InsuranceIssueDate   DATETIME2 = NULL,
    @InsuranceExpiryDate  DATETIME2 = NULL,
    -- Document URLs
    @EmiratesIdDocument NVARCHAR(MAX) = NULL,
    @PassportDocument   NVARCHAR(MAX) = NULL,
    @LabourCardDocument NVARCHAR(MAX) = NULL,
    @IloeDocument       NVARCHAR(MAX) = NULL,
    @InsuranceDocument  NVARCHAR(MAX) = NULL,
    @NewId INT OUTPUT
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
        EmiratesIdIssueDate,  EmiratesIdExpiryDate,
        PassportIssueDate,    PassportExpiryDate,
        LabourCardIssueDate,  LabourCardExpiryDate,
        IloeIssueDate,        IloeExpiryDate,
        InsuranceIssueDate,   InsuranceExpiryDate,
        EmiratesIdDocument, PassportDocument, LabourCardDocument,
        IloeDocument, InsuranceDocument,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @StaffId, @Name, 'Staff', @Designation, @Contact, @Email, @Address,
        ISNULL(@Username, @StaffId), @Password, @LoginAccess, @Status, @Remarks,
        @EmiratesId, @PassportNo, @Nationality, @JobTitle,
        @MoveInDate, @VisaExpiry,
        @EmiratesIdIssueDate,  @EmiratesIdExpiryDate,
        @PassportIssueDate,    @PassportExpiryDate,
        @LabourCardIssueDate,  @LabourCardExpiryDate,
        @IloeIssueDate,        @IloeExpiryDate,
        @InsuranceIssueDate,   @InsuranceExpiryDate,
        ISNULL(@EmiratesIdDocument, ''), ISNULL(@PassportDocument, ''),
        ISNULL(@LabourCardDocument, ''), ISNULL(@IloeDocument, ''),
        ISNULL(@InsuranceDocument, ''),
        GETUTCDATE(), GETUTCDATE()
    );

    SET @NewId = SCOPE_IDENTITY();

    -- Auto-create AppUser login for this staff member
    DECLARE @AppUsername NVARCHAR(MAX) = ISNULL(@Username, @StaffId);
    IF NOT EXISTS (SELECT 1 FROM AppUsers WHERE Username = @AppUsername)
    BEGIN
        DECLARE @UserId NVARCHAR(MAX) =
            'TFMS' + RIGHT('00000' + CAST(@NewId AS NVARCHAR(10)), 5);
        INSERT INTO AppUsers (
            UserId, Name, Username, PasswordHash, Role,
            Source, SourceId, Contact, Email,
            LoginAccess, Status, MenuAccess, IsAdmin,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @UserId, @Name, @AppUsername, @Password, 'Staff',
            'Staff Master', @NewId, @Contact, @Email,
            @LoginAccess, @Status, '[]', 0,
            GETUTCDATE(), GETUTCDATE()
        );
    END
END
GO

-- ── 5. Fix sp_UpdateStaff — add all missing columns ──────────
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
    -- Document dates
    @EmiratesIdIssueDate  DATETIME2 = NULL,
    @EmiratesIdExpiryDate DATETIME2 = NULL,
    @PassportIssueDate    DATETIME2 = NULL,
    @PassportExpiryDate   DATETIME2 = NULL,
    @LabourCardIssueDate  DATETIME2 = NULL,
    @LabourCardExpiryDate DATETIME2 = NULL,
    @IloeIssueDate        DATETIME2 = NULL,
    @IloeExpiryDate       DATETIME2 = NULL,
    @InsuranceIssueDate   DATETIME2 = NULL,
    @InsuranceExpiryDate  DATETIME2 = NULL,
    -- Document URLs (NULL = keep existing value)
    @EmiratesIdDocument NVARCHAR(MAX) = NULL,
    @PassportDocument   NVARCHAR(MAX) = NULL,
    @LabourCardDocument NVARCHAR(MAX) = NULL,
    @IloeDocument       NVARCHAR(MAX) = NULL,
    @InsuranceDocument  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Staff SET
        Name        = @Name,
        Designation = @Designation,
        Contact     = @Contact,
        Email       = @Email,
        Address     = @Address,
        Username    = ISNULL(@Username, Username),
        LoginAccess = @LoginAccess,
        Status      = @Status,
        Remarks     = @Remarks,
        EmiratesId  = @EmiratesId,
        PassportNo  = @PassportNo,
        Nationality = @Nationality,
        JobTitle    = @JobTitle,
        MoveInDate  = @MoveInDate,
        VisaExpiry  = @VisaExpiry,
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
        -- Only overwrite document URLs if new ones were provided
        EmiratesIdDocument = ISNULL(@EmiratesIdDocument, EmiratesIdDocument),
        PassportDocument   = ISNULL(@PassportDocument,   PassportDocument),
        LabourCardDocument = ISNULL(@LabourCardDocument, LabourCardDocument),
        IloeDocument       = ISNULL(@IloeDocument,       IloeDocument),
        InsuranceDocument  = ISNULL(@InsuranceDocument,  InsuranceDocument),
        UpdatedAt          = GETUTCDATE()
    WHERE Id = @Id;

    -- Update password only if provided
    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE Staff SET Password = @Password WHERE Id = @Id;

    -- Sync AppUsers record
    UPDATE AppUsers SET
        Name        = @Name,
        Contact     = @Contact,
        Email       = @Email,
        LoginAccess = @LoginAccess,
        Status      = @Status,
        UpdatedAt   = GETUTCDATE()
    WHERE Source = 'Staff Master' AND SourceId = @Id;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE AppUsers SET PasswordHash = @Password
        WHERE Source = 'Staff Master' AND SourceId = @Id;
END
GO

-- ── 6. sp_DeleteStaff — keep as-is (already correct) ─────────
-- No changes needed for delete.

PRINT '=== Script 031 complete: Staff SPs fully fixed with all columns ===';
GO
