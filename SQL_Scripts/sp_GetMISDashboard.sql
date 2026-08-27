SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ============================================================
-- sp_GetMISDashboard
-- MIS Dashboard — 3 Result Sets:
--   RS1: Collection data per camp (for Collection Table)
--   RS2: Expense category per camp (for Expense Table)
--   RS3: Summary cards (TotalCollection, TotalExpense, TotalUnits, TotalOccupied)
--
-- Filters: @CampId (optional), @Month format 'yyyy-MM' (optional)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetMISDashboard
    @CampId  INT           = NULL,
    @Month   NVARCHAR(7)   = NULL    -- format: '2026-07'
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve month boundaries
    DECLARE @DateFrom DATE = NULL;
    DECLARE @DateTo   DATE = NULL;
    DECLARE @CriMonth NVARCHAR(10) = NULL;  -- CRI Month format: 'Jul26'

    IF @Month IS NOT NULL
    BEGIN
        SET @DateFrom = CAST(@Month + '-01' AS DATE);
        SET @DateTo   = EOMONTH(CAST(@Month + '-01' AS DATE));
        -- Convert to CRI Month label: 'Jul26'
        SET @CriMonth = LEFT(DATENAME(MONTH, @DateFrom), 3)
                        + RIGHT(CAST(YEAR(@DateFrom) AS NVARCHAR(4)), 2);
    END;

    -- ═══════════════════════════════════════════════════════
    -- RS1: Collection per Camp
    -- ═══════════════════════════════════════════════════════
    SELECT
        c.Id                                                            AS CampId,
        c.Code                                                          AS CampCode,
        c.Name                                                          AS CampName,

        -- Total Rooms
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.CampId=c.Id AND r.IsDeleted=0), 0)             AS NetUnits,

        -- Occupied Rooms
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.CampId=c.Id AND r.IsDeleted=0
                  AND r.Status='Occupied'), 0)                         AS Occupied,

        -- Vacant Rooms
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.CampId=c.Id AND r.IsDeleted=0
                  AND r.Status='Vacant'), 0)                           AS Vacant,

        -- Average Rent (occupied rooms)
        ISNULL((SELECT AVG(r.MonthlyPrice) FROM Rooms r
                WHERE r.CampId=c.Id AND r.IsDeleted=0
                  AND r.Status='Occupied'), 0)                         AS AvgRent,

        -- Rental = SUM of InstallAmount for the month (all CRI records)
        ISNULL((SELECT SUM(cri.InstallAmount)
                FROM ContractRoomInstallments cri
                WHERE cri.CampId=c.Id AND ISNULL(cri.IsDeleted,0)=0
                  AND (@CriMonth IS NULL OR cri.Month=@CriMonth)
               ), 0)                                                    AS Rental,

        -- Collected = Paid + PaidPartial PaidAmount
        ISNULL((SELECT SUM(cri2.PaidAmount)
                FROM ContractRoomInstallments cri2
                WHERE cri2.CampId=c.Id AND ISNULL(cri2.IsDeleted,0)=0
                  AND cri2.Status IN ('Paid','PaidPartial')
                  AND (@CriMonth IS NULL OR cri2.Month=@CriMonth)
               ), 0)                                                    AS Collected,

        -- Discount = Waiver amount for the month
        ISNULL((SELECT SUM(w.WaiverAmount)
                FROM Waivers w
                JOIN ContractRoomInstallments cri3
                     ON cri3.ContractId = w.ContractId
                     AND cri3.InstallmentNo = w.InstallmentNo
                     AND cri3.CampId = c.Id
                     AND ISNULL(cri3.IsDeleted,0)=0
                     AND (@CriMonth IS NULL OR cri3.Month=@CriMonth)
                WHERE ISNULL(w.IsDeleted,0)=0
               ), 0)                                                    AS Discount,

        -- Balance = Pending balance (outstanding)
        ISNULL((SELECT SUM(cri4.Balance)
                FROM ContractRoomInstallments cri4
                WHERE cri4.CampId=c.Id AND ISNULL(cri4.IsDeleted,0)=0
                  AND cri4.Status='Pending'
                  AND (@CriMonth IS NULL OR cri4.Month=@CriMonth)
               ), 0)                                                    AS Balance,

        -- ReceivedSD = Security deposit payments received
        -- ContractRoomsTrns se: TxnType='SD-CR', CampId match, date filter
        ISNULL((SELECT SUM(crt.Amount)
                FROM ContractRoomsTrns crt
                WHERE ISNULL(crt.IsDeleted, 0) = 0
                  AND crt.TxnType = 'SD-CR'
                  AND crt.CampId = c.Id
                  AND (@DateFrom IS NULL OR crt.TxnDate >= @DateFrom)
                  AND (@DateTo   IS NULL OR crt.TxnDate <= @DateTo)
               ), 0)                                                    AS ReceivedSD

    FROM Camps c
    WHERE c.IsDeleted = 0
      AND (@CampId IS NULL OR c.Id = @CampId)
    ORDER BY c.Name;

    -- ═══════════════════════════════════════════════════════
    -- RS2: Expense by Category (Head) per Camp — Pivot style
    -- Row = expense head/category
    -- BIFURCATION = grand total of all heads (first row)
    -- ═══════════════════════════════════════════════════════
    SELECT Category, Total, TotalFiltered FROM (
        -- BIFURCATION: total of ALL expense heads (shown first)
        SELECT
            'BIFURCATION'                                               AS Category,
            ISNULL(SUM(e.Amount), 0)                                    AS Total,
            ISNULL(SUM(e.Amount), 0)                                    AS TotalFiltered,
            0                                                           AS SortOrder
        FROM Expenses e
        WHERE e.IsDeleted = 0
          AND ISNULL(e.Head,'') <> ''
          AND ISNULL(e.Head,'') <> 'Partner Profit'
          AND (@CampId   IS NULL OR e.CampId = @CampId)
          AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
          AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)

        UNION ALL

        -- Individual heads
        SELECT
            e.Head                                                      AS Category,
            ISNULL(SUM(e.Amount), 0)                                    AS Total,
            ISNULL(SUM(CASE WHEN c.Name IS NOT NULL
                            THEN e.Amount ELSE 0 END), 0)               AS TotalFiltered,
            1                                                           AS SortOrder
        FROM Expenses e
        LEFT JOIN Camps c ON c.Id = e.CampId AND c.IsDeleted = 0
        WHERE e.IsDeleted = 0
          AND ISNULL(e.Head,'') <> ''
          AND ISNULL(e.Head,'') <> 'Partner Profit'
          AND (@CampId   IS NULL OR e.CampId = @CampId)
          AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
          AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)
        GROUP BY e.Head
    ) x
    ORDER BY x.SortOrder, x.Total DESC;

    -- ═══════════════════════════════════════════════════════
    -- RS3: Expense detail per camp per category (for pivot)
    -- BIFURCATION = camp-wise total of all heads (first)
    -- ═══════════════════════════════════════════════════════
    SELECT Category, CampId, CampName, Amount, SortOrder FROM (
        -- BIFURCATION: per-camp total of ALL heads
        SELECT
            'BIFURCATION'           AS Category,
            e.CampId,
            ISNULL(c.Name, '')      AS CampName,
            ISNULL(SUM(e.Amount),0) AS Amount,
            0                       AS SortOrder
        FROM Expenses e
        LEFT JOIN Camps c ON c.Id = e.CampId AND c.IsDeleted = 0
        WHERE e.IsDeleted = 0
          AND ISNULL(e.Head,'') <> ''
          AND ISNULL(e.Head,'') <> 'Partner Profit'
          AND (@CampId   IS NULL OR e.CampId = @CampId)
          AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
          AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)
        GROUP BY e.CampId, c.Name

        UNION ALL

        -- Individual heads per camp
        SELECT
            e.Head                  AS Category,
            e.CampId,
            ISNULL(c.Name, '')      AS CampName,
            ISNULL(SUM(e.Amount),0) AS Amount,
            1                       AS SortOrder
        FROM Expenses e
        LEFT JOIN Camps c ON c.Id = e.CampId AND c.IsDeleted = 0
        WHERE e.IsDeleted = 0
          AND ISNULL(e.Head,'') <> ''
          AND ISNULL(e.Head,'') <> 'Partner Profit'
          AND (@CampId   IS NULL OR e.CampId = @CampId)
          AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
          AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)
        GROUP BY e.Head, e.CampId, c.Name
    ) x
    ORDER BY x.SortOrder, x.Amount DESC, x.CampName;

    -- ═══════════════════════════════════════════════════════
    -- RS4: Summary Cards
    -- ═══════════════════════════════════════════════════════
    SELECT
        -- TotalCollection: ContractRoomInstallments se direct — no JOIN
        ISNULL((SELECT SUM(cri.PaidAmount)
                FROM ContractRoomInstallments cri
                WHERE ISNULL(cri.IsDeleted, 0) = 0
                  AND cri.Status IN ('Paid', 'PaidPartial')
                  AND (@CampId   IS NULL OR cri.CampId = @CampId)
                  AND (@CriMonth IS NULL OR cri.Month  = @CriMonth)
               ), 0)                                                    AS TotalCollection,

        -- Total Expense
        ISNULL((SELECT SUM(e.Amount)
                FROM Expenses e
                WHERE e.IsDeleted=0
                  AND (@CampId IS NULL OR e.CampId=@CampId)
                  AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)
               ), 0)                                                    AS TotalExpense,

        -- Total Units (all rooms)
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.IsDeleted=0
                  AND (@CampId IS NULL OR r.CampId=@CampId)
               ), 0)                                                    AS TotalUnits,

        -- Occupied Units
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.IsDeleted=0 AND r.Status='Occupied'
                  AND (@CampId IS NULL OR r.CampId=@CampId)
               ), 0)                                                    AS TotalOccupied,

        -- Vacant Units
        ISNULL((SELECT COUNT(*) FROM Rooms r
                WHERE r.IsDeleted=0 AND r.Status='Vacant'
                  AND (@CampId IS NULL OR r.CampId=@CampId)
               ), 0)                                                    AS TotalVacant;

    -- ═══════════════════════════════════════════════════════
    -- RS5: Partner Profit from Expenses table
    -- ALL partners aayenge (even if no expense)
    -- Filter: RecipientRole='Partner' AND Head='Partner Profit'
    -- ═══════════════════════════════════════════════════════
    SELECT
        p.Id                                                            AS PartnerId,
        p.Name                                                          AS PartnerName,
        ISNULL(e.CampId,  0)                                            AS CampId,
        ISNULL(e.CampName,'')                                           AS CampName,
        ISNULL(SUM(e.Amount), 0)                                        AS Amount
    FROM Partners p
    LEFT JOIN Expenses e ON e.RecipientId   = p.Id
                        AND e.RecipientRole  = 'Partner'
                        AND e.Head           = 'Partner Profit'
                        AND e.IsDeleted      = 0
                        AND (@DateFrom IS NULL OR CAST(e.Date AS DATE) >= @DateFrom)
                        AND (@DateTo   IS NULL OR CAST(e.Date AS DATE) <= @DateTo)
                        AND (@CampId   IS NULL OR e.CampId = @CampId)
    WHERE p.IsDeleted = 0
    GROUP BY p.Id, p.Name, e.CampId, e.CampName
    ORDER BY p.Name, e.CampName;
END;
GO

PRINT 'sp_GetMISDashboard created successfully.';
GO
