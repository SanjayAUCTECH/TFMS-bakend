
CREATE   PROCEDURE [dbo].[sp_GetDashboardStats]
    @CampId   INT = NULL, @TenantId INT = NULL,
    @Year     INT = NULL, @Month    INT = NULL
AS
BEGIN
     ------------------------------------------------------------
    -- Current Year / Month
    ------------------------------------------------------------
    DECLARE @ThisMonth INT = ISNULL(@Month, MONTH(GETUTCDATE()));
    DECLARE @ThisYear  INT = ISNULL(@Year, YEAR(GETUTCDATE()));

    ------------------------------------------------------------
    -- Convert numeric month to DB Month format
    -- Example:
    -- @Year = 2026, @Month = 7  => Jul26
    -- @Year = 2026, @Month = 8  => Aug26
    ------------------------------------------------------------
    DECLARE @CMPmonth VARCHAR(7) = NULL;

    IF @Month IS NOT NULL AND @Year IS NOT NULL
    BEGIN
        SET @CMPmonth = FORMAT(
                            DATEFROMPARTS(@Year, @Month, 1),
                            'MMMyy'
                        );
    END;


    ------------------------------------------------------------
    -- 1. Dashboard Summary
    ------------------------------------------------------------
    SELECT

        --------------------------------------------------------
        -- Total Camps
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM Camps
            WHERE Status = 'Active'
              AND IsDeleted = 0
              AND (@CampId IS NULL OR Id = @CampId)
        ) AS TotalCamps,


        --------------------------------------------------------
        -- Total Rooms
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM Rooms
            WHERE IsDeleted = 0
              AND (@CampId IS NULL OR CampId = @CampId)
        ) AS TotalRooms,


        --------------------------------------------------------
        -- Occupied Rooms
        -- ContractRoomInstallments.Month = Jul26 / Aug26 / Sep26
        --------------------------------------------------------
        ISNULL(
        (
            SELECT COUNT( cri0.RoomNo)
            FROM ContractRoomInstallments cri0
            WHERE ISNULL(cri0.IsDeleted, 0) = 0
              AND (@CampId IS NULL OR cri0.CampId = @CampId)
              AND
              (
                  @Month IS NULL
                  OR cri0.Month = @CMPmonth
              )
              AND cri0.RoomNo IS NOT NULL
        ), 0) AS OccupiedRooms,


        --------------------------------------------------------
        -- Vacant Rooms
        --------------------------------------------------------
        --(
        --    SELECT COUNT(*)
        --    FROM Rooms
        --    WHERE IsDeleted = 0
        --      AND Status = 'Vacant'
        --      AND (@CampId IS NULL OR CampId = @CampId)
        --) 
		
		 (
            SELECT COUNT(*)
            FROM Rooms
            WHERE IsDeleted = 0
              AND (@CampId IS NULL OR CampId = @CampId)
        )-( ISNULL(
        (
            SELECT COUNT( cri0.RoomNo)
            FROM ContractRoomInstallments cri0
            WHERE ISNULL(cri0.IsDeleted, 0) = 0
              AND (@CampId IS NULL OR cri0.CampId = @CampId)
              AND
              (
                  @Month IS NULL
                  OR cri0.Month = @CMPmonth
              )
              AND cri0.RoomNo IS NOT NULL
        ), 0))
		
		
		AS VacantRooms,


        --------------------------------------------------------
        -- Total Tenants
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM Tenants
            WHERE ISNULL(IsDeleted, 0) = 0
        ) AS TotalTenants,


        --------------------------------------------------------
        -- Active Tenants
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM Tenants
            WHERE ISNULL(IsDeleted, 0) = 0
              AND Status = 'Active'
        ) AS ActiveTenants,


        --------------------------------------------------------
        -- Total Partners
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM Partners
            WHERE ISNULL(IsDeleted, 0) = 0
              AND Status = 'Active'
        ) AS TotalPartners,


        --------------------------------------------------------
        -- Active Contracts
        --------------------------------------------------------
        (
            SELECT COUNT(DISTINCT c.Id)
            FROM Contracts c
            LEFT JOIN ContractCamps cc
                ON cc.ContractId = c.ContractId
            WHERE c.Status = 'Active'
              AND c.IsDeleted = 0
              AND (@CampId IS NULL OR cc.CampId = @CampId)
              AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        ) AS ActiveContracts,


        --------------------------------------------------------
        -- Total Due This Month
        --------------------------------------------------------
        ISNULL(
        (
            SELECT SUM(cri.InstallAmount)
            FROM ContractRoomInstallments cri
            INNER JOIN Contracts c
                ON c.ContractId = cri.ContractId
            WHERE cri.Status = 'Pending'
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND MONTH(cri.DueDate) = @ThisMonth
              AND YEAR(cri.DueDate) = @ThisYear
              AND (@CampId IS NULL OR cri.CampId = @CampId)
              AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        ), 0) AS TotalDueThisMonth,


        --------------------------------------------------------
        -- Total Collected This Month
        --------------------------------------------------------
        ISNULL(
        (
            SELECT SUM(cri.PaidAmount)
            FROM ContractRoomInstallments cri
            INNER JOIN Contracts c
                ON c.ContractId = cri.ContractId
            WHERE cri.Status IN ('Paid', 'PaidPartial')
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND MONTH(cri.DueDate) = @ThisMonth
              AND YEAR(cri.DueDate) = @ThisYear
              AND (@CampId IS NULL OR cri.CampId = @CampId)
              AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        ), 0) AS TotalCollectedThisMonth,


        --------------------------------------------------------
        -- Outstanding Balance
        --------------------------------------------------------
        ISNULL(
        (
            SELECT SUM(cri.Balance)
            FROM ContractRoomInstallments cri
            INNER JOIN Contracts c
                ON c.ContractId = cri.ContractId
            WHERE cri.Status = 'Pending'
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND (@CampId IS NULL OR cri.CampId = @CampId)
              AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        ), 0) AS OutstandingBalance,


        --------------------------------------------------------
        -- Overdue Payments
        --------------------------------------------------------
        (
            SELECT COUNT(*)
            FROM ContractRoomInstallments cri
            INNER JOIN Contracts c
                ON c.ContractId = cri.ContractId
            WHERE cri.Status = 'Pending'
              AND ISNULL(cri.IsDeleted, 0) = 0
              AND cri.DueDate < CAST(GETDATE() AS DATE)
              AND (@CampId IS NULL OR cri.CampId = @CampId)
              AND (@TenantId IS NULL OR c.TenantId = @TenantId)
        ) AS OverduePayments;


    ------------------------------------------------------------
    -- 2. Camp Occupancy
    ------------------------------------------------------------
    --SELECT
    --    ca.Name AS CampName,
    --    COUNT(r.Id) AS TotalRooms,

    --    SUM(
    --        CASE
    --            WHEN r.Status = 'Occupied' THEN 1
    --            ELSE 0
    --        END
    --    ) AS Occupied,

    --    SUM(
    --        CASE
    --            WHEN r.Status = 'Vacant' THEN 1
    --            ELSE 0
    --        END
    --    ) AS Vacant

    --FROM Camps ca

    --LEFT JOIN Rooms r
    --    ON r.CampId = ca.Id
    --   AND r.IsDeleted = 0

    --WHERE ca.Status = 'Active'
    --  AND ca.IsDeleted = 0
    -- -- AND (@CampId IS NULL OR ca.Id = @CampId)

    --GROUP BY
    --    ca.Id,
    --    ca.Name

    --ORDER BY
    --    ca.Name;

	SELECT
    ca.Name AS CampName,

    ------------------------------------------------------------
    -- Total Rooms
    ------------------------------------------------------------
    COUNT(r.Id) AS TotalRooms,

    ------------------------------------------------------------
    -- Occupied Rooms
    -- Data ContractRoomInstallments se
    ------------------------------------------------------------
    ISNULL(
    (
        SELECT COUNT(cri0.RoomNo)
        FROM ContractRoomInstallments cri0
        WHERE ISNULL(cri0.IsDeleted, 0) = 0
          AND cri0.CampId = ca.Id
          AND cri0.RoomNo IS NOT NULL
          AND
          (
              @Month IS NULL
              OR cri0.Month = @CMPmonth
          )
    ), 0) AS Occupied,

    ------------------------------------------------------------
    -- Vacant Rooms
    -- Total Rooms - Occupied Rooms
    ------------------------------------------------------------
    COUNT(r.Id)
    -
    ISNULL(
    (
        SELECT COUNT(cri0.RoomNo)
        FROM ContractRoomInstallments cri0
        WHERE ISNULL(cri0.IsDeleted, 0) = 0
          AND cri0.CampId = ca.Id
          AND cri0.RoomNo IS NOT NULL
          AND
          (
              @Month IS NULL
              OR cri0.Month = @CMPmonth
          )
    ), 0) AS Vacant

FROM Camps ca

LEFT JOIN Rooms r
    ON r.CampId = ca.Id
   AND r.IsDeleted = 0

WHERE ca.Status = 'Active'
  AND ca.IsDeleted = 0
  AND (@CampId IS NULL OR ca.Id = @CampId)

GROUP BY
    ca.Id,
    ca.Name

ORDER BY
    ca.Name;
    ------------------------------------------------------------
    -- 3. Monthly Collections
    ------------------------------------------------------------
    SELECT
        cri.Month AS MonthName,
        SUM(cri.PaidAmount) AS Collected

    FROM ContractRoomInstallments cri

    INNER JOIN Contracts ct
        ON ct.ContractId = cri.ContractId

    WHERE ISNULL(cri.IsDeleted, 0) = 0

      AND cri.Status IN ('Paid', 'PaidPartial')

      AND RIGHT(
            cri.Month,
            2
          ) = RIGHT(
                CAST(@ThisYear AS NVARCHAR(4)),
                2
              )

      AND (@CampId IS NULL OR cri.CampId = @CampId)

      AND (@TenantId IS NULL OR ct.TenantId = @TenantId)

    GROUP BY
        cri.Month

    ORDER BY
        MIN(cri.DueDate);


    ------------------------------------------------------------
    -- 4. Camp Revenue
    ------------------------------------------------------------
    SELECT
        ca.Name AS CampName,

        ISNULL(
            SUM(r.MonthlyPrice),
            0
        ) AS MonthlyRevenue

    FROM Camps ca

    LEFT JOIN Rooms r
        ON r.CampId = ca.Id
       --AND r.Status = 'Occupied'
       AND r.IsDeleted = 0

    WHERE ca.Status = 'Active'
      AND ca.IsDeleted = 0
      AND (@CampId IS NULL OR ca.Id = @CampId)

    GROUP BY
        ca.Id,
        ca.Name

    ORDER BY
        ca.Name;
END

