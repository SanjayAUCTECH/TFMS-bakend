SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetCampWisePartnerBalanceReport
    @Month        INT  = NULL,   -- 1..12
    @Year         INT  = NULL,   -- e.g. 2026
    @PartnerId    INT  = NULL,   -- optional filter
    @CampId       INT  = NULL,   -- optional filter
    @PageNumber   INT  = 1,
    @PageSize     INT  = 1000,
    @TotalRecords INT  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Date boundaries ───────────────────────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    -- Selected month
    DECLARE @MonFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @MonTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- ── Total count ───────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM CampPartners cp
    INNER JOIN Camps    c ON c.Id = cp.CampId    AND ISNULL(c.IsDeleted, 0) = 0
    INNER JOIN Partners p ON p.Id = cp.PartnerId AND ISNULL(p.IsDeleted, 0) = 0
    WHERE ISNULL(cp.IsDeleted, 0) = 0
      AND (@CampId    IS NULL OR cp.CampId    = @CampId)
      AND (@PartnerId IS NULL OR cp.PartnerId = @PartnerId);

    -- ════════════════════════════════════════════════════════════
    -- CTE 1: Payout BEFORE selected month (per camp+partner)
    --   PartnerMonthlyCampPayout.Date < @MonFrom
    -- ════════════════════════════════════════════════════════════
    ;WITH CTE_PayoutBefore AS (
        SELECT
            pmcp.CampId,
            pmcp.PartnerId,
            SUM(pmcp.BenefitAmount) AS TotalPayoutBefore
        FROM PartnerMonthlyCampPayout pmcp
        WHERE ISNULL(pmcp.IsDeleted, 0) = 0
          AND CAST(pmcp.Date AS DATE) < @MonFrom
        GROUP BY pmcp.CampId, pmcp.PartnerId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 2: Expense BEFORE selected month (per camp+partner)
    --   Expenses.RecipientRole = 'Partner'
    --   Expenses.CampId + RecipientId (=PartnerId)
    --   Expenses.Date < @MonFrom
    -- ════════════════════════════════════════════════════════════
    CTE_ExpenseBefore AS (
        SELECT
            e.CampId,
            e.RecipientId   AS PartnerId,
            SUM(e.Amount)   AS TotalExpenseBefore
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted, 0) = 0
          AND e.RecipientRole = 'Partner'
          AND e.Date < @MonFrom
        GROUP BY e.CampId, e.RecipientId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 3: Payout Generated for selected month (per camp+partner)
    --   PartnerMonthlyCampPayout.Date within @MonFrom..@MonTo
    -- ════════════════════════════════════════════════════════════
    CTE_PayoutGenerated AS (
        SELECT
            pmcp.CampId,
            pmcp.PartnerId,
            pmcp.CampPartnerPercentage,
            SUM(pmcp.BenefitAmount) AS PayoutGenerated
        FROM PartnerMonthlyCampPayout pmcp
        WHERE ISNULL(pmcp.IsDeleted, 0) = 0
          AND CAST(pmcp.Date AS DATE) >= @MonFrom
          AND CAST(pmcp.Date AS DATE) <= @MonTo
        GROUP BY pmcp.CampId, pmcp.PartnerId, pmcp.CampPartnerPercentage
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 4: Paid Amount for selected month (per camp+partner)
    --   Expenses.Date within @MonFrom..@MonTo
    -- ════════════════════════════════════════════════════════════
    CTE_PaidMonth AS (
        SELECT
            e.CampId,
            e.RecipientId   AS PartnerId,
            SUM(e.Amount)   AS PaidAmount
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted, 0) = 0
          AND e.RecipientRole = 'Partner'
          AND e.Date >= @MonFrom
          AND e.Date <= @MonTo
        GROUP BY e.CampId, e.RecipientId
    )

    -- ════════════════════════════════════════════════════════════
    -- FINAL SELECT: Camp → Partner wise
    -- ════════════════════════════════════════════════════════════
    SELECT
        c.Id                                                          AS CampId,
        c.Code                                                        AS CampCode,
        c.Name                                                        AS CampName,
        p.Id                                                          AS PartnerId,
        p.Code                                                        AS PartnerCode,
        p.Name                                                        AS PartnerName,

        -- Partner % in this camp
        ISNULL(pg.CampPartnerPercentage, cp.ShareValue)              AS PartnerPercentage,

        -- ClosingBalance = Payout before - Expense before (per camp+partner)
        ISNULL(pb.TotalPayoutBefore,  0)
        - ISNULL(eb.TotalExpenseBefore, 0)                           AS ClosingBalance,

        -- PayoutGenerated = selected month ka BenefitAmount
        ISNULL(pg.PayoutGenerated, 0)                                AS PayoutGenerated,

        -- TotalPayout = ClosingBalance + PayoutGenerated
        ( ISNULL(pb.TotalPayoutBefore, 0) - ISNULL(eb.TotalExpenseBefore, 0) )
        + ISNULL(pg.PayoutGenerated, 0)                              AS TotalPayout,

        -- Paid = selected month mein kitna diya (camp+partner wise)
        ISNULL(pm.PaidAmount, 0)                                     AS Paid,

        -- FinalBalance = TotalPayout - Paid
        (
            ( ISNULL(pb.TotalPayoutBefore, 0) - ISNULL(eb.TotalExpenseBefore, 0) )
            + ISNULL(pg.PayoutGenerated, 0)
        )
        - ISNULL(pm.PaidAmount, 0)                                   AS FinalBalance

    FROM CampPartners cp
    INNER JOIN Camps    c  ON c.Id = cp.CampId    AND ISNULL(c.IsDeleted, 0) = 0
    INNER JOIN Partners p  ON p.Id = cp.PartnerId AND ISNULL(p.IsDeleted, 0) = 0
    LEFT  JOIN CTE_PayoutBefore    pb ON pb.CampId    = cp.CampId AND pb.PartnerId    = cp.PartnerId
    LEFT  JOIN CTE_ExpenseBefore   eb ON eb.CampId    = cp.CampId AND eb.PartnerId    = cp.PartnerId
    LEFT  JOIN CTE_PayoutGenerated pg ON pg.CampId    = cp.CampId AND pg.PartnerId    = cp.PartnerId
    LEFT  JOIN CTE_PaidMonth       pm ON pm.CampId    = cp.CampId AND pm.PartnerId    = cp.PartnerId

    WHERE ISNULL(cp.IsDeleted, 0) = 0
      AND (@CampId    IS NULL OR cp.CampId    = @CampId)
      AND (@PartnerId IS NULL OR cp.PartnerId = @PartnerId)

    ORDER BY c.Name, p.Name

    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

END
GO

PRINT 'sp_GetCampWisePartnerBalanceReport created successfully.';
GO
