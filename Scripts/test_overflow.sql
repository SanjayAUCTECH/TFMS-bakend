USE TFMS_TestSoftwareDB;
GO

-- Find contract with 3+ pending installments
DECLARE @CID NVARCHAR(MAX);
SELECT TOP 1 @CID=ContractId FROM Contracts WHERE IsDeleted=0
AND ContractId IN (
    SELECT ContractId FROM ContractInstallments
    WHERE Status IN('Pending','Overdue') AND ISNULL(IsDeleted,0)=0
    GROUP BY ContractId HAVING COUNT(*)>=3
);
SELECT 'CONTRACT' AS T, @CID AS ContractId;

-- Show BEFORE (first 3)
SELECT 'BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0
AND InstallmentNo<=3 ORDER BY InstallmentNo;

-- Pay 2.5x installment amount (should cover inst 1 fully + inst 2 partially)
DECLARE @SingleAmt DECIMAL(18,2);
SELECT TOP 1 @SingleAmt=Amount FROM ContractInstallments
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 ORDER BY InstallmentNo;

DECLARE @PayAmt DECIMAL(18,2) = @SingleAmt * 2.5;  -- 2.5x = covers 2 full + half of 3rd
SELECT 'PAYING' AS T, @PayAmt AS Amount, @SingleAmt AS SingleInstallment;

DECLARE @TxnId INT;
EXEC sp_RecordPayment
    @ContractId=@CID, @InstallmentNo=0,
    @PaidAmount=@PayAmt, @PaidDate='2026-07-28',
    @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@TxnId OUTPUT;

SELECT 'TXN_ID' AS T, @TxnId AS Id;

-- Show AFTER: inst1=Paid, inst2=Paid, inst3=Partial
SELECT 'AFTER' AS T, InstallmentNo, Amount, PaidAmount,
    Amount-PaidAmount AS Remaining, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0
AND InstallmentNo<=3 ORDER BY InstallmentNo;

-- Applied installments in TxnRecord
SELECT 'TXN' AS T, AppliedInstallments, Amount, Unallocated
FROM TxnRecords WHERE Id=@TxnId;

-- Cleanup
EXEC sp_DeleteTxnRecord @Id=@TxnId, @DeletedBy=1;
SELECT 'CLEANUP_DONE' AS T;
GO
