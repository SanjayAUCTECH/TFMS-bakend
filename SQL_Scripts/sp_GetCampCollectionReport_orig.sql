

-- ------------------------------------------------------------------------------
-- OPTIMIZED sp_GetCampCollectionReport — uses ContractRooms (pre-aggregated)
-- instead of ContractRoomInstallments (row-per-month, very slow)
-- ------------------------------------------------------------------------------
CREATE   PROCEDURE sp_GetCampCollectionReport
    @CampId INT=NULL, @PartnerId INT=NULL, @OwnerId INT=NULL,
    @ContractId NVARCHAR(MAX)=NULL, @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count
    SELECT @TotalRecords = COUNT(*)
    FROM Camps c WHERE c.IsDeleted=0
      AND (@CampId IS NULL OR c.Id=@CampId)
      AND (@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId AND ISNULL(cp.IsDeleted,0)=0))
      AND (@OwnerId IS NULL OR EXISTS(SELECT 1 FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.OwnerId=@OwnerId AND oc.IsDeleted=0));

    -- Main result: uses ContractRooms (already aggregated per room)
    SELECT
        c.Id AS CampId,
        c.Code AS CampCode,
        c.Name AS CampName,
        c.Status AS CampStatus,
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0), 0) AS TotalRooms,
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Occupied'), 0) AS OccupiedRooms,
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Vacant'), 0) AS VacantRooms,
        ISNULL((SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0) AS TotalContracts,
        ISNULL((SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr JOIN Contracts ct ON ct.ContractId=cr.ContractId AND ct.Status='Active' AND ct.IsDeleted=0 WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0) AS ActiveContracts,
        ISNULL((SELECT SUM(ISNULL(cr.TotalAmount,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0) AS TotalAmount,
        ISNULL((SELECT SUM(ISNULL(cr.PaidAmount,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0) AS TotalCollected,
        ISNULL((SELECT SUM(ISNULL(cr.Balance,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0) AS TotalDue,
        ISNULL((SELECT COUNT(DISTINCT cp.PartnerId) FROM CampPartners cp WHERE cp.CampId=c.Id AND ISNULL(cp.IsDeleted,0)=0), 0) AS TotalPartners,
        ISNULL((SELECT COUNT(DISTINCT oc.OwnerId) FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.IsDeleted=0), 0) AS TotalOwners
    FROM Camps c
    WHERE c.IsDeleted=0
      AND (@CampId IS NULL OR c.Id=@CampId)
      AND (@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId AND ISNULL(cp.IsDeleted,0)=0))
      AND (@OwnerId IS NULL OR EXISTS(SELECT 1 FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.OwnerId=@OwnerId AND oc.IsDeleted=0))
      AND (@ContractId IS NULL OR EXISTS(SELECT 1 FROM ContractRooms cr WHERE cr.CampId=c.Id AND cr.ContractId=@ContractId AND ISNULL(cr.IsDeleted,0)=0))
    ORDER BY c.Name;

    -- Sub totals
    SELECT
        ISNULL(SUM(s.TotalRooms), 0) AS SubTotalRooms,
        ISNULL(SUM(s.OccupiedRooms), 0) AS SubTotalOccupied,
        ISNULL(SUM(s.VacantRooms), 0) AS SubTotalVacant,
        ISNULL(SUM(s.TotalContracts), 0) AS SubTotalContracts,
        ISNULL(SUM(s.ActiveContracts), 0) AS SubTotalActiveContracts,
        ISNULL(SUM(s.TotalAmount), 0) AS SubTotalAmount,
        ISNULL(SUM(s.TotalCollected), 0) AS SubTotalCollected,
        ISNULL(SUM(s.TotalDue), 0) AS SubTotalDue,
        ISNULL(SUM(s.TotalPartners), 0) AS SubTotalPartners,
        ISNULL(SUM(s.TotalOwners), 0) AS SubTotalOwners
    FROM (
        SELECT
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0) AS TotalRooms,
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Occupied') AS OccupiedRooms,
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Vacant') AS VacantRooms,
            (SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0) AS TotalContracts,
            (SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr JOIN Contracts ct ON ct.ContractId=cr.ContractId AND ct.Status='Active' AND ct.IsDeleted=0 WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0) AS ActiveContracts,
            (SELECT SUM(ISNULL(cr.TotalAmount,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0) AS TotalAmount,
            (SELECT SUM(ISNULL(cr.PaidAmount,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0) AS TotalCollected,
            (SELECT SUM(ISNULL(cr.Balance,0)) FROM ContractRooms cr WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0) AS TotalDue,
            (SELECT COUNT(DISTINCT cp.PartnerId) FROM CampPartners cp WHERE cp.CampId=c.Id AND ISNULL(cp.IsDeleted,0)=0) AS TotalPartners,
            (SELECT COUNT(DISTINCT oc.OwnerId) FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.IsDeleted=0) AS TotalOwners
        FROM Camps c
        WHERE c.IsDeleted=0
          AND (@CampId IS NULL OR c.Id=@CampId)
          AND (@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId AND ISNULL(cp.IsDeleted,0)=0))
          AND (@OwnerId IS NULL OR EXISTS(SELECT 1 FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.OwnerId=@OwnerId AND oc.IsDeleted=0))
    ) s;
END;


(1 rows affected)
