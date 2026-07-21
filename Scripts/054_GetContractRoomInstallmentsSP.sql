-- ============================================================
-- 054: sp_GetContractRoomInstallments — with all filters
--      contractId (compulsory), campId, roomId, month, status (optional)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetContractRoomInstallments
    @ContractId   NVARCHAR(MAX),
    @CampId       INT           = NULL,
    @RoomId       INT           = NULL,
    @Month        NVARCHAR(10)  = NULL,
    @Status       NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cri.Id,
        cri.ContractId,
        cri.CampId,
        cri.CampName,
        cri.RoomId,
        cri.RoomNo,
        cri.InstallmentNo,
        cri.InstallAmount,
        cri.DueDate,
        cri.Month,
        cri.PaymentMode,
        cri.ReferenceNo,
        cri.ClearanceDate,
        cri.Status,
        cri.PaidAmount,
        cri.PaidDate,
        cri.CreatedAt,
        cri.UpdatedAt
    FROM ContractRoomInstallments cri
    WHERE cri.ContractId = @ContractId
      AND (@CampId IS NULL OR cri.CampId = @CampId)
      AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
      AND (@Month  IS NULL OR cri.Month  = @Month)
      AND (@Status IS NULL OR cri.Status = @Status)
    ORDER BY cri.InstallmentNo, cri.CampName, cri.RoomNo;
END
GO

PRINT '054 - sp_GetContractRoomInstallments updated with CampId filter';
GO
