-- Fix sp_GetFundPoolMonthlyBalance to filter IsDeleted = 0
IF OBJECT_ID('dbo.sp_GetFundPoolMonthlyBalance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetFundPoolMonthlyBalance;
GO

CREATE PROCEDURE sp_GetFundPoolMonthlyBalance
    @ReportMonth INT,
    @ReportYear INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Id,
        FundPoolId,
        FundPoolName,
        ReportMonth,
        ReportYear,
        ReportDate,
        CurrentFundPool,
        BufferFundPool,
        TotalFundPool,
        Status,
        CreatedAt,
        UpdatedAt
    FROM FundPoolMonthlyBalances
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear
      AND Status = 'Active'
      AND ISNULL(IsDeleted, 0) = 0
    ORDER BY FundPoolId;

    -- Return totals
    SELECT 
        ISNULL(SUM(CurrentFundPool), 0) AS TotalCurrentFundPool,
        ISNULL(SUM(BufferFundPool), 0) AS TotalBufferFundPool,
        ISNULL(SUM(TotalFundPool), 0) AS NetTotal
    FROM FundPoolMonthlyBalances
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear
      AND Status = 'Active'
      AND ISNULL(IsDeleted, 0) = 0;
END;
GO

-- Fix sp_GetAllFundPoolMonthlyBalances to filter IsDeleted = 0
IF OBJECT_ID('dbo.sp_GetAllFundPoolMonthlyBalances', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetAllFundPoolMonthlyBalances;
GO

CREATE PROCEDURE sp_GetAllFundPoolMonthlyBalances
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchText NVARCHAR(255) = NULL,
    @ReportYear INT = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Calculate total records
    SELECT @TotalRecords = COUNT(DISTINCT CAST(ReportYear AS VARCHAR) + '-' + CAST(ReportMonth AS VARCHAR))
    FROM FundPoolMonthlyBalances
    WHERE ISNULL(IsDeleted, 0) = 0
      AND (@ReportYear IS NULL OR ReportYear = @ReportYear)
      AND (
          @SearchText IS NULL 
          OR FundPoolName LIKE '%' + @SearchText + '%'
          OR CAST(ReportMonth AS VARCHAR) LIKE '%' + @SearchText + '%'
          OR CAST(ReportYear AS VARCHAR) LIKE '%' + @SearchText + '%'
      );

    -- Return paginated summary data grouped by Month/Year
    WITH MonthlyData AS (
        SELECT 
            ReportMonth,
            ReportYear,
            ReportDate,
            COUNT(*) AS TotalFundPools,
            SUM(CurrentFundPool) AS TotalCurrentFundPool,
            SUM(BufferFundPool) AS TotalBufferFundPool,
            SUM(TotalFundPool) AS NetTotal,
            MAX(CreatedAt) AS CreatedAt
        FROM FundPoolMonthlyBalances
        WHERE ISNULL(IsDeleted, 0) = 0
          AND (@ReportYear IS NULL OR ReportYear = @ReportYear)
          AND (
              @SearchText IS NULL 
              OR FundPoolName LIKE '%' + @SearchText + '%'
              OR CAST(ReportMonth AS VARCHAR) LIKE '%' + @SearchText + '%'
              OR CAST(ReportYear AS VARCHAR) LIKE '%' + @SearchText + '%'
          )
        GROUP BY ReportMonth, ReportYear, ReportDate
    )
    SELECT 
        ReportMonth,
        ReportYear,
        ReportDate,
        TotalFundPools,
        TotalCurrentFundPool,
        TotalBufferFundPool,
        NetTotal,
        CreatedAt
    FROM MonthlyData
    ORDER BY ReportYear DESC, ReportMonth DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT 'GET stored procedures updated with IsDeleted = 0 filter!';
