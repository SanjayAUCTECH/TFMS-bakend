-- =============================================
-- Stored Procedure: sp_GetMonthwiseRentalSummary
-- Description: Get aggregated monthly summary of rental installments
--              Groups data by month and provides statistics
-- Parameters:
--   @CampId    - Filter by camp (optional)
--   @TenantId  - Filter by tenant (optional)
--   @Status    - Filter by installment status (optional)
-- Returns:
--   Month-wise aggregated data with counts and amounts
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetMonthwiseRentalSummary')
    DROP PROCEDURE sp_GetMonthwiseRentalSummary;
GO

CREATE PROCEDURE sp_GetMonthwiseRentalSummary
    @CampId    INT         = NULL,
    @TenantId  INT         = NULL,
    @Status    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        cri.Month,
        COUNT(DISTINCT cri.RoomId) AS TotalRooms,
        COUNT(*) AS TotalInstallments,
        SUM(cri.InstallAmount) AS TotalInstallAmount,
        SUM(cri.PaidAmount) AS TotalPaidAmount,
        SUM(cri.Balance) AS TotalBalance,
        
        -- Status breakdown
        SUM(CASE WHEN cri.Status = 'Paid' THEN 1 ELSE 0 END) AS PaidCount,
        SUM(CASE WHEN cri.Status = 'Pending' THEN 1 ELSE 0 END) AS PendingCount,
        SUM(CASE WHEN cri.Status = 'Partial' THEN 1 ELSE 0 END) AS PartialCount,
        SUM(CASE WHEN cri.Status = 'Overdue' THEN 1 ELSE 0 END) AS OverdueCount
    FROM 
        ContractRoomInstallments cri
        INNER JOIN Contracts c ON cri.ContractId = c.ContractId
    WHERE 
        cri.IsDeleted = 0
        AND c.IsDeleted = 0
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        AND (@Status IS NULL OR cri.Status = @Status)
    GROUP BY 
        cri.Month
    ORDER BY 
        -- Sort months chronologically (assumes format like 'Dec26', 'Jan27')
        -- Extract year and convert month name to number for proper sorting
        RIGHT(cri.Month, 2) DESC,
        CASE LEFT(cri.Month, 3)
            WHEN 'Jan' THEN 1
            WHEN 'Feb' THEN 2
            WHEN 'Mar' THEN 3
            WHEN 'Apr' THEN 4
            WHEN 'May' THEN 5
            WHEN 'Jun' THEN 6
            WHEN 'Jul' THEN 7
            WHEN 'Aug' THEN 8
            WHEN 'Sep' THEN 9
            WHEN 'Oct' THEN 10
            WHEN 'Nov' THEN 11
            WHEN 'Dec' THEN 12
            ELSE 99
        END DESC;
END;
GO

-- Grant execute permission
-- GRANT EXECUTE ON sp_GetMonthwiseRentalSummary TO [YourAppUser];
-- GO

PRINT 'Stored Procedure sp_GetMonthwiseRentalSummary created successfully.';
