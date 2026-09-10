SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetFundPoolReport
    @FundPoolId   INT           = NULL,
    @SearchText   NVARCHAR(200) = NULL,
    @Status       NVARCHAR(50)  = NULL,
    @Month        INT           = NULL,   -- 1..12
    @Year         INT           = NULL,   -- e.g. 2026
    @DateFrom     DATE          = NULL,   -- fallback
    @DateTo       DATE          = NULL,   -- fallback
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @TotalRecords INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Resolve selected month boundaries ────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    -- Current month date range
    DECLARE @CurFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @CurTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- Buffer starts NEXT month
    DECLARE @BufFrom DATE = DATEADD(MONTH, 1, @CurFrom);

    -- Month labels
    -- CRI format: 'Jul26'
    DECLARE @CriMonthLabel NVARCHAR(10) =
        LEFT(DATENAME(MONTH, @CurFrom), 3) + RIGHT(CAST(@SelYear AS NVARCHAR(4)), 2);
    -- CRI buffer: all months > current → we use PaidDate >= @BufFrom

    -- OMCI format: 'Jul 2026'
    DECLARE @OmciMonthLabel NVARCHAR(20) =
        LEFT(DATENAME(MONTH, @CurFrom), 3) + ' ' + CAST(@SelYear AS NVARCHAR(4));
    -- OMCI buffer: Month string converted to date > @CurTo

    -- ── Total count ───────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM FundPools fp
    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (@FundPoolId IS NULL OR fp.Id = @FundPoolId)
      AND (@Status     IS NULL OR fp.Status = @Status)
      AND (@SearchText IS NULL OR fp.Name LIKE '%'+@SearchText+'%'
                               OR fp.Code LIKE '%'+@SearchText+'%');

    -- ── CurrentFundTransfer month label (matches CurrentMonth column)
    -- Same format as @OmciMonthLabel: 'September 2026'
    DECLARE @CftMonthLabel NVARCHAR(20) =
        DATENAME(MONTH, @CurFrom) + ' ' + CAST(@SelYear AS NVARCHAR(4));

    -- ════════════════════════════════════════════════════════════
    -- Pre-aggregate Current Income per FundPool
    -- ════════════════════════════════════════════════════════════
    -- CTE 1: Tenant Rental Collection via CRI (Month = @CriMonthLabel)
    -- Only Status IN ('Paid','PaidPartial') → these belong to CURRENT income
    ;WITH CTE_TenantCRI_Cur AS (
        SELECT i.FundPool,
               SUM(cri.PaidAmount) AS TenantCRIAmt
        FROM (
            SELECT DISTINCT i2.FundPool, cri2.Id, cri2.PaidAmount
            FROM Incomes i2
            INNER JOIN ContractRoomInstallments cri2
                ON cri2.ContractId = i2.ContractId
               AND cri2.PaidDate   = i2.[Date]
               AND ISNULL(cri2.IsDeleted,0) = 0
               AND cri2.Month = @CriMonthLabel
               AND cri2.Status IN ('Paid', 'PaidPartial')   -- ✅ Current: only Paid/PaidPartial
            WHERE i2.Source = 'Tenant'
              AND i2.Head   = 'RENTAL COLLECTION'
              AND ISNULL(i2.IsDeleted,0) = 0
        ) i
        INNER JOIN ContractRoomInstallments cri ON cri.Id = i.Id
        GROUP BY i.FundPool
    ),
    -- CTE 2: Other Income (exclude Tenant RENTAL COLLECTION) for current month
    CTE_OtherIncome_Cur AS (
        SELECT i.FundPool,
               SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted,0) = 0
          AND NOT (i.Source = 'Tenant' AND i.Head = 'RENTAL COLLECTION')
          AND i.[Date] >= @CurFrom
          AND i.[Date] <= @CurTo
        GROUP BY i.FundPool
    ),
    -- CTE 3: Owner Payment via OMCI (Month = @OmciMonthLabel) for current month
    -- Extract OcCode from Expenses.Purpose pattern: 'Owner Payment - OC-xxxxx - ...'
    CTE_OwnerOMCI_Cur AS (
        SELECT e.FundPool,
               SUM(omci.Amount) AS OwnerAmt
        FROM Expenses e
        INNER JOIN OwnerContracts oc
            ON oc.OcCode = LTRIM(RTRIM(
                              SUBSTRING(e.Purpose,
                                  CHARINDEX('- ', e.Purpose) + 2,
                                  CHARINDEX(' - Inst', e.Purpose)
                                  - CHARINDEX('- ', e.Purpose) - 2)
                           ))
           AND ISNULL(oc.IsDeleted,0) = 0
        INNER JOIN OwnerMonthlyContractInstallments omci
            ON omci.OwnerContractId = oc.Id
           AND omci.PaidDate = e.[Date]
           AND omci.Month    = @OmciMonthLabel
           AND ISNULL(omci.IsDeleted,0) = 0
        WHERE e.RecipientRole = 'Owner'
          AND e.Head          = 'LANDLORD CHO'
          AND ISNULL(e.IsDeleted,0) = 0
          AND e.[Date] >= @CurFrom
          AND e.[Date] <= @CurTo
          AND CHARINDEX('- ', e.Purpose) > 0
          AND CHARINDEX(' - Inst', e.Purpose) > 0
        GROUP BY e.FundPool
    ),
    -- CTE 4: Other Expense (exclude Owner LANDLORD CHO) for current month
    CTE_OtherExpense_Cur AS (
        SELECT e.FundPool,
               SUM(e.Amount) AS OtherExpAmt
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted,0) = 0
          AND NOT (e.RecipientRole = 'Owner' AND e.Head = 'LANDLORD CHO')
          AND e.[Date] >= @CurFrom
          AND e.[Date] <= @CurTo
        GROUP BY e.FundPool
    ),

    -- ════════════════════════════════════════════════════════════
    -- Pre-aggregate Buffer Income per FundPool
    -- ════════════════════════════════════════════════════════════
    -- CTE 5: Tenant CRI Buffer
    -- Only Status IN ('Advanced','AdvancedPartial') → advance payments = buffer income
    -- Explicitly exclude Paid/PaidPartial so they never appear in buffer
    CTE_TenantCRI_Buf AS (
        SELECT i.FundPool,
               SUM(cri.PaidAmount) AS TenantCRIAmt
        FROM (
            SELECT DISTINCT i2.FundPool, cri2.Id, cri2.PaidAmount
            FROM Incomes i2
            INNER JOIN ContractRoomInstallments cri2
                ON cri2.ContractId = i2.ContractId
               AND cri2.PaidDate   = i2.[Date]
               AND ISNULL(cri2.IsDeleted,0) = 0
               AND cri2.PaidAmount > 0
               AND cri2.Status IN ('Advanced', 'AdvancedPartial')   -- ✅ Buffer: only Advanced/AdvancedPartial
               AND cri2.Status NOT IN ('Paid', 'PaidPartial')       -- ✅ Never mix with current income
               AND cri2.Month <> @CriMonthLabel  -- exclude current month label
               AND TRY_CAST(
                       '01 ' + LEFT(cri2.Month, 3) + ' 20' + RIGHT(cri2.Month, 2) AS DATE
                   ) > @CurTo  -- future months only
            WHERE i2.Source = 'Tenant'
              AND i2.Head   = 'RENTAL COLLECTION'
              AND ISNULL(i2.IsDeleted,0) = 0
        ) i
        INNER JOIN ContractRoomInstallments cri ON cri.Id = i.Id
        GROUP BY i.FundPool
    ),
    -- CTE 6: Other Income Buffer
    CTE_OtherIncome_Buf AS (
        SELECT i.FundPool,
               SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted,0) = 0
          AND NOT (i.Source = 'Tenant' AND i.Head = 'RENTAL COLLECTION')
          AND i.[Date] >= @BufFrom
        GROUP BY i.FundPool
    ),
    -- CTE 7: Owner OMCI Buffer
    -- Convert OMCI Month string 'Jul 2026' -> date, filter > @CurTo
    CTE_OwnerOMCI_Buf AS (
        SELECT e.FundPool,
               SUM(omci.Amount) AS OwnerAmt
        FROM Expenses e
        INNER JOIN OwnerContracts oc
            ON oc.OcCode = LTRIM(RTRIM(
                              SUBSTRING(e.Purpose,
                                  CHARINDEX('- ', e.Purpose) + 2,
                                  CHARINDEX(' - Inst', e.Purpose)
                                  - CHARINDEX('- ', e.Purpose) - 2)
                           ))
           AND ISNULL(oc.IsDeleted,0) = 0
        INNER JOIN OwnerMonthlyContractInstallments omci
            ON omci.OwnerContractId = oc.Id
           AND omci.PaidDate = e.[Date]
           -- Buffer: OMCI.Month converted to date > @CurTo
           AND TRY_CAST(
                   '01 ' + omci.Month AS DATE
               ) > @CurTo
           AND ISNULL(omci.IsDeleted,0) = 0
        WHERE e.RecipientRole = 'Owner'
          AND e.Head          = 'LANDLORD CHO'
          AND ISNULL(e.IsDeleted,0) = 0
          AND e.[Date] >= @BufFrom
          AND CHARINDEX('- ', e.Purpose) > 0
          AND CHARINDEX(' - Inst', e.Purpose) > 0
        GROUP BY e.FundPool
    ),
    -- CTE 8: Other Expense Buffer
    CTE_OtherExpense_Buf AS (
        SELECT e.FundPool,
               SUM(e.Amount) AS OtherExpAmt
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted,0) = 0
          AND NOT (e.RecipientRole = 'Owner' AND e.Head = 'LANDLORD CHO')
          AND e.[Date] >= @BufFrom
        GROUP BY e.FundPool
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 9 & 10: CurrentFundTransfer adjustments
    -- Filter: CurrentMonth = 'September 2026' AND IsDeleted = 0
    -- FromCurrentFundPoolId → amount goes OUT  (subtract from balance)
    -- ToCurrentFundPoolId   → amount comes IN  (add to balance)
    -- ════════════════════════════════════════════════════════════
    CTE_CFT_Out AS (
        -- Fund pools that SENT money → their balance decreases
        SELECT cft.FromCurrentFundPoolId AS FundPoolId,
               SUM(cft.CurrentAmount)    AS TransferOutAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.CurrentMonth = @CftMonthLabel
          AND cft.Status = 'Active'
        GROUP BY cft.FromCurrentFundPoolId
    ),
    CTE_CFT_In AS (
        -- Fund pools that RECEIVED money → their balance increases
        SELECT cft.ToCurrentFundPoolId AS FundPoolId,
               SUM(cft.CurrentAmount)  AS TransferInAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.CurrentMonth = @CftMonthLabel
          AND cft.Status = 'Active'
          AND cft.ToCurrentFundPoolId IS NOT NULL
        GROUP BY cft.ToCurrentFundPoolId
    ),

    -- ════════════════════════════════════════════════════════════
    -- CTE 11 & 12: BufferFundTransfer adjustments
    -- Filter: BufferMonth = 'September 2026' AND IsDeleted = 0
    -- FromBufferFundPoolId → amount goes OUT  (subtract from bufferTotalAmount)
    -- ToBufferFundPoolId   → amount comes IN  (add to bufferTotalAmount)
    -- ════════════════════════════════════════════════════════════
    CTE_BFT_Out AS (
        -- Fund pools that SENT buffer money → buffer balance decreases
        SELECT bft.FromBufferFundPoolId AS FundPoolId,
               SUM(bft.BufferAmount)    AS BufferTransferOutAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.BufferMonth = @CftMonthLabel
          AND bft.Status = 'Active'
        GROUP BY bft.FromBufferFundPoolId
    ),
    CTE_BFT_In AS (
        -- Fund pools that RECEIVED buffer money → buffer balance increases
        SELECT bft.ToBufferFundPoolId AS FundPoolId,
               SUM(bft.BufferAmount)  AS BufferTransferInAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.BufferMonth = @CftMonthLabel
          AND bft.Status = 'Active'
          AND bft.ToBufferFundPoolId IS NOT NULL
        GROUP BY bft.ToBufferFundPoolId
    )

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 1: Current + Buffer per Fund Pool
    -- ════════════════════════════════════════════════════════════
    SELECT
        fp.Id                                                       AS FundPoolId,
        fp.Code                                                     AS FundPoolCode,
        fp.Name                                                     AS FundPoolName,
        fp.Status,

        -- CurrentBalance = FundPool.Balance
        --   + transfers received (ToCurrentFundPoolId = this pool)
        --   - transfers sent     (FromCurrentFundPoolId = this pool)
        fp.Balance
        + ISNULL(cft_in.TransferInAmt,  0)
        - ISNULL(cft_out.TransferOutAmt, 0)                        AS CurrentBalance,

        -- Current Income = CRI Tenant Rental + Other Income
        ISNULL(cur_t.TenantCRIAmt, 0)
        + ISNULL(cur_o.OtherIncAmt, 0)                             AS TotalIncome,

        -- Current Expense = Owner OMCI + Other Expense
        ISNULL(cur_ow.OwnerAmt, 0)
        + ISNULL(cur_e.OtherExpAmt, 0)                             AS TotalExpense,

        -- Total Amount = Total Income + Total Expense
        ISNULL(cur_t.TenantCRIAmt, 0) + ISNULL(cur_o.OtherIncAmt, 0)
        + ISNULL(cur_ow.OwnerAmt, 0)  + ISNULL(cur_e.OtherExpAmt, 0) AS TotalPaymentsReceived,

        -- Difference = Income - Expense
        (ISNULL(cur_t.TenantCRIAmt,0) + ISNULL(cur_o.OtherIncAmt,0))
        - (ISNULL(cur_ow.OwnerAmt,0) + ISNULL(cur_e.OtherExpAmt,0)) AS NetAmount,

        -- BufferAmount (for backward compat)
        ISNULL(buf_t.TenantCRIAmt,0) + ISNULL(buf_o.OtherIncAmt,0) AS BufferAmount,

        -- Buffer Income
        ISNULL(buf_t.TenantCRIAmt, 0)
        + ISNULL(buf_o.OtherIncAmt, 0)                             AS BufferTotalIncome,

        -- Buffer Expense
        ISNULL(buf_ow.OwnerAmt, 0)
        + ISNULL(buf_e.OtherExpAmt, 0)                             AS BufferTotalExpense,

        -- Buffer Total Amount = Buffer Income + Buffer Expense
        --   + BufferFundTransfer received (ToBufferFundPoolId = this pool)
        --   - BufferFundTransfer sent     (FromBufferFundPoolId = this pool)
        ISNULL(buf_t.TenantCRIAmt,0) + ISNULL(buf_o.OtherIncAmt,0)
        + ISNULL(buf_ow.OwnerAmt,0)  + ISNULL(buf_e.OtherExpAmt,0)
        + ISNULL(bft_in.BufferTransferInAmt,  0)
        - ISNULL(bft_out.BufferTransferOutAmt, 0)                  AS BufferTotalAmount,

        -- Buffer Difference = Buffer Income - Buffer Expense
        (ISNULL(buf_t.TenantCRIAmt,0) + ISNULL(buf_o.OtherIncAmt,0))
        - (ISNULL(buf_ow.OwnerAmt,0)  + ISNULL(buf_e.OtherExpAmt,0)) AS BufferNetAmount,

        0 AS IncomeCount, 0 AS ExpenseCount, 0 AS PaymentCount,
        fp.CreatedAt, fp.UpdatedAt

    FROM FundPools fp
    -- Current CTEs
    LEFT JOIN CTE_TenantCRI_Cur    cur_t  ON cur_t.FundPool  = fp.Code
    LEFT JOIN CTE_OtherIncome_Cur  cur_o  ON cur_o.FundPool  = fp.Code
    LEFT JOIN CTE_OwnerOMCI_Cur    cur_ow ON cur_ow.FundPool = fp.Code
    LEFT JOIN CTE_OtherExpense_Cur cur_e  ON cur_e.FundPool  = fp.Code
    -- Buffer CTEs
    LEFT JOIN CTE_TenantCRI_Buf    buf_t  ON buf_t.FundPool  = fp.Code
    LEFT JOIN CTE_OtherIncome_Buf  buf_o  ON buf_o.FundPool  = fp.Code
    LEFT JOIN CTE_OwnerOMCI_Buf    buf_ow ON buf_ow.FundPool = fp.Code
    LEFT JOIN CTE_OtherExpense_Buf buf_e  ON buf_e.FundPool  = fp.Code
    -- CurrentFundTransfer adjustments (join on FundPool.Id)
    LEFT JOIN CTE_CFT_Out          cft_out ON cft_out.FundPoolId = fp.Id
    LEFT JOIN CTE_CFT_In           cft_in  ON cft_in.FundPoolId  = fp.Id
    -- BufferFundTransfer adjustments (join on FundPool.Id)
    LEFT JOIN CTE_BFT_Out          bft_out ON bft_out.FundPoolId = fp.Id
    LEFT JOIN CTE_BFT_In           bft_in  ON bft_in.FundPoolId  = fp.Id

    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (@FundPoolId IS NULL OR fp.Id = @FundPoolId)
      AND (@Status     IS NULL OR fp.Status = @Status)
      AND (@SearchText IS NULL OR fp.Name LIKE '%'+@SearchText+'%'
                               OR fp.Code LIKE '%'+@SearchText+'%')
    ORDER BY fp.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 2: Buffer rows (same data as RS1 buffer columns, all fund pools)
    -- ════════════════════════════════════════════════════════════
    -- Empty result set for backward compatibility
    SELECT
        0 AS FundPoolId, '' AS FundPoolCode, '' AS FundPoolName, '' AS Status,
        CAST(0 AS DECIMAL(18,2)) AS CurrentBalance,
        CAST(0 AS DECIMAL(18,2)) AS TotalIncome,
        CAST(0 AS DECIMAL(18,2)) AS TotalExpense,
        CAST(0 AS DECIMAL(18,2)) AS TotalPaymentsReceived,
        CAST(0 AS DECIMAL(18,2)) AS NetAmount,
        CAST(0 AS DECIMAL(18,2)) AS BufferTotalAmount
    WHERE 1 = 0;  -- empty set, buffer data is in RS1 columns

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 3: Transactions (single fund pool drill-down)
    -- ════════════════════════════════════════════════════════════
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT TOP 50 TxnType, TxnDate, Amount, Head, Mode, CampName, Purpose, VoucherNo, CreatedAt
        FROM (
            SELECT 'Income' AS TxnType, i.[Date] AS TxnDate, i.Amount, i.Head, i.Mode,
                   ISNULL(i.CampName,'') CampName, ISNULL(i.Purpose,'') Purpose,
                   ISNULL(i.VoucherNo,'') VoucherNo, i.CreatedAt
            FROM Incomes i
            WHERE i.FundPool=(SELECT Code FROM FundPools WHERE Id=@FundPoolId AND ISNULL(IsDeleted,0)=0)
              AND ISNULL(i.IsDeleted,0)=0
              AND i.[Date] >= @CurFrom AND i.[Date] <= @CurTo
            UNION ALL
            SELECT 'Expense', e.[Date], e.Amount, e.Head, e.Mode,
                   ISNULL(e.CampName,''), ISNULL(e.Purpose,''), ISNULL(e.VoucherNo,''), e.CreatedAt
            FROM Expenses e
            WHERE e.FundPool=(SELECT Code FROM FundPools WHERE Id=@FundPoolId AND ISNULL(IsDeleted,0)=0)
              AND ISNULL(e.IsDeleted,0)=0
              AND e.[Date] >= @CurFrom AND e.[Date] <= @CurTo
        ) txn ORDER BY txn.TxnDate DESC;
    END
END
GO

PRINT 'sp_GetFundPoolReport updated with CTE-based Income/Expense/Buffer logic.';
GO
