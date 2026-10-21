-- Create Table Type for Fund Pool Monthly Balance
IF TYPE_ID('dbo.FundPoolMonthlyBalanceTableType') IS NOT NULL
    DROP TYPE dbo.FundPoolMonthlyBalanceTableType;
GO

CREATE TYPE dbo.FundPoolMonthlyBalanceTableType AS TABLE
(
    FundPoolId      INT,
    FundPoolName    NVARCHAR(255),
    CurrentFundPool DECIMAL(18, 2),
    BufferFundPool  DECIMAL(18, 2),
    TotalFundPool   DECIMAL(18, 2)
);
GO

-- Update sp_SaveFundPoolMonthlyBalance to accept array of data
IF OBJECT_ID('dbo.sp_SaveFundPoolMonthlyBalance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SaveFundPoolMonthlyBalance;
GO

CREATE PROCEDURE sp_SaveFundPoolMonthlyBalance
    @ReportMonth INT,
    @ReportYear INT,
    @ReportDate DATE = NULL,
    @UserId INT = NULL,
    @FundPoolData FundPoolMonthlyBalanceTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ReportDate IS NULL
        SET @ReportDate = CAST(GETDATE() AS DATE);

    -- Delete existing records for this month/year
    DELETE FROM FundPoolMonthlyBalances 
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear;

    -- Insert new balance snapshot from provided data
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
        FundPoolId,
        FundPoolName,
        @ReportMonth AS ReportMonth,
        @ReportYear AS ReportYear,
        @ReportDate AS ReportDate,
        CurrentFundPool,
        BufferFundPool,
        TotalFundPool,
        'Active' AS Status,
        @UserId AS AddedBy,
        @UserId AS UpdatedBy,
        GETDATE() AS CreatedAt,
        GETDATE() AS UpdatedAt
    FROM @FundPoolData;

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

PRINT 'Fund Pool Monthly Balance stored procedure updated to accept array data!';
