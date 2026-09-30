
-- ContractRoomInstallments
CREATE PROCEDURE sp_GetContractRoomInstallments
    @ContractId NVARCHAR(MAX)=NULL,@CampId INT=NULL,@RoomId INT=NULL,
    @Status NVARCHAR(MAX)=NULL,@Month NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT cri.* FROM ContractRoomInstallments cri
    WHERE cri.IsDeleted=0
      AND (@ContractId IS NULL OR cri.ContractId=@ContractId)
      AND (@CampId IS NULL OR cri.CampId=@CampId)
      AND (@RoomId IS NULL OR cri.RoomId=@RoomId)
      AND (@Status IS NULL OR cri.Status=@Status)
      AND (@Month IS NULL OR cri.Month=@Month)
    ORDER BY cri.ContractId,cri.InstallmentNo;
END

