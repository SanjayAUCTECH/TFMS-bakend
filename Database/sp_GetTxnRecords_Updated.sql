USE [TFMS_TestSoftwareDB];
GO

-- =============================================
-- Update sp_GetTxnRecords with Month Filter
-- Adds @Month parameter to filter by TxnDate
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT = 1,
    @PageSize INT = 500,
    @ContractId NVARCHAR(50) = NULL,
    @TenantId INT = NULL,
    @CampId INT = NULL,
    @TxnType NVARCHAR(10) = NULL,
    @Month NVARCHAR(50) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Helper function to convert month format (Jul26 -> 2026-07)
    -- Month format examples: Jul26, Aug26, Sep26, Jan27, etc.
    DECLARE @FilterYear INT;
    DECLARE @FilterMonth INT;
    
    IF @Month IS NOT NULL AND LEN(@Month) = 5
    BEGIN
        -- Extract year (last 2 digits)
        SET @FilterYear = 2000 + CAST(RIGHT(@Month, 2) AS INT);
        
        -- Extract month (first 3 letters)
        DECLARE @MonthAbbr NVARCHAR(3) = LEFT(@Month, 3);
        
        SET @FilterMonth = CASE @MonthAbbr
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
            ELSE NULL
        END;
    END
    
    -- Get total count
    SELECT @TotalRecords = COUNT(*)
    FROM TxnRecords t
    LEFT JOIN Tenants tn ON t.TenantId = tn.Id
    LEFT JOIN Camps c ON t.CampId = c.Id
    WHERE t.IsDeleted = 0
        AND (@ContractId IS NULL OR t.ContractId = @ContractId)
        AND (@TenantId IS NULL OR t.TenantId = @TenantId)
        AND (@CampId IS NULL OR t.CampId = @CampId)
        AND (@TxnType IS NULL OR t.TxnType = @TxnType)
        AND (
            @Month IS NULL 
            OR (
                YEAR(t.TxnDate) = @FilterYear 
                AND MONTH(t.TxnDate) = @FilterMonth
            )
        );
    
    -- Get paginated data
    SELECT 
        t.Id,
        t.TxnId,
        t.TxnType,
        t.ContractId,
        t.ContractCode,
        t.TenantId,
        ISNULL(tn.Name, '') AS TenantName,
        t.CampId,
        ISNULL(c.Name, '') AS CampName,
        t.TotalAmount,
        t.Amount,
        t.TxnDate,
        t.FromDate,
        t.ToDate,
        t.PaymentMode,
        t.PaymentModeId,
        t.ChequeNumber,
        t.FundPoolId,
        t.FundPoolName,
        t.Description,
        t.ReceivedBy,
        t.ReceivedContact,
        t.IssuedBy,
        t.InstallmentNo,
        t.AppliedInstallments,
        t.Unallocated,
        t.CreatedAt,
        t.UpdatedAt
    FROM TxnRecords t
    LEFT JOIN Tenants tn ON t.TenantId = tn.Id
    LEFT JOIN Camps c ON t.CampId = c.Id
    WHERE t.IsDeleted = 0
        AND (@ContractId IS NULL OR t.ContractId = @ContractId)
        AND (@TenantId IS NULL OR t.TenantId = @TenantId)
        AND (@CampId IS NULL OR t.CampId = @CampId)
        AND (@TxnType IS NULL OR t.TxnType = @TxnType)
        AND (
            @Month IS NULL 
            OR (
                YEAR(t.TxnDate) = @FilterYear 
                AND MONTH(t.TxnDate) = @FilterMonth
            )
        )
    ORDER BY t.TxnDate DESC, t.Id DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT 'sp_GetTxnRecords updated successfully with Month filter!';
PRINT '';

-- Test the procedure
PRINT 'Testing sp_GetTxnRecords with Month filter...';
DECLARE @Total INT;

-- Test 1: Get all TxnRecords
EXEC sp_GetTxnRecords 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TotalRecords = @Total OUTPUT;
PRINT 'Test 1 - All records: ' + CAST(@Total AS NVARCHAR);

-- Test 2: Filter by July 2026
EXEC sp_GetTxnRecords 
    @Month = 'Jul26',
    @PageNumber = 1, 
    @PageSize = 5, 
    @TotalRecords = @Total OUTPUT;
PRINT 'Test 2 - July 2026 records: ' + CAST(@Total AS NVARCHAR);

PRINT '';
PRINT 'Update completed successfully!';
