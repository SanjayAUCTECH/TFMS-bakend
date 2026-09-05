-- ============================================================
-- SALON FUND BALANCE
-- Source: ClosingPayout + CompanyExpensePosting
-- ============================================================

CREATE OR ALTER PROCEDURE sp_GetSalonFundBalance
    @SalonId  INT  = NULL,
    @DateFrom DATE = NULL,
    @DateTo   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Step 1: Identify "current" closing period ─────────────────────────
    -- Current  = most recent DateTo batch (per salon or overall)
    -- Previous = all batches EXCEPT the most recent DateTo

    DECLARE @CurrentDateTo DATE;

    SELECT @CurrentDateTo = MAX(DateTo)
    FROM ClosingPayout
    WHERE IsDeleted = 0
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- ── Step 2: Previous closings (all except current DateTo) ─────────────
    DECLARE @StaffPrevious   DECIMAL(18,2) = 0;
    DECLARE @CompanyPrevious DECIMAL(18,2) = 0;

    SELECT
        @StaffPrevious   = ISNULL(SUM(StaffProfit),    0),
        @CompanyPrevious = ISNULL(SUM(CompanyRevenue), 0)
    FROM ClosingPayout
    WHERE IsDeleted = 0
      AND DateTo    < @CurrentDateTo          -- all except current
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- ── Step 3: Current closing (most recent DateTo) ──────────────────────
    DECLARE @StaffCurrent        DECIMAL(18,2) = 0;
    DECLARE @CompanyCurrent      DECIMAL(18,2) = 0;
    DECLARE @CurrentDateFrom     DATE;

    SELECT
        @StaffCurrent    = ISNULL(SUM(StaffProfit),    0),
        @CompanyCurrent  = ISNULL(SUM(CompanyRevenue), 0),
        @CurrentDateFrom = MIN(DateFrom)
    FROM ClosingPayout
    WHERE IsDeleted = 0
      AND DateTo    = @CurrentDateTo
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- ── Step 4: Totals ────────────────────────────────────────────────────
    DECLARE @TotalStaff   DECIMAL(18,2) = @StaffPrevious   + @StaffCurrent;
    DECLARE @TotalCompany DECIMAL(18,2) = @CompanyPrevious + @CompanyCurrent;

    -- ── Step 5: Expense Posting data ─────────────────────────────────────
    -- Filter by @DateFrom/@DateTo if provided, else no date filter
    DECLARE @StaffPaid      DECIMAL(18,2) = 0;   -- Head = 'salary'
    DECLARE @CompanyExpense DECIMAL(18,2) = 0;   -- All other heads

    SELECT
        @StaffPaid      = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) = 'salary' THEN Amount ELSE 0 END), 0),
        @CompanyExpense = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) != 'salary' THEN Amount ELSE 0 END), 0)
    FROM CompanyExpensePosting
    WHERE IsDeleted = 0
      AND (@SalonId  IS NULL OR SalonId = @SalonId)
      AND (@DateFrom IS NULL OR Date   >= @DateFrom)
      AND (@DateTo   IS NULL OR Date   <= @DateTo);

    -- ── Step 6: Final Balances ────────────────────────────────────────────
    DECLARE @StaffBalance   DECIMAL(18,2) = @TotalStaff   - @StaffPaid;
    DECLARE @CompanyBalance DECIMAL(18,2) = @TotalCompany - @CompanyExpense;

    -- ── Result ────────────────────────────────────────────────────────────
    SELECT
        -- Closing info
        @CurrentDateFrom           AS CurrentClosingDateFrom,
        @CurrentDateTo             AS CurrentClosingDateTo,

        -- Staff breakdown
        @StaffPrevious             AS StaffPreviousMonthClosing,
        @StaffCurrent              AS StaffCurrentClosing,
        @TotalStaff                AS TotalStaffShare,
        @StaffPaid                 AS StaffSalaryPaid,
        @StaffBalance              AS StaffClosingBalance,

        -- Company breakdown
        @CompanyPrevious           AS CompanyPreviousMonthClosing,
        @CompanyCurrent            AS CompanyCurrentClosing,
        @TotalCompany              AS TotalCompanyRevenue,
        @CompanyExpense            AS CompanyExpense,
        @CompanyBalance            AS CompanyClosingBalance;
END;
GO
