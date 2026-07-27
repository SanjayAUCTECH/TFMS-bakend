USE TFMS_TestSoftwareDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Fix sp_GetContractById — include installments (payments)
CREATE OR ALTER PROCEDURE sp_GetContractById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT
        c.Id, c.ContractId, c.TenantId, ISNULL(t.Name,'') TenantName,
        c.StartDate, c.Months, c.EndDate, c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit,0) SecurityDeposit,
        ISNULL(c.SecurityDepositStatus,'Pending') SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,
        ISNULL(c.ContractType,'Monthly') ContractType,
        ISNULL(c.InstallmentType,'monthly') InstallmentType,
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
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0),0) TotalPaid,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status<>'Paid' AND ISNULL(ci.IsDeleted,0)=0),0) TotalDue,
        NULL LastPaymentAmount, NULL LastPaymentDate,
        0 SdForfeitAmount, 0 SdRefundAmount, 0 SdAdjustAmount,
        c.CreatedAt, c.UpdatedAt, c.AddedBy, c.UpdatedBy,
        -- Payment columns (one row per installment)
        ci.Id PayId, ci.InstallmentNo, ci.Amount PayAmount,
        ci.DueDate, ci.PaidAmount, ci.PaidDate,
        ci.Status PayStatus,
        ISNULL(ci.PaymentMode,'') PaymentMode,
        ISNULL(ci.ChequeNumber,'') ChequeNumber,
        ISNULL(ci.ClearanceDate,'') ClearanceDate
    FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0
    WHERE c.Id=@Id AND c.IsDeleted=0
    ORDER BY ci.InstallmentNo;
END
GO

-- Fix sp_GetContractByContractId — same structure
CREATE OR ALTER PROCEDURE sp_GetContractByContractId @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT
        c.Id, c.ContractId, c.TenantId, ISNULL(t.Name,'') TenantName,
        c.StartDate, c.Months, c.EndDate, c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit,0) SecurityDeposit,
        ISNULL(c.SecurityDepositStatus,'Pending') SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,
        ISNULL(c.ContractType,'Monthly') ContractType,
        ISNULL(c.InstallmentType,'monthly') InstallmentType,
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
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments ci2 WHERE ci2.ContractId=c.ContractId AND ISNULL(ci2.IsDeleted,0)=0),0) TotalPaid,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM ContractInstallments ci2 WHERE ci2.ContractId=c.ContractId AND ci2.Status<>'Paid' AND ISNULL(ci2.IsDeleted,0)=0),0) TotalDue,
        NULL LastPaymentAmount, NULL LastPaymentDate,
        0 SdForfeitAmount, 0 SdRefundAmount, 0 SdAdjustAmount,
        c.CreatedAt, c.UpdatedAt, c.AddedBy, c.UpdatedBy,
        -- Payment/Installment columns
        ci.Id PayId, ci.InstallmentNo, ci.Amount PayAmount,
        ci.DueDate, ci.PaidAmount, ci.PaidDate,
        ci.Status PayStatus,
        ISNULL(ci.PaymentMode,'') PaymentMode,
        ISNULL(ci.ChequeNumber,'') ChequeNumber,
        ISNULL(ci.ClearanceDate,'') ClearanceDate
    FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0
    ORDER BY ci.InstallmentNo;
END
GO
PRINT 'sp_GetContractById and sp_GetContractByContractId FIXED with payments';
GO
