-- ============================================================
-- SALON DAILY COLLECTION (SDCollection + SDExpence) Setup
-- ============================================================

-- -----------------------------------------------
-- 1. SDCollection TABLE
-- -----------------------------------------------
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SDCollection' AND xtype='U')
BEGIN
    CREATE TABLE SDCollection (
        CollectionId  INT IDENTITY(1,1) PRIMARY KEY,
        Date          DATE            NOT NULL,
        SalonId       INT             NOT NULL,
        StaffId       INT             NOT NULL,
        HeadId        INT             NULL,        -- SalonHeadMaster FK
        Mode          NVARCHAR(50)    NOT NULL DEFAULT 'Cash',
        Amount        DECIMAL(18,2)   NOT NULL DEFAULT 0,
        Description   NVARCHAR(500)   NULL,
        Status        NVARCHAR(20)    NOT NULL DEFAULT 'Active',
        IsDeleted     BIT             NOT NULL DEFAULT 0,
        AddedBy       NVARCHAR(100)   NULL,
        UpdatedBy     NVARCHAR(100)   NULL,
        CreatedAt     DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt     DATETIME        NULL
    );
END;
GO

-- -----------------------------------------------
-- 2. SDExpence TABLE
-- -----------------------------------------------
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SDExpence' AND xtype='U')
BEGIN
    CREATE TABLE SDExpence (
        ExpenceId     INT IDENTITY(1,1) PRIMARY KEY,
        Date          DATE            NOT NULL,
        SalonId       INT             NOT NULL,
        HeadId        INT             NULL,        -- SalonHeadMaster FK
        ExpenceType   NVARCHAR(50)    NOT NULL DEFAULT 'DC Expense', -- DC Expense | CO Expense
        RecipientName NVARCHAR(150)   NULL,
        Mode          NVARCHAR(50)    NOT NULL DEFAULT 'Cash',
        Amount        DECIMAL(18,2)   NOT NULL DEFAULT 0,
        Description   NVARCHAR(500)   NULL,
        Status        NVARCHAR(20)    NOT NULL DEFAULT 'Active',
        IsDeleted     BIT             NOT NULL DEFAULT 0,
        AddedBy       NVARCHAR(100)   NULL,
        UpdatedBy     NVARCHAR(100)   NULL,
        CreatedAt     DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt     DATETIME        NULL
    );
END;
GO

-- ============================================================
-- SDCollection STORED PROCEDURES
-- ============================================================

-- ── GET ALL (paginated + filters) ─────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSDCollection
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @SearchText   NVARCHAR(200) = NULL,
    @SalonId      INT           = NULL,
    @StaffId      INT           = NULL,
    @DateFrom     DATE          = NULL,
    @DateTo       DATE          = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT @TotalRecords = COUNT(*)
    FROM   SDCollection  c
    JOIN   SalonMaster   sm ON sm.Id      = c.SalonId  AND sm.IsDeleted = 0
    JOIN   Staff         st ON st.StaffId = c.StaffId  AND st.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = c.HeadId   AND hm.IsDeleted = 0
    WHERE  c.IsDeleted = 0
      AND  (@SalonId    IS NULL OR c.SalonId = @SalonId)
      AND  (@StaffId    IS NULL OR c.StaffId = @StaffId)
      AND  (@Status     IS NULL OR c.Status  = @Status)
      AND  (@DateFrom   IS NULL OR c.Date   >= @DateFrom)
      AND  (@DateTo     IS NULL OR c.Date   <= @DateTo)
      AND  (@SearchText IS NULL
            OR sm.Name LIKE '%'+@SearchText+'%'
            OR st.Name LIKE '%'+@SearchText+'%');

    SELECT
        c.CollectionId,
        c.Date,
        c.SalonId,
        sm.Name        AS SalonName,
        c.StaffId,
        st.Name        AS StaffName,
        c.HeadId,
        hm.HeadName    AS HeadName,
        c.Mode,
        c.Amount,
        c.Description,
        c.Status,
        c.CreatedAt,
        c.UpdatedAt
    FROM   SDCollection  c
    JOIN   SalonMaster   sm ON sm.Id      = c.SalonId  AND sm.IsDeleted = 0
    JOIN   Staff         st ON st.StaffId = c.StaffId  AND st.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = c.HeadId   AND hm.IsDeleted = 0
    WHERE  c.IsDeleted = 0
      AND  (@SalonId    IS NULL OR c.SalonId = @SalonId)
      AND  (@StaffId    IS NULL OR c.StaffId = @StaffId)
      AND  (@Status     IS NULL OR c.Status  = @Status)
      AND  (@DateFrom   IS NULL OR c.Date   >= @DateFrom)
      AND  (@DateTo     IS NULL OR c.Date   <= @DateTo)
      AND  (@SearchText IS NULL
            OR sm.Name LIKE '%'+@SearchText+'%'
            OR st.Name LIKE '%'+@SearchText+'%')
    ORDER BY c.Date DESC, c.CreatedAt DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ── GET BY ID ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSDCollectionById
    @CollectionId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.CollectionId, c.Date,
        c.SalonId,  sm.Name  AS SalonName,
        c.StaffId,  st.Name  AS StaffName,
        c.HeadId,   hm.HeadName AS HeadName,
        c.Mode, c.Amount, c.Description, c.Status, c.CreatedAt, c.UpdatedAt
    FROM   SDCollection  c
    JOIN   SalonMaster   sm ON sm.Id      = c.SalonId  AND sm.IsDeleted = 0
    JOIN   Staff         st ON st.StaffId = c.StaffId  AND st.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = c.HeadId   AND hm.IsDeleted = 0
    WHERE  c.CollectionId = @CollectionId AND c.IsDeleted = 0;
END;
GO

-- ── BULK INSERT (JSON array) ──────────────────────────────────
CREATE OR ALTER PROCEDURE sp_BulkCreateSDCollection
    @CollectionsJson NVARCHAR(MAX),   -- JSON array
    @AddedBy         NVARCHAR(100) = NULL,
    @InsertedCount   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO SDCollection
        (Date, SalonId, StaffId, HeadId, Mode, Amount, Description, Status, AddedBy, CreatedAt)
    SELECT
        TRY_CAST(j.Date   AS DATE),
        j.SalonId,
        j.StaffId,
        j.HeadId,
        ISNULL(j.Mode,   'Cash'),
        ISNULL(j.Amount,  0),
        j.Description,
        ISNULL(j.Status, 'Active'),
        @AddedBy,
        GETDATE()
    FROM OPENJSON(@CollectionsJson)
    WITH (
        Date          NVARCHAR(20)  '$.date',
        SalonId       INT           '$.salonId',
        StaffId       INT           '$.staffId',
        HeadId        INT           '$.headId',
        Mode          NVARCHAR(50)  '$.mode',
        Amount        DECIMAL(18,2) '$.amount',
        Description   NVARCHAR(500) '$.description',
        Status        NVARCHAR(20)  '$.status'
    ) j;

    SET @InsertedCount = @@ROWCOUNT;
END;
GO

-- ── UPDATE ────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateSDCollection
    @CollectionId INT,
    @Date         DATE,
    @SalonId      INT,
    @StaffId      INT,
    @HeadId       INT           = NULL,
    @Mode         NVARCHAR(50),
    @Amount       DECIMAL(18,2),
    @Description  NVARCHAR(500) = NULL,
    @Status       NVARCHAR(20),
    @UpdatedBy    NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SDCollection
    SET Date = @Date, SalonId = @SalonId, StaffId = @StaffId,
        HeadId = @HeadId, Mode = @Mode, Amount = @Amount,
        Description = @Description, Status = @Status,
        UpdatedBy = @UpdatedBy, UpdatedAt = GETDATE()
    WHERE CollectionId = @CollectionId AND IsDeleted = 0;
END;
GO

-- ── SOFT DELETE ───────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteSDCollection
    @CollectionId INT,
    @DeletedBy    NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SDCollection
    SET IsDeleted = 1, UpdatedBy = @DeletedBy, UpdatedAt = GETDATE()
    WHERE CollectionId = @CollectionId;
END;
GO

-- ============================================================
-- SDExpence STORED PROCEDURES
-- ============================================================

-- ── GET ALL (paginated + filters) ─────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSDExpence
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @SearchText   NVARCHAR(200) = NULL,
    @SalonId      INT           = NULL,
    @ExpenceType  NVARCHAR(50)  = NULL,
    @DateFrom     DATE          = NULL,
    @DateTo       DATE          = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT @TotalRecords = COUNT(*)
    FROM   SDExpence     e
    JOIN   SalonMaster   sm ON sm.Id  = e.SalonId AND sm.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = e.HeadId AND hm.IsDeleted = 0
    WHERE  e.IsDeleted = 0
      AND  (@SalonId     IS NULL OR e.SalonId    = @SalonId)
      AND  (@ExpenceType IS NULL OR e.ExpenceType= @ExpenceType)
      AND  (@Status      IS NULL OR e.Status     = @Status)
      AND  (@DateFrom    IS NULL OR e.Date       >= @DateFrom)
      AND  (@DateTo      IS NULL OR e.Date       <= @DateTo)
      AND  (@SearchText  IS NULL
            OR sm.Name          LIKE '%'+@SearchText+'%'
            OR e.RecipientName  LIKE '%'+@SearchText+'%');

    SELECT
        e.ExpenceId,
        e.Date,
        e.SalonId,    sm.Name    AS SalonName,
        e.HeadId,     hm.HeadName AS HeadName,
        e.ExpenceType,
        e.RecipientName,
        e.Mode,
        e.Amount,
        e.Description,
        e.Status,
        e.CreatedAt,
        e.UpdatedAt
    FROM   SDExpence     e
    JOIN   SalonMaster   sm ON sm.Id  = e.SalonId AND sm.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = e.HeadId AND hm.IsDeleted = 0
    WHERE  e.IsDeleted = 0
      AND  (@SalonId     IS NULL OR e.SalonId    = @SalonId)
      AND  (@ExpenceType IS NULL OR e.ExpenceType= @ExpenceType)
      AND  (@Status      IS NULL OR e.Status     = @Status)
      AND  (@DateFrom    IS NULL OR e.Date       >= @DateFrom)
      AND  (@DateTo      IS NULL OR e.Date       <= @DateTo)
      AND  (@SearchText  IS NULL
            OR sm.Name          LIKE '%'+@SearchText+'%'
            OR e.RecipientName  LIKE '%'+@SearchText+'%')
    ORDER BY e.Date DESC, e.CreatedAt DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ── GET BY ID ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSDExpenceById
    @ExpenceId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.ExpenceId, e.Date,
        e.SalonId,  sm.Name    AS SalonName,
        e.HeadId,   hm.HeadName AS HeadName,
        e.ExpenceType, e.RecipientName,
        e.Mode, e.Amount, e.Description, e.Status, e.CreatedAt, e.UpdatedAt
    FROM   SDExpence     e
    JOIN   SalonMaster   sm ON sm.Id  = e.SalonId AND sm.IsDeleted = 0
    LEFT JOIN SalonHeadMaster hm ON hm.Id = e.HeadId AND hm.IsDeleted = 0
    WHERE  e.ExpenceId = @ExpenceId AND e.IsDeleted = 0;
END;
GO

-- ── BULK INSERT (JSON array) ──────────────────────────────────
CREATE OR ALTER PROCEDURE sp_BulkCreateSDExpence
    @ExpencesJson  NVARCHAR(MAX),
    @AddedBy       NVARCHAR(100) = NULL,
    @InsertedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO SDExpence
        (Date, SalonId, HeadId, ExpenceType, RecipientName, Mode, Amount, Description, Status, AddedBy, CreatedAt)
    SELECT
        TRY_CAST(j.Date AS DATE),
        j.SalonId,
        j.HeadId,
        ISNULL(j.ExpenceType, 'DC Expense'),
        j.RecipientName,
        ISNULL(j.Mode,   'Cash'),
        ISNULL(j.Amount,  0),
        j.Description,
        ISNULL(j.Status, 'Active'),
        @AddedBy,
        GETDATE()
    FROM OPENJSON(@ExpencesJson)
    WITH (
        Date          NVARCHAR(20)  '$.date',
        SalonId       INT           '$.salonId',
        HeadId        INT           '$.headId',
        ExpenceType   NVARCHAR(50)  '$.expenceType',
        RecipientName NVARCHAR(150) '$.recipientName',
        Mode          NVARCHAR(50)  '$.mode',
        Amount        DECIMAL(18,2) '$.amount',
        Description   NVARCHAR(500) '$.description',
        Status        NVARCHAR(20)  '$.status'
    ) j;

    SET @InsertedCount = @@ROWCOUNT;
END;
GO

-- ── UPDATE ────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateSDExpence
    @ExpenceId     INT,
    @Date          DATE,
    @SalonId       INT,
    @HeadId        INT           = NULL,
    @ExpenceType   NVARCHAR(50),
    @RecipientName NVARCHAR(150) = NULL,
    @Mode          NVARCHAR(50),
    @Amount        DECIMAL(18,2),
    @Description   NVARCHAR(500) = NULL,
    @Status        NVARCHAR(20),
    @UpdatedBy     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SDExpence
    SET Date = @Date, SalonId = @SalonId, HeadId = @HeadId,
        ExpenceType = @ExpenceType, RecipientName = @RecipientName,
        Mode = @Mode, Amount = @Amount, Description = @Description,
        Status = @Status, UpdatedBy = @UpdatedBy, UpdatedAt = GETDATE()
    WHERE ExpenceId = @ExpenceId AND IsDeleted = 0;
END;
GO

-- ── SOFT DELETE ───────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteSDExpence
    @ExpenceId INT,
    @DeletedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SDExpence
    SET IsDeleted = 1, UpdatedBy = @DeletedBy, UpdatedAt = GETDATE()
    WHERE ExpenceId = @ExpenceId;
END;
GO
