USE TFMS_TestSoftwareDB;
GO

-- Step 1: Check current state of CNT-000001 installment 1
SELECT 'BEFORE_PAYMENT' AS Phase, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments WHERE ContractId='CNT-000001' AND InstallmentNo=1 AND ISNULL(IsDeleted,0)=0;

-- Step 2: Record a payment via SP
DECLARE @NewTxnId INT;
EXEC sp_RecordPayment
    @ContractId='CNT-000001', @InstallmentNo=0, @PaidAmount=2200,
    @PaidDate='2026-07-28', @PaymentMode='Cash', @FundPoolId=29,
    @FundPoolName='TestPool', @AddedBy=NULL, @NewTxnRecordId=@NewTxnId OUTPUT;

SELECT 'AFTER_PAYMENT' AS Phase, @NewTxnId AS TxnRecordId;

-- Step 3: Check ContractInstallments AFTER payment
SELECT 'CI_AFTER_PAY' AS Phase, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments WHERE ContractId='CNT-000001' AND InstallmentNo=1 AND ISNULL(IsDeleted,0)=0;

-- Step 4: Now DELETE the TxnRecord
EXEC sp_DeleteTxnRecord @Id=@NewTxnId, @DeletedBy=1;
SELECT 'AFTER_DELETE' AS Phase;

-- Step 5: Check ContractInstallments AFTER delete
SELECT 'CI_AFTER_DEL' AS Phase, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments WHERE ContractId='CNT-000001' AND InstallmentNo=1 AND ISNULL(IsDeleted,0)=0;

-- TxnRecord soft deleted?
SELECT 'TXN_STATE' AS Phase, Id, Amount, IsDeleted FROM TxnRecords WHERE Id=@NewTxnId;
GO
