-- ============================================================
-- SALON FUND BALANCE
-- Source: ClosingPayout + CompanyExpensePosting
-- Filter: Month + Year (instead of DateFrom/DateTo)
-- ============================================================

CREATE OR ALTER PROCEDURE sp_GetSalonFundBalance
    @SalonId INT  = NULL,
    @Month   INT  = NULL,   -- 1..12
    @Year    INT  = NULL    -- e.g. 2026
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Date boundaries from Month/Year ──────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    DECLARE @MonFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @MonTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- ── Step 1: Current Closing — selected month ka ClosingPayout ─
    -- DateFrom >= @MonFrom AND DateTo <= @MonTo
    DECLARE @StaffCurrent   DECIMAL(18,2) = 0;
    DECLARE @CompanyCurrent DECIMAL(18,2) = 0;

    SELECT
        @StaffCurrent   = ISNULL(SUM(StaffProfit),    0),
        @CompanyCurrent = ISNULL(SUM(CompanyRevenue), 0)
    FROM ClosingPayout
    WHERE IsDeleted = 0
      AND DateFrom  >= @MonFrom
      AND DateTo    <= @MonTo
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- ── Step 2: Previous Month Closing ───────────────────────────
    -- All ClosingPayout BEFORE selected month (DateTo < @MonFrom)
    -- MINUS all CompanyExpensePosting BEFORE selected month (Date < @MonFrom)
    -- This gives net balance carried forward

    DECLARE @StaffPayoutBefore   DECIMAL(18,2) = 0;
    DECLARE @CompanyPayoutBefore DECIMAL(18,2) = 0;

    SELECT
        @StaffPayoutBefore   = ISNULL(SUM(StaffProfit),    0),
        @CompanyPayoutBefore = ISNULL(SUM(CompanyRevenue), 0)
    FROM ClosingPayout
    WHERE IsDeleted = 0
      AND DateTo    < @MonFrom
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- Previous month expenses (before selected month)
    DECLARE @StaffPaidBefore   DECIMAL(18,2) = 0;
    DECLARE @CompanyExpBefore  DECIMAL(18,2) = 0;

    SELECT
        @StaffPaidBefore  = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) = 'salary' THEN Amount ELSE 0 END), 0),
        @CompanyExpBefore = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) != 'salary' THEN Amount ELSE 0 END), 0)
    FROM CompanyExpensePosting
    WHERE IsDeleted = 0
      AND Date      < @MonFrom
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- Previous Month Closing = Payout Before - Expense Before
    DECLARE @StaffPrevious   DECIMAL(18,2) = @StaffPayoutBefore   - @StaffPaidBefore;
    DECLARE @CompanyPrevious DECIMAL(18,2) = @CompanyPayoutBefore - @CompanyExpBefore;

    -- ── Step 3: Totals ────────────────────────────────────────────
    DECLARE @TotalStaff   DECIMAL(18,2) = @StaffPrevious   + @StaffCurrent;
    DECLARE @TotalCompany DECIMAL(18,2) = @CompanyPrevious + @CompanyCurrent;

    -- ── Step 4: Selected month Expenses ──────────────────────────
    -- CompanyExpensePosting.Date within @MonFrom..@MonTo
    DECLARE @StaffPaid      DECIMAL(18,2) = 0;
    DECLARE @CompanyExpense DECIMAL(18,2) = 0;

    SELECT
        @StaffPaid      = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) = 'salary' THEN Amount ELSE 0 END), 0),
        @CompanyExpense = ISNULL(SUM(CASE WHEN LOWER(ISNULL(Head,'')) != 'salary' THEN Amount ELSE 0 END), 0)
    FROM CompanyExpensePosting
    WHERE IsDeleted = 0
      AND Date      >= @MonFrom
      AND Date      <= @MonTo
      AND (@SalonId IS NULL OR SalonId = @SalonId);

    -- ── Step 5: Final Balances ────────────────────────────────────
    DECLARE @StaffBalance   DECIMAL(18,2) = @TotalStaff   - @StaffPaid;
    DECLARE @CompanyBalance DECIMAL(18,2) = @TotalCompany - @CompanyExpense;

    -- ── Result ────────────────────────────────────────────────────
    SELECT
        -- Report month label
        DATENAME(MONTH, @MonFrom) + ' ' + CAST(@SelYear AS NVARCHAR(4))
                                   AS ReportMonth,

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

PRINT 'sp_GetSalonFundBalance updated with Month/Year filter.';
GO
