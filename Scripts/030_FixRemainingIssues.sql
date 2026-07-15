-- ============================================================
-- Script 030: Fix remaining SP issues after CampId removal
-- ============================================================

-- ── Fix sp_GetDashboardStats — add missing columns ───────────
CREATE OR ALTER PROCEDURE sp_GetDashboardStats
    @CampId   INT = NULL, @TenantId INT = NULL,
    @Year     INT = NULL, @Month    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ThisMonth INT = ISNULL(@Month, MONTH(GETUTCDATE()));
    DECLARE @ThisYear  INT = ISNULL(@Year,  YEAR(GETUTCDATE()));

    SELECT
        (SELECT COUNT(*) FROM Camps WHERE Status='Active' AND (@CampId IS NULL OR Id=@CampId))       AS TotalCamps,
        (SELECT COUNT(*) FROM Rooms WHERE (@CampId IS NULL OR CampId=@CampId))                        AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Status='Occupied' AND (@CampId IS NULL OR CampId=@CampId))  AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Status='Vacant'   AND (@CampId IS NULL OR CampId=@CampId))  AS VacantRooms,
        (SELECT COUNT(*) FROM Tenants)                                                                 AS TotalTenants,
        (SELECT COUNT(*) FROM Tenants WHERE Status='Active')                                           AS ActiveTenants,
        (SELECT COUNT(*) FROM Partners WHERE Status='Active')                                          AS TotalPartners,
        (SELECT COUNT(DISTINCT c.Id) FROM Contracts c
         LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
         WHERE c.Status='Active'
           AND (@CampId IS NULL OR cc.CampId=@CampId)
           AND (@TenantId IS NULL OR c.TenantId=@TenantId))                                           AS ActiveContracts,
        ISNULL((SELECT SUM(ci.Amount) FROM ContractInstallments ci
                JOIN Contracts c ON c.ContractId=ci.ContractId
                LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
                WHERE ci.Status IN('Pending','Partial')
                  AND MONTH(ci.DueDate)=@ThisMonth AND YEAR(ci.DueDate)=@ThisYear
                  AND (@CampId IS NULL OR cc.CampId=@CampId)),0)                                      AS TotalDueThisMonth,
        ISNULL((SELECT SUM(ci.PaidAmount) FROM ContractInstallments ci
                JOIN Contracts c ON c.ContractId=ci.ContractId
                LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
                WHERE ci.Status='Paid'
                  AND MONTH(ci.PaidDate)=@ThisMonth AND YEAR(ci.PaidDate)=@ThisYear
                  AND (@CampId IS NULL OR cc.CampId=@CampId)),0)                                      AS TotalCollectedThisMonth,
        ISNULL((SELECT SUM(ci.Amount-ci.PaidAmount) FROM ContractInstallments ci
                JOIN Contracts c ON c.ContractId=ci.ContractId
                LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
                WHERE ci.Status IN('Pending','Partial')
                  AND (@CampId IS NULL OR cc.CampId=@CampId)),0)                                      AS OutstandingBalance,
        (SELECT COUNT(*) FROM ContractInstallments ci
         JOIN Contracts c ON c.ContractId=ci.ContractId
         LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
         WHERE ci.Status='Pending' AND ci.DueDate<GETDATE()
           AND (@CampId IS NULL OR cc.CampId=@CampId))                                                AS OverduePayments;

    -- Camp Occupancy
    SELECT ca.Name CampName,
           COUNT(r.Id) TotalRooms,
           SUM(CASE WHEN r.Status='Occupied' THEN 1 ELSE 0 END) Occupied,
           SUM(CASE WHEN r.Status='Vacant'   THEN 1 ELSE 0 END) Vacant
    FROM Camps ca LEFT JOIN Rooms r ON r.CampId=ca.Id
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id, ca.Name ORDER BY ca.Name;

    -- Monthly Collections (current year)
    SELECT MONTH(ci.PaidDate) MonthNum, SUM(ci.PaidAmount) Collected
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=ct.ContractId
    WHERE ci.Status='Paid' AND YEAR(ci.PaidDate)=@ThisYear
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
    GROUP BY MONTH(ci.PaidDate) ORDER BY MONTH(ci.PaidDate);

    -- Camp Revenue
    SELECT ca.Name CampName, ISNULL(SUM(r.MonthlyPrice),0) MonthlyRevenue
    FROM Camps ca LEFT JOIN Rooms r ON r.CampId=ca.Id AND r.Status='Occupied'
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id, ca.Name ORDER BY ca.Name;
END
GO

-- ── Fix sp_GetTenants — remove @Type param that doesn't exist ─
-- Already fixed in 029 — but add @TenantType handling properly
CREATE OR ALTER PROCEDURE sp_GetTenants
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC',
    @Status        NVARCHAR(MAX) = NULL,
    @CampId        INT           = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.EmiratesId LIKE '%'+@SearchText+'%');
    SELECT DISTINCT t.Id,t.Name,t.Type,t.Contact,t.Email,t.Whatsapp,
           t.EmiratesId,t.Passport,t.Nationality,t.Address,
           t.Company,t.TradeLicense,t.LicensingAuthority,t.NumberOfCoOccupants,
           t.PlotNo,t.MakaniNo,t.PropertyArea,t.PremisesNo,
           t.LessorName,t.LessorEid,t.LessorLicense,t.LessorLicAuthority,t.LessorEmail,t.LessorPhone,
           t.Status,t.CreatedAt,t.UpdatedAt
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.EmiratesId LIKE '%'+@SearchText+'%')
    ORDER BY t.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Fix sp_GetContracts — DISTINCT causing open DataReader issue ─
-- Use separate count query, no DISTINCT needed
CREATE OR ALTER PROCEDURE sp_GetContracts
    @PageNumber    INT, @PageSize  INT,
    @SearchText    NVARCHAR(MAX) = NULL, @SortBy NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC', @Status NVARCHAR(MAX) = NULL,
    @TenantId      INT = NULL, @CampId INT = NULL,
    @DateFrom      NVARCHAR(MAX) = NULL, @DateTo NVARCHAR(MAX) = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(DISTINCT c.Id)
    FROM Contracts c
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR c.Status=@Status)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId   IS NULL OR cc.CampId=@CampId)
      AND (@DateFrom IS NULL OR c.StartDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR c.StartDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR EXISTS(SELECT 1 FROM Tenants t2 WHERE t2.Id=c.TenantId AND t2.Name LIKE '%'+@SearchText+'%') OR c.ContractId LIKE '%'+@SearchText+'%');

    SELECT
        c.Id, c.ContractId, c.TenantId,
        t.Name TenantName,
        ISNULL((SELECT TOP 1 cc2.CampId FROM ContractCamps cc2 WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id),0) CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc3 JOIN Camps ca2 ON ca2.Id=cc3.CampId WHERE cc3.ContractId=c.ContractId ORDER BY cc3.Id),'') CampName,
        c.StartDate, c.Months, c.EndDate, c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit,0) SecurityDeposit,
        ISNULL(c.InstallmentType,'monthly') InstallmentType,
        ISNULL(c.ContractType,'Monthly') ContractType,
        ISNULL(c.IssuedBy,'') IssuedBy, ISNULL(c.Notes,'') Notes,
        ISNULL(c.LessorAmount,0) LessorAmount, c.Status,
        ISNULL(c.ContractPropertyUsage,'') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,'')  ContractBuildingName,
        ISNULL(c.ContractPropertyType,'')  ContractPropertyType,
        ISNULL(c.ContractLocation,'')      ContractLocation,
        ISNULL(c.ContractPropertyNo,'')    ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,'')  ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,'')    ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,'')   ContractPaymentMode,
        ISNULL(c.ContractPlotNo,'')        ContractPlotNo,
        ISNULL(c.ContractMakaniNo,'')      ContractMakaniNo,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId),0) TotalPaid,
        c.ContractTotal-ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId),0) TotalDue,
        (SELECT TOP 1 Amount FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC,Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC,Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt
    FROM Contracts c
    JOIN Tenants t ON t.Id=c.TenantId
    WHERE (@Status IS NULL OR c.Status=@Status)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR c.Id IN (SELECT ContractId FROM ContractCamps WHERE CampId=@CampId))
      AND (@DateFrom IS NULL OR c.StartDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR c.StartDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR c.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY c.CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Fix sp_GetCampReport — add CampExpense, HOAllocated, Profit ─
CREATE OR ALTER PROCEDURE sp_GetCampReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Camps ca
    WHERE (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%' OR ca.Code LIKE '%'+@SearchText+'%');
    SELECT ca.Id CampId, ca.Code CampCode, ca.Name CampName, ca.Status,
           COUNT(DISTINCT r.Id) TotalRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Vacant'   THEN r.Id END) VacantRooms,
           COUNT(DISTINCT CASE WHEN c.Status='Active'   THEN c.Id END) ActiveContracts,
           ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN r.MonthlyPrice ELSE 0 END),0) TotalMonthlyRent,
           ISNULL((SELECT SUM(ci2.PaidAmount) FROM ContractInstallments ci2 JOIN ContractCamps cc2 ON cc2.ContractId=ci2.ContractId WHERE cc2.CampId=ca.Id AND ci2.Status='Paid'),0) TotalCollected,
           ISNULL((SELECT SUM(ci3.Amount)     FROM ContractInstallments ci3 JOIN ContractCamps cc3 ON cc3.ContractId=ci3.ContractId WHERE cc3.CampId=ca.Id AND ci3.Status='Pending'),0) TotalDue,
           ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.Nature='Camp' AND e.CampId=ca.Id),0) CampExpense,
           ISNULL((SELECT SUM(e2.Amount)*0.1 FROM Expenses e2 WHERE e2.Nature='HO'),0) HOAllocated,
           ISNULL((SELECT SUM(ci4.PaidAmount) FROM ContractInstallments ci4 JOIN ContractCamps cc4 ON cc4.ContractId=ci4.ContractId WHERE cc4.CampId=ca.Id AND ci4.Status='Paid'),0)
             - ISNULL((SELECT SUM(e3.Amount) FROM Expenses e3 WHERE e3.Nature='Camp' AND e3.CampId=ca.Id),0) Profit,
           ISNULL((SELECT SUM(e4.Amount) FROM Expenses e4 WHERE e4.CampId=ca.Id OR e4.Nature='HO'),0) TotalExpense
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN ContractCamps cc ON cc.CampId=ca.Id
    LEFT JOIN Contracts c ON c.ContractId=cc.ContractId
    WHERE (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%' OR ca.Code LIKE '%'+@SearchText+'%')
    GROUP BY ca.Id,ca.Code,ca.Name,ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Fix sp_GetTxnRecords — add ChequeNumber, ReceivedContact, IssuedBy ─
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT, @PageSize INT,
    @ContractId NVARCHAR(MAX)=NULL, @TenantId INT=NULL, @CampId INT=NULL,
    @TxnType NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType);
    SELECT tr.Id, tr.TxnId, tr.TxnType, tr.ContractId, tr.ContractCode,
           c.TenantId, t.Name TenantName,
           ISNULL(tr.CampId, ISNULL((SELECT TOP 1 cc2.CampId FROM ContractCamps cc2 WHERE cc2.ContractId=tr.ContractId ORDER BY cc2.Id),0)) CampId,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc3 JOIN Camps ca2 ON ca2.Id=cc3.CampId WHERE cc3.ContractId=tr.ContractId ORDER BY cc3.Id),'') CampName,
           tr.TotalAmount, tr.Amount, tr.PaidDate TxnDate, tr.FromDate, tr.ToDate,
           tr.PaymentMode, tr.PaymentModeId,
           ISNULL(tr.ChequeNumber,'') ChequeNumber,
           ISNULL(tr.FundPoolId,NULL) FundPoolId, ISNULL(tr.FundPoolName,'') FundPoolName,
           ISNULL(tr.Description,'') Description, ISNULL(tr.ReceivedBy,'') ReceivedBy,
           ISNULL(tr.ReceivedContact,'') ReceivedContact, ISNULL(tr.IssuedBy,'') IssuedBy,
           tr.InstallmentNo, ISNULL(tr.AppliedInstallments,'') AppliedInstallments,
           ISNULL(tr.Unallocated,0) Unallocated,
           tr.CreatedAt, tr.UpdatedAt
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType)
    ORDER BY tr.PaidDate DESC, tr.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Fix sp_GetMisStats — cast OccupancyPct to DECIMAL ─────────
-- Already fixed in 029 with DECIMAL(5,1) cast — just ensure consistent
-- The issue is COUNT returning INT vs DECIMAL math
-- Fix: explicitly CAST all numeric outputs
CREATE OR ALTER PROCEDURE sp_GetMisStats
    @CampId INT=NULL, @Month NVARCHAR(MAX)=NULL, @PartnerId INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL(SUM(CAST(ci.Amount AS DECIMAL(18,2))),0.0) TotalRental,
        ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN CAST(ci.PaidAmount AS DECIMAL(18,2)) ELSE 0.0 END),0.0) TotalCollected,
        ISNULL(SUM(CASE WHEN ci.Status='Pending' THEN CAST(ci.Amount AS DECIMAL(18,2)) ELSE 0.0 END),0.0) TotalOutstanding,
        ISNULL((SELECT SUM(CAST(e.Amount AS DECIMAL(18,2))) FROM Expenses e
                WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO')
                  AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0.0) TotalExpenses,
        ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN CAST(ci.PaidAmount AS DECIMAL(18,2)) ELSE 0.0 END),0.0)
          - ISNULL((SELECT SUM(CAST(e.Amount AS DECIMAL(18,2))) FROM Expenses e
                    WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO')
                      AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0.0) NetProfit,
        CAST(COUNT(DISTINCT r.Id) AS DECIMAL(18,2)) TotalUnits,
        CAST(COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) AS DECIMAL(18,2)) OccupiedUnits,
        CAST(COUNT(DISTINCT CASE WHEN r.Status='Vacant'   THEN r.Id END) AS DECIMAL(18,2)) VacantUnits,
        CASE WHEN COUNT(r.Id)>0
             THEN CAST(COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END)*100.0/COUNT(r.Id) AS DECIMAL(5,1))
             ELSE CAST(0 AS DECIMAL(5,1)) END OccupancyPct
    FROM Rooms r
    JOIN Camps ca ON ca.Id=r.CampId
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
        AND (@Month IS NULL OR LEFT(CAST(ci.DueDate AS NVARCHAR),7)=@Month)
    WHERE (@CampId IS NULL OR r.CampId=@CampId)
      AND (@PartnerId IS NULL OR r.CampId IN (SELECT CampId FROM CampPartners WHERE PartnerId=@PartnerId));

    SELECT ca.Id CampId, ca.Name CampName,
           COUNT(DISTINCT r.Id) TotalRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
           ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN CAST(r.MonthlyPrice AS DECIMAL(18,2)) ELSE 0.0 END),0.0) MonthlyRevenue,
           ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN CAST(ci.PaidAmount AS DECIMAL(18,2)) ELSE 0.0 END),0.0) TotalCollected,
           ISNULL(SUM(CASE WHEN ci.Status='Pending' THEN CAST(ci.Amount AS DECIMAL(18,2)) ELSE 0.0 END),0.0) TotalOutstanding
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId AND (@Month IS NULL OR LEFT(CAST(ci.DueDate AS NVARCHAR),7)=@Month)
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id,ca.Name ORDER BY ca.Name;

    SELECT FORMAT(ci.DueDate,'MMM yyyy') [Month],
           ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) Collected,
           ISNULL(SUM(ci.Amount),0) Due, 0 Expenses, 0 NetProfit
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@CampId IS NULL OR cc.CampId=@CampId)
      AND ci.DueDate >= DATEADD(MONTH,-11,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))
    GROUP BY FORMAT(ci.DueDate,'MMM yyyy'),YEAR(ci.DueDate),MONTH(ci.DueDate)
    ORDER BY YEAR(ci.DueDate),MONTH(ci.DueDate);

    SELECT e.Head, SUM(e.Amount) Amount
    FROM Expenses e
    WHERE (@CampId IS NULL OR e.Nature='HO' OR (e.Nature='Camp' AND e.CampId=@CampId))
      AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)
    GROUP BY e.Head ORDER BY Amount DESC;
END
GO

PRINT '=== Script 030 complete ===';
