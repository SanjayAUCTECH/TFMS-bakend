-- ============================================================
-- 098: sp_GetTenantDashboard
-- Tenant Dashboard Summary + Recent Transactions
--
-- Fields:
--   TotalAmount       = SUM of DR type TxnRecords (total payable)
--   TotalPaid         = SUM of CR + Penalty (refund at cancellation)
--   TotalDue          = TotalAmount - TotalPaid
--   TotalSecurityAmount = SUM of Contracts.SecurityDeposit
--   SecurityPaidAmount  = SUM of SD-CR type TxnRecords
--   SecurityDueAmount   = TotalSecurityAmount - SecurityPaidAmount
--   PenaltyAmount       = SUM from ContractCancellations
--   RecentTransactions  = Last 10 TxnRecords
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetTenantDashboard
    @TenantId INT = NULL    -- Optional: NULL = all tenants
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Summary ─────────────────────────────────────────────
    SELECT
        -- Total Amount due (all DR transactions = contract totals)
        ISNULL(SUM(CASE WHEN tr.TxnType = 'DR'    THEN tr.Amount ELSE 0 END), 0) AS TotalAmount,

        -- Total Paid (all CR transactions = payments received)
        ISNULL(SUM(CASE WHEN tr.TxnType = 'CR'    THEN tr.Amount ELSE 0 END), 0) AS TotalPaid,

        -- Total Due = TotalAmount - TotalPaid
        ISNULL(SUM(CASE WHEN tr.TxnType = 'DR'    THEN tr.Amount ELSE 0 END), 0)
        - ISNULL(SUM(CASE WHEN tr.TxnType = 'CR'  THEN tr.Amount ELSE 0 END), 0) AS TotalDue,

        -- Security Deposit Paid (SD-CR type)
        ISNULL(SUM(CASE WHEN tr.TxnType = 'SD-CR' THEN tr.Amount ELSE 0 END), 0) AS SecurityPaidAmount,

        -- Total Security Amount from Contracts
        ISNULL((
            SELECT SUM(ISNULL(c2.SecurityDeposit, 0))
            FROM Contracts c2
            WHERE c2.IsDeleted = 0
              AND (@TenantId IS NULL OR c2.TenantId = @TenantId)
        ), 0) AS TotalSecurityAmount,

        -- Security Due
        ISNULL((
            SELECT SUM(ISNULL(c2.SecurityDeposit, 0))
            FROM Contracts c2
            WHERE c2.IsDeleted = 0
              AND (@TenantId IS NULL OR c2.TenantId = @TenantId)
        ), 0)
        - ISNULL(SUM(CASE WHEN tr.TxnType = 'SD-CR' THEN tr.Amount ELSE 0 END), 0) AS SecurityDueAmount,

        -- Penalty Amount from cancellations (penalty applied)
        ISNULL((
            SELECT SUM(ISNULL(cc.PenaltyAmount, 0))
            FROM ContractCancellations cc
            WHERE ISNULL(cc.IsDeleted, 0) = 0
              AND (@TenantId IS NULL OR cc.TenantId = @TenantId)
        ), 0) AS PenaltyAmount,

        -- Refund Amount from cancellations
        ISNULL((
            SELECT SUM(ISNULL(cc.RefundAmount, 0))
            FROM ContractCancellations cc
            WHERE ISNULL(cc.IsDeleted, 0) = 0
              AND (@TenantId IS NULL OR cc.TenantId = @TenantId)
        ), 0) AS RefundAmount,

        -- Tenant info (when single tenant)
        MAX(t.Id)      AS TenantId,
        MAX(t.Name)    AS TenantName,
        MAX(t.Contact) AS TenantContact,
        MAX(t.Email)   AS TenantEmail,
        MAX(t.Status)  AS TenantStatus

    FROM TxnRecords tr
    JOIN Tenants t ON t.Id = tr.TenantId
    WHERE ISNULL(tr.IsDeleted, 0) = 0
      AND t.IsDeleted = 0
      AND (@TenantId IS NULL OR tr.TenantId = @TenantId);

    -- ── 2. Recent Transactions (last 20) ───────────────────────
    SELECT TOP 20
        tr.Id,
        tr.TxnId,
        tr.TxnType,
        tr.ContractId,
        tr.ContractCode,
        tr.TenantId,
        ISNULL(t.Name, '')       AS TenantName,
        tr.CampId,
        ISNULL(ca.Name, '')      AS CampName,
        tr.TotalAmount,
        tr.Amount,
        CONVERT(NVARCHAR(10), tr.PaidDate, 23)  AS TxnDate,
        tr.PaymentMode,
        tr.PaymentModeId,
        ISNULL(tr.ChequeNumber, '')   AS ChequeNumber,
        ISNULL(tr.Description, '')    AS Description,
        ISNULL(tr.ReceivedBy, '')     AS ReceivedBy,
        ISNULL(tr.FundPoolName, '')   AS FundPoolName,
        tr.AppliedInstallments,
        tr.InstallmentNo,
        tr.Unallocated,
        tr.CreatedAt
    FROM TxnRecords tr
    JOIN Tenants t  ON t.Id  = tr.TenantId AND t.IsDeleted = 0
    LEFT JOIN Camps ca ON ca.Id = tr.CampId AND ca.IsDeleted = 0  -- ✅ IsDeleted filter
    WHERE ISNULL(tr.IsDeleted, 0) = 0
      AND (@TenantId IS NULL OR tr.TenantId = @TenantId)
    ORDER BY tr.Id DESC;
END
GO

PRINT '✅ sp_GetTenantDashboard created';
GO
