SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerPayoutReport
    @Month        INT           = NULL,   -- 1..12
    @Year         INT           = NULL,   -- e.g. 2026
    @PartnerId    INT           = NULL,   -- filter by specific partner
    @PageNumber   INT           = 1,
    @PageSize     INT           = 1000,
    @TotalRecords INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Date boundaries ───────────────────────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    -- Selected month: first and last day
    DECLARE @MonFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @MonTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- Before selected month: everything BEFORE @MonFrom
    -- Used for ClosingBalance calculation
    DECLARE @BeforeMonTo DATE = DATEADD(DAY, -1, @MonFrom);  -- last day of previous month

    -- ── Total count ───────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM Partners p
    WHERE ISNULL(p.IsDeleted, 0) = 0
      AND (@PartnerId IS NULL OR p.Id = @PartnerId);

    -- ════════════════════════════════════════════════════════════
    -- CTE 1: Payout BEFORE selected month
    --   Remark format: 'Monthly Payout: 01-07-2026 to 31-07-2026'
    --   End date = part after ' to ' → TRY_CONVERT to date
    --   Filter: end date < @MonFrom
    -- ════════════════════════════════════════════════════════════
    ;WITH CTE_PayoutBefore AS (
        SELECT
            pt.PartnerId,
            SUM(pt.Amount) AS TotalPayoutBefore
        FROM PartnerTrans pt
        WHERE ISNULL(pt.IsDeleted, 0) = 0
          AND pt.Type = 'Payout'
          AND TRY_CONVERT(DATE,
                LTRIM(SUBSTRING(pt.Remark,
                    CHARINDEX(' to ', pt.Remark) + 4,
                    LEN(pt.Remark)
                )), 105) < @MonFrom
        GROUP BY pt.PartnerId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 2: Expense BEFORE selected month
    --   Join AccountMasters on AccountId → use TransDate
    --   Filter: am.TransDate < @MonFrom
    -- ════════════════════════════════════════════════════════════
    CTE_ExpenseBefore AS (
        SELECT
            pt.PartnerId,
            SUM(pt.Amount) AS TotalExpenseBefore
        FROM PartnerTrans pt
        INNER JOIN AccountMasters am ON am.AccountId = pt.AccountId
        WHERE ISNULL(pt.IsDeleted, 0) = 0
          AND pt.Type = 'Expense'
          AND CAST(am.TransDate AS DATE) < @MonFrom
        GROUP BY pt.PartnerId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 3: Payout Generated for selected month
    --   Remark end date = @MonTo (last day of selected month)
    -- ════════════════════════════════════════════════════════════
    CTE_PayoutGenerated AS (
        SELECT
            pt.PartnerId,
            SUM(pt.Amount) AS PayoutGenerated
        FROM PartnerTrans pt
        WHERE ISNULL(pt.IsDeleted, 0) = 0
          AND pt.Type = 'Payout'
          AND TRY_CONVERT(DATE,
                LTRIM(SUBSTRING(pt.Remark,
                    CHARINDEX(' to ', pt.Remark) + 4,
                    LEN(pt.Remark)
                )), 105) = @MonTo
        GROUP BY pt.PartnerId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 4: Paid Amount for selected month
    --   Join AccountMasters → TransDate within @MonFrom..@MonTo
    -- ════════════════════════════════════════════════════════════
    CTE_PaidMonth AS (
        SELECT
            pt.PartnerId,
            SUM(pt.Amount) AS PaidAmount
        FROM PartnerTrans pt
        INNER JOIN AccountMasters am ON am.AccountId = pt.AccountId
        WHERE ISNULL(pt.IsDeleted, 0) = 0
          AND pt.Type = 'Expense'
          AND CAST(am.TransDate AS DATE) >= @MonFrom
          AND CAST(am.TransDate AS DATE) <= @MonTo
        GROUP BY pt.PartnerId
    )

    -- ════════════════════════════════════════════════════════════
    -- FINAL SELECT
    -- ════════════════════════════════════════════════════════════
    SELECT
        p.Id                                                          AS PartnerId,
        p.Code                                                        AS PartnerCode,
        p.Name                                                        AS PartnerName,
        p.Mobile,
        p.Email,
        p.Status,

        -- ClosingBalance = (All Payout before this month) - (All Expense paid before this month)
        ISNULL(pb.TotalPayoutBefore,  0)
        - ISNULL(eb.TotalExpenseBefore, 0)                           AS ClosingBalance,

        -- PayoutGenerated = selected month ka payout (from PartnerMonthlyPayout)
        ISNULL(pg.PayoutGenerated, 0)                                AS PayoutGenerated,

        -- TotalRemainingPayout = ClosingBalance + PayoutGenerated
        (ISNULL(pb.TotalPayoutBefore,  0) - ISNULL(eb.TotalExpenseBefore, 0))
        + ISNULL(pg.PayoutGenerated, 0)                              AS TotalRemainingPayout,

        -- PaidAmount = selected month mein jo paisa diya gaya (Expense)
        ISNULL(pm.PaidAmount, 0)                                     AS PaidAmount,

        -- Balance = TotalRemainingPayout - PaidAmount
        (
            (ISNULL(pb.TotalPayoutBefore,  0) - ISNULL(eb.TotalExpenseBefore, 0))
            + ISNULL(pg.PayoutGenerated, 0)
        )
        - ISNULL(pm.PaidAmount, 0)                                   AS Balance

    FROM Partners p
    LEFT JOIN CTE_PayoutBefore    pb ON pb.PartnerId  = p.Id
    LEFT JOIN CTE_ExpenseBefore   eb ON eb.PartnerId  = p.Id
    LEFT JOIN CTE_PayoutGenerated pg ON pg.PartnerId  = p.Id
    LEFT JOIN CTE_PaidMonth       pm ON pm.PartnerId  = p.Id

    WHERE ISNULL(p.IsDeleted, 0) = 0
      AND (@PartnerId IS NULL OR p.Id = @PartnerId)

    ORDER BY p.Name

    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

END
GO

PRINT 'sp_GetPartnerPayoutReport created successfully.';
GO
