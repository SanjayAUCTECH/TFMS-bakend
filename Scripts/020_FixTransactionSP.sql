USE TFMS_softwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(200) = NULL,
    @ContractId  NVARCHAR(50)  = NULL,
    @TenantId    INT           = NULL,
    @CampId      INT           = NULL,
    @Status      NVARCHAR(20)  = NULL,
    @DateFrom    DATE          = NULL,
    @DateTo      DATE          = NULL,
    @Month       NVARCHAR(7)   = NULL,
    @Year        NVARCHAR(4)   = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Build combined dataset into temp table ──────────────────────────────
    IF OBJECT_ID('tempdb..#AllTxns') IS NOT NULL DROP TABLE #AllTxns;

    CREATE TABLE #AllTxns (
        Id            INT,
        TxnDate       DATE,
        AccountHead   NVARCHAR(200),
        Particular    NVARCHAR(200),
        CampName      NVARCHAR(200),
        CampId        INT,
        FundPoolName  NVARCHAR(200),
        TxnType       NVARCHAR(5),
        Source        NVARCHAR(100),
        Mode          NVARCHAR(50),
        Amount        DECIMAL(18,2),
        Status        NVARCHAR(20),
        ContractId    NVARCHAR(20),
        TenantName    NVARCHAR(200)
    );

    -- DR rows: paid installments from ContractInstallments
    INSERT INTO #AllTxns
    SELECT
        ci.Id,
        ci.PaidDate,
        'Rent Income'                                    AccountHead,
        ISNULL(t.Name,'—')                               Particular,
        ISNULL(ca.Name,'—')                              CampName,
        ISNULL(ca.Id, 0)                                 CampId,
        ISNULL(ci.FundPoolName,'—')                      FundPoolName,
        'DR'                                             TxnType,
        'Inst #'+CAST(ci.InstallmentNo AS NVARCHAR(10))  Source,
        ISNULL(ci.PaymentMode,'—')                       Mode,
        ci.PaidAmount                                    Amount,
        ci.Status,
        ct.ContractId,
        ISNULL(t.Name,'—')                               TenantName
    FROM ContractInstallments ci
    JOIN  Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t  ON t.Id  = ct.TenantId
    LEFT JOIN Camps   ca ON ca.Id = ct.CampId
    WHERE ci.Status = 'Paid'
      AND ci.PaidDate IS NOT NULL
      AND (@TenantId   IS NULL OR ct.TenantId   = @TenantId)
      AND (@CampId     IS NULL OR ct.CampId     = @CampId)
      AND (@ContractId IS NULL OR ct.ContractId = @ContractId);

    -- CR rows: expenses
    INSERT INTO #AllTxns
    SELECT
        e.Id,
        e.Date,
        e.Head                                           AccountHead,
        ISNULL(e.RecipientName,'—')                      Particular,
        ISNULL(e.CampName, CASE WHEN e.Nature='HO' THEN 'HO' ELSE '—' END) CampName,
        ISNULL(e.CampId, 0)                              CampId,
        ISNULL(e.FundPoolName,'—')                       FundPoolName,
        'CR'                                             TxnType,
        ISNULL(e.ExpenseId,'—')                          Source,
        ISNULL(e.Mode,'—')                               Mode,
        e.Amount,
        'Paid'                                           Status,
        '—'                                              ContractId,
        ISNULL(e.RecipientName,'—')                      TenantName
    FROM Expenses e
    WHERE (@CampId IS NULL OR e.CampId = @CampId);

    -- ── Apply filters and count ──────────────────────────────────────────────
    SELECT @TotalRecords = COUNT(*)
    FROM #AllTxns
    WHERE (@Status    IS NULL OR TxnType   = @Status)
      AND (@DateFrom  IS NULL OR TxnDate  >= @DateFrom)
      AND (@DateTo    IS NULL OR TxnDate  <= @DateTo)
      AND (@Month     IS NULL OR FORMAT(TxnDate,'yyyy-MM') = @Month)
      AND (@Year      IS NULL OR YEAR(TxnDate) = CAST(@Year AS INT))
      AND (@SearchText IS NULL
           OR Particular  LIKE '%'+@SearchText+'%'
           OR TenantName  LIKE '%'+@SearchText+'%'
           OR ContractId  LIKE '%'+@SearchText+'%'
           OR AccountHead LIKE '%'+@SearchText+'%');

    -- ── Return paged results ─────────────────────────────────────────────────
    SELECT
        Id, TxnDate [Date], AccountHead, Particular,
        CampName, FundPoolName, TxnType, Source, Mode,
        Amount, Status, ContractId, TenantName
    FROM #AllTxns
    WHERE (@Status    IS NULL OR TxnType   = @Status)
      AND (@DateFrom  IS NULL OR TxnDate  >= @DateFrom)
      AND (@DateTo    IS NULL OR TxnDate  <= @DateTo)
      AND (@Month     IS NULL OR FORMAT(TxnDate,'yyyy-MM') = @Month)
      AND (@Year      IS NULL OR YEAR(TxnDate) = CAST(@Year AS INT))
      AND (@SearchText IS NULL
           OR Particular  LIKE '%'+@SearchText+'%'
           OR TenantName  LIKE '%'+@SearchText+'%'
           OR ContractId  LIKE '%'+@SearchText+'%'
           OR AccountHead LIKE '%'+@SearchText+'%')
    ORDER BY TxnDate DESC
    OFFSET  (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    DROP TABLE #AllTxns;
END
GO

PRINT 'sp_GetTransactionStatement fixed — temp table replaces CTE';
GO
