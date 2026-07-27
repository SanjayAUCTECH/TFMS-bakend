USE TFMS_TestSoftwareDB;
GO

-- First check what SP currently looks like (key part)
SELECT SUBSTRING(OBJECT_DEFINITION(OBJECT_ID('sp_CreateOwnerContract')), 1, 500) AS SpDef;
GO

-- Check the OPENJSON parsing - what keys does it expect?
DECLARE @MciJson NVARCHAR(MAX) = '[{"InstallmentNo":1,"Amount":946.15,"PaidAmount":0,"Balance":946.15,"DueDate":"2026-07-27","PaidDate":"","Status":"Pending","ExpenseId":null,"PaymentMode":"","PaymentStatus":"Pending"}]';

-- Test OPENJSON parsing
SELECT InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate, Status, PaymentMode, PaymentStatus
FROM OPENJSON(@MciJson) WITH (
    InstallmentNo INT           '$.InstallmentNo',
    Amount        DECIMAL(18,2) '$.Amount',
    PaidAmount    DECIMAL(18,2) '$.PaidAmount',
    Balance       DECIMAL(18,2) '$.Balance',
    DueDate       DATE          '$.DueDate',
    PaidDate      NVARCHAR(50)  '$.PaidDate',
    Status        NVARCHAR(MAX) '$.Status',
    ExpenseId     INT           '$.ExpenseId',
    PaymentMode   NVARCHAR(MAX) '$.PaymentMode',
    PaymentStatus NVARCHAR(MAX) '$.PaymentStatus'
);
GO

-- Now run actual SP test
DECLARE @NewId INT;
DECLARE @InstJson NVARCHAR(MAX) = '[{"No":1,"Amount":2460,"DueDate":"2026-07-27"},{"No":2,"Amount":2460,"DueDate":"2026-10-27"}]';
DECLARE @MciJson2 NVARCHAR(MAX) = '[{"InstallmentNo":1,"Amount":946.15,"PaidAmount":0,"Balance":946.15,"DueDate":"2026-07-27","PaidDate":"","Status":"Pending","ExpenseId":null,"PaymentMode":"","PaymentStatus":"Pending"},{"InstallmentNo":2,"Amount":946.15,"PaidAmount":0,"Balance":946.15,"DueDate":"2026-08-27","PaidDate":"","Status":"Pending","ExpenseId":null,"PaymentMode":"","PaymentStatus":"Pending"}]';

EXEC sp_CreateOwnerContract
    @CampId=82, @OwnerId=66, @PaymentType='Quarterly',
    @TotalAmount=12300, @StartDate='2026-07-27',
    @InstallmentsJson=@InstJson,
    @MonthlyInstallmentsJson=@MciJson2,
    @AddedBy=NULL,
    @NewId=@NewId OUTPUT;

SELECT 'NewId' AS Label, @NewId AS Value;
SELECT 'OI_Count'  AS Label, COUNT(*) AS Value FROM OwnerInstallments              WHERE OwnerContractId=@NewId;
SELECT 'MCI_Count' AS Label, COUNT(*) AS Value FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=@NewId;

-- Cleanup
DELETE FROM OwnerTransactions               WHERE OwnerContractId=@NewId;
DELETE FROM OwnerInstallments               WHERE OwnerContractId=@NewId;
DELETE FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=@NewId;
DELETE FROM OwnerContracts                  WHERE Id=@NewId;
PRINT 'Test done and cleaned up';
GO
