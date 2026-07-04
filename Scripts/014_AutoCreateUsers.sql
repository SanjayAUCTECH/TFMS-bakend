-- ============================================================
-- TFMS — Auto-create AppUser when Master record is inserted
-- Tables: Partners, Owners, OtherPersons, Tenants
-- Password: Pass@123 (plain text as per system design)
-- ============================================================
USE TFMS_softwareDB;
GO

-- ── Helper Function: Clean username from name ─────────────────────────────────
CREATE OR ALTER FUNCTION fn_MakeUsername(@Name NVARCHAR(200), @Id INT, @Suffix CHAR(1))
RETURNS NVARCHAR(50)
AS BEGIN
    DECLARE @base NVARCHAR(50);
    -- lowercase, replace spaces with dots, remove non-alpha-dot chars, max 18 chars
    SET @base = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        LEFT(@Name, 20),
        ' ', '.'), '-', ''), '''', ''), '/', ''), '(', ''), ')', ''));
    SET @base = LEFT(@base, 18) + @Suffix + CAST(@Id AS NVARCHAR(6));
    RETURN @base;
END
GO

-- ── Helper Function: Next UserId ──────────────────────────────────────────────
CREATE OR ALTER FUNCTION fn_NextUserId()
RETURNS NVARCHAR(20)
AS BEGIN
    DECLARE @next INT;
    SELECT @next = ISNULL(MAX(CAST(RIGHT(UserId, 6) AS INT)), 0) + 1
    FROM AppUsers
    WHERE UserId LIKE 'USR-%';
    RETURN 'USR-' + RIGHT('000000' + CAST(@next AS NVARCHAR), 6);
END
GO

-- ══════════════════════════════════════════════════════════════
-- TRIGGER: Partners → Auto-create Partner user
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER TRIGGER trg_Partners_AfterInsert
ON Partners
AFTER INSERT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO AppUsers
        (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
         Contact, Email, IsAdmin, LoginAccess, Status,
         MenuAccess, CreatedAt, UpdatedAt)
    SELECT
        dbo.fn_NextUserId(),
        i.Name,
        dbo.fn_MakeUsername(i.Name, i.Id, 'p'),
        'Pass@123',
        'Partner',
        'Partner Master',
        i.Id,
        ISNULL(i.Mobile, ''),
        ISNULL(i.Email,  ''),
        0,
        CASE WHEN i.Status = 'Active' THEN 'enabled' ELSE 'disabled' END,
        i.Status,
        '{"dashboard":true,"report-partner":true,"report-camp":true,"report-transaction":true,"report-inventory":true}',
        GETUTCDATE(),
        GETUTCDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers WHERE Source = 'Partner Master' AND SourceId = i.Id
    );
END
GO

-- ══════════════════════════════════════════════════════════════
-- TRIGGER: Owners → Auto-create Owner user
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER TRIGGER trg_Owners_AfterInsert
ON Owners
AFTER INSERT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO AppUsers
        (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
         Contact, Email, IsAdmin, LoginAccess, Status,
         MenuAccess, CreatedAt, UpdatedAt)
    SELECT
        dbo.fn_NextUserId(),
        i.Name,
        dbo.fn_MakeUsername(i.Name, i.Id, 'o'),
        'Pass@123',
        'Owner',
        'Owner Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email,   ''),
        0,
        CASE WHEN i.Status = 'Active' THEN 'enabled' ELSE 'disabled' END,
        i.Status,
        '{"dashboard":true,"report-owner":true,"report-camp":true,"report-inventory":true}',
        GETUTCDATE(),
        GETUTCDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers WHERE Source = 'Owner Master' AND SourceId = i.Id
    );
END
GO

-- ══════════════════════════════════════════════════════════════
-- TRIGGER: OtherPersons → Auto-create Staff user
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER TRIGGER trg_OtherPersons_AfterInsert
ON OtherPersons
AFTER INSERT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO AppUsers
        (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
         Contact, Email, IsAdmin, LoginAccess, Status,
         MenuAccess, CreatedAt, UpdatedAt)
    SELECT
        dbo.fn_NextUserId(),
        i.Name,
        dbo.fn_MakeUsername(i.Name, i.Id, 's'),
        'Pass@123',
        'Other Accounts',
        'Other Person Master',
        i.Id,
        ISNULL(i.Mobile, ''),
        ISNULL(NULLIF(LTRIM(RTRIM(i.Email)),''), ''),
        0,
        CASE WHEN i.Status = 'Active' THEN 'enabled' ELSE 'disabled' END,
        i.Status,
        '{"dashboard":true,"income":true,"expense":true,"report-transaction":true,"mis-dashboard":true}',
        GETUTCDATE(),
        GETUTCDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers WHERE Source = 'Other Person Master' AND SourceId = i.Id
    );
END
GO

-- ══════════════════════════════════════════════════════════════
-- TRIGGER: Tenants → Auto-create Tenant user
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER TRIGGER trg_Tenants_AfterInsert
ON Tenants
AFTER INSERT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO AppUsers
        (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
         Contact, Email, IsAdmin, LoginAccess, Status,
         MenuAccess, CreatedAt, UpdatedAt)
    SELECT
        dbo.fn_NextUserId(),
        i.Name,
        dbo.fn_MakeUsername(i.Name, i.Id, 't'),
        'Pass@123',
        'Tenant',
        'Tenant Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(NULLIF(LTRIM(RTRIM(i.Email)),''), ''),
        0,
        CASE WHEN i.Status = 'Active' THEN 'enabled' ELSE 'disabled' END,
        i.Status,
        '{"dashboard":true,"report-ledger":true,"report-due":true}',
        GETUTCDATE(),
        GETUTCDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers WHERE Source = 'Tenant Master' AND SourceId = i.Id
    );
END
GO

-- ══════════════════════════════════════════════════════════════
-- SYNC: Fix any duplicate usernames after triggers
-- ══════════════════════════════════════════════════════════════
WITH Dupes AS (
    SELECT Id,
           ROW_NUMBER() OVER(PARTITION BY Username ORDER BY Id) AS rn
    FROM AppUsers
)
UPDATE AppUsers
SET Username = AppUsers.Username + CAST(d.rn AS VARCHAR)
FROM AppUsers
INNER JOIN Dupes d ON d.Id = AppUsers.Id
WHERE d.rn > 1;
GO

-- ══════════════════════════════════════════════════════════════
-- VERIFY: Show all triggers created
-- ══════════════════════════════════════════════════════════════
SELECT name, parent_class_desc, type_desc
FROM sys.triggers
WHERE name LIKE 'trg_%'
ORDER BY name;

SELECT COUNT(*) as TotalUsers FROM AppUsers;
PRINT 'Auto-user triggers created successfully!';
PRINT 'New Partner/Owner/OtherPerson/Tenant = Auto UserId + Pass@123';
GO
