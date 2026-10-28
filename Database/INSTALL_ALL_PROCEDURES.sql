-- =============================================
-- Complete Installation Script for Month-wise Rental Report API
-- Run this entire script in your NEW database
-- Created: October 27, 2026
-- =============================================

-- ⚠️ CHANGE THIS to your database name
USE YourDatabaseName;  -- <-- UPDATE THIS LINE
GO

PRINT '================================================';
PRINT 'Month-wise Rental Report API - Installation';
PRINT '================================================';
PRINT '';
PRINT 'Starting installation...';
PRINT '';

-- =============================================
-- PROCEDURE 1: sp_GetMonthwiseRentalReport (V2 - With Vacant Rooms)
-- Used by: Main report and Export endpoints
-- Endpoints: 
--   - GET /api/monthwiserentalreport
--   - GET /api/monthwiserentalreport/export
-- Shows BOTH Occupied rooms AND Vacant rooms
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetMonthwiseRentalReport')
BEGIN
    DROP PROCEDURE sp_GetMonthwiseRentalReport;
    PRINT 'Dropped existing sp_GetMonthwiseRentalReport';
END
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
    @SortBy          VARCHAR(50)  = 'RoomNo',
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
    
    -- Create temp table for combined data
    CREATE TABLE #CombinedData (
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
    
    -- Insert Occupied Rooms
    INSERT INTO #CombinedData
    SELECT 
        cri.Id,
        cri.ContractId,
        'Occupied' AS RoomStatus,
        c.ContractType,
        c.Status AS ContractStatus,
        c.InstallmentType,
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
        -- SD from TxnRecords → ContractRooms JOIN
        ISNULL(sdtxn.Amount, 0.00) AS SdAmount,
        sdtxn.TxnDate AS SdDate,
        cri.CreatedAt,
        cri.UpdatedAt
    FROM 
        ContractRoomInstallments cri
        INNER JOIN Contracts c ON cri.ContractId = c.ContractId
        INNER JOIN Tenants t ON c.TenantId = t.Id
        INNER JOIN Camps camp ON cri.CampId = camp.Id
        INNER JOIN Rooms r ON cri.RoomId = r.Id
        LEFT JOIN Floors f ON r.FloorId = f.Id
        -- Join to get SD-CR transaction details via TxnRecords → ContractRooms
        LEFT JOIN (
            SELECT 
                txn.ContractId,
                cr.CampId,
                cr.RoomId,
                txn.Amount,
                txn.TxnDate
            FROM TxnRecords txn
            INNER JOIN ContractRooms cr ON txn.ContractId = cr.ContractId
            WHERE txn.TxnType = 'SD-CR' 
              AND txn.IsDeleted = 0
              AND cr.IsDeleted = 0
        ) sdtxn ON cri.ContractId = sdtxn.ContractId 
                AND cri.CampId = sdtxn.CampId 
                AND cri.RoomId = sdtxn.RoomId
    WHERE 
        cri.IsDeleted = 0 
        AND c.IsDeleted = 0
        AND (@Month IS NULL OR cri.Month = @Month)
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
        AND (@Status IS NULL OR cri.Status = @Status)
        AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        AND (@ContractStatus IS NULL OR c.Status = @ContractStatus)
        AND (@FromDate IS NULL OR cri.DueDate >= @FromDate)
        AND (@ToDate IS NULL OR cri.DueDate <= @ToDate);
    
    -- Insert Vacant Rooms
    INSERT INTO #CombinedData
    SELECT 
        NULL AS Id,
        NULL AS ContractId,
        'Vacant' AS RoomStatus,
        NULL AS ContractType,
        NULL AS ContractStatus,
        NULL AS InstallmentType,
        NULL AS StartDate,
        NULL AS EndDate,
        NULL AS TenantId,
        'N/A' AS TenantName,
        NULL AS TenantContact,
        NULL AS TenantEmail,
        r.CampId,
        camp.Name AS CampName,
        camp.CampLocation AS CampLocation,
        r.Id AS RoomId,
        r.RoomNo,
        f.Name AS FloorName,
        0 AS InstallmentNo,
        @Month AS Month,
        NULL AS DueDate,
        0.00 AS InstallAmount,
        'N/A' AS PaymentMode,
        'N/A' AS ReferenceNo,
        NULL AS ClearanceDate,
        NULL AS PaidDate,
        0.00 AS PaidAmount,
        0.00 AS Balance,
        'Vacant' AS Status,
        0.00 AS SdAmount,
        NULL AS SdDate,
        r.CreatedAt,
        r.UpdatedAt
    FROM 
        Rooms r
        INNER JOIN Camps camp ON r.CampId = camp.Id
        LEFT JOIN Floors f ON r.FloorId = f.Id
    WHERE 
        r.IsDeleted = 0
        AND camp.IsDeleted = 0
        AND (@CampId IS NULL OR r.CampId = @CampId)
        AND (@RoomId IS NULL OR r.Id = @RoomId)
        AND NOT EXISTS (
            SELECT 1 
            FROM ContractRoomInstallments cri
            INNER JOIN Contracts c ON cri.ContractId = c.ContractId
            WHERE cri.RoomId = r.Id
              AND cri.IsDeleted = 0
              AND c.IsDeleted = 0
              AND (@Month IS NULL OR cri.Month = @Month)
              AND c.Status = 'Active'
        );
    
    -- Get total count
    SELECT @TotalRecords = COUNT(*) FROM #CombinedData;
    
    -- Return paginated results
    SELECT 
        Id,
        ContractId,
        RoomStatus,
        ContractType,
        ContractStatus,
        InstallmentType,
        StartDate,
        EndDate,
        TenantId,
        TenantName,
        TenantContact,
        TenantEmail,
        CampId,
        CampName,
        CampLocation,
        RoomId,
        RoomNo,
        FloorName,
        InstallmentNo,
        Month,
        DueDate,
        InstallAmount,
        PaymentMode,
        ReferenceNo,
        ClearanceDate,
        PaidDate,
        PaidAmount,
        Balance,
        Status,
        SdAmount,
        SdDate,
        CreatedAt,
        UpdatedAt
    FROM #CombinedData
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
    DROP TABLE #CombinedData;
        
END;
GO

PRINT 'SUCCESS: sp_GetMonthwiseRentalReport (V2 with Vacant Rooms) created!';
PRINT '';

-- =============================================
-- PROCEDURE 2: sp_GetMonthwiseRentalSummary
-- Used by: Summary endpoint
-- Endpoint: GET /api/monthwiserentalreport/summary
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetMonthwiseRentalSummary')
BEGIN
    DROP PROCEDURE sp_GetMonthwiseRentalSummary;
    PRINT 'Dropped existing sp_GetMonthwiseRentalSummary';
END
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

PRINT 'SUCCESS: sp_GetMonthwiseRentalSummary created!';
PRINT '';

-- =============================================
-- VERIFICATION TESTS
-- =============================================
PRINT '================================================';
PRINT 'Running verification tests...';
PRINT '================================================';
PRINT '';

-- Test Procedure 1
PRINT 'Test 1: sp_GetMonthwiseRentalReport';
DECLARE @TestTotal INT;
BEGIN TRY
    EXEC sp_GetMonthwiseRentalReport 
        @PageNumber = 1, 
        @PageSize = 5,
        @TotalRecords = @TestTotal OUTPUT;
    PRINT 'Result: SUCCESS - Total Records Found: ' + CAST(ISNULL(@TestTotal, 0) AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'Result: FAILED - Error: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- Test Procedure 2
PRINT 'Test 2: sp_GetMonthwiseRentalSummary';
BEGIN TRY
    EXEC sp_GetMonthwiseRentalSummary;
    PRINT 'Result: SUCCESS - Procedure executed successfully';
END TRY
BEGIN CATCH
    PRINT 'Result: FAILED - Error: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =============================================
-- INSTALLATION SUMMARY
-- =============================================
PRINT '================================================';
PRINT 'INSTALLATION COMPLETE!';
PRINT '================================================';
PRINT '';
PRINT 'Procedures installed:';
PRINT '  1. sp_GetMonthwiseRentalReport';
PRINT '  2. sp_GetMonthwiseRentalSummary';
PRINT '';
PRINT 'API Endpoints:';
PRINT '  GET  /api/monthwiserentalreport';
PRINT '  GET  /api/monthwiserentalreport/summary';
PRINT '  GET  /api/monthwiserentalreport/export';
PRINT '';
PRINT 'Required Tables:';
PRINT '  - ContractRoomInstallments (main)';
PRINT '  - Contracts';
PRINT '  - Tenants (must have: Contact, Email columns)';
PRINT '  - Camps (must have: CampLocation column)';
PRINT '  - Rooms';
PRINT '  - Floors (optional)';
PRINT '';
PRINT 'Next Steps:';
PRINT '  1. Update connection string in appsettings.json';
PRINT '  2. Restart backend API';
PRINT '  3. Test at: http://your-api-url/swagger';
PRINT '';
PRINT '================================================';
