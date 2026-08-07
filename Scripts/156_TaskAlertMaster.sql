-- ============================================================
-- 156: Task Alert Master — Table + Stored Procedures
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. CREATE TABLE
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TaskAlertMasters')
BEGIN
    CREATE TABLE [dbo].[TaskAlertMasters] (
        [Id]               INT IDENTITY(1,1) PRIMARY KEY,
        [TaskId]           NVARCHAR(50)   NOT NULL DEFAULT '',
        [TaskDate]         DATE           NOT NULL,
        [TaskTitle]        NVARCHAR(200)  NOT NULL DEFAULT '',
        [TaskDescription]  NVARCHAR(1000) NOT NULL DEFAULT '',
        [TaskStatus]       NVARCHAR(50)   NOT NULL DEFAULT 'Running',
        -- Status: Running | Complete | Partial | Cancel
        [PartialRemark]    NVARCHAR(500)  NOT NULL DEFAULT '',
        [AssignPersonId]   INT            NULL,
        [AssignPersonName] NVARCHAR(200)  NOT NULL DEFAULT '',
        [AddedBy]          INT            NULL,
        [UpdatedBy]        INT            NULL,
        [DeletedBy]        INT            NULL,
        [IsDeleted]        BIT            NOT NULL DEFAULT 0,
        [CreatedAt]        DATETIME       NOT NULL DEFAULT GETDATE(),
        [UpdatedAt]        DATETIME       NOT NULL DEFAULT GETDATE()
    );
    PRINT '✅ TaskAlertMasters table created.';
END
ELSE
    PRINT '⚠️ TaskAlertMasters table already exists.';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_GetTaskAlerts (Paginated list with filters)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetTaskAlerts
    @PageNumber      INT           = 1,
    @PageSize        INT           = 10,
    @SearchText      NVARCHAR(MAX) = NULL,
    @TaskStatus      NVARCHAR(50)  = NULL,
    @AssignPersonId  INT           = NULL,
    @DateFrom        DATE          = NULL,
    @DateTo          DATE          = NULL,
    @TotalRecords    INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM TaskAlertMasters
    WHERE IsDeleted = 0
      AND (@TaskStatus     IS NULL OR TaskStatus     = @TaskStatus)
      AND (@AssignPersonId IS NULL OR AssignPersonId = @AssignPersonId)
      AND (@DateFrom       IS NULL OR TaskDate       >= @DateFrom)
      AND (@DateTo         IS NULL OR TaskDate       <= @DateTo)
      AND (@SearchText     IS NULL OR TaskTitle      LIKE '%'+@SearchText+'%'
                                   OR TaskDescription LIKE '%'+@SearchText+'%'
                                   OR AssignPersonName LIKE '%'+@SearchText+'%');

    SELECT
        Id, TaskId, TaskDate, TaskTitle, TaskDescription, TaskStatus,
        PartialRemark, AssignPersonId, AssignPersonName,
        AddedBy, UpdatedBy, IsDeleted, CreatedAt, UpdatedAt
    FROM TaskAlertMasters
    WHERE IsDeleted = 0
      AND (@TaskStatus     IS NULL OR TaskStatus     = @TaskStatus)
      AND (@AssignPersonId IS NULL OR AssignPersonId = @AssignPersonId)
      AND (@DateFrom       IS NULL OR TaskDate       >= @DateFrom)
      AND (@DateTo         IS NULL OR TaskDate       <= @DateTo)
      AND (@SearchText     IS NULL OR TaskTitle       LIKE '%'+@SearchText+'%'
                                   OR TaskDescription  LIKE '%'+@SearchText+'%'
                                   OR AssignPersonName  LIKE '%'+@SearchText+'%')
    ORDER BY TaskDate DESC, Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ sp_GetTaskAlerts created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_GetActiveTaskAlerts (Alert API)
--    Returns tasks where:
--      - TaskDate <= TODAY (alert started)
--      - Status = 'Running' OR 'Partial' (still active)
--      - Filter by AssignPersonId (optional)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetActiveTaskAlerts
    @AssignPersonId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, TaskId, TaskDate, TaskTitle, TaskDescription, TaskStatus,
        PartialRemark, AssignPersonId, AssignPersonName,
        CreatedAt, UpdatedAt,
        DATEDIFF(DAY, TaskDate, GETDATE()) AS DaysOverdue
    FROM TaskAlertMasters
    WHERE IsDeleted = 0
      AND TaskDate <= CAST(GETDATE() AS DATE)
      AND TaskStatus IN ('Running', 'Partial')
      AND (@AssignPersonId IS NULL OR AssignPersonId = @AssignPersonId)
    ORDER BY TaskDate ASC, Id ASC;
END
GO

PRINT '✅ sp_GetActiveTaskAlerts created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_GetTaskAlertById
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetTaskAlertById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, TaskId, TaskDate, TaskTitle, TaskDescription, TaskStatus,
           PartialRemark, AssignPersonId, AssignPersonName,
           AddedBy, UpdatedBy, IsDeleted, CreatedAt, UpdatedAt
    FROM TaskAlertMasters
    WHERE Id = @Id AND IsDeleted = 0;
END
GO

-- ══════════════════════════════════════════════════════════════
-- 5. sp_CreateTaskAlert
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CreateTaskAlert
    @TaskDate         DATE,
    @TaskTitle        NVARCHAR(200),
    @TaskDescription  NVARCHAR(1000) = '',
    @TaskStatus       NVARCHAR(50)   = 'Running',
    @PartialRemark    NVARCHAR(500)  = '',
    @AssignPersonId   INT            = NULL,
    @AssignPersonName NVARCHAR(200)  = '',
    @AddedBy          INT            = NULL,
    @NewId            INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TaskId NVARCHAR(50) = 'TASK-' + RIGHT('000000' +
        CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TaskAlertMasters) AS NVARCHAR), 6);

    INSERT INTO TaskAlertMasters(
        TaskId, TaskDate, TaskTitle, TaskDescription, TaskStatus,
        PartialRemark, AssignPersonId, AssignPersonName,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @TaskId, @TaskDate, @TaskTitle, @TaskDescription, @TaskStatus,
        @PartialRemark, @AssignPersonId, @AssignPersonName,
        @AddedBy, 0, GETDATE(), GETDATE()
    );
    SET @NewId = SCOPE_IDENTITY();
END
GO

PRINT '✅ sp_CreateTaskAlert created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 6. sp_UpdateTaskAlert
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateTaskAlert
    @Id               INT,
    @TaskDate         DATE,
    @TaskTitle        NVARCHAR(200),
    @TaskDescription  NVARCHAR(1000) = '',
    @TaskStatus       NVARCHAR(50)   = 'Running',
    @PartialRemark    NVARCHAR(500)  = '',
    @AssignPersonId   INT            = NULL,
    @AssignPersonName NVARCHAR(200)  = '',
    @UpdatedBy        INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TaskAlertMasters SET
        TaskDate         = @TaskDate,
        TaskTitle        = @TaskTitle,
        TaskDescription  = @TaskDescription,
        TaskStatus       = @TaskStatus,
        PartialRemark    = @PartialRemark,
        AssignPersonId   = @AssignPersonId,
        AssignPersonName = @AssignPersonName,
        UpdatedBy        = @UpdatedBy,
        UpdatedAt        = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END
GO

PRINT '✅ sp_UpdateTaskAlert created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 7. sp_DeleteTaskAlert (Soft Delete)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_DeleteTaskAlert
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TaskAlertMasters
    SET IsDeleted = 1, DeletedBy = @DeletedBy, UpdatedAt = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END
GO

PRINT '✅ sp_DeleteTaskAlert created.';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 156 - Task Alert Master Complete!';
PRINT '   Table: TaskAlertMasters';
PRINT '   Status values: Running | Complete | Partial | Cancel';
PRINT '   SPs: GetAll, GetById, GetActiveAlerts, Create, Update, Delete';
PRINT '═══════════════════════════════════════════════════════════';
GO
