-- Update sp_SaveFundPoolMonthlyBalance with correct column names
IF OBJECT_ID('dbo.sp_SaveFundPoolMonthlyBalance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SaveFundPoolMonthlyBalance;
GO

CREATE PROCEDURE sp_SaveFundPoolMonthlyBalance
    @ReportMonth INT,
    @ReportYear INT,
    @ReportDate DATE = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ReportDate IS NULL
        SET @ReportDate = CAST(GETDATE() AS DATE);

    -- Delete existing records for this month/year
    DELETE FROM FundPoolMonthlyBalances 
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear;

    -- Insert new balance snapshot for all fund pools
    INSERT INTO FundPoolMonthlyBalances (
        FundPoolId,
        FundPoolName,
        ReportMonth,
        ReportYear,
        ReportDate,
        CurrentFundPool,
        BufferFundPool,
        TotalFundPool,
        Status,
        AddedBy,
        UpdatedBy,
        CreatedAt,
        UpdatedAt
    )
    SELECT 
        fp.Id AS FundPoolId,
        fp.Name AS FundPoolName,
        @ReportMonth AS ReportMonth,
        @ReportYear AS ReportYear,
        @ReportDate AS ReportDate,
        
        -- Calculate Current Fund Pool Balance
        ISNULL((
            SELECT SUM(CurrentAmount)
            FROM CurrentFundTransfer
            WHERE ToCurrentFundPoolId = fp.Id
              AND IsDeleted = 0
        ), 0) - ISNULL((
            SELECT SUM(CurrentAmount)
            FROM CurrentFundTransfer
            WHERE FromCurrentFundPoolId = fp.Id
              AND IsDeleted = 0
        ), 0) AS CurrentFundPool,
        
        -- Calculate Buffer Fund Pool Balance
        ISNULL((
            SELECT SUM(BufferAmount)
            FROM BufferFundTransfer
            WHERE ToBufferFundPoolId = fp.Id
              AND IsDeleted = 0
        ), 0) - ISNULL((
            SELECT SUM(BufferAmount)
            FROM BufferFundTransfer
            WHERE FromBufferFundPoolId = fp.Id
              AND IsDeleted = 0
        ), 0) AS BufferFundPool,
        
        -- Calculate Total (Current + Buffer)
        (
            ISNULL((
                SELECT SUM(CurrentAmount)
                FROM CurrentFundTransfer
                WHERE ToCurrentFundPoolId = fp.Id
                  AND IsDeleted = 0
            ), 0) - ISNULL((
                SELECT SUM(CurrentAmount)
                FROM CurrentFundTransfer
                WHERE FromCurrentFundPoolId = fp.Id
                  AND IsDeleted = 0
            ), 0)
        ) + (
            ISNULL((
                SELECT SUM(BufferAmount)
                FROM BufferFundTransfer
                WHERE ToBufferFundPoolId = fp.Id
                  AND IsDeleted = 0
            ), 0) - ISNULL((
                SELECT SUM(BufferAmount)
                FROM BufferFundTransfer
                WHERE FromBufferFundPoolId = fp.Id
                  AND IsDeleted = 0
            ), 0)
        ) AS TotalFundPool,
        
        'Active' AS Status,
        @UserId AS AddedBy,
        @UserId AS UpdatedBy,
        GETDATE() AS CreatedAt,
        GETDATE() AS UpdatedAt
    FROM FundPools fp
    WHERE fp.IsDeleted = 0
      AND fp.Status = 'Active';

    -- Return the saved records
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
    ORDER BY FundPoolId;
END;
GO

-- Update sp_GetFundPoolMonthlyBalance with correct column names
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
    ORDER BY FundPoolId;

    -- Return totals
    SELECT 
        SUM(CurrentFundPool) AS TotalCurrentFundPool,
        SUM(BufferFundPool) AS TotalBufferFundPool,
        SUM(TotalFundPool) AS NetTotal
    FROM FundPoolMonthlyBalances
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear
      AND Status = 'Active';
END;
GO

PRINT 'Fund Pool Monthly Balance stored procedures updated successfully with correct column names!';
