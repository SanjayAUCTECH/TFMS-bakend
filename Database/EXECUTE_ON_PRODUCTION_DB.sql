-- =============================================
-- MonthwiseRentalReport - Production Database Installation
-- Execute this script in your PRODUCTION database
-- Created: October 28, 2026
-- =============================================

-- ⚠️ IMPORTANT: Update database name below
USE YourProductionDatabaseName;  -- <-- CHANGE THIS TO YOUR DATABASE NAME
GO

PRINT '================================================';
PRINT 'MonthwiseRentalReport - Production Installation';
PRINT '================================================';
PRINT '';

-- Drop existing procedure if exists
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetMonthwiseRentalReport')
BEGIN
    DROP PROCEDURE sp_GetMonthwiseRentalReport;
    PRINT 'Dropped existing sp_GetMonthwiseRentalReport';
END
GO

-- =============================================
-- Create Procedure: sp_GetMonthwiseRentalReport
-- Version: 3.0
-- Description: Month-wise rental report with Booked/Vacant rooms
-- =============================================

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
    @SortBy          VARCHAR(50)  = 'RoomNo',
    @SortDirection   VARCHAR(4)   = 'ASC',
    @TotalRecords    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate parameters
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'ASC';
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Create temp table
    CREATE TABLE #RoomReport (
        Id INT,
        ContractId NVARCHAR(50),
        RoomStatus VARCHAR(20),
        ContractType VARCHAR(50),
        ContractStatus VARCHAR(50),
        InstallmentType VARCHAR(50),
        StartDate DATETIME,
        EndDate DATETIME,
        TenantId INT,
        TenantName NVARCHAR(255),
        TenantContact NVARCHAR(50),
        TenantEmail NVARCHAR(255),
        CampId INT,
        CampName NVARCHAR(255),
        CampLocation NVARCHAR(500),
        RoomId INT,
        RoomNo NVARCHAR(50),
        FloorName NVARCHAR(255),
        InstallmentNo INT,
        Month VARCHAR(10),
        DueDate DATETIME,
        InstallAmount DECIMAL(18,2),
        PaymentMode NVARCHAR(50),
        ReferenceNo NVARCHAR(100),
        ClearanceDate DATETIME,
        PaidDate DATETIME,
        PaidAmount DECIMAL(18,2),
        Balance DECIMAL(18,2),
        Status VARCHAR(50),
        SdAmount DECIMAL(18,2),
        SdDate DATETIME,
        CreatedAt DATETIME,
        UpdatedAt DATETIME
    );
    
    -- Insert data: Base = Rooms table
    INSERT INTO #RoomReport
    SELECT 
        cri.Id,
        cri.ContractId,
        -- RoomStatus: Check if room is booked in this month
        CASE 
            WHEN cri.Id IS NOT NULL THEN 'Booked'
            ELSE 'Vacant'
        END AS RoomStatus,
        
        -- Contract Details (NULL for vacant)
        c.ContractType,
        c.Status AS ContractStatus,
        c.InstallmentType,
        c.StartDate,
        c.EndDate,
        
        -- Tenant Details (NULL for vacant)
        c.TenantId,
        t.Name AS TenantName,
        t.Contact AS TenantContact,
        t.Email AS TenantEmail,
        
        -- Room & Camp Details
        r.CampId,
        camp.Name AS CampName,
        camp.CampLocation AS CampLocation,
        r.Id AS RoomId,
        r.RoomNo,
        f.Name AS FloorName,
        
        -- Installment Details (0/NULL for vacant)
        ISNULL(cri.InstallmentNo, 0) AS InstallmentNo,
        ISNULL(cri.Month, @Month) AS Month,
        cri.DueDate,
        ISNULL(cri.InstallAmount, 0.00) AS InstallAmount,
        
        -- Payment Details (N/A for vacant)
        ISNULL(cri.PaymentMode, 'N/A') AS PaymentMode,
        ISNULL(cri.ReferenceNo, 'N/A') AS ReferenceNo,
        cri.ClearanceDate,
        cri.PaidDate,
        ISNULL(cri.PaidAmount, 0.00) AS PaidAmount,
        ISNULL(cri.Balance, 0.00) AS Balance,
        ISNULL(cri.Status, 'Vacant') AS Status,
        
        -- SD from TxnRecords (TxnType='SD-CR')
        ISNULL(sdtxn.Amount, 0.00) AS SdAmount,
        sdtxn.TxnDate AS SdDate,
        
        -- Timestamps
        r.CreatedAt,
        r.UpdatedAt
    FROM 
        Rooms r
        INNER JOIN Camps camp ON r.CampId = camp.Id
        LEFT JOIN Floors f ON r.FloorId = f.Id
        
        -- Check if room is booked in this month (Active contracts only)
        LEFT JOIN ContractRoomInstallments cri ON r.Id = cri.RoomId
            AND cri.IsDeleted = 0
            AND (@Month IS NULL OR cri.Month = @Month)
        
        -- Get Contract details (if booked)
        LEFT JOIN Contracts c ON cri.ContractId = c.ContractId
            AND c.IsDeleted = 0
            AND c.Status NOT IN ('Cancelled', 'Expired')
        
        -- Get Tenant details (if booked)
        LEFT JOIN Tenants t ON c.TenantId = t.Id
        
        -- Get SD details from TxnRecords (TxnType='SD-CR')
        LEFT JOIN (
            SELECT 
                ContractId,
                Amount,
                TxnDate
            FROM TxnRecords
            WHERE TxnType = 'SD-CR' 
              AND IsDeleted = 0
        ) sdtxn ON c.ContractId = sdtxn.ContractId
    WHERE 
        r.IsDeleted = 0
        AND camp.IsDeleted = 0
        AND (@CampId IS NULL OR r.CampId = @CampId)
        AND (@RoomId IS NULL OR r.Id = @RoomId)
        AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        AND (@Status IS NULL OR cri.Status = @Status)
        AND (@ContractStatus IS NULL OR c.Status = @ContractStatus)
        AND (@FromDate IS NULL OR cri.DueDate >= @FromDate)
        AND (@ToDate IS NULL OR cri.DueDate <= @ToDate);
    
    -- Get total count
    SELECT @TotalRecords = COUNT(*) FROM #RoomReport;
    
    -- Return paginated results
    SELECT * FROM #RoomReport
    ORDER BY 
        CASE WHEN @SortBy = 'RoomNo' THEN RoomNo END,
        CASE WHEN @SortBy = 'CampName' THEN CampName END,
        CASE WHEN @SortBy = 'TenantName' THEN TenantName END,
        CASE WHEN @SortBy = 'Status' THEN Status END,
        CASE WHEN @SortBy = 'DueDate' THEN DueDate END,
        RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
    
    -- Clean up
    DROP TABLE #RoomReport;
        
END;
GO

PRINT '';
PRINT '================================================';
PRINT 'SUCCESS: Stored Procedure Created!';
PRINT '================================================';
PRINT '';
PRINT 'Procedure Name: sp_GetMonthwiseRentalReport';
PRINT 'Version: 3.0';
PRINT '';
PRINT 'Features:';
PRINT '  ✓ Base: Rooms table (all rooms)';
PRINT '  ✓ RoomStatus: Booked or Vacant';
PRINT '  ✓ Month filter on ContractRoomInstallments';
PRINT '  ✓ Excludes Cancelled/Expired contracts';
PRINT '  ✓ SD Amount from TxnRecords (TxnType=SD-CR)';
PRINT '  ✓ InstallmentType from Contracts';
PRINT '  ✓ Tenant details from Tenants table';
PRINT '';
PRINT 'API Endpoint:';
PRINT '  GET /api/MonthwiseRentalReport';
PRINT '';
PRINT 'Parameters:';
PRINT '  - month: Filter by month (e.g., Jul26)';
PRINT '  - campId: Filter by camp';
PRINT '  - tenantId: Filter by tenant';
PRINT '  - roomId: Filter by room';
PRINT '  - status: Filter by payment status';
PRINT '  - contractStatus: Filter by contract status';
PRINT '  - pageNumber: Page number (default: 1)';
PRINT '  - pageSize: Records per page (default: 50)';
PRINT '';
PRINT '================================================';
PRINT 'Installation Complete!';
PRINT '================================================';
