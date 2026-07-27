-- ============================================================
-- 107: Add Mode field to all Dashboard SP recent transactions
-- Tenant    → TxnRecords.PaymentMode AS Mode
-- Partner   → Incomes.Mode + Expenses.Mode
-- Staff     → Expenses.Mode
-- OtherPerson → Expenses.Mode
-- Owner     → OwnerTransactions has no Mode col → '' AS Mode
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. sp_GetTenantDashboard ──────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantDashboard
    @TenantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Summary
    SELECT
        ISNULL(SUM(CASE WHEN tr.TxnType='DR'    THEN tr.Amount ELSE 0 END),0) AS TotalAmount,
        ISNULL(SUM(CASE WHEN tr.TxnType='CR'    THEN tr.Amount ELSE 0 END),0) AS TotalPaid,
        ISNULL(SUM(CASE WHEN tr.TxnType='DR'    THEN tr.Amount ELSE 0 END),0)
        - ISNULL(SUM(CASE WHEN tr.TxnType='CR'  THEN tr.Amount ELSE 0 END),0) AS TotalDue,
        ISNULL(SUM(CASE WHEN tr.TxnType='SD-CR' THEN tr.Amount ELSE 0 END),0) AS SecurityPaidAmount,
        ISNULL((SELECT SUM(ISNULL(c2.SecurityDeposit,0)) FROM Contracts c2
                WHERE c2.IsDeleted=0 AND (@TenantId IS NULL OR c2.TenantId=@TenantId)),0) AS TotalSecurityAmount,
        ISNULL((SELECT SUM(ISNULL(c2.SecurityDeposit,0)) FROM Contracts c2
                WHERE c2.IsDeleted=0 AND (@TenantId IS NULL OR c2.TenantId=@TenantId)),0)
        - ISNULL(SUM(CASE WHEN tr.TxnType='SD-CR' THEN tr.Amount ELSE 0 END),0) AS SecurityDueAmount,
        ISNULL((SELECT SUM(ISNULL(cc.PenaltyAmount,0)) FROM ContractCancellations cc
                WHERE ISNULL(cc.IsDeleted,0)=0 AND (@TenantId IS NULL OR cc.TenantId=@TenantId)),0) AS PenaltyAmount,
        ISNULL((SELECT SUM(ISNULL(cc.RefundAmount,0)) FROM ContractCancellations cc
                WHERE ISNULL(cc.IsDeleted,0)=0 AND (@TenantId IS NULL OR cc.TenantId=@TenantId)),0) AS RefundAmount,
        MAX(t.Id)      AS TenantId,
        MAX(t.Name)    AS TenantName,
        MAX(t.Contact) AS TenantContact,
        MAX(t.Email)   AS TenantEmail,
        MAX(t.Status)  AS TenantStatus
    FROM TxnRecords tr
    JOIN Tenants t ON t.Id=tr.TenantId AND t.IsDeleted=0
    WHERE ISNULL(tr.IsDeleted,0)=0
      AND (@TenantId IS NULL OR tr.TenantId=@TenantId);

    -- Recent Transactions (with Mode)
    SELECT TOP 20
        tr.Id, tr.TxnId, tr.TxnType,
        tr.ContractId, tr.ContractCode,
        tr.TenantId, ISNULL(t.Name,'')    AS TenantName,
        tr.CampId,   ISNULL(ca.Name,'')   AS CampName,
        tr.TotalAmount, tr.Amount,
        CONVERT(NVARCHAR(10), tr.PaidDate, 23) AS TxnDate,
        ISNULL(tr.PaymentMode,'')          AS Mode,       -- ✅ Mode added
        tr.PaymentMode,
        tr.PaymentModeId,
        ISNULL(tr.ChequeNumber,'')         AS ChequeNumber,
        ISNULL(tr.Description,'')          AS Description,
        ISNULL(tr.ReceivedBy,'')           AS ReceivedBy,
        ISNULL(tr.FundPoolName,'')         AS FundPoolName,
        tr.AppliedInstallments, tr.InstallmentNo, tr.Unallocated, tr.CreatedAt
    FROM TxnRecords tr
    JOIN Tenants t ON t.Id=tr.TenantId AND t.IsDeleted=0
    LEFT JOIN Camps ca ON ca.Id=tr.CampId AND ca.IsDeleted=0
    WHERE ISNULL(tr.IsDeleted,0)=0
      AND (@TenantId IS NULL OR tr.TenantId=@TenantId)
    ORDER BY tr.Id DESC;
END
GO
PRINT '✅ sp_GetTenantDashboard - Mode added';
GO

-- ── 2. sp_GetPartnerDashboard ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerDashboard
    @PartnerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(p.Id,0) AS PartnerId, ISNULL(p.Name,'') AS PartnerName,
        ISNULL(p.Code,'') AS PartnerCode, ISNULL(p.Contact,'') AS PartnerContact,
        ISNULL(p.Email,'') AS PartnerEmail, ISNULL(p.Status,'') AS PartnerStatus,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)),0) AS TotalIncome,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner' AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)),0) AS TotalExpense,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)),0)
        - ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner' AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)),0) AS NetBalance,
        ISNULL((SELECT COUNT(DISTINCT cp.CampId) FROM CampPartners cp WHERE ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS AssignedCamps,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS TotalRooms,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND r.Occupied=1 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS OccupiedRooms,
        ISNULL((SELECT COUNT(DISTINCT r.Id) FROM Rooms r JOIN CampPartners cp ON cp.CampId=r.CampId WHERE r.IsDeleted=0 AND r.Occupied=0 AND ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)),0) AS VacantRooms
    FROM Partners p WHERE p.IsDeleted=0 AND (@PartnerId IS NULL OR p.Id=@PartnerId);

    -- Camps detail
    SELECT cp.PartnerId, cp.CampId,
        ISNULL(ca.Name,'') AS CampName, ISNULL(ca.Code,'') AS CampCode,
        cp.ShareType, cp.ShareValue,
        ISNULL(ca.Status,'') AS CampStatus,
        CONVERT(NVARCHAR(10), ca.StartDate, 23) AS FromDate,
        CONVERT(NVARCHAR(10), ca.EndDate,   23) AS ToDate,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0) AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=1) AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms r WHERE r.CampId=ca.Id AND r.IsDeleted=0 AND r.Occupied=0) AS VacantRooms
    FROM CampPartners cp
    JOIN Camps ca ON ca.Id=cp.CampId AND ca.IsDeleted=0
    WHERE ISNULL(cp.IsDeleted,0)=0 AND (@PartnerId IS NULL OR cp.PartnerId=@PartnerId)
    ORDER BY ca.Name;

    -- Recent Transactions (with Mode)
    SELECT TOP 30 TxnType, TxnRefId, Date, Amount, Head,
        Mode,                    -- ✅ Mode already present in Incomes/Expenses
        FundPoolName, Purpose, CampId, CampName, CreatedAt
    FROM (
        SELECT 'Income' AS TxnType, i.IncomeId AS TxnRefId, i.Date, i.Amount,
               ISNULL(i.Head,'') AS Head, ISNULL(i.Mode,'') AS Mode,
               ISNULL(i.FundPoolName,'') AS FundPoolName, ISNULL(i.Purpose,'') AS Purpose,
               ISNULL(i.CampId,0) AS CampId, ISNULL(i.CampName,'') AS CampName, i.CreatedAt
        FROM Incomes i WHERE ISNULL(i.IsDeleted,0)=0 AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)
        UNION ALL
        SELECT 'Expense', e.ExpenseId, e.Date, e.Amount,
               ISNULL(e.Head,''), ISNULL(e.Mode,''),
               ISNULL(e.FundPoolName,''), ISNULL(e.Purpose,''),
               ISNULL(e.CampId,0), ISNULL(e.CampName,''), e.CreatedAt
        FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Partner'
          AND (@PartnerId IS NULL OR e.RecipientId=@PartnerId)
    ) txn ORDER BY txn.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetPartnerDashboard - Mode confirmed';
GO

-- ── 3. sp_GetStaffDashboard ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetStaffDashboard
    @StaffId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(s.Id,0) AS StaffId, ISNULL(s.StaffId,'') AS StaffCode,
        ISNULL(s.Name,'') AS StaffName, ISNULL(s.Role,'') AS Role,
        ISNULL(s.Designation,'') AS Designation, ISNULL(s.JobTitle,'') AS JobTitle,
        ISNULL(s.Contact,'') AS Contact, ISNULL(s.Email,'') AS Email,
        ISNULL(s.Status,'') AS Status,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Staff' AND (@StaffId IS NULL OR e.RecipientId=@StaffId)),0) AS TotalIncome,
        ISNULL((SELECT COUNT(*) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='Staff' AND (@StaffId IS NULL OR e.RecipientId=@StaffId)),0) AS TotalTransactions
    FROM Staff s WHERE s.IsDeleted=0 AND (@StaffId IS NULL OR s.Id=@StaffId);

    -- Recent Transactions (with Mode)
    SELECT TOP 30
        e.Id, e.ExpenseId AS TxnRefId, 'Credit' AS TxnType,
        CONVERT(NVARCHAR(10), e.Date, 23) AS Date,
        e.Amount,
        ISNULL(e.Head,'')         AS Head,
        ISNULL(e.Mode,'')         AS Mode,     -- ✅ Mode added
        ISNULL(e.FundPoolName,'') AS FundPoolName,
        ISNULL(e.Purpose,'')      AS Purpose,
        ISNULL(e.CampId,0)        AS CampId,
        ISNULL(e.CampName,'')     AS CampName,
        ISNULL(e.RecipientId,0)   AS RecipientId,
        ISNULL(e.RecipientName,'') AS RecipientName,
        e.CreatedAt
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted,0)=0
      AND e.RecipientRole='Staff'
      AND (@StaffId IS NULL OR e.RecipientId=@StaffId)
    ORDER BY e.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetStaffDashboard - Mode added';
GO

-- ── 4. sp_GetOtherPersonDashboard ────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetOtherPersonDashboard
    @PersonId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(op.Id,0) AS PersonId, ISNULL(op.Code,'') AS PersonCode,
        ISNULL(op.Name,'') AS PersonName, ISNULL(op.Designation,'') AS Designation,
        ISNULL(op.Mobile,'') AS Mobile, ISNULL(op.Email,'') AS Email,
        ISNULL(op.Address,'') AS Address, ISNULL(op.Status,'') AS Status,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='OtherPerson' AND (@PersonId IS NULL OR e.RecipientId=@PersonId)),0) AS TotalIncome,
        ISNULL((SELECT COUNT(*) FROM Expenses e WHERE ISNULL(e.IsDeleted,0)=0 AND e.RecipientRole='OtherPerson' AND (@PersonId IS NULL OR e.RecipientId=@PersonId)),0) AS TotalTransactions
    FROM OtherPersons op WHERE op.IsDeleted=0 AND (@PersonId IS NULL OR op.Id=@PersonId);

    -- Recent Transactions (with Mode)
    SELECT TOP 30
        e.Id, e.ExpenseId AS TxnRefId, 'Credit' AS TxnType,
        CONVERT(NVARCHAR(10), e.Date, 23) AS Date,
        e.Amount,
        ISNULL(e.Head,'')         AS Head,
        ISNULL(e.Mode,'')         AS Mode,     -- ✅ Mode added
        ISNULL(e.FundPoolName,'') AS FundPoolName,
        ISNULL(e.Purpose,'')      AS Purpose,
        ISNULL(e.CampId,0)        AS CampId,
        ISNULL(e.CampName,'')     AS CampName,
        ISNULL(e.RecipientId,0)   AS RecipientId,
        ISNULL(e.RecipientName,'') AS RecipientName,
        e.CreatedAt
    FROM Expenses e
    WHERE ISNULL(e.IsDeleted,0)=0
      AND e.RecipientRole='OtherPerson'
      AND (@PersonId IS NULL OR e.RecipientId=@PersonId)
    ORDER BY e.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOtherPersonDashboard - Mode added';
GO

-- ── 5. sp_GetOwnerDashboard ───────────────────────────────────
-- OwnerTransactions has no Mode column → '' AS Mode
CREATE OR ALTER PROCEDURE sp_GetOwnerDashboard
    @OwnerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ISNULL(o.Id,0) AS OwnerId, ISNULL(o.Code,'') AS OwnerCode,
        ISNULL(o.Name,'') AS OwnerName, ISNULL(o.Contact,'') AS OwnerContact,
        ISNULL(o.Email,'') AS OwnerEmail, ISNULL(o.Status,'') AS OwnerStatus,
        ISNULL(SUM(CASE WHEN ot.Type='DR' THEN ot.Amount ELSE 0 END),0) AS TotalAmount,
        ISNULL(SUM(CASE WHEN ot.Type='CR' THEN ot.Amount ELSE 0 END),0) AS TotalPaid,
        ISNULL(SUM(CASE WHEN ot.Type='DR' THEN ot.Amount ELSE 0 END),0)
        - ISNULL(SUM(CASE WHEN ot.Type='CR' THEN ot.Amount ELSE 0 END),0) AS TotalDue,
        ISNULL((SELECT COUNT(*) FROM OwnerContracts oc WHERE oc.IsDeleted=0 AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId) AND oc.Status='Active'),0) AS ActiveContracts,
        ISNULL((SELECT COUNT(*) FROM OwnerContracts oc WHERE oc.IsDeleted=0 AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)),0) AS TotalContracts
    FROM Owners o
    LEFT JOIN OwnerTransactions ot ON ot.OwnerId=o.Id AND ISNULL(ot.IsDeleted,0)=0
    WHERE o.IsDeleted=0 AND (@OwnerId IS NULL OR o.Id=@OwnerId)
    GROUP BY o.Id, o.Code, o.Name, o.Contact, o.Email, o.Status;

    -- Recent Transactions (Mode = '' as OwnerTransactions has no Mode col)
    SELECT TOP 20
        ot.Id,
        ISNULL(ot.TxnCode,'')       AS TxnCode,
        ot.OwnerContractId,
        ISNULL(ot.OcCode,'')        AS OcCode,
        ot.OwnerId,
        ISNULL(ot.OwnerName,'')     AS OwnerName,
        ot.CampId,
        ISNULL(ot.CampName,'')      AS CampName,
        ISNULL(ot.Type,'')          AS TxnType,
        ot.Amount,
        CONVERT(NVARCHAR(10), ot.Date, 23) AS TxnDate,
        ''                          AS Mode,      -- ✅ Mode = '' (no col in OwnerTransactions)
        ISNULL(ot.Description,'')   AS Description,
        ISNULL(ot.InstallmentNos,'') AS InstallmentNos,
        ot.ExpenseId,
        ot.CreatedAt
    FROM OwnerTransactions ot
    JOIN Owners o ON o.Id=ot.OwnerId AND o.IsDeleted=0
    WHERE ISNULL(ot.IsDeleted,0)=0
      AND (@OwnerId IS NULL OR ot.OwnerId=@OwnerId)
    ORDER BY ot.Id DESC;
END
GO
PRINT '✅ sp_GetOwnerDashboard - Mode added (empty string, no col in OwnerTransactions)';
GO

PRINT '=== ALL 5 DASHBOARD SPs UPDATED WITH Mode FIELD ===';
GO
