-- =============================================
-- Stored Procedure: sp_GetFundPoolReport
-- Description: Fund Pool Report with IncludeBalance condition
-- 
-- @IncludeBalance parameter logic:
-- - TRUE  (1): Include all previous balances (cumulative up to selected month)
-- - FALSE (0): Only show transactions for the selected month
-- =============================================

ALTER PROCEDURE [dbo].[sp_GetFundPoolReport]
    @FundPoolId    INT           = NULL,
    @SearchText    NVARCHAR(250) = NULL,
    @Status        NVARCHAR(50)  = NULL,
    @Month         INT           = NULL,
    @Year          INT           = NULL,
    @DateFrom      DATE          = NULL,
    @DateTo        DATE          = NULL,
    @PageNumber    INT           = 1,
    @PageSize      INT           = 1000,
    @IncludeBalance BIT          = 1,      -- New parameter: 1 = include previous balance, 0 = only current month
    @TotalRecords  INT           = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Build date range based on Month/Year or DateFrom/DateTo
    DECLARE @StartDate DATE;
    DECLARE @EndDate DATE;

    IF @Month IS NOT NULL AND @Year IS NOT NULL
    BEGIN
        SET @StartDate = DATEFROMPARTS(@Year, @Month, 1);
        SET @EndDate   = EOMONTH(@StartDate);
    END
    ELSE
    BEGIN
        SET @StartDate = ISNULL(@DateFrom, '1900-01-01');
        SET @EndDate   = ISNULL(@DateTo, '9999-12-31');
    END

    -- ═══════════════════════════════════════════════════════════
    -- RESULT SET 1: CURRENT FUND POOL REPORT
    -- ═══════════════════════════════════════════════════════════
    
    ;WITH FundPoolCTE AS
    (
        SELECT
            fp.FundPoolId,
            fp.FundPoolCode,
            fp.FundPoolName,
            fp.Status,
            fp.CreatedAt,
            fp.UpdatedAt,

            -- ─────────────────────────────────────────────────────
            -- INCOME (from FundPoolIncome)
            -- ─────────────────────────────────────────────────────
            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    -- Include all income up to end date
                    CASE WHEN i.IncomeDate <= @EndDate THEN i.Amount ELSE 0 END
                ELSE 
                    -- Only include income within the selected month
                    CASE WHEN i.IncomeDate BETWEEN @StartDate AND @EndDate THEN i.Amount ELSE 0 END
            END), 0) AS TotalIncome,

            COUNT(DISTINCT CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN i.IncomeDate <= @EndDate THEN i.IncomeId END
                ELSE 
                    CASE WHEN i.IncomeDate BETWEEN @StartDate AND @EndDate THEN i.IncomeId END
            END) AS IncomeCount,

            -- ─────────────────────────────────────────────────────
            -- EXPENSE (from FundPoolExpense)
            -- ─────────────────────────────────────────────────────
            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN e.ExpenseDate <= @EndDate THEN e.Amount ELSE 0 END
                ELSE 
                    CASE WHEN e.ExpenseDate BETWEEN @StartDate AND @EndDate THEN e.Amount ELSE 0 END
            END), 0) AS TotalExpense,

            COUNT(DISTINCT CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN e.ExpenseDate <= @EndDate THEN e.ExpenseId END
                ELSE 
                    CASE WHEN e.ExpenseDate BETWEEN @StartDate AND @EndDate THEN e.ExpenseId END
            END) AS ExpenseCount,

            -- ─────────────────────────────────────────────────────
            -- PAYMENTS (from FundPoolPayment)
            -- ─────────────────────────────────────────────────────
            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN p.PaymentDate <= @EndDate THEN p.Amount ELSE 0 END
                ELSE 
                    CASE WHEN p.PaymentDate BETWEEN @StartDate AND @EndDate THEN p.Amount ELSE 0 END
            END), 0) AS TotalPaymentsReceived,

            COUNT(DISTINCT CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN p.PaymentDate <= @EndDate THEN p.PaymentId END
                ELSE 
                    CASE WHEN p.PaymentDate BETWEEN @StartDate AND @EndDate THEN p.PaymentId END
            END) AS PaymentCount

        FROM FundPools fp
        LEFT JOIN FundPoolIncome i   ON fp.FundPoolId = i.FundPoolId AND i.Status = 'Active'
        LEFT JOIN FundPoolExpense e  ON fp.FundPoolId = e.FundPoolId AND e.Status = 'Active'
        LEFT JOIN FundPoolPayment p  ON fp.FundPoolId = p.FundPoolId AND p.Status = 'Active'

        WHERE 1=1
            AND (@FundPoolId IS NULL OR fp.FundPoolId = @FundPoolId)
            AND (@SearchText IS NULL OR fp.FundPoolName LIKE '%' + @SearchText + '%' OR fp.FundPoolCode LIKE '%' + @SearchText + '%')
            AND (@Status IS NULL OR fp.Status = @Status)

        GROUP BY fp.FundPoolId, fp.FundPoolCode, fp.FundPoolName, fp.Status, fp.CreatedAt, fp.UpdatedAt
    ),
    BufferCTE AS
    (
        SELECT
            bf.FundPoolId,
            
            -- ─────────────────────────────────────────────────────
            -- BUFFER FUND TRANSFERS (BufferFundTransfer)
            -- ─────────────────────────────────────────────────────
            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE WHEN bf.BufferTransferDate <= @EndDate THEN bf.Amount ELSE 0 END
                ELSE 
                    CASE WHEN bf.BufferTransferDate BETWEEN @StartDate AND @EndDate THEN bf.Amount ELSE 0 END
            END), 0) AS BufferTotalAmount,

            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE 
                        WHEN bf.BufferTransferDate <= @EndDate AND bf.FromFundPoolId = bf.FundPoolId THEN bf.Amount 
                        ELSE 0 
                    END
                ELSE 
                    CASE 
                        WHEN bf.BufferTransferDate BETWEEN @StartDate AND @EndDate AND bf.FromFundPoolId = bf.FundPoolId THEN bf.Amount 
                        ELSE 0 
                    END
            END), 0) AS BufferTotalIncome,

            ISNULL(SUM(CASE 
                WHEN @IncludeBalance = 1 THEN 
                    CASE 
                        WHEN bf.BufferTransferDate <= @EndDate AND bf.ToFundPoolId = bf.FundPoolId THEN bf.Amount 
                        ELSE 0 
                    END
                ELSE 
                    CASE 
                        WHEN bf.BufferTransferDate BETWEEN @StartDate AND @EndDate AND bf.ToFundPoolId = bf.FundPoolId THEN bf.Amount 
                        ELSE 0 
                    END
            END), 0) AS BufferTotalExpense

        FROM BufferFundTransfer bf
        WHERE bf.Status = 'Active'
        GROUP BY bf.FundPoolId
    )

    SELECT
        fp.FundPoolId,
        fp.FundPoolCode,
        fp.FundPoolName,
        fp.Status,
        
        -- Current Balance Calculation
        (fp.TotalIncome - fp.TotalExpense + fp.TotalPaymentsReceived) AS CurrentBalance,
        
        fp.TotalIncome,
        fp.TotalExpense,
        fp.TotalPaymentsReceived,
        
        -- Net Amount = Income - Expense + Payments
        (fp.TotalIncome - fp.TotalExpense + fp.TotalPaymentsReceived) AS NetAmount,
        
        -- Buffer calculations
        ISNULL(b.BufferTotalAmount, 0) AS BufferAmount,
        ISNULL(b.BufferTotalIncome, 0) AS BufferTotalIncome,
        ISNULL(b.BufferTotalExpense, 0) AS BufferTotalExpense,
        ISNULL(b.BufferTotalAmount, 0) AS BufferTotalAmount,
        ISNULL(b.BufferTotalIncome - b.BufferTotalExpense, 0) AS BufferNetAmount,
        
        fp.IncomeCount,
        fp.ExpenseCount,
        fp.PaymentCount,
        fp.CreatedAt,
        fp.UpdatedAt

    FROM FundPoolCTE fp
    LEFT JOIN BufferCTE b ON fp.FundPoolId = b.FundPoolId

    ORDER BY fp.FundPoolName
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- Set total records
    SELECT @TotalRecords = COUNT(*)
    FROM FundPoolCTE;

    -- ═══════════════════════════════════════════════════════════
    -- RESULT SET 2: BUFFER FUND POOL (if needed)
    -- ═══════════════════════════════════════════════════════════
    SELECT
        fp.FundPoolId,
        fp.FundPoolCode,
        fp.FundPoolName,
        fp.Status,
        0 AS CurrentBalance,
        0 AS TotalIncome,
        0 AS TotalExpense,
        0 AS TotalPaymentsReceived,
        0 AS NetAmount,
        ISNULL(b.BufferTotalAmount, 0) AS BufferTotalAmount
    FROM FundPoolCTE fp
    LEFT JOIN BufferCTE b ON fp.FundPoolId = b.FundPoolId
    WHERE @FundPoolId IS NULL;

    -- ═══════════════════════════════════════════════════════════
    -- RESULT SET 3: TRANSACTIONS (when single fund pool selected)
    -- ═══════════════════════════════════════════════════════════
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT
            'Income' AS TxnType,
            i.IncomeDate AS TxnDate,
            i.Amount,
            ah.AccountHeadName AS Head,
            i.PaymentMode AS Mode,
            c.CampName,
            i.Purpose,
            i.VoucherNo,
            i.CreatedAt
        FROM FundPoolIncome i
        LEFT JOIN AccountsHead ah ON i.AccountsHeadId = ah.AccountsHeadId
        LEFT JOIN Camps c ON i.CampId = c.CampId
        WHERE i.FundPoolId = @FundPoolId 
            AND i.Status = 'Active'
            AND (
                (@IncludeBalance = 1 AND i.IncomeDate <= @EndDate) OR
                (@IncludeBalance = 0 AND i.IncomeDate BETWEEN @StartDate AND @EndDate)
            )

        UNION ALL

        SELECT
            'Expense' AS TxnType,
            e.ExpenseDate AS TxnDate,
            e.Amount,
            ah.AccountHeadName AS Head,
            e.PaymentMode AS Mode,
            c.CampName,
            e.Purpose,
            e.VoucherNo,
            e.CreatedAt
        FROM FundPoolExpense e
        LEFT JOIN AccountsHead ah ON e.AccountsHeadId = ah.AccountsHeadId
        LEFT JOIN Camps c ON e.CampId = c.CampId
        WHERE e.FundPoolId = @FundPoolId 
            AND e.Status = 'Active'
            AND (
                (@IncludeBalance = 1 AND e.ExpenseDate <= @EndDate) OR
                (@IncludeBalance = 0 AND e.ExpenseDate BETWEEN @StartDate AND @EndDate)
            )

        UNION ALL

        SELECT
            'Payment' AS TxnType,
            p.PaymentDate AS TxnDate,
            p.Amount,
            'Payment' AS Head,
            p.PaymentMode AS Mode,
            c.CampName,
            p.Purpose,
            p.VoucherNo,
            p.CreatedAt
        FROM FundPoolPayment p
        LEFT JOIN Camps c ON p.CampId = c.CampId
        WHERE p.FundPoolId = @FundPoolId 
            AND p.Status = 'Active'
            AND (
                (@IncludeBalance = 1 AND p.PaymentDate <= @EndDate) OR
                (@IncludeBalance = 0 AND p.PaymentDate BETWEEN @StartDate AND @EndDate)
            )

        ORDER BY TxnDate DESC;
    END
END;
GO
