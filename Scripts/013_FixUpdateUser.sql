USE TFMS_softwareDB;
GO

-- Fix sp_UpdateUser:
-- 1. Remove SET NOCOUNT ON (so affected rows return correctly)
-- 2. Preserve Source if empty/null passed (prevent accidental blank)
-- 3. Preserve LoginAccess if empty/null passed

CREATE OR ALTER PROCEDURE sp_UpdateUser
    @Id          INT,
    @Name        NVARCHAR(MAX),
    @Role        NVARCHAR(MAX),
    @Source      NVARCHAR(MAX)      = '',
    @SourceId    INT               = NULL,
    @Contact     NVARCHAR(MAX)      = '',
    @Email       NVARCHAR(MAX)     = '',
    @IsAdmin     BIT               = 0,
    @LoginAccess NVARCHAR(MAX)      = 'enabled',
    @Status      NVARCHAR(MAX)      = 'Active',
    @MenuAccess  NVARCHAR(MAX)     = '{}'
AS
BEGIN
    UPDATE AppUsers SET
        Name        = @Name,
        Role        = @Role,
        -- Preserve existing Source if blank passed
        Source      = CASE WHEN ISNULL(LTRIM(RTRIM(@Source)),'') = '' THEN Source ELSE @Source END,
        -- Preserve existing SourceId if null
        SourceId    = CASE WHEN @SourceId IS NULL THEN SourceId ELSE @SourceId END,
        Contact     = @Contact,
        Email       = @Email,
        IsAdmin     = @IsAdmin,
        -- Preserve existing LoginAccess if blank passed
        LoginAccess = CASE WHEN ISNULL(LTRIM(RTRIM(@LoginAccess)),'') = '' THEN LoginAccess ELSE @LoginAccess END,
        Status      = @Status,
        MenuAccess  = CASE WHEN ISNULL(@MenuAccess,'{}') = '{}' THEN MenuAccess ELSE @MenuAccess END,
        UpdatedAt   = GETUTCDATE()
    WHERE Id = @Id;
END
GO

-- Restore Source for users that got blanked out
UPDATE AppUsers SET Source = 'Partner Master'      WHERE Role = 'Partner'        AND ISNULL(Source,'') = '';
UPDATE AppUsers SET Source = 'Owner Master'        WHERE Role = 'Owner'          AND ISNULL(Source,'') = '';
UPDATE AppUsers SET Source = 'Tenant Master'       WHERE Role = 'Tenant'         AND ISNULL(Source,'') = '';
UPDATE AppUsers SET Source = 'Other Person Master' WHERE Role = 'Staff'          AND ISNULL(Source,'') = '';
UPDATE AppUsers SET Source = 'System'              WHERE Role = 'Admin'          AND ISNULL(Source,'') = '';
GO

SELECT Id, Username, Role, Source, LoginAccess FROM AppUsers ORDER BY Id;
PRINT 'sp_UpdateUser fixed and Source restored!';
GO
