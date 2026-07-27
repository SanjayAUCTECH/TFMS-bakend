USE TFMS_TestSoftwareDB;
GO

DECLARE @TestOcId INT;
EXEC sp_CreateOwnerContract
    @CampId=81, @OwnerId=66, @PaymentType='Monthly',
    @TotalAmount=500, @StartDate='2026-07-28',
    @InstallmentsJson='[{"No":1,"Amount":500,"DueDate":"2026-07-28"}]',
    @MonthlyInstallmentsJson='[]',
    @AddedBy=1, @NewId=@TestOcId OUTPUT;

SELECT 'CREATED' AS T, @TestOcId AS OcId;
SELECT 'OI_BEFORE' AS T, COUNT(*) AS Cnt FROM OwnerInstallments WHERE OwnerContractId=@TestOcId AND ISNULL(IsDeleted,0)=0;
SELECT 'OT_BEFORE' AS T, COUNT(*) AS Cnt FROM OwnerTransactions WHERE OwnerContractId=@TestOcId AND ISNULL(IsDeleted,0)=0;

-- Delete
EXEC sp_DeleteOwnerContract @Id=@TestOcId, @DeletedBy=1;

-- Verify
SELECT 'OC_DELETED'       AS T, IsDeleted, DeletedBy FROM OwnerContracts WHERE Id=@TestOcId;
SELECT 'OI_ACTIVE'        AS T, COUNT(*) AS ShouldBe0 FROM OwnerInstallments WHERE OwnerContractId=@TestOcId AND ISNULL(IsDeleted,0)=0;
SELECT 'OI_SOFTDEL'       AS T, COUNT(*) AS ShouldBe1 FROM OwnerInstallments WHERE OwnerContractId=@TestOcId AND IsDeleted=1;
SELECT 'OT_ACTIVE'        AS T, COUNT(*) AS ShouldBe0 FROM OwnerTransactions WHERE OwnerContractId=@TestOcId AND ISNULL(IsDeleted,0)=0;
SELECT 'OT_SOFTDEL'       AS T, COUNT(*) AS ShouldBe1 FROM OwnerTransactions WHERE OwnerContractId=@TestOcId AND IsDeleted=1;
SELECT 'GET_SP_RESULT'    AS T, COUNT(*) AS ShouldBe0 FROM OwnerContracts WHERE Id=@TestOcId AND IsDeleted=0;
GO
