-- ============================================================
-- 039: Add SD Settlement fields to sp_GetContracts
--      sdForfeitAmount (SD-FRF), sdRefundAmount (SD-REF), sdAdjustAmount (SD-ADJ)
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

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
    LEFT JOIN ContractCamps cc ON cc.ContractId = c.ContractId
    WHERE (@Status    IS NULL OR c.Status    = @Status)
      AND (@TenantId  IS NULL OR c.TenantId  = @TenantId)
      AND (@CampId    IS NULL OR cc.CampId   = @CampId)
      AND (@DateFrom  IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo    IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL
           OR EXISTS(SELECT 1 FROM Tenants t2 WHERE t2.Id=c.TenantId AND t2.Name LIKE '%'+@SearchText+'%')
           OR c.ContractId LIKE '%'+@SearchText+'%');

    SELECT
        c.Id, c.ContractId, c.TenantId,
        t.Name TenantName,
        ISNULL((SELECT TOP 1 cc2.CampId FROM ContractCamps cc2 WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id), 0) CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc3 JOIN Camps ca2 ON ca2.Id=cc3.CampId WHERE cc3.ContractId=c.ContractId ORDER BY cc3.Id), '') CampName,
        c.StartDate, c.Months, c.EndDate, c.MonthlyTotal, c.ContractTotal,

        -- Security Deposit basic
        ISNULL(c.SecurityDeposit, 0)              SecurityDeposit,
        ISNULL(c.SecurityDepositStatus, 'Pending') SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid, 0)           SecurityDepositPaid,

        -- Security Deposit Settlement breakdown (from TxnRecords)
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr
                WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-FRF'), 0) SdForfeitAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr
                WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-REF'), 0) SdRefundAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr
                WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-ADJ'), 0) SdAdjustAmount,

        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.ContractType, 'Monthly')    ContractType,
        ISNULL(c.IssuedBy, '')  IssuedBy,
        ISNULL(c.Notes, '')     Notes,
        ISNULL(c.LessorAmount, 0) LessorAmount,
        c.Status,

        -- Property info
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName, '')  ContractBuildingName,
        ISNULL(c.ContractPropertyType, '')  ContractPropertyType,
        ISNULL(c.ContractLocation, '')      ContractLocation,
        ISNULL(c.ContractPropertyNo, '')    ContractPropertyNo,
        ISNULL(c.ContractPropertyArea, '')  ContractPropertyArea,
        ISNULL(c.ContractPremisesNo, '')    ContractPremisesNo,
        ISNULL(c.ContractPaymentMode, '')   ContractPaymentMode,
        ISNULL(c.ContractPlotNo, '')        ContractPlotNo,
        ISNULL(c.ContractMakaniNo, '')      ContractMakaniNo,

        -- Payment summary (rent only, from ContractInstallments)
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId), 0) TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId=c.ContractId), 0) TotalDue,

        -- Last payment info
        (SELECT TOP 1 Amount  FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId=c.ContractId AND TxnType='CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,

        c.CreatedAt, c.UpdatedAt
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    WHERE (@Status   IS NULL OR c.Status   = @Status)
      AND (@TenantId IS NULL OR c.TenantId = @TenantId)
      AND (@CampId   IS NULL OR c.Id IN (SELECT ContractId FROM ContractCamps WHERE CampId=@CampId))
      AND (@DateFrom IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR c.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY c.CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '039 - sp_GetContracts updated with SD settlement fields (SdForfeitAmount, SdRefundAmount, SdAdjustAmount)';
GO
