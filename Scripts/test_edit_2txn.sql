USE TFMS_TestSoftwareDB;
GO
DECLARE @CID NVARCHAR(MAX) = 'CNT-000091';

SELECT 'BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=2 ORDER BY InstallmentNo;

-- Txn1: Pay partial on installment 1 (600 of 1200)
DECLARE @Txn1 INT;
EXEC sp_RecordPayment @ContractId=@CID, @InstallmentNo=1, @PaidAmount=600,
    @PaidDate='2026-07-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@Txn1 OUTPUT;
SELECT 'TXN1_PARTIAL' AS T, @Txn1 AS Id, 600 AS Paid;

-- Txn2: Pay remaining on installment 1 (600 remaining)
DECLARE @Txn2 INT;
EXEC sp_RecordPayment @ContractId=@CID, @InstallmentNo=1, @PaidAmount=600,
    @PaidDate='2026-07-29', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@Txn2 OUTPUT;
SELECT 'TXN2_REMAINING' AS T, @Txn2 AS Id, 600 AS Paid;

SELECT 'AFTER_2_PAYS' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=2 ORDER BY InstallmentNo;
-- Expected: Inst 1 = Paid (1200), Inst 2 = Pending

-- Now EDIT Txn2: change amount from 600 to 1200 (should pay inst1 remaining + start inst2)
EXEC sp_UpdateTxnRecord @Id=@Txn2, @Amount=1200,
    @TxnDate='2026-07-29', @PaymentMode='Cash',
    @FundPoolId=29, @FundPoolName='TestPool',
    @Description='Increased to 1200', @ReceivedBy='Admin';

SELECT 'AFTER_EDIT_TXN2_1200' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=2 ORDER BY InstallmentNo;
-- Expected: Inst 1 = Paid, Inst 2 = Paid OR Partial

-- TxnRecords state
SELECT 'TXNS' AS T, Id, Amount, AppliedInstallments, IsDeleted FROM TxnRecords
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 ORDER BY Id DESC;

-- Cleanup
EXEC sp_DeleteTxnRecord @Id=@Txn2, @DeletedBy=1;
EXEC sp_DeleteTxnRecord @Id=@Txn1, @DeletedBy=1;
SELECT 'CLEANUP_DONE' AS T;

SELECT 'CI_FINAL' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=2 ORDER BY InstallmentNo;
GO
