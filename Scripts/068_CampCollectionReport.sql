-- ============================================================
-- 068: sp_GetCampCollectionReport
--      Camp wise collection report
--      Tables: Camps, Rooms, ContractRoomInstallments,
--              Contracts, ContractCamps, CampPartners, OwnerContracts
-- Date: July 24, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetCampCollectionReport
    @CampId      INT            = NULL,
    @PartnerId   INT            = NULL,
    @OwnerId     INT            = NULL,
    @ContractId  NVARCHAR(MAX)  = NULL,
    @DateFrom    DATE           = NULL,
    @DateTo      DATE           = NULL,
    @Month       NVARCHAR(MAX)  = NULL,   -- format: yyyy-MM
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Main camp-wise aggregation ─────────────────────────────────────
    SELECT @TotalRecords = COUNT(DISTINCT c.Id)
    FROM Camps c
    WHERE (@CampId IS NULL OR c.Id = @CampId)
      AND (@PartnerId IS NULL OR EXISTS (
              SELECT 1 FROM CampPartners cp WHERE cp.CampId = c.Id AND cp.PartnerId = @PartnerId))
      AND (@OwnerId IS NULL OR EXISTS (
              SELECT 1 FROM OwnerContracts oc WHERE oc.CampId = c.Id AND oc.OwnerId = @OwnerId));

    -- ── Main result set ───────────────────────────────────────────────
    SELECT
        c.Id                                                        CampId,
        c.Code                                                      CampCode,
        c.Name                                                      CampName,
        c.Status                                                    CampStatus,

        -- Room stats
        COUNT(DISTINCT r.Id)                                        TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied = 1 THEN r.Id END)      OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied = 0 THEN r.Id END)      VacantRooms,

        -- Contract stats (unique ContractId from ContractRoomInstallments)
        COUNT(DISTINCT cri.ContractId)                              TotalContracts,
        COUNT(DISTINCT CASE WHEN ct.Status = 'Active' THEN ct.ContractId END) ActiveContracts,

        -- Installment amount stats (filtered by date/month)
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)     AND
                (@ContractId IS NULL OR cri.ContractId = @ContractId)
            THEN cri.InstallAmount ELSE 0 END
        ), 0)                                                       TotalAmount,

        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)     AND
                (@ContractId IS NULL OR cri.ContractId = @ContractId)
            THEN cri.PaidAmount ELSE 0 END
        ), 0)                                                       TotalCollected,

        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)     AND
                (@ContractId IS NULL OR cri.ContractId = @ContractId)
            THEN cri.Balance ELSE 0 END
        ), 0)                                                       TotalDue,

        -- Partner count
        (SELECT COUNT(DISTINCT cp.PartnerId)
         FROM CampPartners cp WHERE cp.CampId = c.Id)              TotalPartners,

        -- Owner count
        (SELECT COUNT(DISTINCT oc.OwnerId)
         FROM OwnerContracts oc WHERE oc.CampId = c.Id)            TotalOwners

    FROM Camps c
    LEFT JOIN Rooms r
           ON r.CampId = c.Id
    LEFT JOIN ContractRoomInstallments cri
           ON cri.CampId = c.Id
    LEFT JOIN Contracts ct
           ON ct.ContractId = cri.ContractId

    WHERE (@CampId IS NULL OR c.Id = @CampId)
      AND (@PartnerId IS NULL OR EXISTS (
              SELECT 1 FROM CampPartners cp2 WHERE cp2.CampId = c.Id AND cp2.PartnerId = @PartnerId))
      AND (@OwnerId IS NULL OR EXISTS (
              SELECT 1 FROM OwnerContracts oc2 WHERE oc2.CampId = c.Id AND oc2.OwnerId = @OwnerId))

    GROUP BY c.Id, c.Code, c.Name, c.Status
    ORDER BY c.Name;

    -- ── Summary (subtotals) ───────────────────────────────────────────
    SELECT
        SUM(TotalRooms)       SubTotalRooms,
        SUM(OccupiedRooms)    SubTotalOccupied,
        SUM(VacantRooms)      SubTotalVacant,
        SUM(TotalContracts)   SubTotalContracts,
        SUM(ActiveContracts)  SubTotalActiveContracts,
        SUM(TotalAmount)      SubTotalAmount,
        SUM(TotalCollected)   SubTotalCollected,
        SUM(TotalDue)         SubTotalDue,
        SUM(TotalPartners)    SubTotalPartners,
        SUM(TotalOwners)      SubTotalOwners
    FROM (
        SELECT
            COUNT(DISTINCT r2.Id)                                       TotalRooms,
            COUNT(DISTINCT CASE WHEN r2.Occupied=1 THEN r2.Id END)      OccupiedRooms,
            COUNT(DISTINCT CASE WHEN r2.Occupied=0 THEN r2.Id END)      VacantRooms,
            COUNT(DISTINCT cri2.ContractId)                             TotalContracts,
            COUNT(DISTINCT CASE WHEN ct2.Status='Active' THEN ct2.ContractId END) ActiveContracts,
            ISNULL(SUM(CASE WHEN
                (@DateFrom IS NULL OR cri2.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri2.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri2.Month   = @Month)     AND
                (@ContractId IS NULL OR cri2.ContractId = @ContractId)
            THEN cri2.InstallAmount ELSE 0 END), 0)                     TotalAmount,
            ISNULL(SUM(CASE WHEN
                (@DateFrom IS NULL OR cri2.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri2.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri2.Month   = @Month)     AND
                (@ContractId IS NULL OR cri2.ContractId = @ContractId)
            THEN cri2.PaidAmount ELSE 0 END), 0)                        TotalCollected,
            ISNULL(SUM(CASE WHEN
                (@DateFrom IS NULL OR cri2.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri2.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri2.Month   = @Month)     AND
                (@ContractId IS NULL OR cri2.ContractId = @ContractId)
            THEN cri2.Balance ELSE 0 END), 0)                           TotalDue,
            (SELECT COUNT(DISTINCT cp3.PartnerId) FROM CampPartners cp3 WHERE cp3.CampId=c2.Id) TotalPartners,
            (SELECT COUNT(DISTINCT oc3.OwnerId)   FROM OwnerContracts oc3 WHERE oc3.CampId=c2.Id) TotalOwners
        FROM Camps c2
        LEFT JOIN Rooms r2               ON r2.CampId  = c2.Id
        LEFT JOIN ContractRoomInstallments cri2 ON cri2.CampId = c2.Id
        LEFT JOIN Contracts ct2          ON ct2.ContractId = cri2.ContractId
        WHERE (@CampId     IS NULL OR c2.Id = @CampId)
          AND (@PartnerId  IS NULL OR EXISTS (SELECT 1 FROM CampPartners cp4 WHERE cp4.CampId=c2.Id AND cp4.PartnerId=@PartnerId))
          AND (@OwnerId    IS NULL OR EXISTS (SELECT 1 FROM OwnerContracts oc4 WHERE oc4.CampId=c2.Id AND oc4.OwnerId=@OwnerId))
        GROUP BY c2.Id
    ) sub;
END
GO

PRINT '068 - sp_GetCampCollectionReport created';
GO
