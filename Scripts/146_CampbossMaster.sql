-- ============================================================
-- 146: Campboss Master
--      + Add 'Campboss' role to Roles table
--      + Create Campbosses table (no CampId — multi camp assign via CampCampbosses)
--      + Create CampCampbosses junction table
--      + CRUD SPs + AppUsers sync
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: Add Campboss role ─────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName='Campboss' AND IsDeleted=0)
BEGIN
    INSERT INTO Roles(RoleCode, RoleName, Status, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(CONCAT('ROL', RIGHT('000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Roles) AS NVARCHAR),3)),
           'Campboss', 'Active', 0, GETUTCDATE(), GETUTCDATE());
    PRINT '✅ Campboss role added to Roles table';
END
ELSE PRINT '⚠️ Campboss role already exists';
GO

-- ── Step 2: Create Campbosses table ──────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='Campbosses')
BEGIN
    CREATE TABLE Campbosses (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        CampbossId  NVARCHAR(50)  NOT NULL DEFAULT '',
        Name        NVARCHAR(MAX) NOT NULL,
        Contact     NVARCHAR(MAX) NULL,
        Email       NVARCHAR(MAX) NULL,
        Address     NVARCHAR(MAX) NULL,
        Username    NVARCHAR(MAX) NULL,
        Password    NVARCHAR(MAX) NULL,
        LoginAccess NVARCHAR(50)  NOT NULL DEFAULT 'enabled',
        Status      NVARCHAR(50)  NOT NULL DEFAULT 'Active',
        Remarks     NVARCHAR(MAX) NULL,
        EmiratesId  NVARCHAR(MAX) NULL,
        PassportNo  NVARCHAR(MAX) NULL,
        Nationality NVARCHAR(MAX) NULL,
        IsDeleted   BIT           NOT NULL DEFAULT 0,
        AddedBy     INT           NULL,
        UpdatedBy   INT           NULL,
        DeletedBy   INT           NULL,
        CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '✅ Campbosses table created';
END
ELSE PRINT '⚠️ Campbosses table already exists';
GO

-- ── Step 3: CampCampbosses junction table (like CampPartners) ─
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='CampCampbosses')
BEGIN
    CREATE TABLE CampCampbosses (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        CampId      INT           NOT NULL REFERENCES Camps(Id) ON DELETE CASCADE,
        CampbossId  INT           NOT NULL REFERENCES Campbosses(Id),
        Type        NVARCHAR(MAX) NOT NULL DEFAULT '',
        Amount      DECIMAL(18,2) NOT NULL DEFAULT 0
    );
    PRINT '✅ CampCampbosses junction table created (with Type + Amount)';
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='Type')
        ALTER TABLE CampCampbosses ADD Type NVARCHAR(MAX) NOT NULL DEFAULT '';
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('CampCampbosses') AND name='Amount')
        ALTER TABLE CampCampbosses ADD Amount DECIMAL(18,2) NOT NULL DEFAULT 0;
    PRINT '⚠️ CampCampbosses table exists — Type/Amount columns added if missing';
END
GO

-- ── Step 4: sp_GetCampbosses ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCampbosses
    @PageNumber    INT           = 1,
    @PageSize      INT           = 2147483647,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC',
    @Status        NVARCHAR(MAX) = NULL,
    @TotalRecords  INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords = COUNT(*) FROM Campbosses cb
    WHERE cb.IsDeleted=0
      AND (@Status IS NULL OR cb.Status=@Status)
      AND (@SearchText IS NULL OR cb.Name LIKE '%'+@SearchText+'%'
           OR cb.Contact LIKE '%'+@SearchText+'%'
           OR cb.EmiratesId LIKE '%'+@SearchText+'%'
           OR cb.CampbossId LIKE '%'+@SearchText+'%');

    SELECT cb.Id, cb.CampbossId, cb.Name, cb.Contact, cb.Email, cb.Address,
        cb.Username, cb.LoginAccess, cb.Status, cb.Remarks,
        cb.EmiratesId, cb.PassportNo, cb.Nationality,
        cb.CreatedAt, cb.UpdatedAt
    FROM Campbosses cb
    WHERE cb.IsDeleted=0
      AND (@Status IS NULL OR cb.Status=@Status)
      AND (@SearchText IS NULL OR cb.Name LIKE '%'+@SearchText+'%'
           OR cb.Contact LIKE '%'+@SearchText+'%'
           OR cb.EmiratesId LIKE '%'+@SearchText+'%'
           OR cb.CampbossId LIKE '%'+@SearchText+'%')
    ORDER BY cb.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT '✅ sp_GetCampbosses created';
GO

-- ── Step 5: sp_GetCampbossById ───────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCampbossById @Id INT
AS BEGIN
    SET NOCOUNT ON;
    SELECT cb.Id, cb.CampbossId, cb.Name, cb.Contact, cb.Email, cb.Address,
        cb.Username, cb.LoginAccess, cb.Status, cb.Remarks,
        cb.EmiratesId, cb.PassportNo, cb.Nationality,
        cb.CreatedAt, cb.UpdatedAt
    FROM Campbosses cb
    WHERE cb.Id=@Id AND cb.IsDeleted=0;
END
GO
PRINT '✅ sp_GetCampbossById created';
GO

-- ── Step 6: sp_CreateCampboss + AppUsers sync ────────────────
CREATE OR ALTER PROCEDURE sp_CreateCampboss
    @Name        NVARCHAR(MAX),
    @Contact     NVARCHAR(MAX) = NULL,
    @Email       NVARCHAR(MAX) = NULL,
    @Address     NVARCHAR(MAX) = NULL,
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = NULL,
    @LoginAccess NVARCHAR(50)  = 'enabled',
    @Status      NVARCHAR(50)  = 'Active',
    @Remarks     NVARCHAR(MAX) = NULL,
    @EmiratesId  NVARCHAR(MAX) = NULL,
    @PassportNo  NVARCHAR(MAX) = NULL,
    @Nationality NVARCHAR(MAX) = NULL,
    @AddedBy     INT           = NULL,
    @NewId       INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Campbosses(CampbossId,Name,Contact,Email,Address,Username,Password,
        LoginAccess,Status,Remarks,EmiratesId,PassportNo,Nationality,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES('',@Name,@Contact,@Email,@Address,@Username,ISNULL(@Password,'Pass@123'),
        @LoginAccess,@Status,@Remarks,@EmiratesId,@PassportNo,@Nationality,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();
    UPDATE Campbosses SET CampbossId=CONCAT('CB-',RIGHT('0000'+CAST(@NewId AS NVARCHAR),4)) WHERE Id=@NewId;

    -- AppUsers sync
    IF @Username IS NOT NULL AND LEN(@Username) > 0
    BEGIN
        DECLARE @UserId NVARCHAR(MAX) = CONCAT('USR-',RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6));
        INSERT INTO AppUsers(UserId,Name,Username,PasswordHash,Role,Source,SourceId,
            Contact,Email,LoginAccess,Status,IsAdmin,MenuAccess,CreatedAt,UpdatedAt)
        VALUES(@UserId,@Name,@Username,ISNULL(@Password,'Pass@123'),'Campboss','Campboss Master',@NewId,
            @Contact,@Email,@LoginAccess,@Status,0,'{}',GETUTCDATE(),GETUTCDATE());
    END
END
GO
PRINT '✅ sp_CreateCampboss created';
GO

-- ── Step 7: sp_UpdateCampboss + AppUsers sync ────────────────
CREATE OR ALTER PROCEDURE sp_UpdateCampboss
    @Id          INT,
    @Name        NVARCHAR(MAX),
    @Contact     NVARCHAR(MAX) = NULL,
    @Email       NVARCHAR(MAX) = NULL,
    @Address     NVARCHAR(MAX) = NULL,
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = NULL,
    @LoginAccess NVARCHAR(50)  = 'enabled',
    @Status      NVARCHAR(50)  = 'Active',
    @Remarks     NVARCHAR(MAX) = NULL,
    @EmiratesId  NVARCHAR(MAX) = NULL,
    @PassportNo  NVARCHAR(MAX) = NULL,
    @Nationality NVARCHAR(MAX) = NULL,
    @UpdatedBy   INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Campbosses SET
        Name=@Name, Contact=@Contact, Email=@Email, Address=@Address,
        Username=ISNULL(@Username, Username), LoginAccess=@LoginAccess,
        Status=@Status, Remarks=@Remarks, EmiratesId=@EmiratesId,
        PassportNo=@PassportNo, Nationality=@Nationality,
        UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE Campbosses SET Password=@Password WHERE Id=@Id;

    -- AppUsers sync
    UPDATE AppUsers SET
        Name=@Name, Contact=@Contact, Email=@Email,
        LoginAccess=@LoginAccess, Status=@Status, UpdatedAt=GETUTCDATE()
    WHERE Source='Campboss Master' AND SourceId=@Id;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE AppUsers SET PasswordHash=@Password WHERE Source='Campboss Master' AND SourceId=@Id;
END
GO
PRINT '✅ sp_UpdateCampboss created';
GO

-- ── Step 8: sp_DeleteCampboss ────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteCampboss @Id INT, @DeletedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Campbosses SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    UPDATE AppUsers SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Source='Campboss Master' AND SourceId=@Id;
    -- CampCampbosses cleanup
    DELETE FROM CampCampbosses WHERE CampbossId=@Id;
END
GO
PRINT '✅ sp_DeleteCampboss created';
GO

PRINT '';
PRINT '✅✅ 146 - Campboss Master complete!';
PRINT '    Camp assign: sp_UpdateCamp mein CampCampbosses handle karo (jaise CampPartners)';
GO
