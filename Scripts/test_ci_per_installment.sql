USE TFMS_TestSoftwareDB;
GO

-- Find contract with 3+ pending installments
DECLARE @CID NVARCHAR(MAX);
SELECT TOP 1 @CID = c.ContractId
FROM Contracts c
JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
WHERE c.IsDeleted=0 AND ISNULL(ci.IsDeleted,0)=0 AND ci.Status IN('Pending','Overdue')
GROUP BY c.ContractId HAVING COUNT(*)>=2
ORDER BY c.ContractId;

SELECT 'CONTRACT' AS T, @CID AS ContractId;

-- BEFORE: show all installments
SELECT 'CI_BEFORE' AS T, InstallmentNo, PaidAmount, Status, PaidDate
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0
ORDER BY InstallmentNo;

-- Payment 1: Pay installment 1 only
DECLARE @Txn1 INT;
DECLARE @Amt1 DECIMAL(18,2);
SELECT TOP 1 @Amt1=Amount FROM ContractInstallments
WHERE ContractId=@CID AND Status IN('Pending','Overdue') AND ISNULL(IsDeleted,0)=0
ORDER BY InstallmentNo;

EXEC sp_RecordPayment
    @ContractId=@CID, @InstallmentNo=1,
    @PaidAmount=@Amt1, @PaidDate='2026-07-28',
    @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@Txn1 OUTPUT;

SELECT 'TXN1' AS T, @Txn1 AS Id;

-- Payment 2: Pay installment 2 only
DECLARE @Txn2 INT;
DECLARE @Amt2 DECIMAL(18,2);
SELECT TOP 1 @Amt2=Amount FROM ContractInstallments
WHERE ContractId=@CID AND InstallmentNo=2 AND ISNULL(IsDeleted,0)=0;

EXEC sp_RecordPayment
    @ContractId=@CID, @InstallmentNo=2,
    @PaidAmount=@Amt2, @PaidDate='2026-07-28',
    @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@Txn2 OUTPUT;

SELECT 'TXN2' AS T, @Txn2 AS Id;

-- AFTER 2 PAYMENTS: both should be Paid
SELECT 'CI_AFTER_2PAYS' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0
ORDER BY InstallmentNo;

-- DELETE only Payment 1 (Txn1)
EXEC sp_DeleteTxnRecord @Id=@Txn1, @DeletedBy=1;

-- AFTER DELETE TXN1:
-- InstallmentNo 1 → should revert to Pending/Overdue ✅
-- InstallmentNo 2 → should stay PAID (not affected)  ✅
SELECT 'CI_AFTER_DEL_TXN1' AS T, InstallmentNo, PaidAmount, Status, PaidDate
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0
ORDER BY InstallmentNo;

-- Cleanup: delete Txn2 too
EXEC sp_DeleteTxnRecord @Id=@Txn2, @DeletedBy=1;
SELECT 'CLEANUP_DONE' AS T;
GO
