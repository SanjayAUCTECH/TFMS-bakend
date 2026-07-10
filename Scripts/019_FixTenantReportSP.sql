USE TFMS_softwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @Status NVARCHAR(20)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count: 1 row per tenant (not per room)
    SELECT @TotalRecords = COUNT(DISTINCT t.Id)
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    WHERE (@Status     IS NULL OR t.Status  = @Status)
      AND (@CampId     IS NULL OR c.CampId  = @CampId)
      AND (@SearchText IS NULL OR t.Name    LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%');

    -- 1 row per ContractId — rooms as aggregated string
    SELECT
        t.Id                                         TenantId,
        t.Name                                       TenantName,
        t.Contact,
        t.Email,
        t.EmiratesId,
        t.Nationality,
        t.Status,
        ISNULL(t.Type,'Individual')                  [Type],
        ISNULL(c.ContractId,'')                      ContractId,
        ISNULL(ca.Name,'')                           CampName,
        ISNULL((
            SELECT STRING_AGG(r2.RoomNo, ', ')
            FROM ContractRooms cr2
            JOIN Rooms r2 ON r2.Id = cr2.RoomId
            WHERE cr2.ContractId = c.ContractId
        ),'')                                        RoomNo,
        c.StartDate                                  ContractStart,
        c.EndDate                                    ContractEnd,
        ISNULL(c.Status,'')                          ContractStatus,
        ISNULL(c.MonthlyTotal,0)                     MonthlyRent,
        ISNULL(c.ContractTotal,0)                    TotalAmount,
        ISNULL((SELECT COUNT(*) FROM ContractRooms cr3
                WHERE cr3.ContractId = c.ContractId),0)                         RoomsBooked,
        ISNULL((SELECT SUM(ci.PaidAmount) FROM ContractInstallments ci
                WHERE ci.ContractId = c.ContractId),0)                          TotalPaid,
        ISNULL((SELECT SUM(ci.Amount - ci.PaidAmount) FROM ContractInstallments ci
                WHERE ci.ContractId = c.ContractId
                  AND ci.Status IN ('Pending','Partial')),0)                    TotalDue,
        ISNULL(c.ContractTotal,0)
            - ISNULL((SELECT SUM(ci2.PaidAmount) FROM ContractInstallments ci2
                      WHERE ci2.ContractId = c.ContractId),0)                   Balance,
        ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w
                WHERE w.ContractId = c.ContractId),0)                           WaiverAmount
    FROM Tenants t
    LEFT JOIN Contracts c  ON c.TenantId = t.Id AND c.Status = 'Active'
    LEFT JOIN Camps     ca ON ca.Id = c.CampId
    WHERE (@Status     IS NULL OR t.Status  = @Status)
      AND (@CampId     IS NULL OR c.CampId  = @CampId)
      AND (@SearchText IS NULL OR t.Name    LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%')
    ORDER BY t.Name, c.ContractId
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'sp_GetTenantReport updated — 1 row per ContractId, rooms aggregated';
GO
