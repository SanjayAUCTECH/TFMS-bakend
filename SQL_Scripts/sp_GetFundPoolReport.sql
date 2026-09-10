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

    -- ── Date variables ────────────────────────────────────────────
    DECLARE @SelYear  INT  = ISNULL(@Year,  YEAR(GETDATE()));
    DECLARE @SelMonth INT  = ISNULL(@Month, MONTH(GETDATE()));

    -- ── SINGLE MONTH range (for TotalIncome, TotalExpense, NetAmount etc.) ──
    DECLARE @MonFrom DATE = DATEFROMPARTS(@SelYear, @SelMonth, 1);
    DECLARE @MonTo   DATE = EOMONTH(DATEFROMPARTS(@SelYear, @SelMonth, 1));

    -- ── CUMULATIVE range Jan→SelectedMonth (for CurrentBalance, BufferTotalIncome) ──
    DECLARE @RngFrom DATE = DATEFROMPARTS(@SelYear, 1, 1);
    DECLARE @RngTo   DATE = @MonTo;

    -- Buffer starts NEXT month after selected month
    DECLARE @BufFrom DATE = DATEADD(MONTH, 1, @MonFrom);

    -- Month labels for CRI (e.g. 'Aug26') and OMCI (e.g. 'Aug 2026') — single month
    DECLARE @CriMonthLabel  NVARCHAR(10) =
        LEFT(DATENAME(MONTH, @MonFrom), 3) + RIGHT(CAST(@SelYear AS NVARCHAR(4)), 2);
    DECLARE @OmciMonthLabel NVARCHAR(20) =
        LEFT(DATENAME(MONTH, @MonFrom), 3) + ' ' + CAST(@SelYear AS NVARCHAR(4));

    -- ── Total count ───────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM FundPools fp
    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (@FundPoolId IS NULL OR fp.Id = @FundPoolId)
      AND (@Status     IS NULL OR fp.Status = @Status)
      AND (@SearchText IS NULL OR fp.Name LIKE '%'+@SearchText+'%'
                               OR fp.Code LIKE '%'+@SearchText+'%');

    -- ════════════════════════════════════════════════════════════
    -- ██ SINGLE MONTH CTEs — TotalIncome, TotalExpense, NetAmount
    -- ════════════════════════════════════════════════════════════

    ;WITH

    -- CTE 1: Tenant CRI — single selected month only
    CTE_TenantCRI_Mon AS (
        SELECT i.FundPool,
               SUM(cri.PaidAmount) AS TenantCRIAmt
        FROM (
            SELECT DISTINCT i2.FundPool, cri2.Id, cri2.PaidAmount
            FROM Incomes i2
            INNER JOIN ContractRoomInstallments cri2
                ON cri2.ContractId = i2.ContractId
               AND cri2.PaidDate   = i2.[Date]
               AND ISNULL(cri2.IsDeleted,0) = 0
               AND cri2.Month  = @CriMonthLabel
               AND cri2.Status IN ('Paid', 'PaidPartial')
            WHERE i2.Source = 'Tenant'
              AND i2.Head   = 'RENTAL COLLECTION'
              AND ISNULL(i2.IsDeleted,0) = 0
        ) i
        INNER JOIN ContractRoomInstallments cri ON cri.Id = i.Id
        GROUP BY i.FundPool
    ),

    -- CTE 2: Other Income — single month
    CTE_OtherIncome_Mon AS (
        SELECT i.FundPool, SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted,0) = 0
          AND NOT (i.Source = 'Tenant' AND i.Head = 'RENTAL COLLECTION')
          AND i.[Date] >= @MonFrom AND i.[Date] <= @MonTo
        GROUP BY i.FundPool
    ),

    -- CTE 3: Owner OMCI — single month
    CTE_OwnerOMCI_Mon AS (
        SELECT e.FundPool, SUM(omci.Amount) AS OwnerAmt
        FROM Expenses e
        INNER JOIN OwnerContracts oc
            ON oc.OcCode = LTRIM(RTRIM(
                              SUBSTRING(e.Purpose,
                                  CHARINDEX('- ', e.Purpose) + 2,
                                  CHARINDEX(' - Inst', e.Purpose) - CHARINDEX('- ', e.Purpose) - 2)
                           ))
           AND ISNULL(oc.IsDeleted,0) = 0
        INNER JOIN OwnerMonthlyContractInstallments omci
            ON omci.OwnerContractId = oc.Id
           AND omci.PaidDate = e.[Date]
           AND omci.Month    = @OmciMonthLabel
           AND ISNULL(omci.IsDeleted,0) = 0
        WHERE e.RecipientRole = 'Owner'
          AND e.Head = 'LANDLORD CHO'
          AND ISNULL(e.IsDeleted,0) = 0
          AND e.[Date] >= @MonFrom AND e.[Date] <= @MonTo
          AND CHARINDEX('- ', e.Purpose) > 0
          AND CHARINDEX(' - Inst', e.Purpose) > 0
        GROUP BY e.FundPool
    ),

    -- CTE 4: Other Expense — single month
    CTE_OtherExpense_Mon AS (
        SELECT e.FundPool, SUM(e.Amount) AS OtherExpAmt
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted,0) = 0
          AND NOT (e.RecipientRole = 'Owner' AND e.Head = 'LANDLORD CHO')
          AND e.[Date] >= @MonFrom AND e.[Date] <= @MonTo
        GROUP BY e.FundPool
    ),

    -- ════════════════════════════════════════════════════════════
    -- ██ CUMULATIVE CTEs — CurrentBalance (Jan → SelectedMonth)
    -- ════════════════════════════════════════════════════════════

    -- CTE 5: CurrentFundTransfer OUT — cumulative range
    CTE_CFT_Out AS (
        SELECT cft.FromCurrentFundPoolId AS FundPoolId,
               SUM(cft.CurrentAmount)    AS TransferOutAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.Status = 'Active'
          AND TRY_CAST('01 ' + cft.CurrentMonth AS DATE) >= @RngFrom
          AND TRY_CAST('01 ' + cft.CurrentMonth AS DATE) <= @RngTo
        GROUP BY cft.FromCurrentFundPoolId
    ),

    -- CTE 6: CurrentFundTransfer IN — cumulative range
    CTE_CFT_In AS (
        SELECT cft.ToCurrentFundPoolId AS FundPoolId,
               SUM(cft.CurrentAmount)  AS TransferInAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.Status = 'Active'
          AND cft.ToCurrentFundPoolId IS NOT NULL
          AND TRY_CAST('01 ' + cft.CurrentMonth AS DATE) >= @RngFrom
          AND TRY_CAST('01 ' + cft.CurrentMonth AS DATE) <= @RngTo
        GROUP BY cft.ToCurrentFundPoolId
    ),

    -- ════════════════════════════════════════════════════════════
    -- ██ BUFFER CTEs — BufferTotalIncome (cumulative Jan→SelectedMonth)
    --                  BufferTotalExpense, BufferTotalAmount, BufferNetAmount (single month)
    -- ════════════════════════════════════════════════════════════

    -- CTE 7: Tenant CRI Buffer SINGLE MONTH — for BufferTotalIncome
    CTE_TenantCRI_Buf_Rng AS (
        SELECT i.FundPool, SUM(cri.PaidAmount) AS TenantCRIAmt
        FROM (
            SELECT DISTINCT i2.FundPool, cri2.Id, cri2.PaidAmount
            FROM Incomes i2
            INNER JOIN ContractRoomInstallments cri2
                ON cri2.ContractId = i2.ContractId
               AND cri2.PaidDate   = i2.[Date]
               AND ISNULL(cri2.IsDeleted,0) = 0
               AND cri2.PaidAmount > 0
               AND cri2.Status IN ('Advanced', 'AdvancedPartial')
               AND cri2.Status NOT IN ('Paid', 'PaidPartial')
               AND TRY_CAST(
                       '01 ' + LEFT(cri2.Month, 3) + ' 20' + RIGHT(cri2.Month, 2) AS DATE
                   ) > @MonTo   -- future beyond selected month
            WHERE i2.Source = 'Tenant'
              AND i2.Head   = 'RENTAL COLLECTION'
              AND ISNULL(i2.IsDeleted,0) = 0
        ) i
        INNER JOIN ContractRoomInstallments cri ON cri.Id = i.Id
        GROUP BY i.FundPool
    ),

    -- CTE 8: Other Income Buffer SINGLE MONTH — for BufferTotalIncome
    CTE_OtherIncome_Buf_Rng AS (
        SELECT i.FundPool, SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted,0) = 0
          AND NOT (i.Source = 'Tenant' AND i.Head = 'RENTAL COLLECTION')
          AND i.[Date] >= @BufFrom
        GROUP BY i.FundPool
    ),

    -- CTE 9: BufferFundTransfer OUT — CUMULATIVE (Jan → SelectedMonth) for BufferTotalAmount
    CTE_BFT_Out AS (
        SELECT bft.FromBufferFundPoolId AS FundPoolId,
               SUM(bft.BufferAmount)    AS BufferTransferOutAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.Status = 'Active'
          AND TRY_CAST('01 ' + bft.BufferMonth AS DATE) >= @RngFrom
          AND TRY_CAST('01 ' + bft.BufferMonth AS DATE) <= @RngTo
        GROUP BY bft.FromBufferFundPoolId
    ),

    -- CTE 10: BufferFundTransfer IN — CUMULATIVE (Jan → SelectedMonth) for BufferTotalAmount
    CTE_BFT_In AS (
        SELECT bft.ToBufferFundPoolId AS FundPoolId,
               SUM(bft.BufferAmount)  AS BufferTransferInAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.Status = 'Active'
          AND bft.ToBufferFundPoolId IS NOT NULL
          AND TRY_CAST('01 ' + bft.BufferMonth AS DATE) >= @RngFrom
          AND TRY_CAST('01 ' + bft.BufferMonth AS DATE) <= @RngTo
        GROUP BY bft.ToBufferFundPoolId
    ),

    -- CTE 11: Owner OMCI Buffer — single month (for BufferTotalExpense)
    CTE_OwnerOMCI_Buf AS (
        SELECT e.FundPool, SUM(omci.Amount) AS OwnerAmt
        FROM Expenses e
        INNER JOIN OwnerContracts oc
            ON oc.OcCode = LTRIM(RTRIM(
                              SUBSTRING(e.Purpose,
                                  CHARINDEX('- ', e.Purpose) + 2,
                                  CHARINDEX(' - Inst', e.Purpose) - CHARINDEX('- ', e.Purpose) - 2)
                           ))
           AND ISNULL(oc.IsDeleted,0) = 0
        INNER JOIN OwnerMonthlyContractInstallments omci
            ON omci.OwnerContractId = oc.Id
           AND omci.PaidDate = e.[Date]
           AND TRY_CAST('01 ' + omci.Month AS DATE) > @MonTo   -- future only
           AND ISNULL(omci.IsDeleted,0) = 0
        WHERE e.RecipientRole = 'Owner'
          AND e.Head = 'LANDLORD CHO'
          AND ISNULL(e.IsDeleted,0) = 0
          AND e.[Date] >= @BufFrom
          AND CHARINDEX('- ', e.Purpose) > 0
          AND CHARINDEX(' - Inst', e.Purpose) > 0
        GROUP BY e.FundPool
    ),

    -- CTE 12: Other Expense Buffer — single month (for BufferTotalExpense)
    CTE_OtherExpense_Buf AS (
        SELECT e.FundPool, SUM(e.Amount) AS OtherExpAmt
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted,0) = 0
          AND NOT (e.RecipientRole = 'Owner' AND e.Head = 'LANDLORD CHO')
          AND e.[Date] >= @BufFrom
        GROUP BY e.FundPool
    )

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 1
    -- ════════════════════════════════════════════════════════════
    SELECT
        fp.Id                                                        AS FundPoolId,
        fp.Code                                                      AS FundPoolCode,
        fp.Name                                                      AS FundPoolName,
        fp.Status,

        -- ✅ CUMULATIVE: CurrentBalance = FundPool.Balance
        --    + CFT received (Jan → SelectedMonth)
        --    - CFT sent     (Jan → SelectedMonth)
        fp.Balance
        + ISNULL(cft_in.TransferInAmt,   0)
        - ISNULL(cft_out.TransferOutAmt,  0)                        AS CurrentBalance,

        -- ✅ SINGLE MONTH: TotalIncome
        ISNULL(mon_t.TenantCRIAmt, 0)
        + ISNULL(mon_o.OtherIncAmt, 0)                              AS TotalIncome,

        -- ✅ SINGLE MONTH: TotalExpense
        ISNULL(mon_ow.OwnerAmt, 0)
        + ISNULL(mon_e.OtherExpAmt, 0)                              AS TotalExpense,

        -- ✅ SINGLE MONTH: TotalPaymentsReceived
        ISNULL(mon_t.TenantCRIAmt, 0) + ISNULL(mon_o.OtherIncAmt, 0)
        + ISNULL(mon_ow.OwnerAmt,  0) + ISNULL(mon_e.OtherExpAmt,  0) AS TotalPaymentsReceived,

        -- ✅ SINGLE MONTH: NetAmount
        ( ISNULL(mon_t.TenantCRIAmt,0) + ISNULL(mon_o.OtherIncAmt,0) )
        - ( ISNULL(mon_ow.OwnerAmt,0) + ISNULL(mon_e.OtherExpAmt,0) ) AS NetAmount,

        -- ✅ SINGLE MONTH: BufferAmount (same as BufferTotalIncome)
        ISNULL(buf_t.TenantCRIAmt,0) + ISNULL(buf_o.OtherIncAmt,0) AS BufferAmount,

        -- ✅ SINGLE MONTH: BufferTotalIncome
        ISNULL(buf_t.TenantCRIAmt, 0)
        + ISNULL(buf_o.OtherIncAmt, 0)                              AS BufferTotalIncome,

        -- ✅ SINGLE MONTH: BufferTotalExpense
        ISNULL(buf_ow.OwnerAmt, 0)
        + ISNULL(buf_e.OtherExpAmt, 0)                              AS BufferTotalExpense,

        -- ✅ CUMULATIVE: BufferTotalAmount (Jan → SelectedMonth)
        --    + BFT received - BFT sent (cumulative)
        ISNULL(buf_t.TenantCRIAmt,0)  + ISNULL(buf_o.OtherIncAmt,0)
        + ISNULL(buf_ow.OwnerAmt,0)   + ISNULL(buf_e.OtherExpAmt,0)
        + ISNULL(bft_in.BufferTransferInAmt,  0)
        - ISNULL(bft_out.BufferTransferOutAmt, 0)                   AS BufferTotalAmount,

        -- ✅ SINGLE MONTH: BufferNetAmount
        ( ISNULL(buf_t.TenantCRIAmt,0) + ISNULL(buf_o.OtherIncAmt,0) )
        - ( ISNULL(buf_ow.OwnerAmt,0)  + ISNULL(buf_e.OtherExpAmt,0) ) AS BufferNetAmount,

        0 AS IncomeCount, 0 AS ExpenseCount, 0 AS PaymentCount,
        fp.CreatedAt, fp.UpdatedAt

    FROM FundPools fp
    -- Single month CTEs
    LEFT JOIN CTE_TenantCRI_Mon     mon_t   ON mon_t.FundPool  = fp.Code
    LEFT JOIN CTE_OtherIncome_Mon   mon_o   ON mon_o.FundPool  = fp.Code
    LEFT JOIN CTE_OwnerOMCI_Mon     mon_ow  ON mon_ow.FundPool = fp.Code
    LEFT JOIN CTE_OtherExpense_Mon  mon_e   ON mon_e.FundPool  = fp.Code
    -- Cumulative CTEs (CurrentBalance)
    LEFT JOIN CTE_CFT_Out           cft_out ON cft_out.FundPoolId = fp.Id
    LEFT JOIN CTE_CFT_In            cft_in  ON cft_in.FundPoolId  = fp.Id
    -- Cumulative Buffer Income CTEs (BufferTotalIncome)
    LEFT JOIN CTE_TenantCRI_Buf_Rng buf_t   ON buf_t.FundPool  = fp.Code
    LEFT JOIN CTE_OtherIncome_Buf_Rng buf_o ON buf_o.FundPool  = fp.Code
    -- Single month Buffer Expense CTEs
    LEFT JOIN CTE_OwnerOMCI_Buf     buf_ow  ON buf_ow.FundPool = fp.Code
    LEFT JOIN CTE_OtherExpense_Buf  buf_e   ON buf_e.FundPool  = fp.Code
    -- Single month BufferFundTransfer CTEs
    LEFT JOIN CTE_BFT_Out           bft_out ON bft_out.FundPoolId = fp.Id
    LEFT JOIN CTE_BFT_In            bft_in  ON bft_in.FundPoolId  = fp.Id

    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (@FundPoolId IS NULL OR fp.Id = @FundPoolId)
      AND (@Status     IS NULL OR fp.Status = @Status)
      AND (@SearchText IS NULL OR fp.Name LIKE '%'+@SearchText+'%'
                               OR fp.Code LIKE '%'+@SearchText+'%')
    ORDER BY fp.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 2: Empty (buffer data already in RS1 columns)
    -- ════════════════════════════════════════════════════════════
    SELECT
        0 AS FundPoolId, '' AS FundPoolCode, '' AS FundPoolName, '' AS Status,
        CAST(0 AS DECIMAL(18,2)) AS CurrentBalance,
        CAST(0 AS DECIMAL(18,2)) AS TotalIncome,
        CAST(0 AS DECIMAL(18,2)) AS TotalExpense,
        CAST(0 AS DECIMAL(18,2)) AS TotalPaymentsReceived,
        CAST(0 AS DECIMAL(18,2)) AS NetAmount,
        CAST(0 AS DECIMAL(18,2)) AS BufferTotalAmount
    WHERE 1 = 0;

    -- ════════════════════════════════════════════════════════════
    -- RESULT SET 3: Transactions drill-down (single fund pool)
    -- ════════════════════════════════════════════════════════════
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT TOP 50 TxnType, TxnDate, Amount, Head, Mode, CampName, Purpose, VoucherNo, CreatedAt
        FROM (
            SELECT 'Income' AS TxnType, i.[Date] AS TxnDate, i.Amount, i.Head, i.Mode,
                   ISNULL(i.CampName,'') CampName, ISNULL(i.Purpose,'') Purpose,
                   ISNULL(i.VoucherNo,'') VoucherNo, i.CreatedAt
            FROM Incomes i
            WHERE i.FundPool = (SELECT Code FROM FundPools WHERE Id=@FundPoolId AND ISNULL(IsDeleted,0)=0)
              AND ISNULL(i.IsDeleted,0) = 0
              AND i.[Date] >= @MonFrom AND i.[Date] <= @MonTo
            UNION ALL
            SELECT 'Expense', e.[Date], e.Amount, e.Head, e.Mode,
                   ISNULL(e.CampName,''), ISNULL(e.Purpose,''), ISNULL(e.VoucherNo,''), e.CreatedAt
            FROM Expenses e
            WHERE e.FundPool = (SELECT Code FROM FundPools WHERE Id=@FundPoolId AND ISNULL(IsDeleted,0)=0)
              AND ISNULL(e.IsDeleted,0) = 0
              AND e.[Date] >= @MonFrom AND e.[Date] <= @MonTo
        ) txn ORDER BY txn.TxnDate DESC;
    END
END
GO

PRINT 'sp_GetFundPoolReport updated with CTE-based Income/Expense/Buffer logic.';
GO
