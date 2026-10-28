-- Fix column names in sp_GetMonthwiseRentalReport procedure
USE TFMS_SoftwareDB;
GO

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
    
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'ASC';
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    DECLARE @WhereClause NVARCHAR(MAX) = '1=1';
    
    IF @Month IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.Month = @Month';
    IF @CampId IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.CampId = @CampId';
    IF @RoomId IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.RoomId = @RoomId';
    IF @Status IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.Status = @Status';
    IF @TenantId IS NOT NULL SET @WhereClause = @WhereClause + ' AND c.TenantId = @TenantId';
    IF @ContractStatus IS NOT NULL SET @WhereClause = @WhereClause + ' AND c.Status = @ContractStatus';
    IF @FromDate IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.DueDate >= @FromDate';
    IF @ToDate IS NOT NULL SET @WhereClause = @WhereClause + ' AND cri.DueDate <= @ToDate';
    
    IF @SortBy NOT IN (
        'Id', 'ContractId', 'Month', 'DueDate', 'InstallAmount', 
        'PaidAmount', 'Balance', 'Status', 'CampName', 'RoomNo', 
        'TenantName', 'ContractStatus', 'InstallmentNo', 'CreatedAt'
    ) SET @SortBy = 'DueDate';
    
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
            t.Contact AS TenantContact,
            t.Email AS TenantEmail,
            cri.CampId,
            camp.Name AS CampName,
            camp.CampLocation AS CampLocation,
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
            t.Contact AS TenantContact,
            t.Email AS TenantEmail,
            cri.CampId,
            camp.Name AS CampName,
            camp.CampLocation AS CampLocation,
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

PRINT 'Procedure sp_GetMonthwiseRentalReport updated with correct column names!';
