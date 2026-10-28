-- =============================================
-- Direct Installation Script for Month-wise Rental Report
-- Run this entire script in SSMS or Azure Data Studio
-- Database: TFMS_SoftwareDB
-- =============================================

USE TFMS_SoftwareDB;
GO

-- =============================================
-- 1. Main Report Procedure
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetMonthwiseRentalReport')
    DROP PROCEDURE sp_GetMonthwiseRentalReport;
GO

CREATE PROCEDURE sp_GetMonthwiseRentalReport
    @Month           VARCHAR(10)  = NULL,
    @CampId          INT          = NULL,
    @TenantId        INT          = NULL,
    @RoomId          INT          = NULL,
    @Status          VARCHAR(20)  = NULL,
    @ContractStatus  VARCHAR(20)  = NULL,
    @FromDate        DATETIME     = NULL,
    @ToDate          DATETIME     = NULL,
    @PageNumber      INT          = 1,
    @PageSize        INT          = 50,
    @SortBy          VARCHAR(50)  = 'DueDate',
    @SortDirection   VARCHAR(4)   = 'ASC',
    @TotalRecords    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate pagination parameters
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    
    -- Validate sort direction
    IF @SortDirection NOT IN ('ASC', 'DESC')
        SET @SortDirection = 'ASC';
    
    -- Calculate offset
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Build dynamic WHERE clause
    DECLARE @WhereClause NVARCHAR(MAX) = '1=1';
    
    IF @Month IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.Month = @Month';
    
    IF @CampId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.CampId = @CampId';
    
    IF @RoomId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.RoomId = @RoomId';
    
    IF @Status IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.Status = @Status';
    
    IF @TenantId IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND c.TenantId = @TenantId';
    
    IF @ContractStatus IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND c.Status = @ContractStatus';
    
    IF @FromDate IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.DueDate >= @FromDate';
    
    IF @ToDate IS NOT NULL
        SET @WhereClause = @WhereClause + ' AND cri.DueDate <= @ToDate';
    
    -- Validate sort column
    IF @SortBy NOT IN (
        'Id', 'ContractId', 'Month', 'DueDate', 'InstallAmount', 
        'PaidAmount', 'Balance', 'Status', 'CampName', 'RoomNo', 
        'TenantName', 'ContractStatus', 'InstallmentNo', 'CreatedAt'
    )
        SET @SortBy = 'DueDate';
    
    -- Build sort column
    DECLARE @SortColumn NVARCHAR(100);
    SET @SortColumn = CASE @SortBy
        WHEN 'Id' THEN 'cri.Id'
        WHEN 'ContractId' THEN 'cri.ContractId'
        WHEN 'Month' THEN 'cri.Month'
        WHEN 'DueDate' THEN 'cri.DueDate'
        WHEN 'InstallAmount' THEN 'cri.InstallAmount'
        WHEN 'PaidAmount' THEN 'cri.PaidAmount'
        WHEN 'Balance' THEN 'cri.Balance'
        WHEN 'Status' THEN 'cri.Status'
        WHEN 'CampName' THEN 'camp.Name'
        WHEN 'RoomNo' THEN 'r.RoomNo'
        WHEN 'TenantName' THEN 't.Name'
        WHEN 'ContractStatus' THEN 'c.Status'
        WHEN 'InstallmentNo' THEN 'cri.InstallmentNo'
        WHEN 'CreatedAt' THEN 'cri.CreatedAt'
        ELSE 'cri.DueDate'
    END;
    
    -- Main query
    DECLARE @SQL NVARCHAR(MAX);
    
    SET @SQL = N'
    WITH FilteredData AS (
        SELECT 
            cri.Id,
            cri.ContractId,
            c.ContractType,
            c.Status AS ContractStatus,
            c.StartDate,
            c.EndDate,
            c.TenantId,
            t.Name AS TenantName,
            t.ContactPerson AS TenantContactPerson,
            t.Phone AS TenantPhone,
            cri.CampId,
            camp.Name AS CampName,
            camp.Location AS CampLocation,
            cri.RoomId,
            r.RoomNo,
            f.Name AS FloorName,
            cri.InstallmentNo,
            cri.Month,
            cri.DueDate,
            cri.InstallAmount,
            cri.PaymentMode,
            cri.ReferenceNo,
            cri.ClearanceDate,
            cri.PaidDate,
            cri.PaidAmount,
            cri.Balance,
            cri.Status,
            cri.CreatedAt,
            cri.UpdatedAt
        FROM 
            ContractRoomInstallments cri
            INNER JOIN Contracts c ON cri.ContractId = c.ContractId
            INNER JOIN Tenants t ON c.TenantId = t.Id
            INNER JOIN Camps camp ON cri.CampId = camp.Id
            INNER JOIN Rooms r ON cri.RoomId = r.Id
            LEFT JOIN Floors f ON r.FloorId = f.Id
        WHERE 
            cri.IsDeleted = 0 
            AND c.IsDeleted = 0 
            AND ' + @WhereClause + '
    )
    SELECT 
        @TotalRecords = COUNT(*)
    FROM FilteredData;
    
    WITH FilteredData AS (
        SELECT 
            cri.Id,
            cri.ContractId,
            c.ContractType,
            c.Status AS ContractStatus,
            c.StartDate,
            c.EndDate,
            c.TenantId,
            t.Name AS TenantName,
            t.ContactPerson AS TenantContactPerson,
            t.Phone AS TenantPhone,
            cri.CampId,
            camp.Name AS CampName,
            camp.Location AS CampLocation,
            cri.RoomId,
            r.RoomNo,
            f.Name AS FloorName,
            cri.InstallmentNo,
            cri.Month,
            cri.DueDate,
            cri.InstallAmount,
            cri.PaymentMode,
            cri.ReferenceNo,
            cri.ClearanceDate,
            cri.PaidDate,
            cri.PaidAmount,
            cri.Balance,
            cri.Status,
            cri.CreatedAt,
            cri.UpdatedAt
        FROM 
            ContractRoomInstallments cri
            INNER JOIN Contracts c ON cri.ContractId = c.ContractId
            INNER JOIN Tenants t ON c.TenantId = t.Id
            INNER JOIN Camps camp ON cri.CampId = camp.Id
            INNER JOIN Rooms r ON cri.RoomId = r.Id
            LEFT JOIN Floors f ON r.FloorId = f.Id
        WHERE 
            cri.IsDeleted = 0 
            AND c.IsDeleted = 0 
            AND ' + @WhereClause + '
    )
    SELECT *
    FROM FilteredData
    ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;';
    
    -- Execute query
    EXEC sp_executesql @SQL,
        N'@Month VARCHAR(10), @CampId INT, @TenantId INT, @RoomId INT, 
          @Status VARCHAR(20), @ContractStatus VARCHAR(20), 
          @FromDate DATETIME, @ToDate DATETIME,
          @Offset INT, @PageSize INT, @TotalRecords INT OUTPUT',
        @Month, @CampId, @TenantId, @RoomId, 
        @Status, @ContractStatus, 
        @FromDate, @ToDate,
        @Offset, @PageSize, @TotalRecords OUTPUT;
END;
GO

PRINT 'Procedure sp_GetMonthwiseRentalReport created successfully';
GO

-- =============================================
-- 2. Summary Procedure
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
        RIGHT(cri.Month, 2) DESC,
        CASE LEFT(cri.Month, 3)
            WHEN 'Jan' THEN 1 WHEN 'Feb' THEN 2 WHEN 'Mar' THEN 3
            WHEN 'Apr' THEN 4 WHEN 'May' THEN 5 WHEN 'Jun' THEN 6
            WHEN 'Jul' THEN 7 WHEN 'Aug' THEN 8 WHEN 'Sep' THEN 9
            WHEN 'Oct' THEN 10 WHEN 'Nov' THEN 11 WHEN 'Dec' THEN 12
            ELSE 99
        END DESC;
END;
GO

PRINT 'Procedure sp_GetMonthwiseRentalSummary created successfully';
GO

-- =============================================
-- Test the procedures
-- =============================================
PRINT '';
PRINT 'Testing procedures...';
PRINT '';

-- Test 1: Main report
DECLARE @Total INT;
EXEC sp_GetMonthwiseRentalReport 
    @PageNumber = 1, 
    @PageSize = 5,
    @TotalRecords = @Total OUTPUT;
PRINT 'Test 1: Main Report - Total Records: ' + CAST(@Total AS VARCHAR(10));

-- Test 2: Summary
EXEC sp_GetMonthwiseRentalSummary;
PRINT 'Test 2: Summary - Executed successfully';

PRINT '';
PRINT '================================================';
PRINT 'Installation Complete!';
PRINT '================================================';
PRINT 'Procedures created:';
PRINT '  1. sp_GetMonthwiseRentalReport';
PRINT '  2. sp_GetMonthwiseRentalSummary';
PRINT '';
PRINT 'API Endpoints:';
PRINT '  GET /api/monthwiserentalreport';
PRINT '  GET /api/monthwiserentalreport/summary';
PRINT '  GET /api/monthwiserentalreport/export';
PRINT '';
