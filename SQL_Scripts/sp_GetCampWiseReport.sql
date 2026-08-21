SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetCampWiseReport
    @FromDate      DATE         = NULL,
    @ToDate        DATE         = NULL,
    @FinancialYear NVARCHAR(20) = NULL,
    @CampId        INT          = NULL,
    @Detail        BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve date range
    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate = DATEFROMPARTS(@FY,   4, 1);
        SET @ToDate   = DATEFROMPARTS(@FY+1, 3, 31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT = YEAR(GETDATE()); DECLARE @CM INT = MONTH(GETDATE());
        IF @CM >= 4 BEGIN SET @FromDate = DATEFROMPARTS(@CY,   4, 1); SET @ToDate = DATEFROMPARTS(@CY+1, 3, 31); END
        ELSE         BEGIN SET @FromDate = DATEFROMPARTS(@CY-1, 4, 1); SET @ToDate = DATEFROMPARTS(@CY,   3, 31); END
    END

    IF @Detail = 0
    BEGIN
        -- ── Step 1: Total HO Expense for period ──────────────────
        DECLARE @TotalHOExpense DECIMAL(18,2) = 0;
        SELECT @TotalHOExpense = ISNULL(SUM(e.Amount), 0)
        FROM Expenses e
        WHERE e.IsDeleted = 0
          AND e.Nature = 'HO'
          AND CAST(e.TransDate AS DATE) >= @FromDate
          AND CAST(e.TransDate AS DATE) <= @ToDate;

        -- ── Step 2: Total active rooms across all active camps ────
        DECLARE @TotalActiveRooms INT = 0;
        SELECT @TotalActiveRooms = ISNULL(COUNT(r.Id), 0)
        FROM Rooms r
        INNER JOIN Camps c ON c.Id = r.CampId
        WHERE ISNULL(r.IsDeleted,0) = 0
          AND ISNULL(c.IsDeleted,0) = 0
          AND c.Status = 'Active';

        IF @TotalActiveRooms = 0 SET @TotalActiveRooms = 1; -- avoid divide by zero

        -- ── Step 3: Per Room HO Expense ──────────────────────────
        DECLARE @PerRoomHO DECIMAL(18,4) = @TotalHOExpense / @TotalActiveRooms;

        -- ── Summary: Camp-wise with HOExpense ─────────────────────
        ;WITH CampData AS (
            SELECT ISNULL(i.CampId,0) AS CampId, ISNULL(i.CampName,'(No Camp)') AS CampName,
                   i.Amount AS IncomeAmt, 0.00 AS ExpenseAmt
            FROM Incomes i
            WHERE i.IsDeleted = 0
              AND CAST(i.TransDate AS DATE) >= @FromDate
              AND CAST(i.TransDate AS DATE) <= @ToDate
              AND (@CampId IS NULL OR i.CampId = @CampId)

            UNION ALL

            SELECT ISNULL(e.CampId,0), ISNULL(e.CampName,'(No Camp)'),
                   0.00, e.Amount
            FROM Expenses e
            WHERE e.IsDeleted = 0
              AND CAST(e.TransDate AS DATE) >= @FromDate
              AND CAST(e.TransDate AS DATE) <= @ToDate
              AND (@CampId IS NULL OR e.CampId = @CampId)
        ),
        CampSummary AS (
            SELECT CampId, CampName,
                   ISNULL(SUM(IncomeAmt),  0) AS TotalIncome,
                   ISNULL(SUM(ExpenseAmt), 0) AS TotalExpense
            FROM CampData
            GROUP BY CampId, CampName
        ),
        -- Camp room counts (active rooms per active camp)
        CampRooms AS (
            SELECT c.Id AS CampId,
                   COUNT(r.Id) AS RoomCount
            FROM Camps c
            LEFT JOIN Rooms r ON r.CampId = c.Id AND ISNULL(r.IsDeleted,0) = 0
            WHERE ISNULL(c.IsDeleted,0) = 0
              AND c.Status = 'Active'
            GROUP BY c.Id
        )
        SELECT
            cs.CampId,
            cs.CampName,
            cs.TotalIncome,
            cs.TotalExpense,
            -- Camp HO Expense = PerRoomHO × Camp's room count
            ROUND(ISNULL(cr.RoomCount, 0) * @PerRoomHO, 2)        AS HOExpense,
            -- TotalExpense including HO
            cs.TotalExpense
            + ROUND(ISNULL(cr.RoomCount, 0) * @PerRoomHO, 2)      AS TotalExpenseWithHO,
            -- NetProfit = Income - (TotalExpense + HOExpense)
            cs.TotalIncome
            - cs.TotalExpense
            - ROUND(ISNULL(cr.RoomCount, 0) * @PerRoomHO, 2)      AS NetProfit
        FROM CampSummary cs
        LEFT JOIN CampRooms cr ON cr.CampId = cs.CampId
        ORDER BY cs.CampName;

        -- Grand total
        SELECT
            ISNULL((SELECT SUM(Amount) FROM Incomes  WHERE IsDeleted=0
                    AND CAST(TransDate AS DATE) >= @FromDate
                    AND CAST(TransDate AS DATE) <= @ToDate), 0) AS GrandIncome,
            ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                    AND CAST(TransDate AS DATE) >= @FromDate
                    AND CAST(TransDate AS DATE) <= @ToDate), 0) AS GrandExpense,
            @TotalHOExpense                                       AS GrandHOExpense,
            ISNULL((SELECT SUM(Amount) FROM Incomes  WHERE IsDeleted=0
                    AND CAST(TransDate AS DATE) >= @FromDate
                    AND CAST(TransDate AS DATE) <= @ToDate), 0)
            - ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                    AND CAST(TransDate AS DATE) >= @FromDate
                    AND CAST(TransDate AS DATE) <= @ToDate), 0)
            - @TotalHOExpense                                     AS GrandNet;
    END
    ELSE
    BEGIN
        -- Detail: vouchers for a specific camp
        SELECT TransDate, VoucherNo, 'Income' AS VoucherType, Head AS AccountHead,
               Amount, ISNULL(Purpose,'') AS Purpose
        FROM Incomes
        WHERE IsDeleted = 0 AND CampId = @CampId
          AND CAST(TransDate AS DATE) >= @FromDate
          AND CAST(TransDate AS DATE) <= @ToDate

        UNION ALL

        SELECT TransDate, VoucherNo, 'Expense', Head,
               Amount, ISNULL(Purpose,'')
        FROM Expenses
        WHERE IsDeleted = 0 AND CampId = @CampId
          AND CAST(TransDate AS DATE) >= @FromDate
          AND CAST(TransDate AS DATE) <= @ToDate
        ORDER BY TransDate ASC;
    END
END
GO

PRINT 'sp_GetCampWiseReport updated with HOExpense calculation.';
GO
