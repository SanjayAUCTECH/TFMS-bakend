-- ============================================================
-- TFMS AppUsers Seed — matching UI buildUserList() logic
-- Admin@123  hash: $2a$11$1mKOHqPf4pwNpCNt4.1wWOmjhvcBf6Tv2nYHAgJqDciZljaZA3NBq
-- Pass@123   hash: $2a$11$U7jvMDFxQewx/Xaync8AYOEBVwAlxb1n8zV13lpzcUykC686CWlVC
-- ============================================================
USE TFMS_softwareDB;
GO

-- Clear existing users and reset identity
DELETE FROM AppUsers;
DBCC CHECKIDENT('AppUsers', RESEED, 0);
GO

PRINT '>>> Inserting AppUsers...';

-- ── 1. Admin ─────────────────────────────────────────────────────────────────
INSERT INTO AppUsers
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
VALUES
    ('USR-000001','System Administrator','admin',
     '$2a$11$1mKOHqPf4pwNpCNt4.1wWOmjhvcBf6Tv2nYHAgJqDciZljaZA3NBq',
     'Admin','System',NULL,'','admin@tfms.ae',
     1,'enabled','Active','{}',GETUTCDATE(),GETUTCDATE());
GO

-- ── 2-6. Partners → role=Partner, Pass@123 ──────────────────────────────────
INSERT INTO AppUsers
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
SELECT
    'USR-' + RIGHT('000000' + CAST(ROW_NUMBER() OVER(ORDER BY Id) + 1 AS VARCHAR), 6),
    Name,
    LOWER(REPLACE(REPLACE(Name,' ','.'),'-','')) + CAST(Id AS VARCHAR),
    '$2a$11$U7jvMDFxQewx/Xaync8AYOEBVwAlxb1n8zV13lpzcUykC686CWlVC',
    'Partner', 'Partner Master', Id,
    Mobile, Email,
    0,
    CASE WHEN Status='Active' THEN 'enabled' ELSE 'disabled' END,
    Status,
    '{"dashboard":true,"report-partner":true,"report-camp":true,"report-transaction":true,"report-inventory":true}',
    GETUTCDATE(), GETUTCDATE()
FROM Partners;
GO

-- ── 3. Owners → role=Owner, Pass@123 ────────────────────────────────────────
INSERT INTO AppUsers
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
SELECT
    'USR-' + RIGHT('000000' + CAST(
        (SELECT COUNT(*) FROM AppUsers) + ROW_NUMBER() OVER(ORDER BY Id)
    AS VARCHAR), 6),
    Name,
    LOWER(REPLACE(REPLACE(Name,' ','.'),'-','')) + 'o' + CAST(Id AS VARCHAR),
    '$2a$11$U7jvMDFxQewx/Xaync8AYOEBVwAlxb1n8zV13lpzcUykC686CWlVC',
    'Owner', 'Owner Master', Id,
    Contact, Email,
    0,
    CASE WHEN Status='Active' THEN 'enabled' ELSE 'disabled' END,
    Status,
    '{"dashboard":true,"report-owner":true,"report-camp":true,"report-inventory":true}',
    GETUTCDATE(), GETUTCDATE()
FROM Owners;
GO

-- ── 4. Tenants → role=Tenant, Pass@123 ──────────────────────────────────────
INSERT INTO AppUsers
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
SELECT
    'USR-' + RIGHT('000000' + CAST(
        (SELECT COUNT(*) FROM AppUsers) + ROW_NUMBER() OVER(ORDER BY Id)
    AS VARCHAR), 6),
    Name,
    LOWER(
      LEFT(REPLACE(REPLACE(Name,' ','.'),'-',''), 15)
    ) + 't' + CAST(Id AS VARCHAR),
    '$2a$11$U7jvMDFxQewx/Xaync8AYOEBVwAlxb1n8zV13lpzcUykC686CWlVC',
    'Tenant', 'Tenant Master', Id,
    Contact, Email,
    0,
    CASE WHEN Status='Active' THEN 'enabled' ELSE 'disabled' END,
    Status,
    '{"dashboard":true,"report-ledger":true,"report-due":true}',
    GETUTCDATE(), GETUTCDATE()
FROM Tenants;
GO

-- ── 5. OtherPersons → role=Staff, Pass@123 ──────────────────────────────────
INSERT INTO AppUsers
    (UserId, Name, Username, PasswordHash, Role, Source, SourceId,
     Contact, Email, IsAdmin, LoginAccess, Status, MenuAccess, CreatedAt, UpdatedAt)
SELECT
    'USR-' + RIGHT('000000' + CAST(
        (SELECT COUNT(*) FROM AppUsers) + ROW_NUMBER() OVER(ORDER BY Id)
    AS VARCHAR), 6),
    Name,
    LOWER(REPLACE(REPLACE(Name,' ','.'),'-','')) + 's' + CAST(Id AS VARCHAR),
    '$2a$11$U7jvMDFxQewx/Xaync8AYOEBVwAlxb1n8zV13lpzcUykC686CWlVC',
    'Staff', 'Other Person Master', Id,
    Mobile,
    ISNULL(NULLIF(LTRIM(RTRIM(Email)),''), ''),
    0,
    CASE WHEN Status='Active' THEN 'enabled' ELSE 'disabled' END,
    Status,
    '{"dashboard":true,"camps":true,"rooms":true,"tenants":true,"newcontract":true,"viewcontract":true,"contractlist":true,"makepayment":true,"waiver":true,"report-inventory":true,"report-tenant":true,"report-ledger":true,"report-due":true}',
    GETUTCDATE(), GETUTCDATE()
FROM OtherPersons;
GO

-- Fix any duplicate usernames by appending row number
WITH Dupes AS (
    SELECT Id,
           Username,
           ROW_NUMBER() OVER(PARTITION BY Username ORDER BY Id) as rn
    FROM AppUsers
)
UPDATE AppUsers
SET Username = AppUsers.Username + CAST(d.rn AS VARCHAR)
FROM AppUsers
INNER JOIN Dupes d ON d.Id = AppUsers.Id
WHERE d.rn > 1;
GO

-- Fix UserIds to be sequential
WITH Numbered AS (
    SELECT Id, ROW_NUMBER() OVER(ORDER BY Id) as rn
    FROM AppUsers
)
UPDATE AppUsers
SET UserId = 'USR-' + RIGHT('000000' + CAST(n.rn AS VARCHAR), 6)
FROM AppUsers
INNER JOIN Numbered n ON n.Id = AppUsers.Id;
GO

SELECT
    Id, UserId, Name, Username, Role, Source,
    LoginAccess, Status
FROM AppUsers
ORDER BY Id;

SELECT
    'Total Users' = COUNT(*),
    'Admin'       = SUM(CASE WHEN Role='Admin'   THEN 1 ELSE 0 END),
    'Partners'    = SUM(CASE WHEN Role='Partner' THEN 1 ELSE 0 END),
    'Owners'      = SUM(CASE WHEN Role='Owner'   THEN 1 ELSE 0 END),
    'Tenants'     = SUM(CASE WHEN Role='Tenant'  THEN 1 ELSE 0 END),
    'Staff'       = SUM(CASE WHEN Role='Staff'   THEN 1 ELSE 0 END)
FROM AppUsers;
GO

PRINT '>>> Users seeded successfully!';
PRINT '>>> admin / Admin@123';
PRINT '>>> Others / Pass@123';
GO
