-- ============================================================
-- 069: sp_GetRoomWiseCollectionReport
--      Room wise collection per camp
--      Tables: Rooms, ContractRoomInstallments, Contracts
-- Date: July 24, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetRoomWiseCollectionReport
    @CampId         INT,                        -- REQUIRED
    @DateFrom       DATE           = NULL,
    @DateTo         DATE           = NULL,
    @Month          NVARCHAR(MAX)  = NULL,       -- format: yyyy-MM e.g. 2026-07
    @ContractStatus NVARCHAR(MAX)  = NULL,       -- Active | Expired | Cancelled
    @RoomStatus     NVARCHAR(MAX)  = NULL,       -- Occupied | Vacant
    @TotalRecords   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count: sirf wahi rooms jinke contract hain
    SELECT @TotalRecords = COUNT(DISTINCT r.Id)
    FROM Rooms r
    INNER JOIN ContractRoomInstallments cri0
           ON cri0.RoomId = r.Id AND cri0.CampId = @CampId
    WHERE r.CampId = @CampId
      AND (@RoomStatus IS NULL OR r.Status = @RoomStatus);

    -- Main result: 1 row per room
    SELECT
        r.Id                                                        RoomId,
        r.RoomNo,
        r.Status                                                    RoomStatus,
        r.MonthlyPrice,
        r.Occupied,

        -- Contract info (latest active contract for this room)
        ISNULL(ct.ContractId, '')                                   ContractId,
        ISNULL(ct.Status,     '')                                   ContractStatus,

        -- Tenant name
        ISNULL(t.Name, '')                                          TenantName,

        -- Total installment amount (filtered)
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)
            THEN cri.InstallAmount ELSE 0 END
        ), 0)                                                       TotalAmount,

        -- Collected (paid amount, filtered)
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)
            THEN cri.PaidAmount ELSE 0 END
        ), 0)                                                       Collected,

        -- Due (balance, filtered)
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri.Month   = @Month)
            THEN cri.Balance ELSE 0 END
        ), 0)                                                       Due,

        -- Last payment date
        MAX(
            CASE WHEN cri.PaidDate IS NOT NULL AND
                 (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                 (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                 (@Month    IS NULL OR cri.Month   = @Month)
            THEN cri.PaidDate ELSE NULL END
        )                                                           LastDate,

        -- Last paid amount (most recent payment)
        ISNULL((
            SELECT TOP 1 cri2.PaidAmount
            FROM ContractRoomInstallments cri2
            WHERE cri2.RoomId = r.Id
              AND cri2.CampId = @CampId
              AND cri2.PaidDate IS NOT NULL
              AND cri2.PaidAmount > 0
              AND (@DateFrom IS NULL OR cri2.DueDate >= @DateFrom)
              AND (@DateTo   IS NULL OR cri2.DueDate <= @DateTo)
              AND (@Month    IS NULL OR cri2.Month   = @Month)
            ORDER BY cri2.PaidDate DESC
        ), 0)                                                       LastAmount,

        -- Overall status for this room
        CASE
            WHEN COUNT(CASE WHEN
                    (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                    (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                    (@Month    IS NULL OR cri.Month   = @Month)
                 THEN cri.Id END) = 0 THEN 'No Installments'
            WHEN SUM(
                    CASE WHEN
                        (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                        (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                        (@Month    IS NULL OR cri.Month   = @Month)
                    THEN cri.Balance ELSE 0 END) = 0  THEN 'Fully Paid'
            WHEN SUM(
                    CASE WHEN
                        (@DateFrom IS NULL OR cri.DueDate >= @DateFrom) AND
                        (@DateTo   IS NULL OR cri.DueDate <= @DateTo)   AND
                        (@Month    IS NULL OR cri.Month   = @Month)
                    THEN cri.PaidAmount ELSE 0 END) = 0 THEN 'Unpaid'
            ELSE 'Partial'
        END                                                         Status

    FROM Rooms r
    -- INNER JOIN: sirf wahi rooms jo ContractRoomInstallments mein hain (contract bana ho)
    INNER JOIN ContractRoomInstallments cri
           ON cri.RoomId = r.Id AND cri.CampId = @CampId
    LEFT JOIN Contracts ct
           ON ct.ContractId = cri.ContractId
          AND (@ContractStatus IS NULL OR ct.Status = @ContractStatus)
    LEFT JOIN Tenants t
           ON t.Id = ct.TenantId

    WHERE r.CampId = @CampId
      AND (@RoomStatus     IS NULL OR r.Status    = @RoomStatus)

    GROUP BY r.Id, r.RoomNo, r.Status, r.MonthlyPrice, r.Occupied,
             ct.ContractId, ct.Status, t.Name
    ORDER BY r.RoomNo;

    -- Summary row
    SELECT
        COUNT(DISTINCT r2.Id)                   TotalRooms,
        COUNT(DISTINCT CASE WHEN r2.Occupied=1
              THEN r2.Id END)                   OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r2.Occupied=0
              THEN r2.Id END)                   VacantRooms,
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri3.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri3.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri3.Month   = @Month)
            THEN cri3.InstallAmount ELSE 0 END
        ), 0)                                   TotalAmount,
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri3.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri3.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri3.Month   = @Month)
            THEN cri3.PaidAmount ELSE 0 END
        ), 0)                                   TotalCollected,
        ISNULL(SUM(
            CASE WHEN
                (@DateFrom IS NULL OR cri3.DueDate >= @DateFrom) AND
                (@DateTo   IS NULL OR cri3.DueDate <= @DateTo)   AND
                (@Month    IS NULL OR cri3.Month   = @Month)
            THEN cri3.Balance ELSE 0 END
        ), 0)                                   TotalDue
    FROM Rooms r2
    -- INNER JOIN: sirf wahi rooms jo ContractRoomInstallments mein hain
    INNER JOIN ContractRoomInstallments cri3
           ON cri3.RoomId = r2.Id AND cri3.CampId = @CampId
    LEFT JOIN Contracts ct2
           ON ct2.ContractId = cri3.ContractId
          AND (@ContractStatus IS NULL OR ct2.Status = @ContractStatus)
    WHERE r2.CampId = @CampId
      AND (@RoomStatus IS NULL OR r2.Status = @RoomStatus);
END
GO

PRINT '069 - sp_GetRoomWiseCollectionReport created';
GO
