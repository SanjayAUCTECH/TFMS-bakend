SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetSalonStaffPayoutBalanceReport
    @Month        INT = NULL,   -- 1..12
    @Year         INT = NULL,   -- e.g. 2026
    @StaffId      INT = NULL,   -- optional: filter by Staff.Id
    @SalonId      INT = NULL,   -- optional: filter by SalonId
    @PageNumber   INT = 1,
    @PageSize     INT = 1000,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Date boundaries ───────────────────────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    DECLARE @MonFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @MonTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- ── Total count: 1 row per staff (DISTINCT) ───────────────────
    SELECT @TotalRecords = COUNT(DISTINCT ssa.StaffId)
    FROM SalonStaffAssign ssa
    INNER JOIN Staff s ON s.Id = ssa.StaffId AND ISNULL(s.IsDeleted,0) = 0
    WHERE ISNULL(ssa.IsDeleted, 0) = 0
      AND (@SalonId IS NULL OR ssa.SalonId = @SalonId)
      AND (@StaffId IS NULL OR ssa.StaffId = @StaffId);

    -- ════════════════════════════════════════════════════════════
    -- CTE 1: Payout BEFORE selected month — STAFF WISE (all salons merged)
    --   If @SalonId passed → filter by salon
    --   Else → sum across all salons
    -- ════════════════════════════════════════════════════════════
    ;WITH CTE_PayoutBefore AS (
        SELECT
            cp.StaffId,
            SUM(cp.StaffProfit) AS TotalPayoutBefore
        FROM ClosingPayout cp
        WHERE ISNULL(cp.IsDeleted, 0) = 0
          AND cp.DateTo < @MonFrom
          AND (@SalonId IS NULL OR cp.SalonId = @SalonId)
        GROUP BY cp.StaffId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 2: Salary BEFORE selected month — STAFF WISE (all salons merged)
    -- ════════════════════════════════════════════════════════════
    CTE_SalaryBefore AS (
        SELECT
            cep.RecipientId  AS StaffId,
            SUM(cep.Amount)  AS TotalSalaryBefore
        FROM CompanyExpensePosting cep
        WHERE ISNULL(cep.IsDeleted, 0) = 0
          AND LOWER(cep.Head) = 'salary'
          AND cep.Date < @MonFrom
          AND (@SalonId IS NULL OR cep.SalonId = @SalonId)
        GROUP BY cep.RecipientId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 3: Payout SELECTED month — STAFF WISE (all salons merged)
    -- ════════════════════════════════════════════════════════════
    CTE_PayoutCurrent AS (
        SELECT
            cp.StaffId,
            SUM(cp.StaffProfit) AS PayoutGenerated
        FROM ClosingPayout cp
        WHERE ISNULL(cp.IsDeleted, 0) = 0
          AND cp.DateTo >= @MonFrom
          AND cp.DateTo <= @MonTo
          AND (@SalonId IS NULL OR cp.SalonId = @SalonId)
        GROUP BY cp.StaffId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 4: Salary Paid SELECTED month — STAFF WISE (all salons merged)
    -- ════════════════════════════════════════════════════════════
    CTE_SalaryCurrent AS (
        SELECT
            cep.RecipientId  AS StaffId,
            SUM(cep.Amount)  AS PaidAmount
        FROM CompanyExpensePosting cep
        WHERE ISNULL(cep.IsDeleted, 0) = 0
          AND LOWER(cep.Head) = 'salary'
          AND cep.Date >= @MonFrom
          AND cep.Date <= @MonTo
          AND (@SalonId IS NULL OR cep.SalonId = @SalonId)
        GROUP BY cep.RecipientId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 5: Distinct staff list (1 row per staff)
    -- ════════════════════════════════════════════════════════════
    CTE_StaffList AS (
        SELECT DISTINCT ssa.StaffId
        FROM SalonStaffAssign ssa
        WHERE ISNULL(ssa.IsDeleted, 0) = 0
          AND (@SalonId IS NULL OR ssa.SalonId = @SalonId)
          AND (@StaffId IS NULL OR ssa.StaffId = @StaffId)
    )

    -- ════════════════════════════════════════════════════════════
    -- FINAL SELECT: 1 row per staff (salon-merged)
    -- ════════════════════════════════════════════════════════════
    SELECT
        s.Id                                                            AS StaffId,
        s.StaffId                                                       AS StaffCode,
        s.Name                                                          AS StaffName,
        s.Role                                                          AS StaffRole,
        s.Contact,
        s.Status,

        -- ClosingBalance = Payout Before - Salary Before
        ISNULL(pb.TotalPayoutBefore,  0)
        - ISNULL(sb.TotalSalaryBefore, 0)                              AS ClosingBalance,

        -- PayoutGenerated = selected month (all salons merged)
        ISNULL(pc.PayoutGenerated, 0)                                  AS PayoutGenerated,

        -- PayableAmount = ClosingBalance + PayoutGenerated
        ( ISNULL(pb.TotalPayoutBefore,  0) - ISNULL(sb.TotalSalaryBefore, 0) )
        + ISNULL(pc.PayoutGenerated, 0)                                AS PayableAmount,

        -- Paid = selected month salary paid (all salons merged)
        ISNULL(sc.PaidAmount, 0)                                       AS Paid,

        -- FinalBalance = PayableAmount - Paid
        (
            ( ISNULL(pb.TotalPayoutBefore,  0) - ISNULL(sb.TotalSalaryBefore, 0) )
            + ISNULL(pc.PayoutGenerated, 0)
        )
        - ISNULL(sc.PaidAmount, 0)                                     AS FinalBalance

    FROM CTE_StaffList sl
    INNER JOIN Staff s  ON s.Id = sl.StaffId AND ISNULL(s.IsDeleted,0) = 0
    LEFT JOIN CTE_PayoutBefore  pb ON pb.StaffId = sl.StaffId
    LEFT JOIN CTE_SalaryBefore  sb ON sb.StaffId = sl.StaffId
    LEFT JOIN CTE_PayoutCurrent pc ON pc.StaffId = sl.StaffId
    LEFT JOIN CTE_SalaryCurrent sc ON sc.StaffId = sl.StaffId

    ORDER BY s.Name

    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

END
GO

PRINT 'sp_GetSalonStaffPayoutBalanceReport updated - staff wise (salon merged).';
GO
