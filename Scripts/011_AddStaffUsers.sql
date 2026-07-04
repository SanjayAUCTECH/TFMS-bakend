USE TFMS_softwareDB;
GO

-- Add Staff users from OtherPersons (plain text passwords)
INSERT INTO AppUsers 
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
SELECT
    'USR-' + RIGHT('000000' + CAST(
        (SELECT COUNT(*) FROM AppUsers) + ROW_NUMBER() OVER(ORDER BY Id) AS VARCHAR), 6),
    Name,
    LOWER(REPLACE(REPLACE(LEFT(Name,15),' ','.'),'-','')) + 's' + CAST(Id AS VARCHAR),
    'Pass@123',
    'Staff', 'Other Person Master', Id,
    ISNULL(NULLIF(LTRIM(RTRIM(Mobile)),''), ''),
    ISNULL(NULLIF(LTRIM(RTRIM(Email)),''), ''),
    0,
    CASE WHEN Status='Active' THEN 'enabled' ELSE 'disabled' END,
    Status,
    '{}',
    GETUTCDATE(), GETUTCDATE()
FROM OtherPersons;
GO

-- Fix UserIds to be sequential
WITH N AS (SELECT Id, ROW_NUMBER() OVER(ORDER BY Id) rn FROM AppUsers)
UPDATE AppUsers 
SET UserId = 'USR-' + RIGHT('000000' + CAST(n.rn AS VARCHAR), 6)
FROM AppUsers 
JOIN N n ON n.Id = AppUsers.Id;
GO

-- Show final summary
SELECT 
    COUNT(*) as TotalUsers,
    SUM(CASE WHEN Role='Admin'   THEN 1 ELSE 0 END) as Admin,
    SUM(CASE WHEN Role='Staff'   THEN 1 ELSE 0 END) as Staff,
    SUM(CASE WHEN Role='Partner' THEN 1 ELSE 0 END) as Partner,
    SUM(CASE WHEN Role='Owner'   THEN 1 ELSE 0 END) as Owner,
    SUM(CASE WHEN Role='Tenant'  THEN 1 ELSE 0 END) as Tenant
FROM AppUsers;

SELECT Id, UserId, Name, Username, PasswordHash, Role, Status, LoginAccess 
FROM AppUsers 
ORDER BY Id;
GO
