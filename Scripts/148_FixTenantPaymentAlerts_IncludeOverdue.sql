-- ============================================================
-- 148: Fix sp_GetTenantPaymentAlerts
--      Problem: Sirf upcoming due dikhata tha
--      Fix: Overdue (past due) + Due Today + Upcoming sab include
--           Jab tak paisa nahi diya tab tak alert aata rahe
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetTenantPaymentAlerts
    @DaysAhead INT = 2,
    @TenantId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.Id                                    AS TenantId,
        t.Name                                  AS TenantName,
        ISNULL(t.Contact,'')                    AS Contact,
        c.ContractId                            AS ContractCode,
        ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc2
                JOIN Camps ca ON ca.Id=cc2.CampId
                WHERE cc2.ContractId=c.ContractId),'') AS CampName,
        ci.Id                                   AS InstallmentId,
        ci.InstallmentNo                        AS InstallmentNo,
        ci.Amount                               AS Amount,
        ISNULL(ci.PaidAmount,0)                 AS PaidAmount,
        ci.Amount - ISNULL(ci.PaidAmount,0)     AS BalanceAmount,
        ci.DueDate                              AS DueDate,
        DATEDIFF(DAY, GETDATE(), ci.DueDate)    AS DaysUntilDue,
        CASE
            WHEN ci.DueDate < CAST(GETDATE() AS DATE) AND ci.Amount - ISNULL(ci.PaidAmount,0) > 0
                THEN 'Overdue'
            WHEN ci.DueDate = CAST(GETDATE() AS DATE)
                THEN 'Due Today'
            ELSE 'Upcoming'
        END                                     AS InstallmentStatus
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId = ci.ContractId AND c.IsDeleted = 0
    JOIN Tenants t   ON t.Id = c.TenantId AND t.IsDeleted = 0
    WHERE ISNULL(ci.IsDeleted,0) = 0
      AND c.Status = 'Active'
      -- Balance > 0 (paisa nahi diya)
      AND (ci.Amount - ISNULL(ci.PaidAmount,0)) > 0
      -- Overdue: past due (koi bhi purani date) + Upcoming: within @DaysAhead
      AND ci.DueDate <= DATEADD(DAY, @DaysAhead, GETDATE())
      -- Status check: Pending, Partial, Overdue (Paid excluded)
      AND ci.Status IN ('Pending', 'Partial', 'Overdue')
      -- Optional tenant filter
      AND (@TenantId IS NULL OR c.TenantId = @TenantId)
    ORDER BY ci.DueDate ASC, t.Name;
END
GO

PRINT '✅ 148 - sp_GetTenantPaymentAlerts fixed: Overdue tab tak dikhega jab tak paisa na de';
GO
