-- ============================================================
-- 046: Activity Log System
--      Table: ActivityLogs
--      SPs: sp_LogActivity, sp_GetActivityLogs, sp_GetActivityLogById
--           sp_ClearOldLogs
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. ActivityLogs Table ─────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ActivityLogs')
CREATE TABLE ActivityLogs (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    LogId         NVARCHAR(50)   NOT NULL UNIQUE,       -- LOG-000001
    ActivityType  NVARCHAR(50)   NOT NULL,               -- LOGIN, INSERT, UPDATE, DELETE, LOGOUT, ERROR
    Module        NVARCHAR(100)  NOT NULL DEFAULT '',    -- Contracts, Payments, Incomes, etc.
    Action        NVARCHAR(200)  NOT NULL DEFAULT '',    -- "Created Contract CNT-000001"
    EntityId      NVARCHAR(200)  NOT NULL DEFAULT '',    -- Record ID affected (e.g., CNT-000001, 42)
    EntityType    NVARCHAR(100)  NOT NULL DEFAULT '',    -- Contract, Payment, Tenant, Income, etc.
    OldValues     NVARCHAR(MAX)  NULL,                   -- JSON: before update/delete
    NewValues     NVARCHAR(MAX)  NULL,                   -- JSON: after insert/update
    UserId        INT            NULL,                   -- FK to Users (nullable for system)
    UserName      NVARCHAR(200)  NOT NULL DEFAULT '',    -- Name / email of the user
    UserRole      NVARCHAR(100)  NOT NULL DEFAULT '',    -- Admin, Manager, Staff, System
    IpAddress     NVARCHAR(50)   NOT NULL DEFAULT '',    -- Client IP
    UserAgent     NVARCHAR(500)  NOT NULL DEFAULT '',    -- Browser/client info
    Status        NVARCHAR(20)   NOT NULL DEFAULT 'Success', -- Success, Failed, Warning
    ErrorMessage  NVARCHAR(MAX)  NULL,                   -- If Status=Failed
    CreatedAt     DATETIME2      NOT NULL DEFAULT GETDATE()
);
GO

-- Index on common filter columns
CREATE INDEX IF NOT EXISTS IX_ActivityLogs_CreatedAt    ON ActivityLogs (CreatedAt DESC);
GO
CREATE INDEX IF NOT EXISTS IX_ActivityLogs_UserId       ON ActivityLogs (UserId);
GO
CREATE INDEX IF NOT EXISTS IX_ActivityLogs_ActivityType ON ActivityLogs (ActivityType);
GO
CREATE INDEX IF NOT EXISTS IX_ActivityLogs_Module       ON ActivityLogs (Module);
GO

PRINT 'ActivityLogs table created.';
GO

-- ── 2. sp_LogActivity ─────────────────────────────────────────
-- Call this from application to insert a log entry
CREATE OR ALTER PROCEDURE sp_LogActivity
    @ActivityType  NVARCHAR(50),
    @Module        NVARCHAR(100)  = '',
    @Action        NVARCHAR(200)  = '',
    @EntityId      NVARCHAR(200)  = '',
    @EntityType    NVARCHAR(100)  = '',
    @OldValues     NVARCHAR(MAX)  = NULL,
    @NewValues     NVARCHAR(MAX)  = NULL,
    @UserId        INT            = NULL,
    @UserName      NVARCHAR(200)  = '',
    @UserRole      NVARCHAR(100)  = '',
    @IpAddress     NVARCHAR(50)   = '',
    @UserAgent     NVARCHAR(500)  = '',
    @Status        NVARCHAR(20)   = 'Success',
    @ErrorMessage  NVARCHAR(MAX)  = NULL,
    @NewId         INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogId NVARCHAR(50) =
        'LOG-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM ActivityLogs) AS NVARCHAR), 6);

    INSERT INTO ActivityLogs (
        LogId, ActivityType, Module, Action,
        EntityId, EntityType, OldValues, NewValues,
        UserId, UserName, UserRole,
        IpAddress, UserAgent, Status, ErrorMessage,
        CreatedAt
    )
    VALUES (
        @LogId, @ActivityType, @Module, @Action,
        @EntityId, @EntityType, @OldValues, @NewValues,
        @UserId, @UserName, @UserRole,
        @IpAddress, @UserAgent, @Status, @ErrorMessage,
        GETDATE()
    );

    SET @NewId = SCOPE_IDENTITY();
END
GO

-- ── 3. sp_GetActivityLogs ─────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetActivityLogs
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX)  = NULL,
    @ActivityType  NVARCHAR(50)   = NULL,   -- LOGIN / INSERT / UPDATE / DELETE / LOGOUT / ERROR
    @Module        NVARCHAR(100)  = NULL,
    @UserId        INT            = NULL,
    @UserName      NVARCHAR(200)  = NULL,
    @Status        NVARCHAR(20)   = NULL,   -- Success / Failed
    @DateFrom      NVARCHAR(MAX)  = NULL,
    @DateTo        NVARCHAR(MAX)  = NULL,
    @TotalRecords  INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count
    SELECT @TotalRecords = COUNT(*)
    FROM ActivityLogs al
    WHERE (@ActivityType IS NULL OR al.ActivityType = @ActivityType)
      AND (@Module       IS NULL OR al.Module       = @Module)
      AND (@UserId       IS NULL OR al.UserId        = @UserId)
      AND (@UserName     IS NULL OR al.UserName LIKE '%' + @UserName + '%')
      AND (@Status       IS NULL OR al.Status        = @Status)
      AND (@DateFrom     IS NULL OR al.CreatedAt    >= CAST(@DateFrom AS DATETIME2))
      AND (@DateTo       IS NULL OR al.CreatedAt    <= CAST(@DateTo   AS DATETIME2))
      AND (@SearchText   IS NULL
           OR al.Action      LIKE '%' + @SearchText + '%'
           OR al.UserName    LIKE '%' + @SearchText + '%'
           OR al.Module      LIKE '%' + @SearchText + '%'
           OR al.EntityId    LIKE '%' + @SearchText + '%'
           OR al.EntityType  LIKE '%' + @SearchText + '%');

    -- Data
    SELECT
        al.Id,
        al.LogId,
        al.ActivityType,
        al.Module,
        al.Action,
        al.EntityId,
        al.EntityType,
        al.OldValues,
        al.NewValues,
        al.UserId,
        al.UserName,
        al.UserRole,
        al.IpAddress,
        al.UserAgent,
        al.Status,
        al.ErrorMessage,
        al.CreatedAt
    FROM ActivityLogs al
    WHERE (@ActivityType IS NULL OR al.ActivityType = @ActivityType)
      AND (@Module       IS NULL OR al.Module       = @Module)
      AND (@UserId       IS NULL OR al.UserId        = @UserId)
      AND (@UserName     IS NULL OR al.UserName LIKE '%' + @UserName + '%')
      AND (@Status       IS NULL OR al.Status        = @Status)
      AND (@DateFrom     IS NULL OR al.CreatedAt    >= CAST(@DateFrom AS DATETIME2))
      AND (@DateTo       IS NULL OR al.CreatedAt    <= CAST(@DateTo   AS DATETIME2))
      AND (@SearchText   IS NULL
           OR al.Action      LIKE '%' + @SearchText + '%'
           OR al.UserName    LIKE '%' + @SearchText + '%'
           OR al.Module      LIKE '%' + @SearchText + '%'
           OR al.EntityId    LIKE '%' + @SearchText + '%'
           OR al.EntityType  LIKE '%' + @SearchText + '%')
    ORDER BY al.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── 4. sp_GetActivityLogById ──────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetActivityLogById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        al.Id, al.LogId, al.ActivityType, al.Module, al.Action,
        al.EntityId, al.EntityType, al.OldValues, al.NewValues,
        al.UserId, al.UserName, al.UserRole,
        al.IpAddress, al.UserAgent, al.Status, al.ErrorMessage,
        al.CreatedAt
    FROM ActivityLogs al
    WHERE al.Id = @Id;
END
GO

-- ── 5. sp_GetActivitySummary ──────────────────────────────────
-- Dashboard cards: total logs, logins, errors, today's activity
CREATE OR ALTER PROCEDURE sp_GetActivitySummary
    @DateFrom NVARCHAR(MAX) = NULL,
    @DateTo   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*)                                                          TotalLogs,
        SUM(CASE WHEN ActivityType = 'LOGIN'  THEN 1 ELSE 0 END)         TotalLogins,
        SUM(CASE WHEN ActivityType = 'INSERT' THEN 1 ELSE 0 END)         TotalInserts,
        SUM(CASE WHEN ActivityType = 'UPDATE' THEN 1 ELSE 0 END)         TotalUpdates,
        SUM(CASE WHEN ActivityType = 'DELETE' THEN 1 ELSE 0 END)         TotalDeletes,
        SUM(CASE WHEN Status = 'Failed'       THEN 1 ELSE 0 END)         TotalErrors,
        SUM(CASE WHEN CAST(CreatedAt AS DATE) = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END) TodayLogs,
        COUNT(DISTINCT UserId)                                            UniqueUsers
    FROM ActivityLogs
    WHERE (@DateFrom IS NULL OR CreatedAt >= CAST(@DateFrom AS DATETIME2))
      AND (@DateTo   IS NULL OR CreatedAt <= CAST(@DateTo   AS DATETIME2));
END
GO

-- ── 6. sp_ClearOldLogs ───────────────────────────────────────
-- Delete logs older than N days (default 90 days)
CREATE OR ALTER PROCEDURE sp_ClearOldLogs
    @DaysToKeep INT = 90,
    @DeletedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM ActivityLogs
    WHERE CreatedAt < DATEADD(DAY, -@DaysToKeep, GETDATE());
    SET @DeletedCount = @@ROWCOUNT;
END
GO

PRINT '046 - ActivityLog system created: Table + sp_LogActivity + sp_GetActivityLogs + sp_GetActivityLogById + sp_GetActivitySummary + sp_ClearOldLogs';
GO
