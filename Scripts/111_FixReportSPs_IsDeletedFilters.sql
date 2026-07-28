-- ============================================================
-- 111: Fix ALL Report SPs — add IsDeleted=0 filters
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. sp_GetPartnerReport ─────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM Partners p
    WHERE p.IsDeleted=0                               -- ✅
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%');

    SELECT
        p.Id PartnerId, p.Code PartnerCode, p.Name PartnerName,
        ISNULL(p.Contact,'') Contact, ISNULL(p.Mobile,'') Mobile,
        ISNULL(p.Email,'') Email, p.Status,
        COUNT(DISTINCT cp.CampId) TotalCamps,
        ISNULL(STUFF((
            SELECT DISTINCT ', ' + c2.Name
            FROM CampPartners cp2
            JOIN Camps c2 ON c2.Id=cp2.CampId AND c2.IsDeleted=0  -- ✅
            WHERE cp2.PartnerId=p.Id AND ISNULL(cp2.IsDeleted,0)=0 -- ✅
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'),1,2,''),'') CampNames,
        ISNULL(MAX(cp.ShareValue),0) ShareValue,
        ISNULL(MAX(cp.ShareType),'') ShareType,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0),0) TotalCollected, -- ✅
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0),0) TotalPaid, -- ✅
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0),0)
        - ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0),0) ShareDue
    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id AND ISNULL(cp.IsDeleted,0)=0  -- ✅
    WHERE p.IsDeleted=0                               -- ✅
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
    GROUP BY p.Id, p.Code, p.Name, p.Contact, p.Mobile, p.Email, p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT '✅ sp_GetPartnerReport - IsDeleted fixed';
GO

-- ── 2. sp_GetWaiverReport ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetWaiverReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @TenantId INT=NULL, @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Waivers w
    JOIN Tenants t ON t.Id=w.TenantId AND t.IsDeleted=0  -- ✅
    WHERE ISNULL(w.IsDeleted,0)=0                        -- ✅
      AND (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR w.WaiverDate<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%');

    SELECT w.Id WaiverId, w.TenantId, t.Name TenantName, w.ContractId,
           w.InstallmentNo, w.OriginalAmount, w.WaiverAmount, w.BalanceAmount,
           w.Remark, w.WaiverDate
    FROM Waivers w
    JOIN Tenants t ON t.Id=w.TenantId AND t.IsDeleted=0  -- ✅
    WHERE ISNULL(w.IsDeleted,0)=0                        -- ✅
      AND (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR w.WaiverDate<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY w.WaiverDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT '✅ sp_GetWaiverReport - IsDeleted fixed';
GO

-- ── 3. sp_GetTransactionStatement ─────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @ContractId NVARCHAR(MAX)=NULL,
    @TenantId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL,
    @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @Year NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..#AllTxns') IS NOT NULL DROP TABLE #AllTxns;
    CREATE TABLE #AllTxns (Id INT, TxnDate DATE, AccountHead NVARCHAR(MAX),
        Particular NVARCHAR(MAX), CampName NVARCHAR(MAX), CampId INT,
        FundPoolName NVARCHAR(MAX), TxnType NVARCHAR(MAX),
        Source NVARCHAR(MAX), Mode NVARCHAR(MAX), Amount DECIMAL(18,2),
        Status NVARCHAR(MAX), ContractId NVARCHAR(MAX), TenantName NVARCHAR(MAX));

    -- Rent payments from ContractInstallments (IsDeleted=0)
    INSERT INTO #AllTxns
    SELECT ci.Id, ci.PaidDate, 'Rent Income', ISNULL(t.Name,''),
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId AND ca2.IsDeleted=0 WHERE cc2.ContractId=ct.ContractId AND ISNULL(cc2.IsDeleted,0)=0 ORDER BY cc2.Id),''),
           ISNULL((SELECT TOP 1 cc3.CampId FROM ContractCamps cc3 WHERE cc3.ContractId=ct.ContractId AND ISNULL(cc3.IsDeleted,0)=0 ORDER BY cc3.Id),0),
           ISNULL(ci.FundPoolName,''), 'DR', 'Inst #'+CAST(ci.InstallmentNo AS NVARCHAR),
           ISNULL(ci.PaymentMode,''), ci.PaidAmount, ci.Status, ct.ContractId, ISNULL(t.Name,'')
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId AND ct.IsDeleted=0  -- ✅
    LEFT JOIN Tenants t ON t.Id=ct.TenantId AND t.IsDeleted=0            -- ✅
    WHERE ci.Status='Paid' AND ci.PaidDate IS NOT NULL
      AND ISNULL(ci.IsDeleted,0)=0                                       -- ✅
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR (SELECT TOP 1 cc4.CampId FROM ContractCamps cc4 WHERE cc4.ContractId=ct.ContractId AND ISNULL(cc4.IsDeleted,0)=0 ORDER BY cc4.Id)=@CampId)
      AND (@ContractId IS NULL OR ct.ContractId=@ContractId);

    -- Expenses
    INSERT INTO #AllTxns
    SELECT e.Id, e.Date, e.Head, ISNULL(e.RecipientName,''),
           ISNULL(e.CampName, CASE WHEN e.Nature='HO' THEN 'HO' ELSE '' END), ISNULL(e.CampId,0),
           ISNULL(e.FundPoolName,''), 'CR', ISNULL(e.ExpenseId,''), ISNULL(e.Mode,''),
           e.Amount, 'Paid', '', ISNULL(e.RecipientName,'')
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted,0)=0                                        -- ✅
      AND (@CampId IS NULL OR e.CampId=@CampId);

    SELECT @TotalRecords=COUNT(*) FROM #AllTxns
    WHERE (@Status IS NULL OR TxnType=@Status)
      AND (@DateFrom IS NULL OR TxnDate>=@DateFrom) AND (@DateTo IS NULL OR TxnDate<=@DateTo)
      AND (@Month IS NULL OR FORMAT(TxnDate,'yyyy-MM')=@Month)
      AND (@Year IS NULL OR YEAR(TxnDate)=CAST(@Year AS INT))
      AND (@SearchText IS NULL OR TenantName LIKE '%'+@SearchText+'%' OR AccountHead LIKE '%'+@SearchText+'%');

    SELECT Id, TxnDate [Date], AccountHead, Particular, CampName, FundPoolName,
           TxnType, Source, Mode, Amount, Status, ContractId, TenantName
    FROM #AllTxns
    WHERE (@Status IS NULL OR TxnType=@Status)
      AND (@DateFrom IS NULL OR TxnDate>=@DateFrom) AND (@DateTo IS NULL OR TxnDate<=@DateTo)
      AND (@Month IS NULL OR FORMAT(TxnDate,'yyyy-MM')=@Month)
      AND (@Year IS NULL OR YEAR(TxnDate)=CAST(@Year AS INT))
      AND (@SearchText IS NULL OR TenantName LIKE '%'+@SearchText+'%' OR AccountHead LIKE '%'+@SearchText+'%')
    ORDER BY TxnDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    DROP TABLE #AllTxns;
END
GO
PRINT '✅ sp_GetTransactionStatement - IsDeleted fixed';
GO

-- ── 4. sp_GetTransactionReport ────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTransactionReport
    @PageNumber INT=1, @PageSize INT=2147483647,
    @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @AccountHead NVARCHAR(MAX)=NULL, @Party NVARCHAR(MAX)=NULL,
    @CampId INT=NULL, @FundPool NVARCHAR(MAX)=NULL,
    @Type NVARCHAR(MAX)=NULL, @Source NVARCHAR(MAX)=NULL,
    @Mode NVARCHAR(MAX)=NULL, @Role NVARCHAR(MAX)=NULL,
    @SearchText NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..#TxnAll') IS NOT NULL DROP TABLE #TxnAll;
    CREATE TABLE #TxnAll (Id INT, TxnDate DATE, AccountHead NVARCHAR(MAX),
        Party NVARCHAR(MAX), CampName NVARCHAR(MAX), FundPool NVARCHAR(MAX),
        FundPoolName NVARCHAR(MAX), TxnType NVARCHAR(MAX), Source NVARCHAR(MAX),
        Mode NVARCHAR(MAX), Amount DECIMAL(18,2), Role NVARCHAR(MAX), RefId NVARCHAR(MAX));

    -- Incomes (IsDeleted=0)
    INSERT INTO #TxnAll
    SELECT i.Id, i.Date, ISNULL(i.Head,''), ISNULL(i.SourceRef,''),
           ISNULL(i.CampName,''), ISNULL(i.FundPool,''), ISNULL(i.FundPoolName,''),
           'Income', ISNULL(i.Source,''), ISNULL(i.Mode,''),
           i.Amount, ISNULL(i.Source,''), i.IncomeId
    FROM Incomes i
    WHERE ISNULL(i.IsDeleted,0)=0                             -- ✅
      AND (@DateFrom IS NULL OR i.Date>=@DateFrom) AND (@DateTo IS NULL OR i.Date<=@DateTo)
      AND (@AccountHead IS NULL OR i.Head=@AccountHead)
      AND (@CampId IS NULL OR i.CampId=@CampId)
      AND (@FundPool IS NULL OR i.FundPool=@FundPool)
      AND (@Mode IS NULL OR i.Mode=@Mode)
      AND (@Source IS NULL OR i.Source=@Source)
      AND (@Party IS NULL OR i.SourceRef LIKE '%'+@Party+'%' OR i.Purpose LIKE '%'+@Party+'%')
      AND (@SearchText IS NULL OR i.Head LIKE '%'+@SearchText+'%' OR i.IncomeId LIKE '%'+@SearchText+'%');

    -- Expenses (IsDeleted=0)
    INSERT INTO #TxnAll
    SELECT e.Id, e.Date, ISNULL(e.Head,''), ISNULL(e.RecipientName,''),
           ISNULL(e.CampName,''), ISNULL(e.FundPool,''), ISNULL(e.FundPoolName,''),
           'Expense', ISNULL(e.RecipientRole,''), ISNULL(e.Mode,''),
           e.Amount, ISNULL(e.RecipientRole,''), e.ExpenseId
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted,0)=0                             -- ✅
      AND (@DateFrom IS NULL OR e.Date>=@DateFrom) AND (@DateTo IS NULL OR e.Date<=@DateTo)
      AND (@AccountHead IS NULL OR e.Head=@AccountHead)
      AND (@CampId IS NULL OR e.CampId=@CampId)
      AND (@FundPool IS NULL OR e.FundPool=@FundPool)
      AND (@Mode IS NULL OR e.Mode=@Mode)
      AND (@Role IS NULL OR e.RecipientRole=@Role)
      AND (@Party IS NULL OR e.RecipientName LIKE '%'+@Party+'%')
      AND (@SearchText IS NULL OR e.Head LIKE '%'+@SearchText+'%' OR e.ExpenseId LIKE '%'+@SearchText+'%');

    SELECT @TotalRecords=COUNT(*) FROM #TxnAll
    WHERE (@Type IS NULL OR TxnType=@Type);

    -- Rows
    SELECT Id, TxnDate [Date], AccountHead, Party PartyRecipient, CampName,
           FundPool, FundPoolName, TxnType [Type], Source, Mode, Amount, Role, RefId
    FROM #TxnAll
    WHERE (@Type IS NULL OR TxnType=@Type)
    ORDER BY TxnDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    -- Summary cards
    SELECT
        COUNT(*) NoOfPayments,
        SUM(CASE WHEN TxnType='Income'  THEN Amount ELSE 0 END) TotalIncome,
        SUM(CASE WHEN TxnType='Expense' THEN Amount ELSE 0 END) TotalExpense,
        SUM(Amount) TotalAmount
    FROM #TxnAll
    WHERE (@Type IS NULL OR TxnType=@Type);

    DROP TABLE #TxnAll;
END
GO
PRINT '✅ sp_GetTransactionReport - IsDeleted fixed';
GO

-- ── 5. sp_GetTenantLedger ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantLedger
    @TenantId INT, @ContractId NVARCHAR(20)=NULL,
    @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Summary
    SELECT t.Name TenantName, t.Contact,
        ISNULL((SELECT SUM(Amount) FROM ContractInstallments p
                JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0  -- ✅
                WHERE c.TenantId=@TenantId AND ISNULL(p.IsDeleted,0)=0           -- ✅
                  AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) TotalDebit,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments p
                JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0  -- ✅
                WHERE c.TenantId=@TenantId AND p.Status='Paid' AND ISNULL(p.IsDeleted,0)=0 -- ✅
                  AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) TotalCredit,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM ContractInstallments p
                JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0  -- ✅
                WHERE c.TenantId=@TenantId AND p.Status IN('Pending','Partial') AND ISNULL(p.IsDeleted,0)=0 -- ✅
                  AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) NetBalance
    FROM Tenants t WHERE t.Id=@TenantId AND t.IsDeleted=0;                        -- ✅

    -- Ledger rows
    SELECT p.DueDate [Date],
           'Rent Due - Installment #'+CAST(p.InstallmentNo AS NVARCHAR) Description,
           'Debit' [Type], p.Amount Debit, CAST(0 AS DECIMAL(18,2)) Credit,
           CAST(0 AS DECIMAL(18,2)) Balance,
           p.ContractId, p.InstallmentNo, '' PaymentMode, '' Reference
    FROM ContractInstallments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0               -- ✅
    WHERE c.TenantId=@TenantId AND ISNULL(p.IsDeleted,0)=0                        -- ✅
      AND (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR p.DueDate<=CAST(@DateTo AS DATE))

    UNION ALL

    SELECT p.PaidDate [Date],
           'Payment Received - Installment #'+CAST(p.InstallmentNo AS NVARCHAR) Description,
           'Credit' [Type], CAST(0 AS DECIMAL(18,2)) Debit, p.PaidAmount Credit,
           CAST(0 AS DECIMAL(18,2)) Balance,
           p.ContractId, p.InstallmentNo, p.PaymentMode, ISNULL(p.ChequeNumber,'') Reference
    FROM ContractInstallments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0               -- ✅
    WHERE c.TenantId=@TenantId AND p.Status IN('Paid','Partial') AND ISNULL(p.IsDeleted,0)=0 -- ✅
      AND (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR p.PaidDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR p.PaidDate<=CAST(@DateTo AS DATE))

    ORDER BY [Date], InstallmentNo;
END
GO
PRINT '✅ sp_GetTenantLedger - IsDeleted fixed';
GO

-- ── 6. sp_GetCampCollectionReport ────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCampCollectionReport
    @CampId INT=NULL, @PartnerId INT=NULL, @OwnerId INT=NULL,
    @ContractId NVARCHAR(MAX)=NULL, @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords=COUNT(DISTINCT c.Id)
    FROM Camps c
    WHERE c.IsDeleted=0                                                            -- ✅
      AND (@CampId IS NULL OR c.Id=@CampId)
      AND (@PartnerId IS NULL OR EXISTS(
              SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId AND ISNULL(cp.IsDeleted,0)=0)) -- ✅
      AND (@OwnerId IS NULL OR EXISTS(
              SELECT 1 FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.OwnerId=@OwnerId AND oc.IsDeleted=0)); -- ✅

    SELECT
        c.Id CampId, c.Code CampCode, c.Name CampName, c.Status CampStatus,
        COUNT(DISTINCT r.Id) TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied=1 THEN r.Id END) OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Occupied=0 THEN r.Id END) VacantRooms,
        COUNT(DISTINCT cri.ContractId) TotalContracts,
        COUNT(DISTINCT CASE WHEN ct.Status='Active' THEN ct.ContractId END) ActiveContracts,
        ISNULL(SUM(CASE WHEN (@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month) THEN cri.InstallAmount ELSE 0 END),0) TotalInstallAmount,
        ISNULL(SUM(CASE WHEN (@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month) THEN cri.PaidAmount ELSE 0 END),0) TotalPaid,
        ISNULL(SUM(CASE WHEN (@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month) THEN cri.Balance ELSE 0 END),0) TotalDue
    FROM Camps c
    LEFT JOIN Rooms r ON r.CampId=c.Id AND r.IsDeleted=0                          -- ✅
    LEFT JOIN ContractRoomInstallments cri ON cri.CampId=c.Id AND ISNULL(cri.IsDeleted,0)=0 -- ✅
    LEFT JOIN Contracts ct ON ct.ContractId=cri.ContractId AND ct.IsDeleted=0     -- ✅
    WHERE c.IsDeleted=0                                                            -- ✅
      AND (@CampId IS NULL OR c.Id=@CampId)
      AND (@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId AND ISNULL(cp.IsDeleted,0)=0))
      AND (@OwnerId IS NULL OR EXISTS(SELECT 1 FROM OwnerContracts oc WHERE oc.CampId=c.Id AND oc.OwnerId=@OwnerId AND oc.IsDeleted=0))
      AND (@ContractId IS NULL OR cri.ContractId=@ContractId)
    GROUP BY c.Id, c.Code, c.Name, c.Status
    ORDER BY c.Name;
END
GO
PRINT '✅ sp_GetCampCollectionReport - IsDeleted fixed';
GO

-- ── 7. sp_GetRoomWiseCollectionReport ─────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRoomWiseCollectionReport
    @CampId INT, @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @ContractStatus NVARCHAR(MAX)=NULL,
    @RoomStatus NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords=COUNT(DISTINCT r.Id)
    FROM Rooms r
    INNER JOIN ContractRoomInstallments cri0 ON cri0.RoomId=r.Id AND cri0.CampId=@CampId AND ISNULL(cri0.IsDeleted,0)=0 -- ✅
    WHERE r.CampId=@CampId AND r.IsDeleted=0                                      -- ✅
      AND (@RoomStatus IS NULL OR r.Status=@RoomStatus);

    SELECT
        r.Id RoomId, r.RoomNo, r.Status RoomStatus, r.MonthlyPrice, r.Occupied,
        ISNULL(ct.ContractId,'') ContractId,
        ISNULL(ct.Status,'') ContractStatus,
        ISNULL(t.Name,'') TenantName,
        ISNULL(SUM(CASE WHEN ((@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month)) THEN cri.InstallAmount ELSE 0 END),0) TotalAmount,
        ISNULL(SUM(CASE WHEN ((@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month)) THEN cri.PaidAmount ELSE 0 END),0) TotalPaid,
        ISNULL(SUM(CASE WHEN ((@DateFrom IS NULL OR cri.DueDate>=@DateFrom) AND (@DateTo IS NULL OR cri.DueDate<=@DateTo) AND (@Month IS NULL OR FORMAT(cri.DueDate,'yyyy-MM')=@Month)) THEN cri.Balance ELSE 0 END),0) TotalDue
    FROM Rooms r
    LEFT JOIN ContractRoomInstallments cri ON cri.RoomId=r.Id AND cri.CampId=@CampId AND ISNULL(cri.IsDeleted,0)=0 -- ✅
    LEFT JOIN Contracts ct ON ct.ContractId=cri.ContractId AND ct.IsDeleted=0     -- ✅
      AND (@ContractStatus IS NULL OR ct.Status=@ContractStatus)
    LEFT JOIN Tenants t ON t.Id=ct.TenantId AND t.IsDeleted=0                     -- ✅
    WHERE r.CampId=@CampId AND r.IsDeleted=0                                      -- ✅
      AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
    GROUP BY r.Id, r.RoomNo, r.Status, r.MonthlyPrice, r.Occupied, ct.ContractId, ct.Status, t.Name
    ORDER BY r.RoomNo;
END
GO
PRINT '✅ sp_GetRoomWiseCollectionReport - IsDeleted fixed';
GO

-- ── 8. sp_GetRoomHistory ────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRoomHistory @RoomId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId, t.Name TenantName,
           c.StartDate, c.EndDate, c.MonthlyTotal MonthlyRent, c.Status
    FROM ContractRooms cr
    JOIN Contracts c ON c.ContractId=cr.ContractId AND c.IsDeleted=0              -- ✅
    JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0                           -- ✅
    WHERE cr.RoomId=@RoomId AND ISNULL(cr.IsDeleted,0)=0                          -- ✅
    ORDER BY c.StartDate DESC;
END
GO
PRINT '✅ sp_GetRoomHistory - IsDeleted fixed';
GO

PRINT '=== ALL 8 REPORT SPs FIXED WITH IsDeleted=0 FILTERS ===';
GO
