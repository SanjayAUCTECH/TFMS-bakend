USE TFMS_TestSoftwareDB;
GO

-- ═══════════════════════════════════════════════
-- TEST: ContractInstallments Insert/Update/Delete
-- ═══════════════════════════════════════════════

-- STEP 1: Find a contract with pending installments
DECLARE @CID NVARCHAR(MAX);
SELECT TOP 1 @CID = c.ContractId
FROM Contracts c
JOIN ContractInstallments ci ON ci.ContractId = c.ContractId
WHERE c.IsDeleted=0 AND ci.Status IN('Pending','Overdue') AND ISNULL(ci.IsDeleted,0)=0
ORDER BY c.Id;

SELECT 'CONTRACT' AS T, @CID AS ContractId;

-- STEP 2: Show BEFORE state (first 3 installments)
SELECT 'CI_BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3
ORDER BY InstallmentNo;

-- STEP 3: Record payment
DECLARE @NewTxnId INT;
DECLARE @PayAmt DECIMAL(18,2);
SELECT TOP 1 @PayAmt = Amount
FROM ContractInstallments
WHERE ContractId=@CID AND Status IN('Pending','Overdue') AND ISNULL(IsDeleted,0)=0
ORDER BY InstallmentNo;

EXEC sp_RecordPayment
    @ContractId=@CID, @InstallmentNo=0,
    @PaidAmount=@PayAmt,
    @PaidDate='2026-07-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@NewTxnId OUTPUT;

SELECT 'AFTER_PAYMENT' AS T, @NewTxnId AS TxnRecordId;

-- STEP 4: Show AFTER PAYMENT state
SELECT 'CI_AFTER_PAY' AS T, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3
ORDER BY InstallmentNo;

-- TxnRecord created?
SELECT 'TXN_CREATED' AS T, Id, TxnType, Amount, AppliedInstallments, IsDeleted
FROM TxnRecords WHERE Id=@NewTxnId;

-- Income created?
SELECT 'INCOME_CREATED' AS T, Id, IncomeId, Amount, TxnRecordId, IsDeleted
FROM Incomes WHERE TxnRecordId=@NewTxnId AND ISNULL(IsDeleted,0)=0;

-- FundPool updated?
SELECT 'FUNDPOOL' AS T, Id, Balance FROM FundPools WHERE Id=29;

-- STEP 5: DELETE (soft delete TxnRecord → revert CI)
EXEC sp_DeleteTxnRecord @Id=@NewTxnId, @DeletedBy=1;
SELECT 'AFTER_DELETE' AS T;

-- STEP 6: Show AFTER DELETE state (should revert to Pending)
SELECT 'CI_AFTER_DEL' AS T, InstallmentNo, Amount, PaidAmount, Status, PaidDate
FROM ContractInstallments
WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3
ORDER BY InstallmentNo;

-- TxnRecord soft deleted?
SELECT 'TXN_SOFTDEL' AS T, Id, IsDeleted, DeletedBy FROM TxnRecords WHERE Id=@NewTxnId;

-- Income soft deleted?
SELECT 'INCOME_SOFTDEL' AS T, Id, IsDeleted FROM Incomes WHERE TxnRecordId=@NewTxnId;
GO
