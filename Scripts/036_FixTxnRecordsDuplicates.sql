-- ============================================================================
-- 036: Fix sp_GetTxnRecords — Remove duplicate rows caused by ContractCamps JOIN
-- Issue: LEFT JOIN ContractCamps produces multiple rows per TxnRecord when
--        a contract has multiple camps assigned.
-- Fix: Use subquery/EXISTS for CampId filter instead of JOIN.
-- ============================================================================

CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT, @PageSize INT,
    @ContractId NVARCHAR(MAX)=NULL, @TenantId INT=NULL, @CampId INT=NULL,
    @TxnType NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count (no JOIN on ContractCamps to avoid duplicates)
    SELECT @TotalRecords=COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId))
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType);

    -- Data (no JOIN on ContractCamps — use subqueries for camp info)
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
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId))
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType)
    ORDER BY tr.PaidDate DESC, tr.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '036 — sp_GetTxnRecords duplicate fix applied!';
GO
