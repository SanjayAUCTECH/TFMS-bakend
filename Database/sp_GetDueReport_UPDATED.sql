-- =============================================
-- Stored Procedure: sp_GetDueReport (UPDATED VERSION)
-- Description: Get due report with all filters and features
--              Includes summary stats and chart data
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetDueReport
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TenantId INT = NULL,
    @CampId INT = NULL,
    @ContractId VARCHAR(50) = NULL,
    @Month VARCHAR(7) = NULL,
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL,
    @Status VARCHAR(20) = NULL,
    @SearchText VARCHAR(100) = NULL,
    @Mode VARCHAR(50) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Build WHERE conditions dynamically
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @WhereClause NVARCHAR(MAX) = '';
    DECLARE @Params NVARCHAR(MAX);
    
    -- Base filter
    SET @WhereClause = 'WHERE ci.Status IN (''Pending'',''Partial'',''Overdue'')';
    
    -- TenantId filter
    IF @TenantId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ct.TenantId = @TenantId';
    
    -- CampId filter
    IF @CampId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ct.ContractId IN (SELECT ContractId FROM ContractCamps WHERE CampId = @CampId)';
    
    -- ContractId filter
    IF @ContractId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ci.ContractId = @ContractId';
    
    -- Month filter (format: yyyy-MM)
    IF @Month IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND FORMAT(ci.DueDate, ''yyyy-MM'') = @Month';
    
    -- DateFrom filter
    IF @DateFrom IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ci.DueDate >= @DateFrom';
    
    -- DateTo filter
    IF @DateTo IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ci.DueDate <= @DateTo';
    
    -- Status filter (Overdue or Pending)
    IF @Status = 'Overdue'
        SET @WhereClause = @WhereClause + ' AND ci.DueDate < GETDATE()';
    ELSE IF @Status = 'Pending'
        SET @WhereClause = @WhereClause + ' AND ci.DueDate >= GETDATE()';
    
    -- SearchText filter
    IF @SearchText IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND (t.Name LIKE ''%'' + @SearchText + ''%'' OR ci.ContractId LIKE ''%'' + @SearchText + ''%'')';
    
    -- Mode filter
    IF @Mode IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND ISNULL(ci.PaymentMode, '''') = @Mode';
    
    -- Get total count
    SET @SQL = '
    SELECT @TotalRecords = COUNT(*)
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t ON t.Id = ct.TenantId
    ' + @WhereClause;
    
    SET @Params = '
        @TenantId INT,
        @CampId INT,
        @ContractId VARCHAR(50),
        @Month VARCHAR(7),
        @DateFrom DATE,
        @DateTo DATE,
        @Status VARCHAR(20),
        @SearchText VARCHAR(100),
        @Mode VARCHAR(50),
        @TotalRecords INT OUTPUT';
    
    EXEC sp_executesql @SQL, @Params,
        @TenantId = @TenantId,
        @CampId = @CampId,
        @ContractId = @ContractId,
        @Month = @Month,
        @DateFrom = @DateFrom,
        @DateTo = @DateTo,
        @Status = @Status,
        @SearchText = @SearchText,
        @Mode = @Mode,
        @TotalRecords = @TotalRecords OUTPUT;
    
    -- Get paginated data with all fields
    SET @SQL = '
    SELECT
        ci.Id,
        ci.ContractId,
        ci.InstallmentNo,
        ci.Amount,
        ci.PaidAmount,
        ci.Amount - ci.PaidAmount AS BalanceAmount,
        ci.DueDate,
        ci.Status,
        ISNULL(ci.PaymentMode, '''') AS PaymentMode,
        ISNULL(t.Name, '''') AS TenantName,
        ct.TenantId,
        ISNULL((
            SELECT TOP 1 ca2.Name 
            FROM ContractCamps cc2 
            JOIN Camps ca2 ON ca2.Id = cc2.CampId 
            WHERE cc2.ContractId = ct.ContractId 
            ORDER BY cc2.Id
        ), '''') AS CampName,
        ISNULL(rm.RoomNo, '''') AS RoomNo,
        CASE 
            WHEN ci.DueDate < GETDATE() THEN ''Overdue'' 
            ELSE ''Pending'' 
        END AS DueStatus
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t ON t.Id = ct.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId = ci.ContractId
    LEFT JOIN Rooms rm ON rm.Id = cr.RoomId
    ' + @WhereClause + '
    ORDER BY ci.DueDate
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY';
    
    SET @Params = '
        @TenantId INT,
        @CampId INT,
        @ContractId VARCHAR(50),
        @Month VARCHAR(7),
        @DateFrom DATE,
        @DateTo DATE,
        @Status VARCHAR(20),
        @SearchText VARCHAR(100),
        @Mode VARCHAR(50),
        @PageNumber INT,
        @PageSize INT';
    
    EXEC sp_executesql @SQL, @Params,
        @TenantId = @TenantId,
        @CampId = @CampId,
        @ContractId = @ContractId,
        @Month = @Month,
        @DateFrom = @DateFrom,
        @DateTo = @DateTo,
        @Status = @Status,
        @SearchText = @SearchText,
        @Mode = @Mode,
        @PageNumber = @PageNumber,
        @PageSize = @PageSize;
    
END;
GO

-- =============================================
-- Test Script
-- =============================================

/*
-- Test 1: Basic query (all due payments)
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 2: Filter by tenant
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @TenantId = 5,
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 3: Filter by camp and month
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @CampId = 2,
    @Month = '2026-07',
    @PageNumber = 1,
    @PageSize = 20,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 4: Get overdue payments only
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @Status = 'Overdue',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 5: Search with text
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @SearchText = 'John',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 6: Combined filters
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @TenantId = 5,
    @CampId = 2,
    @Month = '2026-08',
    @Status = 'Overdue',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;

-- Test 7: Date range filter
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @DateFrom = '2026-07-01',
    @DateTo = '2026-07-31',
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;
*/
