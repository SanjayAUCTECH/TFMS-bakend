-- Fix sp_DeleteFundPoolMonthlyBalance to soft delete (IsDeleted = 1)
IF OBJECT_ID('dbo.sp_DeleteFundPoolMonthlyBalance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_DeleteFundPoolMonthlyBalance;
GO

CREATE PROCEDURE sp_DeleteFundPoolMonthlyBalance
    @ReportMonth INT,
    @ReportYear INT,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Soft delete (set IsDeleted = 1)
    UPDATE FundPoolMonthlyBalances 
    SET IsDeleted = 1,
        UpdatedAt = GETDATE(),
        UpdatedBy = @UserId
    WHERE ReportMonth = @ReportMonth 
      AND ReportYear = @ReportYear
      AND ISNULL(IsDeleted, 0) = 0;

    -- Return count of deleted records
    SELECT @@ROWCOUNT AS DeletedRecords;
END;
GO

PRINT 'sp_DeleteFundPoolMonthlyBalance updated to soft delete (IsDeleted = 1)!';
