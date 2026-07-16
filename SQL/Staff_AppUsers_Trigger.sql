-- ============================================================
-- Trigger: Staff INSERT  → AppUsers INSERT
-- Trigger: Staff UPDATE  → AppUsers UPDATE
-- Username format: TFMS00001 (TFMS + 5 digit zero-padded)
-- ============================================================

-- ── DROP old triggers if exist ────────────────────────────────────────────────
IF OBJECT_ID('trg_Staff_Insert_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Staff_Insert_AppUsers;
GO

IF OBJECT_ID('trg_Staff_Update_AppUsers', 'TR') IS NOT NULL
    DROP TRIGGER trg_Staff_Update_AppUsers;
GO

-- ── INSERT TRIGGER ────────────────────────────────────────────────────────────
CREATE TRIGGER trg_Staff_Insert_AppUsers
ON Staff
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AppUsers (
        UserId,
        Name,
        Username,
        PasswordHash,
        Role,
        Source,
        SourceId,
        Contact,
        Email,
        LoginAccess,
        Status,
        MenuAccess,
        IsAdmin,
        CreatedAt,
        UpdatedAt
    )
    SELECT
        -- UserId: TFMS + 5-digit zero-padded Id  e.g. TFMS00001
        'TFMS' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),

        -- Name
        i.Name,

        -- Username: same as UserId
        'TFMS' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),

        -- PasswordHash: use staff password as-is (plain or hashed)
        ISNULL(NULLIF(i.Password, ''), 'Pass@123'),

        -- Role
        'Staff',

        -- Source
        'Staff Master',

        -- SourceId (Staff.Id)
        i.Id,

        -- Contact
        ISNULL(i.Contact, ''),

        -- Email
        ISNULL(i.Email, ''),

        -- LoginAccess
        ISNULL(i.LoginAccess, 'enabled'),

        -- Status
        ISNULL(i.Status, 'Active'),

        -- MenuAccess (default empty JSON or empty string)
        '[]',

        -- IsAdmin
        0,

        -- Timestamps
        GETDATE(),
        GETDATE()

    FROM inserted i
    -- Only insert if not already exists for this SourceId
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Staff Master' AND SourceId = i.Id
    );
END
GO

-- ── UPDATE TRIGGER ────────────────────────────────────────────────────────────
CREATE TRIGGER trg_Staff_Update_AppUsers
ON Staff
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Update existing AppUsers record linked to this staff
    UPDATE au
    SET
        au.Name        = i.Name,
        au.Contact     = ISNULL(i.Contact, ''),
        au.Email       = ISNULL(i.Email, ''),
        au.LoginAccess = ISNULL(i.LoginAccess, 'enabled'),
        au.Status      = ISNULL(i.Status, 'Active'),
        -- Only update password if it changed and is not empty
        au.PasswordHash = CASE
                            WHEN ISNULL(i.Password, '') <> '' AND i.Password <> d.Password
                            THEN i.Password
                            ELSE au.PasswordHash
                          END,
        au.UpdatedAt   = GETDATE()
    FROM AppUsers au
    INNER JOIN inserted i  ON au.SourceId = i.Id AND au.Source = 'Staff Master'
    INNER JOIN deleted  d  ON d.Id = i.Id;

    -- If somehow no AppUsers record exists yet, insert it (safety net)
    INSERT INTO AppUsers (
        UserId, Name, Username, PasswordHash, Role,
        Source, SourceId, Contact, Email,
        LoginAccess, Status, MenuAccess, IsAdmin,
        CreatedAt, UpdatedAt
    )
    SELECT
        'TFMS' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        i.Name,
        'TFMS' + RIGHT('00000' + CAST(i.Id AS NVARCHAR(10)), 5),
        ISNULL(NULLIF(i.Password, ''), 'Pass@123'),
        'Staff',
        'Staff Master',
        i.Id,
        ISNULL(i.Contact, ''),
        ISNULL(i.Email, ''),
        ISNULL(i.LoginAccess, 'enabled'),
        ISNULL(i.Status, 'Active'),
        '[]',
        0,
        GETDATE(),
        GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM AppUsers
        WHERE Source = 'Staff Master' AND SourceId = i.Id
    );
END
GO

PRINT 'Triggers created successfully: trg_Staff_Insert_AppUsers, trg_Staff_Update_AppUsers';
GO
