-- ============================================================
-- 067: sp_GetTransactionReport
--      Income + Expense tables se data
--      Filters: DateFrom, DateTo, AccountHead, Party, CampId,
--               FundPool, Type (Income/Expense), Source, Mode, Role
--      Cards: NoOfPayments, TotalIncome, TotalExpense, TotalAmount
-- Date: July 24, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetTransactionReport
    @PageNumber   INT            = 1,
    @PageSize     INT            = 2147483647,
    @DateFrom     DATE           = NULL,
    @DateTo       DATE           = NULL,
    @AccountHead  NVARCHAR(MAX)  = NULL,
    @Party        NVARCHAR(MAX)  = NULL,   -- Party / Recipient name search
    @CampId       INT            = NULL,
    @FundPool     NVARCHAR(MAX)  = NULL,
    @Type         NVARCHAR(MAX)  = NULL,   -- 'Income' or 'Expense'
    @Source       NVARCHAR(MAX)  = NULL,
    @Mode         NVARCHAR(MAX)  = NULL,
    @Role         NVARCHAR(MAX)  = NULL,   -- RecipientRole in Expenses / Source in Incomes
    @SearchText   NVARCHAR(MAX)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Build combined temp table ────────────────────────────────────
    IF OBJECT_ID('tempdb..#TxnAll') IS NOT NULL DROP TABLE #TxnAll;

    CREATE TABLE #TxnAll (
        Id            INT,
        TxnDate       DATE,
        AccountHead   NVARCHAR(MAX),
        Party         NVARCHAR(MAX),
        CampName      NVARCHAR(MAX),
        FundPool      NVARCHAR(MAX),
        FundPoolName  NVARCHAR(MAX),
        TxnType       NVARCHAR(MAX),   -- 'Income' | 'Expense'
        Source        NVARCHAR(MAX),
        Mode          NVARCHAR(MAX),
        Amount        DECIMAL(18,2),
        Role          NVARCHAR(MAX),
        RefId         NVARCHAR(MAX)    -- IncomeId or ExpenseId
    );

    -- ── 1. INSERT from Incomes ───────────────────────────────────────
    INSERT INTO #TxnAll
    SELECT
        i.Id,
        i.Date,
        ISNULL(i.Head,        ''),
        ISNULL(i.TenantName,  ISNULL(i.PartnerName, ISNULL(i.Source, ''))),
        ISNULL(i.CampName,    ''),
        ISNULL(i.FundPool,    ''),
        ISNULL(i.FundPoolName,''),
        'Income',
        ISNULL(i.Source,      ''),
        ISNULL(i.Mode,        ''),
        ISNULL(i.Amount,      0),
        ISNULL(i.Source,      ''),   -- Role = Source for income
        ISNULL(i.IncomeId,    '')
    FROM Incomes i
    WHERE (@Type IS NULL OR @Type = 'Income');

    -- ── 2. INSERT from Expenses ──────────────────────────────────────
    INSERT INTO #TxnAll
    SELECT
        e.Id,
        e.Date,
        ISNULL(e.Head,          ''),
        ISNULL(e.RecipientName, ''),
        ISNULL(e.CampName,      ''),
        ISNULL(e.FundPool,      ''),
        ISNULL(e.FundPoolName,  ''),
        'Expense',
        ISNULL(e.RecipientRole, ''),
        ISNULL(e.Mode,          ''),
        ISNULL(e.Amount,        0),
        ISNULL(e.RecipientRole, ''),
        ISNULL(e.ExpenseId,     '')
    FROM Expenses e
    WHERE (@Type IS NULL OR @Type = 'Expense');

    -- ── 3. COUNT with filters ────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM #TxnAll
    WHERE
        (@DateFrom    IS NULL OR TxnDate     >= @DateFrom)
    AND (@DateTo      IS NULL OR TxnDate     <= @DateTo)
    AND (@AccountHead IS NULL OR AccountHead  = @AccountHead)
    AND (@CampId      IS NULL OR CampName IN (SELECT Name FROM Camps WHERE Id = @CampId))
    AND (@FundPool    IS NULL OR FundPool     = @FundPool)
    AND (@Mode        IS NULL OR Mode         = @Mode)
    AND (@Role        IS NULL OR Role         = @Role)
    AND (@Source      IS NULL OR Source       = @Source)
    AND (@Party       IS NULL OR Party LIKE '%' + @Party + '%')
    AND (@SearchText  IS NULL OR
         AccountHead  LIKE '%' + @SearchText + '%' OR
         Party        LIKE '%' + @SearchText + '%' OR
         CampName     LIKE '%' + @SearchText + '%' OR
         RefId        LIKE '%' + @SearchText + '%');

    -- ── 4. Paginated result ──────────────────────────────────────────
    SELECT
        Id,
        TxnDate       [Date],
        AccountHead,
        Party         [PartyRecipient],
        CampName,
        FundPool,
        FundPoolName,
        TxnType       [Type],
        Source,
        Mode,
        Amount,
        Role,
        RefId
    FROM #TxnAll
    WHERE
        (@DateFrom    IS NULL OR TxnDate     >= @DateFrom)
    AND (@DateTo      IS NULL OR TxnDate     <= @DateTo)
    AND (@AccountHead IS NULL OR AccountHead  = @AccountHead)
    AND (@CampId      IS NULL OR CampName IN (SELECT Name FROM Camps WHERE Id = @CampId))
    AND (@FundPool    IS NULL OR FundPool     = @FundPool)
    AND (@Mode        IS NULL OR Mode         = @Mode)
    AND (@Role        IS NULL OR Role         = @Role)
    AND (@Source      IS NULL OR Source       = @Source)
    AND (@Party       IS NULL OR Party LIKE '%' + @Party + '%')
    AND (@SearchText  IS NULL OR
         AccountHead  LIKE '%' + @SearchText + '%' OR
         Party        LIKE '%' + @SearchText + '%' OR
         CampName     LIKE '%' + @SearchText + '%' OR
         RefId        LIKE '%' + @SearchText + '%')
    ORDER BY TxnDate DESC, Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- ── 5. Summary cards ────────────────────────────────────────────
    SELECT
        COUNT(*)                                                  NoOfPayments,
        SUM(CASE WHEN TxnType = 'Income'  THEN Amount ELSE 0 END) TotalIncome,
        SUM(CASE WHEN TxnType = 'Expense' THEN Amount ELSE 0 END) TotalExpense,
        SUM(Amount)                                               TotalAmount
    FROM #TxnAll
    WHERE
        (@DateFrom    IS NULL OR TxnDate     >= @DateFrom)
    AND (@DateTo      IS NULL OR TxnDate     <= @DateTo)
    AND (@AccountHead IS NULL OR AccountHead  = @AccountHead)
    AND (@CampId      IS NULL OR CampName IN (SELECT Name FROM Camps WHERE Id = @CampId))
    AND (@FundPool    IS NULL OR FundPool     = @FundPool)
    AND (@Mode        IS NULL OR Mode         = @Mode)
    AND (@Role        IS NULL OR Role         = @Role)
    AND (@Source      IS NULL OR Source       = @Source)
    AND (@Party       IS NULL OR Party LIKE '%' + @Party + '%')
    AND (@SearchText  IS NULL OR
         AccountHead  LIKE '%' + @SearchText + '%' OR
         Party        LIKE '%' + @SearchText + '%' OR
         CampName     LIKE '%' + @SearchText + '%' OR
         RefId        LIKE '%' + @SearchText + '%');

    DROP TABLE #TxnAll;
END
GO

PRINT '067 - sp_GetTransactionReport: Income+Expense tables, all filters, cards';
GO
