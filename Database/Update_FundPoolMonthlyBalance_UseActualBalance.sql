-- Update sp_SaveFundPoolMonthlyBalance to use actual Balance from FundPools table
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
    -- Using the actual Balance column from FundPools table
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
        
        -- Using actual Balance from FundPools table as CurrentFundPool
        fp.Balance AS CurrentFundPool,
        
        -- BufferFundPool - we'll set to 0 for now as there's no separate buffer column
        0.00 AS BufferFundPool,
        
        -- TotalFundPool = CurrentFundPool (since Buffer is 0)
        fp.Balance AS TotalFundPool,
        
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

PRINT 'Fund Pool Monthly Balance stored procedure updated to use actual Balance from FundPools table!';
