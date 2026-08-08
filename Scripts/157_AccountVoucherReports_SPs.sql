-- ============================================================
-- 157: Account Voucher Reports — All Stored Procedures
-- 
-- Reports:
--   1. sp_GetDayBook
--   2. sp_GetVoucherRegister
--   3. sp_GetVoucherDetail
--   4. sp_GetIncomeRegister
--   5. sp_GetExpenseRegister
--   6. sp_GetAccountHeadLedger
--   7. sp_GetCampWiseReport
--   8. sp_GetPropertyWiseReport
--   9. sp_GetMonthlyProfitSummary
--  10. sp_GetFinancialYearSummary
--  11. sp_GetPaymentModeReport
--
-- Common:
--   • IsDeleted=0 mandatory on all tables
--   • Date filter on TransDate
--   • Grand Totals in SQL
--   • Running Balance via SUM OVER (ORDER BY)
--   • Server-side Pagination
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. sp_GetDayBook
--    Date-wise Income + Expense with Running Balance
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetDayBook
    @FromDate      DATE          = NULL,
    @ToDate        DATE          = NULL,
    @FinancialYear NVARCHAR(20)  = NULL,  -- e.g. '2026-2027'
    @VoucherType   NVARCHAR(50)  = NULL,  -- 'Income' | 'Expense' | NULL=All
    @AccountHead   NVARCHAR(200) = NULL,
    @CampId        INT           = NULL,
    @PaymentMode   NVARCHAR(100) = NULL,
    @TenantId      INT           = NULL,
    @SearchText    NVARCHAR(200) = NULL,
    @PageNumber    INT           = 1,
    @PageSize      INT           = 20,
    @TotalRecords  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve FinancialYear to date range (April to March)
    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear, 4) AS INT);
        SET @FromDate = DATEFROMPARTS(@FY, 4, 1);
        SET @ToDate   = DATEFROMPARTS(@FY + 1, 3, 31);
    END
    -- Default: current financial year
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT = YEAR(GETDATE());
        DECLARE @CM INT = MONTH(GETDATE());
        IF @CM >= 4
        BEGIN SET @FromDate = DATEFROMPARTS(@CY, 4, 1); SET @ToDate = DATEFROMPARTS(@CY+1, 3, 31); END
        ELSE
        BEGIN SET @FromDate = DATEFROMPARTS(@CY-1, 4, 1); SET @ToDate = DATEFROMPARTS(@CY, 3, 31); END
    END

    -- Load combined data into temp table (CTE scope is single-statement only)
    SELECT
        i.TransDate AS TxnDate,
        i.VoucherNo,
        CAST('Income' AS NVARCHAR(50)) AS VoucherType,
        i.Head AS AccountHead,
        ISNULL(i.CampName,'') AS CampName,
        ISNULL(i.FundPoolName,'') AS Property,
        ISNULL(i.TenantName,'') AS TenantName,
        CAST('' AS NVARCHAR(200)) AS LandlordName,
        ISNULL(i.Mode,'') AS PaymentMode,
        i.Amount AS IncomeAmt,
        CAST(0.00 AS DECIMAL(18,2)) AS ExpenseAmt,
        ISNULL(i.Purpose,'') AS Purpose,
        ISNULL(i.TenantName,'') AS PartyName      -- Income: TenantName = party
    INTO #Combined
    FROM Incomes i
    WHERE i.IsDeleted=0
      AND (i.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (i.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@VoucherType IS NULL OR @VoucherType = 'Income')
      AND (@AccountHead IS NULL OR i.Head = @AccountHead)
      AND (@CampId IS NULL OR i.CampId = @CampId)
      AND (@PaymentMode IS NULL OR i.Mode = @PaymentMode)
      AND (@TenantId IS NULL OR i.TenantId = @TenantId)
      AND (@SearchText IS NULL OR i.VoucherNo LIKE '%'+@SearchText+'%'
           OR i.Head LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%')

    UNION ALL

    SELECT
        e.TransDate,
        e.VoucherNo,
        'Expense',
        e.Head,
        ISNULL(e.CampName,''),
        ISNULL(e.FundPoolName,''),
        '',
        ISNULL(e.RecipientName,''),
        ISNULL(e.Mode,''),
        0.00,
        e.Amount,
        ISNULL(e.Purpose,''),
        ISNULL(e.RecipientName,'')               -- Expense: RecipientName = party
    FROM Expenses e
    WHERE e.IsDeleted=0
      AND (e.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (e.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@VoucherType IS NULL OR @VoucherType = 'Expense')
      AND (@AccountHead IS NULL OR e.Head = @AccountHead)
      AND (@CampId IS NULL OR e.CampId = @CampId)
      AND (@PaymentMode IS NULL OR e.Mode = @PaymentMode)
      AND (@SearchText IS NULL OR e.VoucherNo LIKE '%'+@SearchText+'%'
           OR e.Head LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%');

    -- Total record count
    SELECT @TotalRecords = COUNT(*) FROM #Combined;

    -- Footer totals (Result Set 1)
    SELECT
        ISNULL(SUM(IncomeAmt),0)  AS TotalIncome,
        ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
        ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS NetAmount
    FROM #Combined;

    -- Paged data with running balance (Result Set 2)
    ;WITH Ranked AS (
        SELECT *,
               ROW_NUMBER() OVER (ORDER BY ISNULL(TxnDate,'9999-12-31') ASC, VoucherNo ASC) AS RowNum,
               SUM(IncomeAmt - ExpenseAmt) OVER (ORDER BY ISNULL(TxnDate,'9999-12-31') ASC, VoucherNo ASC
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningBalance
        FROM #Combined
    )
    SELECT
        TxnDate AS [Date], VoucherNo, VoucherType, AccountHead,
        CampName, Property, TenantName, LandlordName, PaymentMode,
        IncomeAmt AS Income, ExpenseAmt AS Expense,
        RunningBalance, Purpose, PartyName
    FROM Ranked
    WHERE (@PageSize = 0) OR (RowNum BETWEEN ((@PageNumber-1)*@PageSize+1) AND (@PageNumber*@PageSize))
    ORDER BY RowNum;

    DROP TABLE #Combined;
END
GO

PRINT '✅ sp_GetDayBook created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_GetVoucherRegister
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetVoucherRegister
    @FromDate      DATE          = NULL,
    @ToDate        DATE          = NULL,
    @FinancialYear NVARCHAR(20)  = NULL,
    @VoucherType   NVARCHAR(50)  = NULL,
    @PaymentMode   NVARCHAR(100) = NULL,
    @FundPool      NVARCHAR(100) = NULL,
    @SearchText    NVARCHAR(200) = NULL,
    @SortBy        NVARCHAR(50)  = 'TransDate',
    @SortDir       NVARCHAR(4)   = 'DESC',
    @PageNumber    INT           = 1,
    @PageSize      INT           = 20,
    @TotalRecords  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate = DATEFROMPARTS(@FY,4,1); SET @ToDate = DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT = YEAR(GETDATE()); DECLARE @CM INT = MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    SELECT @TotalRecords = COUNT(*) FROM AccountMasters am
    WHERE am.IsDeleted=0
      AND (am.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (am.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@VoucherType IS NULL OR am.PaymentType = @VoucherType)
      AND (@PaymentMode IS NULL OR am.Mode = @PaymentMode)
      AND (@FundPool    IS NULL OR am.FundPool = @FundPool)
      AND (@SearchText  IS NULL OR am.VoucherNo LIKE '%'+@SearchText+'%'
           OR am.RecipientName LIKE '%'+@SearchText+'%'
           OR am.Purpose LIKE '%'+@SearchText+'%');

    SELECT
        am.Id, am.VoucherNo, am.TransDate AS VoucherDate, am.PaymentType AS VoucherType,
        am.RecipientName AS PartyName, am.Mode AS PaymentMode,
        am.FundPoolName AS FundPool, am.Amount,
        CASE WHEN am.IsDeleted=0 THEN 'Active' ELSE 'Deleted' END AS VoucherStatus,
        am.AddedBy AS CreatedBy
    FROM AccountMasters am
    WHERE am.IsDeleted=0
      AND (am.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (am.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@VoucherType IS NULL OR am.PaymentType = @VoucherType)
      AND (@PaymentMode IS NULL OR am.Mode = @PaymentMode)
      AND (@FundPool    IS NULL OR am.FundPool = @FundPool)
      AND (@SearchText  IS NULL OR am.VoucherNo LIKE '%'+@SearchText+'%'
           OR am.RecipientName LIKE '%'+@SearchText+'%'
           OR am.Purpose LIKE '%'+@SearchText+'%')
    ORDER BY
        CASE WHEN @SortBy='VoucherNo'  AND @SortDir='ASC'  THEN am.VoucherNo  END ASC,
        CASE WHEN @SortBy='VoucherNo'  AND @SortDir='DESC' THEN am.VoucherNo  END DESC,
        CASE WHEN @SortBy='Amount'     AND @SortDir='ASC'  THEN am.Amount     END ASC,
        CASE WHEN @SortBy='Amount'     AND @SortDir='DESC' THEN am.Amount     END DESC,
        CASE WHEN @SortDir='ASC'  THEN am.TransDate END ASC,
        CASE WHEN @SortDir='DESC' THEN am.TransDate END DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ sp_GetVoucherRegister created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_GetVoucherDetail
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetVoucherDetail
    @VoucherNo NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- Header
    SELECT am.VoucherNo, am.TransDate, am.FundPoolName, am.Mode AS PaymentMode,
           am.RecipientName AS PartyName, am.PaymentType, am.Amount, am.Purpose
    FROM AccountMasters am
    WHERE am.VoucherNo = @VoucherNo AND am.IsDeleted = 0;

    -- Detail lines (Income + Expense)
    SELECT i.Head AS AccountHead, ISNULL(i.Purpose,'') AS Description,
           i.Amount, 'Income' AS LineType, i.IncomeId AS LineId
    FROM Incomes i WHERE i.VoucherNo=@VoucherNo AND i.IsDeleted=0

    UNION ALL

    SELECT e.Head, ISNULL(e.Purpose,''), e.Amount, 'Expense', e.ExpenseId
    FROM Expenses e WHERE e.VoucherNo=@VoucherNo AND e.IsDeleted=0
    ORDER BY LineType, AccountHead;

    -- Footer totals
    SELECT
        ISNULL(SUM(CASE WHEN LineType='Income'  THEN Amount ELSE 0 END),0) AS TotalIncome,
        ISNULL(SUM(CASE WHEN LineType='Expense' THEN Amount ELSE 0 END),0) AS TotalExpense
    FROM (
        SELECT 'Income' LineType, Amount FROM Incomes  WHERE VoucherNo=@VoucherNo AND IsDeleted=0
        UNION ALL
        SELECT 'Expense', Amount         FROM Expenses WHERE VoucherNo=@VoucherNo AND IsDeleted=0
    ) t;
END
GO

PRINT '✅ sp_GetVoucherDetail created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_GetIncomeRegister
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetIncomeRegister
    @FromDate      DATE          = NULL,
    @ToDate        DATE          = NULL,
    @FinancialYear NVARCHAR(20)  = NULL,
    @AccountHead   NVARCHAR(200) = NULL,
    @CampId        INT           = NULL,
    @TenantId      INT           = NULL,
    @PaymentMode   NVARCHAR(100) = NULL,
    @SearchText    NVARCHAR(200) = NULL,
    @SortBy        NVARCHAR(50)  = 'TransDate',
    @SortDir       NVARCHAR(4)   = 'DESC',
    @PageNumber    INT           = 1,
    @PageSize      INT           = 20,
    @TotalRecords  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT = YEAR(GETDATE()); DECLARE @CM INT = MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    SELECT @TotalRecords = COUNT(*) FROM Incomes i
    WHERE i.IsDeleted=0
      AND (i.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (i.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR i.Head = @AccountHead)
      AND (@CampId IS NULL OR i.CampId = @CampId)
      AND (@TenantId IS NULL OR i.TenantId = @TenantId)
      AND (@PaymentMode IS NULL OR i.Mode = @PaymentMode)
      AND (@SearchText IS NULL OR i.VoucherNo LIKE '%'+@SearchText+'%'
           OR i.TenantName LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%');

    -- Footer total
    SELECT ISNULL(SUM(i.Amount),0) AS TotalIncome
    FROM Incomes i
    WHERE i.IsDeleted=0
      AND (i.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (i.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR i.Head = @AccountHead)
      AND (@CampId IS NULL OR i.CampId = @CampId)
      AND (@TenantId IS NULL OR i.TenantId = @TenantId)
      AND (@PaymentMode IS NULL OR i.Mode = @PaymentMode);

    -- Paged data
    SELECT
        i.TransDate AS [Date], i.IncomeId, i.VoucherNo,
        ISNULL(i.CampName,'') AS Camp,
        ISNULL(i.FundPoolName,'') AS Property,
        ISNULL(i.TenantName,'') AS Tenant,
        i.Head AS AccountHead, ISNULL(i.Mode,'') AS PaymentMode,
        i.Amount, ISNULL(i.Purpose,'') AS Purpose,
        ISNULL(i.Source,'') AS Source
    FROM Incomes i
    WHERE i.IsDeleted=0
      AND (i.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (i.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR i.Head = @AccountHead)
      AND (@CampId IS NULL OR i.CampId = @CampId)
      AND (@TenantId IS NULL OR i.TenantId = @TenantId)
      AND (@PaymentMode IS NULL OR i.Mode = @PaymentMode)
      AND (@SearchText IS NULL OR i.VoucherNo LIKE '%'+@SearchText+'%'
           OR i.TenantName LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%')
    ORDER BY
        CASE WHEN @SortDir='ASC'  THEN i.TransDate END ASC,
        CASE WHEN @SortDir='DESC' THEN i.TransDate END DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ sp_GetIncomeRegister created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 5. sp_GetExpenseRegister
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetExpenseRegister
    @FromDate      DATE          = NULL,
    @ToDate        DATE          = NULL,
    @FinancialYear NVARCHAR(20)  = NULL,
    @AccountHead   NVARCHAR(200) = NULL,
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(100) = NULL,
    @PaymentMode   NVARCHAR(100) = NULL,
    @SearchText    NVARCHAR(200) = NULL,
    @SortDir       NVARCHAR(4)   = 'DESC',
    @PageNumber    INT           = 1,
    @PageSize      INT           = 20,
    @TotalRecords  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT=YEAR(GETDATE()); DECLARE @CM INT=MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    SELECT @TotalRecords = COUNT(*) FROM Expenses e
    WHERE e.IsDeleted=0
      AND (e.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (e.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR e.Head = @AccountHead)
      AND (@CampId IS NULL OR e.CampId = @CampId)
      AND (@RecipientRole IS NULL OR e.RecipientRole = @RecipientRole)
      AND (@PaymentMode IS NULL OR e.Mode = @PaymentMode)
      AND (@SearchText IS NULL OR e.VoucherNo LIKE '%'+@SearchText+'%'
           OR e.RecipientName LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%');

    -- Footer total
    SELECT ISNULL(SUM(e.Amount),0) AS TotalExpense
    FROM Expenses e
    WHERE e.IsDeleted=0
      AND (e.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (e.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR e.Head = @AccountHead)
      AND (@CampId IS NULL OR e.CampId = @CampId)
      AND (@RecipientRole IS NULL OR e.RecipientRole = @RecipientRole)
      AND (@PaymentMode IS NULL OR e.Mode = @PaymentMode);

    -- Paged data
    SELECT
        e.TransDate AS [Date], e.ExpenseId, e.VoucherNo,
        ISNULL(e.CampName,'') AS Camp,
        ISNULL(e.FundPoolName,'') AS Property,
        ISNULL(e.RecipientName,'') AS Recipient,
        e.Head AS AccountHead, ISNULL(e.Mode,'') AS PaymentMode,
        e.Amount, ISNULL(e.Purpose,'') AS Purpose,
        ISNULL(e.RecipientRole,'') AS RecipientRole
    FROM Expenses e
    WHERE e.IsDeleted=0
      AND (e.TransDate >= @FromDate OR @FromDate IS NULL)
      AND (e.TransDate <= @ToDate   OR @ToDate IS NULL)
      AND (@AccountHead IS NULL OR e.Head = @AccountHead)
      AND (@CampId IS NULL OR e.CampId = @CampId)
      AND (@RecipientRole IS NULL OR e.RecipientRole = @RecipientRole)
      AND (@PaymentMode IS NULL OR e.Mode = @PaymentMode)
      AND (@SearchText IS NULL OR e.VoucherNo LIKE '%'+@SearchText+'%'
           OR e.RecipientName LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%')
    ORDER BY
        CASE WHEN @SortDir='ASC'  THEN e.TransDate END ASC,
        CASE WHEN @SortDir='DESC' THEN e.TransDate END DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ sp_GetExpenseRegister created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 6. sp_GetAccountHeadLedger
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetAccountHeadLedger
    @AccountHead   NVARCHAR(200) = NULL,  -- optional: NULL = all account heads
    @FromDate      DATE          = NULL,
    @ToDate        DATE          = NULL,
    @FinancialYear NVARCHAR(20)  = NULL,
    @PageNumber    INT           = 1,
    @PageSize      INT           = 0,   -- 0 = all records
    @TotalRecords  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT = CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END

    -- Load into temp table (CTE scope is single-statement only)
    SELECT TransDate, VoucherNo,
           Amount AS IncomeAmt,
           CAST(0.00 AS DECIMAL(18,2)) AS ExpenseAmt,
           ISNULL(Purpose,'') AS Narration,
           ISNULL(Head,'') AS AccountHead
    INTO #Ledger
    FROM Incomes
    WHERE IsDeleted=0
      AND (@AccountHead IS NULL OR Head = @AccountHead)
      AND (@FromDate IS NULL OR TransDate >= @FromDate)
      AND (@ToDate   IS NULL OR TransDate <= @ToDate)

    UNION ALL

    SELECT TransDate, VoucherNo, 0.00, Amount, ISNULL(Purpose,''),
           ISNULL(Head,'')
    FROM Expenses
    WHERE IsDeleted=0
      AND (@AccountHead IS NULL OR Head = @AccountHead)
      AND (@FromDate IS NULL OR TransDate >= @FromDate)
      AND (@ToDate   IS NULL OR TransDate <= @ToDate);

    SELECT @TotalRecords = COUNT(*) FROM #Ledger;

    -- Footer (Result Set 1)
    SELECT
        ISNULL(SUM(IncomeAmt),0)  AS TotalCredit,
        ISNULL(SUM(ExpenseAmt),0) AS TotalDebit,
        ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS ClosingBalance
    FROM #Ledger;

    -- Paged data with running balance (Result Set 2)
    ;WITH LedgerRanked AS (
        SELECT *,
               ROW_NUMBER() OVER (ORDER BY ISNULL(TransDate,'9999-12-31') ASC, VoucherNo ASC) AS RowNum,
               SUM(IncomeAmt-ExpenseAmt) OVER (ORDER BY ISNULL(TransDate,'9999-12-31') ASC, VoucherNo ASC
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningBalance
        FROM #Ledger
    )
    SELECT TransDate, VoucherNo, IncomeAmt AS Income, ExpenseAmt AS Expense,
           RunningBalance, Narration, AccountHead
    FROM LedgerRanked
    WHERE @PageSize=0 OR (RowNum BETWEEN ((@PageNumber-1)*@PageSize+1) AND (@PageNumber*@PageSize))
    ORDER BY RowNum;

    DROP TABLE #Ledger;
END
GO

PRINT '✅ sp_GetAccountHeadLedger created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 7. sp_GetCampWiseReport
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetCampWiseReport
    @FromDate      DATE         = NULL,
    @ToDate        DATE         = NULL,
    @FinancialYear NVARCHAR(20) = NULL,
    @CampId        INT          = NULL,  -- NULL=all, or specific camp for detail
    @Detail        BIT          = 0      -- 0=summary, 1=expand camp vouchers
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT=CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT=YEAR(GETDATE()); DECLARE @CM INT=MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    IF @Detail = 0
    BEGIN
        -- Summary: Group by Camp
        ;WITH CampData AS (
            SELECT ISNULL(i.CampId,0) AS CampId, ISNULL(i.CampName,'(No Camp)') AS CampName,
                   i.Amount AS IncomeAmt, 0.00 AS ExpenseAmt
            FROM Incomes i
            WHERE i.IsDeleted=0
              AND (@FromDate IS NULL OR i.TransDate >= @FromDate)
              AND (@ToDate   IS NULL OR i.TransDate <= @ToDate)
              AND (@CampId IS NULL OR i.CampId = @CampId)

            UNION ALL

            SELECT ISNULL(e.CampId,0), ISNULL(e.CampName,'(No Camp)'),
                   0.00, e.Amount
            FROM Expenses e
            WHERE e.IsDeleted=0
              AND (@FromDate IS NULL OR e.TransDate >= @FromDate)
              AND (@ToDate   IS NULL OR e.TransDate <= @ToDate)
              AND (@CampId IS NULL OR e.CampId = @CampId)
        )
        SELECT CampId, CampName,
               ISNULL(SUM(IncomeAmt),0) AS TotalIncome,
               ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
               ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS NetProfit
        FROM CampData
        GROUP BY CampId, CampName
        ORDER BY CampName;

        -- Grand total (separate aggregates — no Cartesian join)
        SELECT
            ISNULL((SELECT SUM(Amount) FROM Incomes  WHERE IsDeleted=0
                    AND (@FromDate IS NULL OR TransDate>=@FromDate)
                    AND (@ToDate   IS NULL OR TransDate<=@ToDate)), 0) AS GrandIncome,
            ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                    AND (@FromDate IS NULL OR TransDate>=@FromDate)
                    AND (@ToDate   IS NULL OR TransDate<=@ToDate)), 0) AS GrandExpense,
            ISNULL((SELECT SUM(Amount) FROM Incomes  WHERE IsDeleted=0
                    AND (@FromDate IS NULL OR TransDate>=@FromDate)
                    AND (@ToDate   IS NULL OR TransDate<=@ToDate)), 0)
            - ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                    AND (@FromDate IS NULL OR TransDate>=@FromDate)
                    AND (@ToDate   IS NULL OR TransDate<=@ToDate)), 0) AS GrandNet;
    END
    ELSE
    BEGIN
        -- Detail: vouchers for a specific camp
        SELECT TransDate, VoucherNo, 'Income' AS VoucherType, Head AS AccountHead,
               Amount, ISNULL(Purpose,'') AS Purpose
        FROM Incomes
        WHERE IsDeleted=0 AND CampId=@CampId
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)

        UNION ALL

        SELECT TransDate, VoucherNo, 'Expense', Head,
               Amount, ISNULL(Purpose,'')
        FROM Expenses
        WHERE IsDeleted=0 AND CampId=@CampId
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)
        ORDER BY TransDate ASC;
    END
END
GO

PRINT '✅ sp_GetCampWiseReport created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 8. sp_GetPropertyWiseReport
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetPropertyWiseReport
    @FromDate      DATE         = NULL,
    @ToDate        DATE         = NULL,
    @FinancialYear NVARCHAR(20) = NULL,
    @FundPool      NVARCHAR(100)= NULL,
    @Detail        BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT=CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT=YEAR(GETDATE()); DECLARE @CM INT=MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    IF @Detail = 0
    BEGIN
        ;WITH PropData AS (
            SELECT ISNULL(i.FundPoolName,'(No Property)') AS Property,
                   i.Amount AS IncomeAmt, 0.00 AS ExpenseAmt
            FROM Incomes i WHERE i.IsDeleted=0
              AND (@FromDate IS NULL OR i.TransDate>=@FromDate)
              AND (@ToDate   IS NULL OR i.TransDate<=@ToDate)
              AND (@FundPool IS NULL OR i.FundPool=@FundPool)
            UNION ALL
            SELECT ISNULL(e.FundPoolName,'(No Property)'),
                   0.00, e.Amount
            FROM Expenses e WHERE e.IsDeleted=0
              AND (@FromDate IS NULL OR e.TransDate>=@FromDate)
              AND (@ToDate   IS NULL OR e.TransDate<=@ToDate)
              AND (@FundPool IS NULL OR e.FundPool=@FundPool)
        )
        SELECT Property,
               ISNULL(SUM(IncomeAmt),0) AS TotalIncome,
               ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
               ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS NetAmount
        FROM PropData GROUP BY Property ORDER BY Property;
    END
    ELSE
    BEGIN
        SELECT TransDate, VoucherNo, 'Income' AS VoucherType, Head AS AccountHead,
               Amount, ISNULL(Purpose,'') AS Purpose
        FROM Incomes
        WHERE IsDeleted=0 AND FundPool=@FundPool
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)
        UNION ALL
        SELECT TransDate, VoucherNo, 'Expense', Head, Amount, ISNULL(Purpose,'')
        FROM Expenses
        WHERE IsDeleted=0 AND FundPool=@FundPool
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)
        ORDER BY TransDate ASC;
    END
END
GO

PRINT '✅ sp_GetPropertyWiseReport created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 9. sp_GetMonthlyProfitSummary
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetMonthlyProfitSummary
    @FromDate      DATE         = NULL,
    @ToDate        DATE         = NULL,
    @FinancialYear NVARCHAR(20) = NULL,
    @CampId        INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT=CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT=YEAR(GETDATE()); DECLARE @CM INT=MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    ;WITH Monthly AS (
        SELECT FORMAT(TransDate,'yyyy-MM') AS YearMonth, Amount AS IncomeAmt, 0.00 AS ExpenseAmt
        FROM Incomes
        WHERE IsDeleted=0 AND (@FromDate IS NULL OR TransDate>=@FromDate) AND (@ToDate IS NULL OR TransDate<=@ToDate)
          AND (@CampId IS NULL OR CampId=@CampId)
        UNION ALL
        SELECT FORMAT(TransDate,'yyyy-MM'), 0.00, Amount
        FROM Expenses
        WHERE IsDeleted=0 AND (@FromDate IS NULL OR TransDate>=@FromDate) AND (@ToDate IS NULL OR TransDate<=@ToDate)
          AND (@CampId IS NULL OR CampId=@CampId)
    )
    SELECT YearMonth AS [Month],
           ISNULL(SUM(IncomeAmt),0) AS TotalIncome,
           ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
           ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS Profit
    FROM Monthly GROUP BY YearMonth ORDER BY YearMonth ASC;

    -- Grand total (separate aggregates — no CROSS JOIN)
    SELECT
        ISNULL((SELECT SUM(Amount) FROM Incomes WHERE IsDeleted=0
                AND (@FromDate IS NULL OR TransDate>=@FromDate)
                AND (@ToDate IS NULL OR TransDate<=@ToDate)
                AND (@CampId IS NULL OR CampId=@CampId)), 0) AS GrandIncome,
        ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                AND (@FromDate IS NULL OR TransDate>=@FromDate)
                AND (@ToDate IS NULL OR TransDate<=@ToDate)
                AND (@CampId IS NULL OR CampId=@CampId)), 0) AS GrandExpense,
        ISNULL((SELECT SUM(Amount) FROM Incomes WHERE IsDeleted=0
                AND (@FromDate IS NULL OR TransDate>=@FromDate)
                AND (@ToDate IS NULL OR TransDate<=@ToDate)
                AND (@CampId IS NULL OR CampId=@CampId)), 0)
        - ISNULL((SELECT SUM(Amount) FROM Expenses WHERE IsDeleted=0
                AND (@FromDate IS NULL OR TransDate>=@FromDate)
                AND (@ToDate IS NULL OR TransDate<=@ToDate)
                AND (@CampId IS NULL OR CampId=@CampId)), 0) AS GrandProfit;
END
GO

PRINT '✅ sp_GetMonthlyProfitSummary created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 10. sp_GetFinancialYearSummary
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetFinancialYearSummary
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AllTxn AS (
        SELECT TransDate, Amount AS IncomeAmt, 0.00 AS ExpenseAmt FROM Incomes  WHERE IsDeleted=0
        UNION ALL
        SELECT TransDate, 0.00, Amount          FROM Expenses WHERE IsDeleted=0
    ),
    FYData AS (
        SELECT
            CAST(CASE WHEN MONTH(TransDate)>=4 THEN YEAR(TransDate) ELSE YEAR(TransDate)-1 END AS NVARCHAR)
            + '-'
            + CAST(CASE WHEN MONTH(TransDate)>=4 THEN YEAR(TransDate)+1 ELSE YEAR(TransDate) END AS NVARCHAR)
            AS FinancialYear,
            IncomeAmt, ExpenseAmt
        FROM AllTxn
    )
    SELECT FinancialYear,
           ISNULL(SUM(IncomeAmt),0) AS TotalIncome,
           ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
           ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS NetProfit,
           CASE WHEN SUM(IncomeAmt)=0 THEN 0
                ELSE ROUND((SUM(IncomeAmt)-SUM(ExpenseAmt))/SUM(IncomeAmt)*100, 2)
           END AS ProfitPercentage
    FROM FYData GROUP BY FinancialYear ORDER BY FinancialYear ASC;
END
GO

PRINT '✅ sp_GetFinancialYearSummary created.';
GO

-- ══════════════════════════════════════════════════════════════
-- 11. sp_GetPaymentModeReport
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetPaymentModeReport
    @FromDate      DATE         = NULL,
    @ToDate        DATE         = NULL,
    @FinancialYear NVARCHAR(20) = NULL,
    @Mode          NVARCHAR(100)= NULL,
    @Detail        BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL AND @FromDate IS NULL
    BEGIN
        DECLARE @FY INT=CAST(LEFT(@FinancialYear,4) AS INT);
        SET @FromDate=DATEFROMPARTS(@FY,4,1); SET @ToDate=DATEFROMPARTS(@FY+1,3,31);
    END
    IF @FromDate IS NULL
    BEGIN
        DECLARE @CY INT=YEAR(GETDATE()); DECLARE @CM INT=MONTH(GETDATE());
        IF @CM>=4 BEGIN SET @FromDate=DATEFROMPARTS(@CY,4,1); SET @ToDate=DATEFROMPARTS(@CY+1,3,31); END
        ELSE BEGIN SET @FromDate=DATEFROMPARTS(@CY-1,4,1); SET @ToDate=DATEFROMPARTS(@CY,3,31); END
    END

    IF @Detail = 0
    BEGIN
        ;WITH ModeData AS (
            SELECT ISNULL(i.Mode,'Cash') AS PayMode, i.Amount AS IncomeAmt, 0.00 AS ExpenseAmt
            FROM Incomes i WHERE i.IsDeleted=0
              AND (@FromDate IS NULL OR i.TransDate>=@FromDate)
              AND (@ToDate   IS NULL OR i.TransDate<=@ToDate)
              AND (@Mode IS NULL OR i.Mode=@Mode)
            UNION ALL
            SELECT ISNULL(e.Mode,'Cash'), 0.00, e.Amount
            FROM Expenses e WHERE e.IsDeleted=0
              AND (@FromDate IS NULL OR e.TransDate>=@FromDate)
              AND (@ToDate   IS NULL OR e.TransDate<=@ToDate)
              AND (@Mode IS NULL OR e.Mode=@Mode)
        )
        SELECT PayMode AS [Mode],
               ISNULL(SUM(IncomeAmt),0) AS TotalIncome,
               ISNULL(SUM(ExpenseAmt),0) AS TotalExpense,
               ISNULL(SUM(IncomeAmt)-SUM(ExpenseAmt),0) AS NetAmount
        FROM ModeData GROUP BY PayMode ORDER BY PayMode;
    END
    ELSE
    BEGIN
        SELECT TransDate, VoucherNo, 'Income' AS VoucherType,
               Head AS AccountHead, Amount, ISNULL(Purpose,'') AS Purpose
        FROM Incomes
        WHERE IsDeleted=0 AND Mode=@Mode
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)
        UNION ALL
        SELECT TransDate, VoucherNo, 'Expense', Head, Amount, ISNULL(Purpose,'')
        FROM Expenses
        WHERE IsDeleted=0 AND Mode=@Mode
          AND (@FromDate IS NULL OR TransDate>=@FromDate)
          AND (@ToDate   IS NULL OR TransDate<=@ToDate)
        ORDER BY TransDate ASC;
    END
END
GO

PRINT '✅ sp_GetPaymentModeReport created.';
GO

PRINT '═══════════════════════════════════════════════════════════';
PRINT '✅ 157 - All Account Voucher Report SPs Complete!';
PRINT '   1.  sp_GetDayBook';
PRINT '   2.  sp_GetVoucherRegister';
PRINT '   3.  sp_GetVoucherDetail';
PRINT '   4.  sp_GetIncomeRegister';
PRINT '   5.  sp_GetExpenseRegister';
PRINT '   6.  sp_GetAccountHeadLedger';
PRINT '   7.  sp_GetCampWiseReport';
PRINT '   8.  sp_GetPropertyWiseReport';
PRINT '   9.  sp_GetMonthlyProfitSummary';
PRINT '  10.  sp_GetFinancialYearSummary';
PRINT '  11.  sp_GetPaymentModeReport';
PRINT '═══════════════════════════════════════════════════════════';
GO
