-- Fix sp_GetMonthwiseRentalReport with simple query (no CTE)
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
    
    -- Get total count first
    SELECT @TotalRecords = COUNT(*)
    FROM ContractRoomInstallments cri
        INNER JOIN Contracts c ON cri.ContractId = c.ContractId
        INNER JOIN Tenants t ON c.TenantId = t.Id
        INNER JOIN Camps camp ON cri.CampId = camp.Id
        INNER JOIN Rooms r ON cri.RoomId = r.Id
        LEFT JOIN Floors f ON r.FloorId = f.Id
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
    
    -- Get paginated data with sorting
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
        AND (@Month IS NULL OR cri.Month = @Month)
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
        AND (@Status IS NULL OR cri.Status = @Status)
        AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        AND (@ContractStatus IS NULL OR c.Status = @ContractStatus)
        AND (@FromDate IS NULL OR cri.DueDate >= @FromDate)
        AND (@ToDate IS NULL OR cri.DueDate <= @ToDate)
    ORDER BY 
        CASE 
            WHEN @SortBy = 'Id' AND @SortDirection = 'ASC' THEN cri.Id
        END ASC,
        CASE 
            WHEN @SortBy = 'Id' AND @SortDirection = 'DESC' THEN cri.Id
        END DESC,
        CASE 
            WHEN @SortBy = 'DueDate' AND @SortDirection = 'ASC' THEN cri.DueDate
        END ASC,
        CASE 
            WHEN @SortBy = 'DueDate' AND @SortDirection = 'DESC' THEN cri.DueDate
        END DESC,
        CASE 
            WHEN @SortBy = 'InstallAmount' AND @SortDirection = 'ASC' THEN cri.InstallAmount
        END ASC,
        CASE 
            WHEN @SortBy = 'InstallAmount' AND @SortDirection = 'DESC' THEN cri.InstallAmount
        END DESC,
        CASE 
            WHEN @SortBy = 'Balance' AND @SortDirection = 'ASC' THEN cri.Balance
        END ASC,
        CASE 
            WHEN @SortBy = 'Balance' AND @SortDirection = 'DESC' THEN cri.Balance
        END DESC,
        cri.DueDate ASC  -- Default fallback sort
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT 'Procedure sp_GetMonthwiseRentalReport fixed with simple query!';
GO

-- Test the procedure
DECLARE @Total INT;
EXEC sp_GetMonthwiseRentalReport 
    @PageNumber = 1, 
    @PageSize = 5,
    @TotalRecords = @Total OUTPUT;
PRINT 'Test successful! Total Records: ' + CAST(@Total AS VARCHAR(10));
GO
