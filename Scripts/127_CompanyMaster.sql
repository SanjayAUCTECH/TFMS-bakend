-- ============================================================
-- 127: Company Master — Table + CRUD Stored Procedures
-- Table: Companies (Id, CompanyName, Status, AddedBy, UpdatedBy,
--                   DeletedBy, IsDeleted, CreatedAt, UpdatedAt)
-- SPs:   sp_CreateCompany, sp_GetCompanies, sp_GetCompanyById,
--        sp_UpdateCompany, sp_DeleteCompany
-- Date: July 31, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. Create Companies Table
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Companies')
BEGIN
    CREATE TABLE Companies (
        Id           INT IDENTITY(1,1) PRIMARY KEY,
        CompanyName  NVARCHAR(MAX) NOT NULL,
        Status       NVARCHAR(MAX) NOT NULL DEFAULT 'Active',
        AddedBy      NVARCHAR(MAX) NULL,
        UpdatedBy    NVARCHAR(MAX) NULL,
        DeletedBy    NVARCHAR(MAX) NULL,
        IsDeleted    BIT           NOT NULL DEFAULT 0,
        CreatedAt    DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt    DATETIME2     NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '✅ Companies table created';
END
ELSE
    PRINT '⚠️  Companies table already exists';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_CreateCompany — Insert new company
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CreateCompany
    @CompanyName NVARCHAR(MAX),
    @Status      NVARCHAR(MAX) = 'Active',
    @AddedBy     NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Companies (CompanyName, Status, AddedBy, CreatedAt, UpdatedAt)
    VALUES (@CompanyName, @Status, @AddedBy, GETUTCDATE(), GETUTCDATE());

    SELECT SCOPE_IDENTITY() AS Id;
END
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_GetCompanies — Get all companies (paginated, with filters)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetCompanies
    @PageNumber   INT           = 1,
    @PageSize     INT           = 2147483647,
    @Search       NVARCHAR(MAX) = NULL,
    @Status       NVARCHAR(MAX) = NULL,
    @TotalRecords INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count total matching records
    SELECT @TotalRecords = COUNT(*)
    FROM Companies
    WHERE IsDeleted = 0
      AND (@Search IS NULL OR CompanyName LIKE '%' + @Search + '%')
      AND (@Status IS NULL OR Status = @Status);

    -- Return paginated results
    SELECT
        Id,
        CompanyName,
        Status,
        AddedBy,
        UpdatedBy,
        DeletedBy,
        IsDeleted,
        CreatedAt,
        UpdatedAt
    FROM Companies
    WHERE IsDeleted = 0
      AND (@Search IS NULL OR CompanyName LIKE '%' + @Search + '%')
      AND (@Status IS NULL OR Status = @Status)
    ORDER BY CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_GetCompanyById — Get single company by Id
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetCompanyById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        CompanyName,
        Status,
        AddedBy,
        UpdatedBy,
        DeletedBy,
        IsDeleted,
        CreatedAt,
        UpdatedAt
    FROM Companies
    WHERE Id = @Id AND IsDeleted = 0;
END
GO

-- ══════════════════════════════════════════════════════════════
-- 5. sp_UpdateCompany — Update existing company
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateCompany
    @Id          INT,
    @CompanyName NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @UpdatedBy   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Companies
    SET
        CompanyName = ISNULL(@CompanyName, CompanyName),
        Status      = ISNULL(@Status, Status),
        UpdatedBy   = @UpdatedBy,
        UpdatedAt   = GETUTCDATE()
    WHERE Id = @Id AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50001, 'Company not found or already deleted', 1;
END
GO

-- ══════════════════════════════════════════════════════════════
-- 6. sp_DeleteCompany — Soft delete company
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_DeleteCompany
    @Id        INT,
    @DeletedBy NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Companies
    SET
        IsDeleted = 1,
        DeletedBy = @DeletedBy,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @Id AND IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 50001, 'Company not found or already deleted', 1;
END
GO

PRINT '✅ 127 - Company Master: Table + CRUD SPs created successfully';
GO
