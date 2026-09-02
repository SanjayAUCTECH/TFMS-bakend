-- =============================================
-- SALON MASTER MODULE - SQL Setup Script
-- =============================================

-- -----------------------------------------------
-- 1. CREATE TABLE
-- -----------------------------------------------
CREATE TABLE SalonMaster (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    Name            NVARCHAR(150)   NOT NULL,
    Address         NVARCHAR(300)   NOT NULL,
    Contact         NVARCHAR(20)    NOT NULL,
    Description     NVARCHAR(500)   NULL,
    ThumbnailImage  NVARCHAR(1000)  NULL,   -- Cloudinary URL
    Status          NVARCHAR(20)    NOT NULL DEFAULT 'Active',
    IsDeleted       BIT             NOT NULL DEFAULT 0,
    AddedBy         NVARCHAR(100)   NULL,
    UpdatedBy       NVARCHAR(100)   NULL,
    CreatedAt       DATETIME        NOT NULL DEFAULT GETDATE(),
    UpdatedAt       DATETIME        NULL
);
GO

-- -----------------------------------------------
-- 2. GET ALL (Paginated + Search + Status filter)
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonMaster
    @PageNumber  INT           = 1,
    @PageSize    INT           = 10,
    @SearchText  NVARCHAR(200) = NULL,
    @Status      NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total count
    SELECT @TotalRecords = COUNT(*)
    FROM SalonMaster
    WHERE IsDeleted = 0
      AND (@Status IS NULL OR Status = @Status)
      AND (@SearchText IS NULL OR Name LIKE '%' + @SearchText + '%'
                               OR Address LIKE '%' + @SearchText + '%'
                               OR Contact LIKE '%' + @SearchText + '%');

    -- Paged data
    SELECT
        Id,
        Name,
        Address,
        Contact,
        Description,
        ThumbnailImage,
        Status,
        CreatedAt,
        UpdatedAt
    FROM SalonMaster
    WHERE IsDeleted = 0
      AND (@Status IS NULL OR Status = @Status)
      AND (@SearchText IS NULL OR Name LIKE '%' + @SearchText + '%'
                               OR Address LIKE '%' + @SearchText + '%'
                               OR Contact LIKE '%' + @SearchText + '%')
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- -----------------------------------------------
-- 3. GET BY ID
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonMasterById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        Id,
        Name,
        Address,
        Contact,
        Description,
        ThumbnailImage,
        Status,
        CreatedAt,
        UpdatedAt
    FROM SalonMaster
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 4. CREATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_CreateSalonMaster
    @Name           NVARCHAR(150),
    @Address        NVARCHAR(300),
    @Contact        NVARCHAR(20),
    @Description    NVARCHAR(500) = NULL,
    @ThumbnailImage NVARCHAR(1000) = NULL,
    @Status         NVARCHAR(20)  = 'Active',
    @AddedBy        NVARCHAR(100) = NULL,
    @NewId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SalonMaster (Name, Address, Contact, Description, ThumbnailImage, Status, AddedBy, CreatedAt)
    VALUES (@Name, @Address, @Contact, @Description, @ThumbnailImage, @Status, @AddedBy, GETDATE());

    SET @NewId = SCOPE_IDENTITY();
END;
GO

-- -----------------------------------------------
-- 5. UPDATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdateSalonMaster
    @Id             INT,
    @Name           NVARCHAR(150),
    @Address        NVARCHAR(300),
    @Contact        NVARCHAR(20),
    @Description    NVARCHAR(500) = NULL,
    @ThumbnailImage NVARCHAR(1000) = NULL,
    @Status         NVARCHAR(20),
    @UpdatedBy      NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonMaster
    SET
        Name           = @Name,
        Address        = @Address,
        Contact        = @Contact,
        Description    = @Description,
        ThumbnailImage = @ThumbnailImage,
        Status         = @Status,
        UpdatedBy      = @UpdatedBy,
        UpdatedAt      = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 6. SOFT DELETE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteSalonMaster
    @Id        INT,
    @DeletedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonMaster
    SET
        IsDeleted = 1,
        UpdatedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @Id;
END;
GO
