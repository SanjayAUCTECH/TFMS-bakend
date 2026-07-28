USE TFMS_TestSoftwareDB;
GO

-- Find contract with pending installments
DECLARE @CID NVARCHAR(MAX) = 'CNT-000091';

-- BEFORE state
SELECT 'BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;

-- Step 1: First payment - partial (pay half of installment 1)
DECLARE @Txn1 INT;
DECLARE @HalfAmt DECIMAL(18,2);
SELECT TOP 1 @HalfAmt = Amount/2 FROM ContractInstallments
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=1;

EXEC sp_RecordPayment
    @ContractId=@CID, @InstallmentNo=1, @PaidAmount=@HalfAmt,
    @PaidDate='2026-07-28', @PaymentMode='Cash',
    @FundPoolId=29, @FundPoolName='TestPool', @AddedBy=1,
    @NewTxnRecordId=@Txn1 OUTPUT;

SELECT 'AFTER_PARTIAL_PAY' AS T, @Txn1 AS TxnId, @HalfAmt AS PaidAmount;
SELECT 'CI_AFTER_P1' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;

-- Step 2: Edit payment - increase to full amount
DECLARE @FullAmt DECIMAL(18,2) = @HalfAmt * 2;
EXEC sp_UpdateTxnRecord
    @Id=@Txn1, @Amount=@FullAmt,
    @TxnDate='2026-07-28', @PaymentMode='Cash',
    @FundPoolId=29, @FundPoolName='TestPool',
    @Description='Updated to full', @ReceivedBy='Admin';

SELECT 'AFTER_EDIT_FULL' AS T;
SELECT 'CI_AFTER_EDIT' AS T, InstallmentNo, Amount, PaidAmount, Amount-PaidAmount AS Due, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;

-- Expected: InstNo 1 = Paid (full amount), InstNo 2,3 = Pending

-- Cleanup
EXEC sp_DeleteTxnRecord @Id=@Txn1, @DeletedBy=1;
SELECT 'CLEANUP' AS T;
SELECT 'CI_FINAL' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;
GO
