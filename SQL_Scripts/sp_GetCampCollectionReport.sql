SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetCampCollectionReport
    @CampId     INT            = NULL,
    @PartnerId  INT            = NULL,
    @OwnerId    INT            = NULL,
    @ContractId NVARCHAR(MAX)  = NULL,
    @DateFrom   DATE           = NULL,
    @DateTo     DATE           = NULL,
    @Month      NVARCHAR(7)    = NULL,   -- format: yyyy-MM
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve effective date range from @Month or @DateFrom/@DateTo
    -- If @Month supplied (e.g. '2026-07'), override DateFrom/DateTo for CRI filter
    DECLARE @EffDateFrom DATE = @DateFrom;
    DECLARE @EffDateTo   DATE = @DateTo;

    IF @Month IS NOT NULL
    BEGIN
        SET @EffDateFrom = CAST(@Month + '-01' AS DATE);
        SET @EffDateTo   = EOMONTH(CAST(@Month + '-01' AS DATE));
    END;

    -- ── Count ──────────────────────────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM Camps c
    WHERE c.IsDeleted = 0
      AND (@CampId    IS NULL OR c.Id = @CampId)
      AND (@PartnerId IS NULL OR EXISTS (
              SELECT 1 FROM CampPartners cp
              WHERE cp.CampId = c.Id AND cp.PartnerId = @PartnerId AND ISNULL(cp.IsDeleted,0) = 0))
      AND (@OwnerId   IS NULL OR EXISTS (
              SELECT 1 FROM OwnerContracts oc
              WHERE oc.CampId = c.Id AND oc.OwnerId = @OwnerId AND oc.IsDeleted = 0));

    -- ── Result Set 1: Camp-wise rows ───────────────────────────────────────────
    SELECT
        c.Id     AS CampId,
        c.Code   AS CampCode,
        c.Name   AS CampName,
        c.Status AS CampStatus,

        -- Room counts (not date-filtered — these are current room states)
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0), 0)                          AS TotalRooms,
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Occupied'), 0)  AS OccupiedRooms,
        ISNULL((SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Vacant'), 0)    AS VacantRooms,

        -- Contract counts
        ISNULL((SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr
                WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0)                                           AS TotalContracts,
        ISNULL((SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr
                JOIN Contracts ct ON ct.ContractId=cr.ContractId AND ct.Status='Active' AND ct.IsDeleted=0
                WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0)                                           AS ActiveContracts,

        -- TotalAmount from ContractRooms
        ISNULL((SELECT SUM(ISNULL(cr.TotalAmount,0)) FROM ContractRooms cr
                WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0), 0)                                           AS TotalAmount,

        -- TotalCollected: CRI Status IN ('Paid','PaidPartial') filtered by date
        ISNULL((
            SELECT SUM(ISNULL(cri.PaidAmount, 0))
            FROM ContractRoomInstallments cri
            INNER JOIN ContractRooms cr ON cr.ContractId = cri.ContractId
                                       AND cr.RoomId     = cri.RoomId
                                       AND ISNULL(cr.IsDeleted, 0) = 0
            WHERE cr.CampId              = c.Id
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND cri.Status IN ('Paid', 'PaidPartial')
              AND (@EffDateFrom IS NULL OR cri.PaidDate >= @EffDateFrom)
              AND (@EffDateTo   IS NULL OR cri.PaidDate <= @EffDateTo)
        ), 0) AS TotalCollected,

        -- TotalAdvance: CRI Status IN ('Advanced','AdvancedPartial') filtered by date
        ISNULL((
            SELECT SUM(ISNULL(cri2.PaidAmount, 0))
            FROM ContractRoomInstallments cri2
            INNER JOIN ContractRooms cr2 ON cr2.ContractId = cri2.ContractId
                                        AND cr2.RoomId     = cri2.RoomId
                                        AND ISNULL(cr2.IsDeleted, 0) = 0
            WHERE cr2.CampId              = c.Id
              AND ISNULL(cri2.IsDeleted, 0) = 0
              AND cri2.Status IN ('Advanced', 'AdvancedPartial')
              AND (@EffDateFrom IS NULL OR cri2.PaidDate >= @EffDateFrom)
              AND (@EffDateTo   IS NULL OR cri2.PaidDate <= @EffDateTo)
        ), 0) AS TotalAdvance,

        -- TotalDue from ContractRooms balance
        ISNULL((SELECT SUM(ISNULL(cr3.Balance,0)) FROM ContractRooms cr3
                WHERE cr3.CampId=c.Id AND ISNULL(cr3.IsDeleted,0)=0), 0)                                         AS TotalDue,

        ISNULL((SELECT COUNT(DISTINCT cp.PartnerId) FROM CampPartners cp
                WHERE cp.CampId=c.Id AND ISNULL(cp.IsDeleted,0)=0), 0)                                           AS TotalPartners,
        ISNULL((SELECT COUNT(DISTINCT oc.OwnerId) FROM OwnerContracts oc
                WHERE oc.CampId=c.Id AND oc.IsDeleted=0), 0)                                                     AS TotalOwners

    FROM Camps c
    WHERE c.IsDeleted = 0
      AND (@CampId     IS NULL OR c.Id = @CampId)
      AND (@PartnerId  IS NULL OR EXISTS (
              SELECT 1 FROM CampPartners cp
              WHERE cp.CampId = c.Id AND cp.PartnerId = @PartnerId AND ISNULL(cp.IsDeleted,0) = 0))
      AND (@OwnerId    IS NULL OR EXISTS (
              SELECT 1 FROM OwnerContracts oc
              WHERE oc.CampId = c.Id AND oc.OwnerId = @OwnerId AND oc.IsDeleted = 0))
      AND (@ContractId IS NULL OR EXISTS (
              SELECT 1 FROM ContractRooms cr
              WHERE cr.CampId = c.Id AND cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted,0) = 0))
    ORDER BY c.Name;

    -- ── Result Set 2: Sub-totals (same filters + date applied) ─────────────────
    SELECT
        ISNULL(SUM(s.TotalRooms),           0) AS SubTotalRooms,
        ISNULL(SUM(s.OccupiedRooms),        0) AS SubTotalOccupied,
        ISNULL(SUM(s.VacantRooms),          0) AS SubTotalVacant,
        ISNULL(SUM(s.TotalContracts),       0) AS SubTotalContracts,
        ISNULL(SUM(s.ActiveContracts),      0) AS SubTotalActiveContracts,
        ISNULL(SUM(s.TotalAmount),          0) AS SubTotalAmount,
        ISNULL(SUM(s.TotalCollected),       0) AS SubTotalCollected,
        ISNULL(SUM(s.TotalAdvance),         0) AS SubTotalAdvance,
        ISNULL(SUM(s.TotalDue),             0) AS SubTotalDue,
        ISNULL(SUM(s.TotalPartners),        0) AS SubTotalPartners,
        ISNULL(SUM(s.TotalOwners),          0) AS SubTotalOwners
    FROM (
        SELECT
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0)                                 AS TotalRooms,
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Occupied')         AS OccupiedRooms,
            (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=c.Id AND r.IsDeleted=0 AND r.Status='Vacant')           AS VacantRooms,
            (SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr
             WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0)                                                  AS TotalContracts,
            (SELECT COUNT(DISTINCT cr.ContractId) FROM ContractRooms cr
             JOIN Contracts ct ON ct.ContractId=cr.ContractId AND ct.Status='Active' AND ct.IsDeleted=0
             WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0)                                                  AS ActiveContracts,
            (SELECT SUM(ISNULL(cr.TotalAmount,0)) FROM ContractRooms cr
             WHERE cr.CampId=c.Id AND ISNULL(cr.IsDeleted,0)=0)                                                  AS TotalAmount,
            -- TotalCollected (date-filtered)
            ISNULL((SELECT SUM(ISNULL(cri.PaidAmount,0))
                    FROM ContractRoomInstallments cri
                    INNER JOIN ContractRooms cr ON cr.ContractId=cri.ContractId AND cr.RoomId=cri.RoomId AND ISNULL(cr.IsDeleted,0)=0
                    WHERE cr.CampId=c.Id AND ISNULL(cri.IsDeleted,0)=0
                      AND cri.Status IN ('Paid','PaidPartial')
                      AND (@EffDateFrom IS NULL OR cri.PaidDate >= @EffDateFrom)
                      AND (@EffDateTo   IS NULL OR cri.PaidDate <= @EffDateTo)
                   ), 0)                                                                                          AS TotalCollected,
            -- TotalAdvance (date-filtered)
            ISNULL((SELECT SUM(ISNULL(cri2.PaidAmount,0))
                    FROM ContractRoomInstallments cri2
                    INNER JOIN ContractRooms cr2 ON cr2.ContractId=cri2.ContractId AND cr2.RoomId=cri2.RoomId AND ISNULL(cr2.IsDeleted,0)=0
                    WHERE cr2.CampId=c.Id AND ISNULL(cri2.IsDeleted,0)=0
                      AND cri2.Status IN ('Advanced','AdvancedPartial')
                      AND (@EffDateFrom IS NULL OR cri2.PaidDate >= @EffDateFrom)
                      AND (@EffDateTo   IS NULL OR cri2.PaidDate <= @EffDateTo)
                   ), 0)                                                                                          AS TotalAdvance,
            (SELECT SUM(ISNULL(cr3.Balance,0)) FROM ContractRooms cr3
             WHERE cr3.CampId=c.Id AND ISNULL(cr3.IsDeleted,0)=0)                                                AS TotalDue,
            (SELECT COUNT(DISTINCT cp.PartnerId) FROM CampPartners cp
             WHERE cp.CampId=c.Id AND ISNULL(cp.IsDeleted,0)=0)                                                  AS TotalPartners,
            (SELECT COUNT(DISTINCT oc.OwnerId) FROM OwnerContracts oc
             WHERE oc.CampId=c.Id AND oc.IsDeleted=0)                                                            AS TotalOwners
        FROM Camps c
        WHERE c.IsDeleted = 0
          AND (@CampId    IS NULL OR c.Id = @CampId)
          AND (@PartnerId IS NULL OR EXISTS (
                  SELECT 1 FROM CampPartners cp
                  WHERE cp.CampId = c.Id AND cp.PartnerId = @PartnerId AND ISNULL(cp.IsDeleted,0) = 0))
          AND (@OwnerId   IS NULL OR EXISTS (
                  SELECT 1 FROM OwnerContracts oc
                  WHERE oc.CampId = c.Id AND oc.OwnerId = @OwnerId AND oc.IsDeleted = 0))
    ) s;

    -- ── Result Set 3: Summary Cards (grand totals across all filtered camps) ───
    SELECT
        -- Overall collected (Paid + PaidPartial from CRI, date-filtered)
        ISNULL((
            SELECT SUM(ISNULL(cri.PaidAmount, 0))
            FROM ContractRoomInstallments cri
            INNER JOIN ContractRooms cr ON cr.ContractId = cri.ContractId
                                       AND cr.RoomId     = cri.RoomId
                                       AND ISNULL(cr.IsDeleted, 0) = 0
            INNER JOIN Camps c ON c.Id = cr.CampId AND c.IsDeleted = 0
            WHERE ISNULL(cri.IsDeleted, 0) = 0
              AND cri.Status IN ('Paid', 'PaidPartial')
              AND (@CampId    IS NULL OR c.Id = @CampId)
              AND (@PartnerId IS NULL OR EXISTS (
                      SELECT 1 FROM CampPartners cp
                      WHERE cp.CampId = c.Id AND cp.PartnerId = @PartnerId AND ISNULL(cp.IsDeleted,0) = 0))
              AND (@OwnerId   IS NULL OR EXISTS (
                      SELECT 1 FROM OwnerContracts oc
                      WHERE oc.CampId = c.Id AND oc.OwnerId = @OwnerId AND oc.IsDeleted = 0))
              AND (@EffDateFrom IS NULL OR cri.PaidDate >= @EffDateFrom)
              AND (@EffDateTo   IS NULL OR cri.PaidDate <= @EffDateTo)
        ), 0) AS GrandTotalCollected,

        -- Overall advance (Advanced + AdvancedPartial from CRI, date-filtered)
        ISNULL((
            SELECT SUM(ISNULL(cri2.PaidAmount, 0))
            FROM ContractRoomInstallments cri2
            INNER JOIN ContractRooms cr2 ON cr2.ContractId = cri2.ContractId
                                        AND cr2.RoomId     = cri2.RoomId
                                        AND ISNULL(cr2.IsDeleted, 0) = 0
            INNER JOIN Camps c2 ON c2.Id = cr2.CampId AND c2.IsDeleted = 0
            WHERE ISNULL(cri2.IsDeleted, 0) = 0
              AND cri2.Status IN ('Advanced', 'AdvancedPartial')
              AND (@CampId    IS NULL OR c2.Id = @CampId)
              AND (@PartnerId IS NULL OR EXISTS (
                      SELECT 1 FROM CampPartners cp2
                      WHERE cp2.CampId = c2.Id AND cp2.PartnerId = @PartnerId AND ISNULL(cp2.IsDeleted,0) = 0))
              AND (@OwnerId   IS NULL OR EXISTS (
                      SELECT 1 FROM OwnerContracts oc2
                      WHERE oc2.CampId = c2.Id AND oc2.OwnerId = @OwnerId AND oc2.IsDeleted = 0))
              AND (@EffDateFrom IS NULL OR cri2.PaidDate >= @EffDateFrom)
              AND (@EffDateTo   IS NULL OR cri2.PaidDate <= @EffDateTo)
        ), 0) AS GrandTotalAdvance,

        -- Grand total due (from ContractRooms balance — not date-filtered, shows current outstanding)
        ISNULL((
            SELECT SUM(ISNULL(cr3.Balance, 0))
            FROM ContractRooms cr3
            INNER JOIN Camps c3 ON c3.Id = cr3.CampId AND c3.IsDeleted = 0
            WHERE ISNULL(cr3.IsDeleted, 0) = 0
              AND (@CampId    IS NULL OR c3.Id = @CampId)
              AND (@PartnerId IS NULL OR EXISTS (
                      SELECT 1 FROM CampPartners cp3
                      WHERE cp3.CampId = c3.Id AND cp3.PartnerId = @PartnerId AND ISNULL(cp3.IsDeleted,0) = 0))
              AND (@OwnerId   IS NULL OR EXISTS (
                      SELECT 1 FROM OwnerContracts oc3
                      WHERE oc3.CampId = c3.Id AND oc3.OwnerId = @OwnerId AND oc3.IsDeleted = 0))
        ), 0) AS GrandTotalDue,

        -- Total camps in result
        (SELECT COUNT(*) FROM Camps c4
         WHERE c4.IsDeleted = 0
           AND (@CampId    IS NULL OR c4.Id = @CampId)
           AND (@PartnerId IS NULL OR EXISTS (
                   SELECT 1 FROM CampPartners cp4
                   WHERE cp4.CampId = c4.Id AND cp4.PartnerId = @PartnerId AND ISNULL(cp4.IsDeleted,0) = 0))
           AND (@OwnerId   IS NULL OR EXISTS (
                   SELECT 1 FROM OwnerContracts oc4
                   WHERE oc4.CampId = c4.Id AND oc4.OwnerId = @OwnerId AND oc4.IsDeleted = 0))
        ) AS TotalCamps;
END;
GO

PRINT 'sp_GetCampCollectionReport: CRI-based TotalCollected + TotalAdvance with date filter + Cards result set added.';
GO
