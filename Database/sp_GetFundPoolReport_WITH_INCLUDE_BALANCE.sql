USE [TFMS_TestSoftwareDB]
GO

/****** Object:  StoredProcedure [dbo].[sp_GetFundPoolReport]    Script Date: 04-11-2026 17:06:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_GetFundPoolReport]
    @FundPoolId     INT           = NULL,
    @SearchText     NVARCHAR(200) = NULL,
    @Status         NVARCHAR(50)  = NULL,
    @Month          INT           = NULL,
    @Year           INT           = NULL,
    @DateFrom       DATE          = NULL,
    @DateTo         DATE          = NULL,
    @PageNumber     INT           = 1,
    @PageSize       INT           = 10,
    @IncludeBalance BIT           = 1,      -- NEW PARAMETER: 1 = Cumulative (Jan-Selected), 0 = Only Selected Month
    @TotalRecords   INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       DATE VARIABLES
       ========================================================= */
    DECLARE @SelYear INT =
        ISNULL(@Year, YEAR(GETDATE()));

    DECLARE @SelMonth INT =
        ISNULL(@Month, MONTH(GETDATE()));

    /* Selected Month */
    DECLARE @MonFrom DATE =
        DATEFROMPARTS(@SelYear, @SelMonth, 1);

    DECLARE @MonTo DATE =
        EOMONTH(@MonFrom);

    /* =========================================================
       CURRENT RANGE - CONDITIONAL BASED ON @IncludeBalance
       
       IF @IncludeBalance = 1 (TRUE):
           JANUARY -> SELECTED MONTH (e.g., Jan-Jul 2026)
       
       IF @IncludeBalance = 0 (FALSE):
           ONLY SELECTED MONTH (e.g., Jul 1-31 2026)
       ========================================================= */
    DECLARE @RngFrom DATE;
    DECLARE @RngTo DATE;

    IF @IncludeBalance = 1
    BEGIN
        -- Cumulative: January to Selected Month
        SET @RngFrom = DATEFROMPARTS(@SelYear, 1, 1);
        SET @RngTo = @MonTo;
    END
    ELSE
    BEGIN
        -- Only Selected Month
        SET @RngFrom = @MonFrom;
        SET @RngTo = @MonTo;
    END

    /* =========================================================
       BUFFER START
       NEXT MONTH AFTER SELECTED MONTH
       ========================================================= */
    DECLARE @BufFrom DATE =
        DATEADD(MONTH, 1, @MonFrom);

    /* =========================================================
       MONTH LABEL
       ========================================================= */
    DECLARE @CriMonthLabel NVARCHAR(10) =
        LEFT(DATENAME(MONTH, @MonFrom), 3)
        + RIGHT(CAST(@SelYear AS NVARCHAR(4)), 2);

    /* =========================================================
       TOTAL RECORDS
       ========================================================= */
    SELECT
        @TotalRecords = COUNT(*)
    FROM FundPools fp
    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (
            @FundPoolId IS NULL
            OR fp.Id = @FundPoolId
          )
      AND (
            @Status IS NULL
            OR fp.Status = @Status
          )
      AND (
            @SearchText IS NULL
            OR fp.Name LIKE '%' + @SearchText + '%'
            OR fp.Code LIKE '%' + @SearchText + '%'
          );

    /* =========================================================
       CTEs
       ========================================================= */
    ;WITH
    /* =========================================================
       1. CURRENT TENANT INCOME
       Uses @RngFrom and @RngTo (conditional based on @IncludeBalance)
       ========================================================= */
    CTE_TenantCRI_Mon AS
    (
        SELECT
            fds.Code AS FundPool,
            SUM(t.Amount) AS TenantCRIAmt
        FROM ContractRoomsTrns t
        LEFT JOIN TxnRecords t1
            ON t.TxnRecordId = t1.Id
           AND ISNULL(t1.IsDeleted, 0) = 0
        LEFT JOIN FundPools fds
            ON t1.FundPoolId = fds.Id
           AND ISNULL(fds.IsDeleted, 0) = 0
        WHERE ISNULL(t.IsDeleted, 0) = 0
          AND t.PaymentStatus IN
          (
              'Paid',
              'PaidPartial'
          )
          /* =========================================
             CONDITIONAL: @RngFrom to @RngTo
             ========================================= */
          AND TRY_CAST(
                '01 ' + t.Month
                AS DATE
              ) >= @RngFrom
          AND TRY_CAST(
                '01 ' + t.Month
                AS DATE
              ) <= @RngTo
        GROUP BY
            fds.Code
    ),

    /* =========================================================
       2. CURRENT OTHER INCOME
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_OtherIncome_Mon AS
    (
        SELECT
            i.FundPool,
            SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted, 0) = 0
          AND NOT
          (
              i.Source = 'Tenant' 
          )
          AND NOT
          (
              i.Source = 'SecurityDeposit' 
          )
          AND i.[Date] >= @RngFrom
          AND i.[Date] <= @RngTo
        GROUP BY
            i.FundPool
    ),

    /* =========================================================
       3. CURRENT EXPENSE
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_CurrentExpense AS
    (
        SELECT
            e.FundPool,
            SUM(e.Amount) AS TotalExpense
        FROM Expenses e
        WHERE ISNULL(e.IsDeleted, 0) = 0
          /* =========================================
             CONDITIONAL: @RngFrom to @RngTo
             ========================================= */
          AND e.[Date] >= @RngFrom
          AND e.[Date] <= @RngTo
        GROUP BY
            e.FundPool
    ),

    /* =========================================================
       4. CURRENT FUND TRANSFER OUT
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_CFT_Out AS
    (
        SELECT
            cft.FromCurrentFundPoolId AS FundPoolId,
            SUM(cft.CurrentAmount) AS TransferOutAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.Status = 'Active'
          AND TRY_CAST(
                '01 ' + cft.CurrentMonth
                AS DATE
              ) >= @RngFrom
          AND TRY_CAST(
                '01 ' + cft.CurrentMonth
                AS DATE
              ) <= @RngTo
        GROUP BY
            cft.FromCurrentFundPoolId
    ),

    /* =========================================================
       5. CURRENT FUND TRANSFER IN
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_CFT_In AS
    (
        SELECT
            cft.ToCurrentFundPoolId AS FundPoolId,
            SUM(cft.CurrentAmount) AS TransferInAmt
        FROM CurrentFundTransfer cft
        WHERE ISNULL(cft.IsDeleted, 0) = 0
          AND cft.Status = 'Active'
          AND cft.ToCurrentFundPoolId IS NOT NULL
          AND TRY_CAST(
                '01 ' + cft.CurrentMonth
                AS DATE
              ) >= @RngFrom
          AND TRY_CAST(
                '01 ' + cft.CurrentMonth
                AS DATE
              ) <= @RngTo
        GROUP BY
            cft.ToCurrentFundPoolId
    ),

    /* =========================================================
       6. BUFFER TENANT INCOME
       Advanced / AdvancedPartial
       ========================================================= */
    CTE_TenantCRI_Buf_Rng AS
    (
        SELECT
            fds.Code AS FundPool,
            SUM(t.Amount) AS TenantCRIAmt
        FROM ContractRoomsTrns t
        LEFT JOIN TxnRecords t1
            ON t.TxnRecordId = t1.Id
           AND ISNULL(t1.IsDeleted, 0) = 0
        LEFT JOIN FundPools fds
            ON t1.FundPoolId = fds.Id
           AND ISNULL(fds.IsDeleted, 0) = 0
        WHERE ISNULL(t.IsDeleted, 0) = 0
          AND t.PaymentStatus IN
          (
              'Advanced',
              'AdvancedPartial'
          )
        GROUP BY
            fds.Code
    ),

    /* =========================================================
       7. BUFFER OTHER INCOME
       NEXT MONTH ONWARDS
       ========================================================= */
    CTE_OtherIncome_Buf_Rng AS
    (
        SELECT
            i.FundPool,
            SUM(i.Amount) AS OtherIncAmt
        FROM Incomes i
        WHERE ISNULL(i.IsDeleted, 0) = 0 and i.Amount=0
          AND NOT
          (
              i.Source = 'Tenant'
              AND i.Head = 'RENTAL COLLECTION'
          )
          AND i.[Date] >= @BufFrom
        GROUP BY
            i.FundPool
    ),

    /* =========================================================
       8. BUFFER FUND TRANSFER OUT
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_BFT_Out AS
    (
        SELECT
            bft.FromBufferFundPoolId AS FundPoolId,
            SUM(bft.BufferAmount) AS BufferTransferOutAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.Status = 'Active'
          AND TRY_CAST(
                '01 ' + bft.BufferMonth
                AS DATE
              ) >= @RngFrom
          AND TRY_CAST(
                '01 ' + bft.BufferMonth
                AS DATE
              ) <= @RngTo
        GROUP BY
            bft.FromBufferFundPoolId
    ),

    /* =========================================================
       OUTSOURCE MONEY
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_OutsourceMoney AS
    (
        SELECT
            om.FundPoolId,
            SUM(om.Amount) AS TotalOutsourceMoney
        FROM OutsourceMoney om
        WHERE ISNULL(om.IsDeleted, 0) = 0
          AND TRY_CONVERT(
                DATE,
                om.[Month] + '-01'
              ) >= @RngFrom
          AND TRY_CONVERT(
                DATE,
                om.[Month] + '-01'
              ) <= @RngTo
        GROUP BY
            om.FundPoolId
    ),

    /* =========================================================
       9. BUFFER FUND TRANSFER IN
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    CTE_BFT_In AS
    (
        SELECT
            bft.ToBufferFundPoolId AS FundPoolId,
            SUM(bft.BufferAmount) AS BufferTransferInAmt
        FROM BufferFundTransfer bft
        WHERE ISNULL(bft.IsDeleted, 0) = 0
          AND bft.Status = 'Active'
          AND bft.ToBufferFundPoolId IS NOT NULL
          AND TRY_CAST(
                '01 ' + bft.BufferMonth
                AS DATE
              ) >= @RngFrom
          AND TRY_CAST(
                '01 ' + bft.BufferMonth
                AS DATE
              ) <= @RngTo
        GROUP BY
            bft.ToBufferFundPoolId
    )

    /* =========================================================
       RESULT SET 1
       ========================================================= */
    SELECT
        fp.Id AS FundPoolId,
        fp.Code AS FundPoolCode,
        fp.Name AS FundPoolName,
        fp.Status,

        /* =====================================================
           CURRENT BALANCE
           ===================================================== */
        (
            ISNULL(mon_t.TenantCRIAmt, 0)
            + ISNULL(mon_o.OtherIncAmt, 0)
            - ISNULL(exp.TotalExpense, 0)
            - ISNULL(om.TotalOutsourceMoney, 0)
            + ISNULL(cft_in.TransferInAmt, 0)
            - ISNULL(cft_out.TransferOutAmt, 0)
        ) AS CurrentBalance,

        /* =====================================================
           TOTAL INCOME
           ===================================================== */
        (
            ISNULL(mon_t.TenantCRIAmt, 0)
            + ISNULL(mon_o.OtherIncAmt, 0)
        ) AS TotalIncome,

        /* =====================================================
           TOTAL EXPENSE
           ===================================================== */
        ISNULL(
            exp.TotalExpense,
            0
        ) AS TotalExpense,

        /* =====================================================
           TOTAL PAYMENTS RECEIVED
           ===================================================== */
        (
            ISNULL(mon_t.TenantCRIAmt, 0)
            + ISNULL(mon_o.OtherIncAmt, 0)
        ) AS TotalPaymentsReceived,

        /* =====================================================
           NET AMOUNT
           ===================================================== */
        (
            ISNULL(mon_t.TenantCRIAmt, 0)
            + ISNULL(mon_o.OtherIncAmt, 0)
            - ISNULL(exp.TotalExpense, 0)
        ) AS NetAmount,

        /* =====================================================
           BUFFER AMOUNT
           ===================================================== */
        (
            ISNULL(buf_t.TenantCRIAmt, 0)
            + ISNULL(buf_o.OtherIncAmt, 0)
        ) AS BufferAmount,

        /* =====================================================
           BUFFER TOTAL INCOME
           ===================================================== */
        (
            ISNULL(buf_t.TenantCRIAmt, 0)
            + ISNULL(buf_o.OtherIncAmt, 0)
        ) AS BufferTotalIncome,

        /* =====================================================
           BUFFER EXPENSE
           ===================================================== */
        CAST(0 AS DECIMAL(18,2))
            AS BufferTotalExpense,

        /* =====================================================
           BUFFER TOTAL AMOUNT
           ===================================================== */
        (
            ISNULL(buf_t.TenantCRIAmt, 0)
            + ISNULL(buf_o.OtherIncAmt, 0)
            + ISNULL(bft_in.BufferTransferInAmt, 0)
            - ISNULL(bft_out.BufferTransferOutAmt, 0)
        ) AS BufferTotalAmount,

        /* =====================================================
           BUFFER NET AMOUNT
           ===================================================== */
        (
            ISNULL(buf_t.TenantCRIAmt, 0)
            + ISNULL(buf_o.OtherIncAmt, 0)
        ) AS BufferNetAmount,

        /* =====================================================
           COUNTS
           ===================================================== */
        0 AS IncomeCount,
        0 AS ExpenseCount,
        0 AS PaymentCount,

        fp.CreatedAt,
        fp.UpdatedAt

    FROM FundPools fp

    /* =========================================================
       CURRENT INCOME
       ========================================================= */
    LEFT JOIN CTE_TenantCRI_Mon mon_t
        ON mon_t.FundPool = fp.Code

    LEFT JOIN CTE_OtherIncome_Mon mon_o
        ON mon_o.FundPool = fp.Code

    /* =========================================================
       CURRENT EXPENSE
       ========================================================= */
    LEFT JOIN CTE_CurrentExpense exp
        ON exp.FundPool = fp.Code

    LEFT JOIN CTE_OutsourceMoney om
        ON om.FundPoolId = fp.Id

    /* =========================================================
       CURRENT FUND TRANSFERS
       ========================================================= */
    LEFT JOIN CTE_CFT_Out cft_out
        ON cft_out.FundPoolId = fp.Id

    LEFT JOIN CTE_CFT_In cft_in
        ON cft_in.FundPoolId = fp.Id

    /* =========================================================
       BUFFER INCOME
       ========================================================= */
    LEFT JOIN CTE_TenantCRI_Buf_Rng buf_t
        ON buf_t.FundPool = fp.Code

    LEFT JOIN CTE_OtherIncome_Buf_Rng buf_o
        ON buf_o.FundPool = fp.Code

    /* =========================================================
       BUFFER TRANSFERS
       ========================================================= */
    LEFT JOIN CTE_BFT_Out bft_out
        ON bft_out.FundPoolId = fp.Id

    LEFT JOIN CTE_BFT_In bft_in
        ON bft_in.FundPoolId = fp.Id

    /* =========================================================
       FILTER
       ========================================================= */
    WHERE ISNULL(fp.IsDeleted, 0) = 0
      AND (
            @FundPoolId IS NULL
            OR fp.Id = @FundPoolId
          )
      AND (
            @Status IS NULL
            OR fp.Status = @Status
          )
      AND (
            @SearchText IS NULL
            OR fp.Name LIKE '%' + @SearchText + '%'
            OR fp.Code LIKE '%' + @SearchText + '%'
          )

    ORDER BY
        fp.Name

    OFFSET
        (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT
        @PageSize ROWS ONLY;

    /* =========================================================
       RESULT SET 2
       EMPTY RESULT
       ========================================================= */
    SELECT
        0 AS FundPoolId,
        '' AS FundPoolCode,
        '' AS FundPoolName,
        '' AS Status,
        CAST(0 AS DECIMAL(18,2)) AS CurrentBalance,
        CAST(0 AS DECIMAL(18,2)) AS TotalIncome,
        CAST(0 AS DECIMAL(18,2)) AS TotalExpense,
        CAST(0 AS DECIMAL(18,2)) AS TotalPaymentsReceived,
        CAST(0 AS DECIMAL(18,2)) AS NetAmount,
        CAST(0 AS DECIMAL(18,2)) AS BufferTotalAmount
    WHERE 1 = 0;

    /* =========================================================
       RESULT SET 3
       TRANSACTION DRILL-DOWN
       Uses @RngFrom and @RngTo (conditional)
       ========================================================= */
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT TOP 50
            TxnType,
            TxnDate,
            Amount,
            Head,
            Mode,
            CampName,
            Purpose,
            VoucherNo,
            CreatedAt
        FROM
        (
            /* =================================================
               INCOME
               ================================================= */
            SELECT
                'Income' AS TxnType,
                i.[Date] AS TxnDate,
                i.Amount,
                i.Head,
                i.Mode,
                ISNULL(i.CampName, '') AS CampName,
                ISNULL(i.Purpose, '') AS Purpose,
                ISNULL(i.VoucherNo, '') AS VoucherNo,
                i.CreatedAt
            FROM Incomes i
            WHERE i.FundPool =
            (
                SELECT Code
                FROM FundPools
                WHERE Id = @FundPoolId
                  AND ISNULL(IsDeleted, 0) = 0
            )
              AND ISNULL(i.IsDeleted, 0) = 0
              AND i.[Date] >= @RngFrom
              AND i.[Date] <= @RngTo

            UNION ALL

            /* =================================================
               EXPENSE
               ================================================= */
            SELECT
                'Expense' AS TxnType,
                e.[Date] AS TxnDate,
                e.Amount,
                e.Head,
                e.Mode,
                ISNULL(e.CampName, '') AS CampName,
                ISNULL(e.Purpose, '') AS Purpose,
                ISNULL(e.VoucherNo, '') AS VoucherNo,
                e.CreatedAt
            FROM Expenses e
            WHERE e.FundPool =
            (
                SELECT Code
                FROM FundPools
                WHERE Id = @FundPoolId
                  AND ISNULL(IsDeleted, 0) = 0
            )
              AND ISNULL(e.IsDeleted, 0) = 0
              AND e.[Date] >= @RngFrom
              AND e.[Date] <= @RngTo
        ) txn
        ORDER BY
            txn.TxnDate DESC;
    END
END
GO
