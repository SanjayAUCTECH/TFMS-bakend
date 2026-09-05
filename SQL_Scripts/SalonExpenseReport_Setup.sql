-- ============================================================
-- SALON EXPENSE REPORT
-- Table: CompanyExpensePosting
-- ============================================================

-- ── Main Report SP ────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSalonExpenseReport
    @DateFrom     DATE          = NULL,
    @DateTo       DATE          = NULL,
    @Head         NVARCHAR(200) = NULL,
    @PageNumber   INT           = 1,
    @PageSize     INT           = 2147483647,
    @TotalRecords INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total count
    SELECT @TotalRecords = COUNT(*)
    FROM   CompanyExpensePosting ce
    WHERE  ce.IsDeleted = 0
      AND  (@DateFrom IS NULL OR ce.Date >= @DateFrom)
      AND  (@DateTo   IS NULL OR ce.Date <= @DateTo)
      AND  (@Head     IS NULL OR ce.Head  = @Head);

    -- Detail rows
    -- FundType logic:
    --   Head = 'salary'  → RecipientName (Staff)
    --   All other heads  → 'Company'
    SELECT
        ce.Id,
        ce.Date,
        ce.RecipientName,
        ce.Head,
        ce.Amount,
        ce.Description,
        CASE
            WHEN LOWER(ISNULL(ce.Head,'')) = 'salary'
                THEN ISNULL(ce.RecipientName, 'Staff')
            ELSE 'Company'
        END AS FundType,
        ce.SalonId,
        ISNULL(sm.Name, '') AS SalonName,
        ce.Status,
        ce.CreatedAt
    FROM   CompanyExpensePosting ce
    LEFT JOIN SalonMaster sm ON sm.Id = ce.SalonId AND sm.IsDeleted = 0
    WHERE  ce.IsDeleted = 0
      AND  (@DateFrom IS NULL OR ce.Date >= @DateFrom)
      AND  (@DateTo   IS NULL OR ce.Date <= @DateTo)
      AND  (@Head     IS NULL OR ce.Head  = @Head)
    ORDER BY ce.Date DESC, ce.CreatedAt DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- ── Cards / Summary SP ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSalonExpenseReportCards
    @DateFrom DATE          = NULL,
    @DateTo   DATE          = NULL,
    @Head     NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        -- Total Staff Fund  = all rows where Head = 'salary'
        ISNULL(SUM(CASE WHEN LOWER(ISNULL(ce.Head,'')) = 'salary' THEN ce.Amount ELSE 0 END), 0) AS TotalStaffFund,

        -- Total Company Fund = all rows where Head != 'salary'
        ISNULL(SUM(CASE WHEN LOWER(ISNULL(ce.Head,'')) != 'salary' THEN ce.Amount ELSE 0 END), 0) AS TotalCompanyFund,

        -- Grand Total
        ISNULL(SUM(ce.Amount), 0) AS GrandTotal,

        -- Total Entries
        COUNT(*) AS TotalEntries
    FROM CompanyExpensePosting ce
    WHERE ce.IsDeleted = 0
      AND (@DateFrom IS NULL OR ce.Date >= @DateFrom)
      AND (@DateTo   IS NULL OR ce.Date <= @DateTo)
      AND (@Head     IS NULL OR ce.Head  = @Head);
END;
GO
