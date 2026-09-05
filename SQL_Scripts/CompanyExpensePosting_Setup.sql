-- ============================================================
-- COMPANY EXPENSE POSTING Setup
-- Table: CompanyExpensePosting
-- ============================================================

-- -----------------------------------------------
-- 1. TABLE
-- -----------------------------------------------
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='CompanyExpensePosting' AND xtype='U')
BEGIN
    CREATE TABLE CompanyExpensePosting (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        Date          DATE            NOT NULL,
        Type          NVARCHAR(100)   NOT NULL,          -- e.g. Salary, Dewa, Rent, etc.
        RecipientName NVARCHAR(200)   NULL,
        Head          NVARCHAR(200)   NULL,              -- Expense head / category
        Amount        DECIMAL(18,2)   NOT NULL DEFAULT 0,
        Mode          NVARCHAR(50)    NOT NULL DEFAULT 'Cash',  -- Cash, Bank, Cheque, etc.
        SalonId       INT             NULL,              -- FK to SalonMaster (optional)
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
-- STORED PROCEDURES
-- ============================================================

-- ── 1. GET ALL (paginated + filters) ─────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCompanyExpensePosting
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @SearchText   NVARCHAR(200) = NULL,
    @SalonId      INT           = NULL,
    @Type         NVARCHAR(100) = NULL,
    @DateFrom     DATE          = NULL,
    @DateTo       DATE          = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT @TotalRecords = COUNT(*)
    FROM   CompanyExpensePosting  ce
    LEFT JOIN SalonMaster sm ON sm.Id = ce.SalonId AND sm.IsDeleted = 0
    WHERE  ce.IsDeleted = 0
      AND  (@SalonId    IS NULL OR ce.SalonId = @SalonId)
      AND  (@Type       IS NULL OR ce.Type    = @Type)
      AND  (@Status     IS NULL OR ce.Status  = @Status)
      AND  (@DateFrom   IS NULL OR ce.Date   >= @DateFrom)
      AND  (@DateTo     IS NULL OR ce.Date   <= @DateTo)
      AND  (@SearchText IS NULL
            OR ce.RecipientName LIKE '%'+@SearchText+'%'
            OR ce.Head          LIKE '%'+@SearchText+'%'
            OR ce.Type          LIKE '%'+@SearchText+'%'
            OR ce.Description   LIKE '%'+@SearchText+'%'
            OR ISNULL(sm.Name,'') LIKE '%'+@SearchText+'%');

    SELECT
        ce.Id,
        ce.Date,
        ce.Type,
        ce.RecipientName,
        ce.Head,
        ce.Amount,
        ce.Mode,
        ce.SalonId,
        ISNULL(sm.Name, '') AS SalonName,
        ce.Description,
        ce.Status,
        ce.CreatedAt,
        ce.UpdatedAt
    FROM   CompanyExpensePosting ce
    LEFT JOIN SalonMaster sm ON sm.Id = ce.SalonId AND sm.IsDeleted = 0
    WHERE  ce.IsDeleted = 0
      AND  (@SalonId    IS NULL OR ce.SalonId = @SalonId)
      AND  (@Type       IS NULL OR ce.Type    = @Type)
      AND  (@Status     IS NULL OR ce.Status  = @Status)
      AND  (@DateFrom   IS NULL OR ce.Date   >= @DateFrom)
      AND  (@DateTo     IS NULL OR ce.Date   <= @DateTo)
      AND  (@SearchText IS NULL
            OR ce.RecipientName LIKE '%'+@SearchText+'%'
            OR ce.Head          LIKE '%'+@SearchText+'%'
            OR ce.Type          LIKE '%'+@SearchText+'%'
            OR ce.Description   LIKE '%'+@SearchText+'%'
            OR ISNULL(sm.Name,'') LIKE '%'+@SearchText+'%')
    ORDER BY ce.Date DESC, ce.CreatedAt DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ── 2. GET BY ID ──────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCompanyExpensePostingById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ce.Id,
        ce.Date,
        ce.Type,
        ce.RecipientName,
        ce.Head,
        ce.Amount,
        ce.Mode,
        ce.SalonId,
        ISNULL(sm.Name, '') AS SalonName,
        ce.Description,
        ce.Status,
        ce.CreatedAt,
        ce.UpdatedAt
    FROM   CompanyExpensePosting ce
    LEFT JOIN SalonMaster sm ON sm.Id = ce.SalonId AND sm.IsDeleted = 0
    WHERE  ce.Id = @Id AND ce.IsDeleted = 0;
END;
GO

-- ── 3. CREATE ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateCompanyExpensePosting
    @Date          DATE,
    @Type          NVARCHAR(100),
    @RecipientName NVARCHAR(200) = NULL,
    @Head          NVARCHAR(200) = NULL,
    @Amount        DECIMAL(18,2),
    @Mode          NVARCHAR(50)  = 'Cash',
    @SalonId       INT           = NULL,
    @Description   NVARCHAR(500) = NULL,
    @Status        NVARCHAR(20)  = 'Active',
    @AddedBy       NVARCHAR(100) = NULL,
    @NewId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO CompanyExpensePosting
        (Date, Type, RecipientName, Head, Amount, Mode, SalonId, Description, Status, AddedBy, CreatedAt)
    VALUES
        (@Date, @Type, @RecipientName, @Head, @Amount, @Mode, @SalonId, @Description, @Status, @AddedBy, GETDATE());
    SET @NewId = SCOPE_IDENTITY();
END;
GO

-- ── 4. UPDATE ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateCompanyExpensePosting
    @Id            INT,
    @Date          DATE,
    @Type          NVARCHAR(100),
    @RecipientName NVARCHAR(200) = NULL,
    @Head          NVARCHAR(200) = NULL,
    @Amount        DECIMAL(18,2),
    @Mode          NVARCHAR(50)  = 'Cash',
    @SalonId       INT           = NULL,
    @Description   NVARCHAR(500) = NULL,
    @Status        NVARCHAR(20)  = 'Active',
    @UpdatedBy     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CompanyExpensePosting
    SET
        Date          = @Date,
        Type          = @Type,
        RecipientName = @RecipientName,
        Head          = @Head,
        Amount        = @Amount,
        Mode          = @Mode,
        SalonId       = @SalonId,
        Description   = @Description,
        Status        = @Status,
        UpdatedBy     = @UpdatedBy,
        UpdatedAt     = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- ── 5. SOFT DELETE ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteCompanyExpensePosting
    @Id        INT,
    @DeletedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE CompanyExpensePosting
    SET IsDeleted = 1, UpdatedBy = @DeletedBy, UpdatedAt = GETDATE()
    WHERE Id = @Id AND IsDeleted = 0;
END;
GO

-- ── 6. SUMMARY TOTALS (optional — for dashboard/report) ───────
CREATE OR ALTER PROCEDURE sp_GetCompanyExpenseSummary
    @SalonId  INT  = NULL,
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ce.Type,
        COUNT(*)          AS TotalEntries,
        SUM(ce.Amount)    AS TotalAmount
    FROM CompanyExpensePosting ce
    WHERE ce.IsDeleted = 0
      AND (@SalonId  IS NULL OR ce.SalonId = @SalonId)
      AND (@DateFrom IS NULL OR ce.Date   >= @DateFrom)
      AND (@DateTo   IS NULL OR ce.Date   <= @DateTo)
    GROUP BY ce.Type
    ORDER BY TotalAmount DESC;
END;
GO
