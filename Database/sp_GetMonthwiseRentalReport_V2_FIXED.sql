-- =============================================
-- Stored Procedure: sp_GetMonthwiseRentalReport (V2 - Fixed)
-- SD Amount from TxnRecords (TxnType='SD-CR') + ContractRooms JOIN
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
    @SortBy          VARCHAR(50)  = 'RoomNo',
    @SortDirection   VARCHAR(4)   = 'ASC',
    @TotalRecords    INT          OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate pagination parameters
    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 50;
    IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'ASC';
    
    -- Calculate offset
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Create temp table
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
    
    -- Insert Occupied Rooms with SD from TxnRecords
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
        -- SD from TxnRecords + ContractRooms
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
        NULL, NULL, 'Vacant',
        NULL, NULL, NULL, NULL, NULL,
        NULL, 'N/A', NULL, NULL,
        r.CampId, camp.Name, camp.CampLocation,
        r.Id, r.RoomNo, f.Name,
        0, @Month, NULL, 0.00,
        'N/A', 'N/A', NULL, NULL, 0.00, 0.00, 'Vacant',
        0.00, NULL,
        r.CreatedAt, r.UpdatedAt
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
            SELECT 1 FROM ContractRoomInstallments cri
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
    SELECT * FROM #CombinedData
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

PRINT 'Stored Procedure sp_GetMonthwiseRentalReport (V2 Fixed) created successfully.';
