USE TFMS_TestSoftwareDB;
GO
DECLARE @newid INT;
EXEC sp_CreateOwnerContract
    @CampId=1, @OwnerId=1, @PaymentType='monthly',
    @TotalAmount=30000, @StartDate='2026-01-01',
    @InstallmentsJson='[{"No":1,"Amount":10000,"DueDate":"2026-01-01"},{"No":2,"Amount":10000,"DueDate":"2026-02-01"},{"No":3,"Amount":10000,"DueDate":"2026-03-01"}]',
    @NewId=@newid OUTPUT;
SELECT 'Result: id=' + CAST(@newid AS VARCHAR) AS Result;
DELETE FROM OwnerTransactions WHERE OwnerContractId=@newid;
DELETE FROM OwnerInstallments WHERE OwnerContractId=@newid;
DELETE FROM OwnerContracts WHERE Id=@newid;
PRINT 'Cleaned up';
GO
