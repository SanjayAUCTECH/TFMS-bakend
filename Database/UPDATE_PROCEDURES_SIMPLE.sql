USE [TFMS_TestSoftwareDB];
GO

-- Update sp_GetMonthwiseOccupiedRooms
CREATE OR ALTER PROCEDURE sp_GetMonthwiseOccupiedRooms
    @CampId INT = NULL,
    @Month NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT @TotalRecords = COUNT(DISTINCT cri.Id)
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON cri.ContractId = c.ContractId
    WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@Month IS NULL OR cri.Month = @Month);
    
    SELECT DISTINCT
        cri.Id,
        cri.ContractId,
        cri.CampId,
        cri.CampName,
        cri.RoomId,
        cri.RoomNo,
        cri.Month,
        cri.DueDate,
        cri.InstallmentNo,
        cri.InstallAmount,
        cri.Status as InstallmentStatus,
        cri.PaidAmount,
        cri.Balance,
        c.Status as ContractStatus,
        c.TenantId,
        c.StartDate,
        c.EndDate,
        c.ContractType
    FROM ContractRoomInstallments cri
    INNER JOIN Contracts c ON cri.ContractId = c.ContractId
    WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
        AND (@CampId IS NULL OR cri.CampId = @CampId)
        AND (@Month IS NULL OR cri.Month = @Month)
    ORDER BY cri.CampName, cri.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- Update sp_GetMonthwiseVacantRooms
CREATE OR ALTER PROCEDURE sp_GetMonthwiseVacantRooms
    @CampId INT = NULL,
    @Month NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    SELECT @TotalRecords = COUNT(DISTINCT r.Id)
    FROM Rooms r
    LEFT JOIN (
        SELECT DISTINCT cri.RoomId
        FROM ContractRoomInstallments cri
        INNER JOIN Contracts c ON cri.ContractId = c.ContractId
        WHERE (c.Status = 'Active' OR c.Status = 'Completed' OR c.Status = 'Complete')
            AND (@Month IS NULL OR cri.Month = @Month)
    ) occupied ON r.Id = occupied.RoomId
    WHERE occupied.RoomId IS NULL 
        AND r.IsDeleted = 0
        AND (@CampId IS NULL OR r.CampId = @CampId);
    
    SELECT 
        r.Id as RoomId,
        r.RoomNo,
        r.CampId,
        c.Name as CampName,
        r.FloorId,
        f.Name as FloorName,
        r.Occupied,
        r.MonthlyPrice,
        r.Status as RoomStatus,
        r.OtherDetails
    FROM Rooms r
    LEFT JOIN Camps c ON r.CampId = c.Id
    LEFT JOIN Floors f ON r.FloorId = f.Id
    LEFT JOIN (
        SELECT DISTINCT cri.RoomId
        FROM ContractRoomInstallments cri
        INNER JOIN Contracts ct ON cri.ContractId = ct.ContractId
        WHERE (ct.Status = 'Active' OR ct.Status = 'Completed' OR ct.Status = 'Complete')
            AND (@Month IS NULL OR cri.Month = @Month)
    ) occupied ON r.Id = occupied.RoomId
    WHERE occupied.RoomId IS NULL 
        AND r.IsDeleted = 0
        AND (@CampId IS NULL OR r.CampId = @CampId)
    ORDER BY c.Name, r.RoomNo
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO
