-- ============================================================
-- 139: Add IsRenewal computed flag to sp_GetOwnerContracts
--      IsRenewal = 1 agar yeh contract kisi renewal ka naya contract hai
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT = NULL,
    @CampId  INT = NULL,
    @Status  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        oc.Id,
        oc.OcCode,
        oc.CampId,
        ISNULL(c.Name, oc.CampName)  AS CampName,
        oc.OwnerId,
        ISNULL(o.Name, oc.OwnerName) AS OwnerName,
        ISNULL(o.Code, oc.OwnerCode) AS OwnerCode,
        oc.PaymentType,
        oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS Balance,
        oc.StartDate,
        oc.EndDate,
        ISNULL(oc.SecurityDeposit,     0) AS SecurityDeposit,
        ISNULL(oc.SecurityDepositPaid, 0) AS SecurityDepositPaid,
        oc.SecurityDepositPaidDate,
        oc.ContractDate,
        ISNULL(oc.MonthlyRent, 0) AS MonthlyRent,
        ISNULL(oc.NoOfMonths,  0) AS NoOfMonths,
        oc.Status,
        -- IsRenewal: 1 if this contract was created via renewal
        CASE WHEN EXISTS (
            SELECT 1 FROM OwnerContractRenewals r
            WHERE r.NewOwnerContractId = oc.Id AND r.IsDeleted = 0
        ) THEN 1 ELSE 0 END AS IsRenewal,
        oc.CreatedAt,
        oc.UpdatedAt,
        oc.AddedBy,
        oc.UpdatedBy,
        oc.IsDeleted
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId AND o.IsDeleted = 0
    LEFT JOIN Camps  c ON c.Id = oc.CampId  AND c.IsDeleted = 0
    WHERE oc.IsDeleted = 0
      AND (@OwnerId IS NULL OR oc.OwnerId = @OwnerId)
      AND (@CampId  IS NULL OR oc.CampId  = @CampId)
      AND (@Status  IS NULL OR oc.Status  = @Status)
    ORDER BY oc.CreatedAt DESC;
END
GO

PRINT '✅ 139 - sp_GetOwnerContracts updated with IsRenewal flag';
GO
