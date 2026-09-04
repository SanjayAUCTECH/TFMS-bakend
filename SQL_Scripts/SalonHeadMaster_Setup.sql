-- =============================================
-- SALON HEAD MASTER MODULE - SQL Setup Script
-- =============================================

-- -----------------------------------------------
-- 1. CREATE TABLE
-- -----------------------------------------------
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SalonHeadMaster' AND xtype='U')
BEGIN
    CREATE TABLE SalonHeadMaster (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        HeadType    NVARCHAR(50)    NOT NULL,   -- 'Income' or 'Expense'
        HeadName    NVARCHAR(150)   NOT NULL,
        Status      NVARCHAR(20)    NOT NULL DEFAULT 'Active',
        IsDeleted   BIT             NOT NULL DEFAULT 0,
        AddedBy     NVARCHAR(100)   NULL,
        UpdatedBy   NVARCHAR(100)   NULL,
        CreatedAt   DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt   DATETIME        NULL
    );
END;
GO

-- -----------------------------------------------
-- 2. GET ALL (Paginated + Search + HeadType + Status filters)
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonHeadMaster
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @SearchText   NVARCHAR(200) = NULL,
    @HeadType     NVARCHAR(50)  = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total count
    SELECT @TotalRecords = COUNT(*)
    FROM SalonHeadMaster
    WHERE IsDeleted = 0
      AND (@HeadType   IS NULL OR HeadType = @HeadType)
      AND (@Status     IS NULL OR Status   = @Status)
      AND (@SearchText IS NULL
           OR HeadName LIKE '%' + @SearchText + '%'
           OR HeadType LIKE '%' + @SearchText + '%');

    -- Paged data
    SELECT
        Id,
        HeadType,
        HeadName,
        Status,
        CreatedAt,
        UpdatedAt
    FROM SalonHeadMaster
    WHERE IsDeleted = 0
      AND (@HeadType   IS NULL OR HeadType = @HeadType)
      AND (@Status     IS NULL OR Status   = @Status)
      AND (@SearchText IS NULL
           OR HeadName LIKE '%' + @SearchText + '%'
           OR HeadType LIKE '%' + @SearchText + '%')
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- -----------------------------------------------
-- 3. GET ALL ACTIVE (for dropdowns)
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonHeadMasterActive
    @HeadType NVARCHAR(50) = NULL   -- optional: filter by Income/Expense
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, HeadType, HeadName, Status
    FROM SalonHeadMaster
    WHERE IsDeleted = 0
      AND Status = 'Active'
      AND (@HeadType IS NULL OR HeadType = @HeadType)
    ORDER BY HeadType, HeadName;
END;
GO

-- -----------------------------------------------
-- 4. GET BY ID
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonHeadMasterById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, HeadType, HeadName, Status, CreatedAt, UpdatedAt
    FROM SalonHeadMaster
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 5. CREATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_CreateSalonHeadMaster
    @HeadType  NVARCHAR(50),
    @HeadName  NVARCHAR(150),
    @Status    NVARCHAR(20)  = 'Active',
    @AddedBy   NVARCHAR(100) = NULL,
    @NewId     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SalonHeadMaster (HeadType, HeadName, Status, AddedBy, CreatedAt)
    VALUES (@HeadType, @HeadName, @Status, @AddedBy, GETDATE());

    SET @NewId = SCOPE_IDENTITY();
END;
GO

-- -----------------------------------------------
-- 6. UPDATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdateSalonHeadMaster
    @Id        INT,
    @HeadType  NVARCHAR(50),
    @HeadName  NVARCHAR(150),
    @Status    NVARCHAR(20),
    @UpdatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonHeadMaster
    SET
        HeadType  = @HeadType,
        HeadName  = @HeadName,
        Status    = @Status,
        UpdatedBy = @UpdatedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 7. SOFT DELETE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteSalonHeadMaster
    @Id        INT,
    @DeletedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonHeadMaster
    SET
        IsDeleted = 1,
        UpdatedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @Id;
END;
GO
