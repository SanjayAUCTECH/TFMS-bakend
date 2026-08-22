SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetRoomWiseCollectionReport
    @CampId         INT,
    @DateFrom       DATE           = NULL,
    @DateTo         DATE           = NULL,
    @Month          NVARCHAR(7)    = NULL,   -- format: yyyy-MM
    @ContractStatus NVARCHAR(50)   = NULL,
    @RoomStatus     NVARCHAR(50)   = NULL,
    @ContractId     NVARCHAR(50)   = NULL,   -- NEW: filter by specific contract
    @PageNumber     INT            = 1,       -- NEW: pagination
    @PageSize       INT            = 2147483647, -- NEW: default = all rows
    @TotalRecords   INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Total count (before pagination) ──────────────────────────────────────
    SELECT @TotalRecords = COUNT(DISTINCT r.Id)
    FROM Rooms r
    LEFT JOIN ContractRoomInstallments cri
           ON cri.RoomId  = r.Id
          AND cri.CampId  = @CampId
          AND ISNULL(cri.IsDeleted, 0) = 0
    LEFT JOIN Contracts ct
           ON ct.ContractId = cri.ContractId
          AND ct.IsDeleted  = 0
    WHERE r.CampId    = @CampId
      AND r.IsDeleted = 0
      AND (@RoomStatus     IS NULL OR r.Status     = @RoomStatus)
      AND (@ContractStatus IS NULL OR ct.Status    = @ContractStatus)
      AND (@ContractId     IS NULL OR cri.ContractId = @ContractId);

    -- ── Main rows (with pagination + ContractId filter) ───────────────────────
    SELECT
        r.Id                           AS RoomId,
        r.RoomNo,
        r.Status                       AS RoomStatus,
        r.MonthlyPrice,
        r.Occupied,
        ISNULL(ct.ContractId, '')      AS ContractId,
        ISNULL(ct.Status,     '')      AS ContractStatus,
        ISNULL(t.Name,        '')      AS TenantName,

        -- TotalAmount filtered by date/month
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.InstallAmount ELSE 0 END), 0)  AS TotalAmount,

        -- Collected filtered by date/month
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.PaidAmount ELSE 0 END), 0)     AS Collected,

        -- Due filtered by date/month
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.Balance ELSE 0 END), 0)        AS Due,

        MAX(cri.PaidDate)              AS LastDate,
        ISNULL(MAX(cri.PaidAmount), 0) AS LastAmount,

        -- Status derived
        CASE
            WHEN SUM(CASE
                     WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
                      AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
                      AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
                     THEN cri.InstallAmount ELSE 0 END) = 0
                 THEN 'Vacant'
            WHEN SUM(CASE
                     WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
                      AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
                      AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
                     THEN cri.Balance ELSE 0 END) = 0
                 THEN 'Fully Paid'
            WHEN SUM(CASE
                     WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
                      AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
                      AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
                     THEN cri.PaidAmount ELSE 0 END) > 0
                 THEN 'Partial'
            ELSE 'Pending'
        END AS Status

    FROM Rooms r
    LEFT JOIN ContractRoomInstallments cri
           ON cri.RoomId  = r.Id
          AND cri.CampId  = @CampId
          AND ISNULL(cri.IsDeleted, 0) = 0
    LEFT JOIN Contracts ct
           ON ct.ContractId = cri.ContractId
          AND ct.IsDeleted  = 0
          AND (@ContractStatus IS NULL OR ct.Status = @ContractStatus)
    LEFT JOIN Tenants t
           ON t.Id        = ct.TenantId
          AND t.IsDeleted = 0
    WHERE r.CampId    = @CampId
      AND r.IsDeleted = 0
      AND (@RoomStatus IS NULL OR r.Status      = @RoomStatus)
      AND (@ContractId IS NULL OR cri.ContractId = @ContractId)
    GROUP BY r.Id, r.RoomNo, r.Status, r.MonthlyPrice, r.Occupied,
             ct.ContractId, ct.Status, t.Name
    ORDER BY
        TRY_CAST(r.RoomNo AS INT),   -- numeric rooms first: 1,2,3...10,11
        r.RoomNo                      -- fallback for alphanumeric: A1, B2...
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- ── Summary (date/month + ContractId filters applied) ─────────────────────
    SELECT
        COUNT(DISTINCT r.Id)                                                     AS TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied = 1 THEN r.Id END)                  AS OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied = 0 THEN r.Id END)                  AS VacantRooms,
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.InstallAmount ELSE 0 END), 0)                              AS TotalAmount,
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.PaidAmount ELSE 0 END), 0)                                 AS TotalCollected,
        ISNULL(SUM(CASE
            WHEN (@DateFrom IS NULL OR cri.DueDate >= @DateFrom)
             AND (@DateTo   IS NULL OR cri.DueDate <= @DateTo)
             AND (@Month    IS NULL OR FORMAT(cri.DueDate, 'yyyy-MM') = @Month)
            THEN cri.Balance ELSE 0 END), 0)                                    AS TotalDue
    FROM Rooms r
    LEFT JOIN ContractRoomInstallments cri
           ON cri.RoomId  = r.Id
          AND cri.CampId  = @CampId
          AND ISNULL(cri.IsDeleted, 0) = 0
    LEFT JOIN Contracts ct
           ON ct.ContractId = cri.ContractId
          AND ct.IsDeleted  = 0
    WHERE r.CampId    = @CampId
      AND r.IsDeleted = 0
      AND (@RoomStatus     IS NULL OR r.Status      = @RoomStatus)
      AND (@ContractStatus IS NULL OR ct.Status     = @ContractStatus)
      AND (@ContractId     IS NULL OR cri.ContractId = @ContractId);
END;
GO

PRINT 'sp_GetRoomWiseCollectionReport: PageNumber, PageSize, ContractId filter added + Summary date filter fixed.';
GO
