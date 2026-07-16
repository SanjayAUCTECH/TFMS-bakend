-- ============================================================
-- Triggers for Tenants, Owners, OtherPersons, Partners
-- On INSERT/UPDATE → Auto-create/update AppUsers record
-- Same pattern as Staff_AppUsers_Trigger.sql
-- ============================================================

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  TENANTS → AppUsers                                         ║
-- ║  Username format: TNT00001 (TNT + 5 digit zero-padded)      ║
-- ╚══════════════════════════════════════════════════════════════╝

IF OBJECT_ID('trg_Tenants_Insert_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Tenants_Insert_AppUsers;
GO

IF OBJECT_ID('trg_Tenants_Update_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Tenants_Update_AppUsers;
GO

CREATE TRIGGER trg_Tenants_Insert_AppUsers
ON Tenants
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'TNT' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'TNT' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Tenant',
        'Tenant Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Tenant Master' AND SourceId = i.Id
    );
END
GO

CREATE TRIGGER trg_Tenants_Update_AppUsers
ON Tenants
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE au
    SET
        au.Name        = i.Name,
        au.Contact     = ISNULL(i.Contact, ''),
        au.Email       = ISNULL(i.Email, ''),
        au.Status      = ISNULL(i.Status, 'Active'),
        au.UpdatedAt   = GETDATE()
    FROM AppUsers au
    INNER JOIN inserted i ON au.SourceId = i.Id AND au.Source = 'Tenant Master';

    -- Safety net: insert if not exists
    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'TNT' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'TNT' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Tenant',
        'Tenant Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Tenant Master' AND SourceId = i.Id
    );
END
GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  OWNERS → AppUsers                                          ║
-- ║  Username format: OWN00001 (OWN + 5 digit zero-padded)      ║
-- ╚══════════════════════════════════════════════════════════════╝

IF OBJECT_ID('trg_Owners_Insert_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Owners_Insert_AppUsers;
GO

IF OBJECT_ID('trg_Owners_Update_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Owners_Update_AppUsers;
GO

CREATE TRIGGER trg_Owners_Insert_AppUsers
ON Owners
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'OWN' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'OWN' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Owner',
        'Owner Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Owner Master' AND SourceId = i.Id
    );
END
GO

CREATE TRIGGER trg_Owners_Update_AppUsers
ON Owners
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE au
    SET
        au.Name        = i.Name,
        au.Contact     = ISNULL(i.Contact, ''),
        au.Email       = ISNULL(i.Email, ''),
        au.Status      = ISNULL(i.Status, 'Active'),
        au.UpdatedAt   = GETDATE()
    FROM AppUsers au
    INNER JOIN inserted i ON au.SourceId = i.Id AND au.Source = 'Owner Master';

    -- Safety net: insert if not exists
    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'OWN' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'OWN' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Owner',
        'Owner Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Owner Master' AND SourceId = i.Id
    );
END
GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  OTHERPERSONS → AppUsers                                    ║
-- ║  Username format: OTP00001 (OTP + 5 digit zero-padded)      ║
-- ╚══════════════════════════════════════════════════════════════╝

IF OBJECT_ID('trg_OtherPersons_Insert_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_OtherPersons_Insert_AppUsers;
GO

IF OBJECT_ID('trg_OtherPersons_Update_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_OtherPersons_Update_AppUsers;
GO

CREATE TRIGGER trg_OtherPersons_Insert_AppUsers
ON OtherPersons
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'OTP' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'OTP' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Other Person',
        'OtherPerson Master',
        i.Id,
        ISNULL(i.Mobile, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'OtherPerson Master' AND SourceId = i.Id
    );
END
GO

CREATE TRIGGER trg_OtherPersons_Update_AppUsers
ON OtherPersons
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE au
    SET
        au.Name        = i.Name,
        au.Contact     = ISNULL(i.Mobile, ''),
        au.Email       = ISNULL(i.Email, ''),
        au.Status      = ISNULL(i.Status, 'Active'),
        au.UpdatedAt   = GETDATE()
    FROM AppUsers au
    INNER JOIN inserted i ON au.SourceId = i.Id AND au.Source = 'OtherPerson Master';

    -- Safety net: insert if not exists
    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'OTP' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'OTP' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Other Person',
        'OtherPerson Master',
        i.Id,
        ISNULL(i.Mobile, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'OtherPerson Master' AND SourceId = i.Id
    );
END
GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  PARTNERS → AppUsers                                        ║
-- ║  Username format: PTR00001 (PTR + 5 digit zero-padded)      ║
-- ╚══════════════════════════════════════════════════════════════╝

IF OBJECT_ID('trg_Partners_Insert_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Partners_Insert_AppUsers;
GO

IF OBJECT_ID('trg_Partners_Update_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Partners_Update_AppUsers;
GO

CREATE TRIGGER trg_Partners_Insert_AppUsers
ON Partners
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'PTR' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'PTR' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Partner',
        'Partner Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Partner Master' AND SourceId = i.Id
    );
END
GO

CREATE TRIGGER trg_Partners_Update_AppUsers
ON Partners
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE au
    SET
        au.Name        = i.Name,
        au.Contact     = ISNULL(i.Contact, ''),
        au.Email       = ISNULL(i.Email, ''),
        au.Status      = ISNULL(i.Status, 'Active'),
        au.UpdatedAt   = GETDATE()
    FROM AppUsers au
    INNER JOIN inserted i ON au.SourceId = i.Id AND au.Source = 'Partner Master';

    -- Safety net: insert if not exists
    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'PTR' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'PTR' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        'Pass@123',
        'Partner',
        'Partner Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        'enabled',
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Partner Master' AND SourceId = i.Id
    );
END
GO

PRINT 'All triggers created successfully:';
PRINT '  - trg_Tenants_Insert_AppUsers, trg_Tenants_Update_AppUsers';
PRINT '  - trg_Owners_Insert_AppUsers, trg_Owners_Update_AppUsers';
PRINT '  - trg_OtherPersons_Insert_AppUsers, trg_OtherPersons_Update_AppUsers';
PRINT '  - trg_Partners_Insert_AppUsers, trg_Partners_Update_AppUsers';
GO
