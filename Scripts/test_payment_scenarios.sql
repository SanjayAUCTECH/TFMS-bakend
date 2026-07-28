USE TFMS_TestSoftwareDB;
GO
-- ═══════════════════════════════════════════════════════════
-- TEST SCENARIO 1: Single installment full payment
-- ═══════════════════════════════════════════════════════════
DECLARE @CID NVARCHAR(MAX) = 'CNT-000092';
DECLARE @Txn1 INT;

SELECT '=== SCENARIO 1: Single installment full ===' AS Info;
SELECT 'S1_BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=2;

EXEC sp_RecordPayment @ContractId=@CID, @InstallmentNo=2, @PaidAmount=4800,
    @PaidDate='2026-07-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@Txn1 OUTPUT;

SELECT 'S1_AFTER_CI' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=2;
SELECT 'S1_TXN' AS T, Id, Amount, AppliedInstallments, TxnType
FROM TxnRecords WHERE Id=@Txn1;
SELECT 'S1_INCOME' AS T, Id, Amount, TxnRecordId FROM Incomes WHERE TxnRecordId=@Txn1 AND ISNULL(IsDeleted,0)=0;
SELECT 'S1_FP' AS T, Balance FROM FundPools WHERE Id=29;

-- Cleanup S1
EXEC sp_DeleteTxnRecord @Id=@Txn1, @DeletedBy=1;
SELECT 'S1_REVERTED' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=2;
GO

-- ═══════════════════════════════════════════════════════════
-- TEST SCENARIO 2: Partial payment then remaining
-- ═══════════════════════════════════════════════════════════
DECLARE @CID2 NVARCHAR(MAX) = 'CNT-000092';
DECLARE @T2a INT, @T2b INT;

SELECT '=== SCENARIO 2: Partial + Remaining ===' AS Info;
SELECT 'S2_BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID2 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=3;

-- Partial: 2400 (half)
EXEC sp_RecordPayment @ContractId=@CID2, @InstallmentNo=3, @PaidAmount=2400,
    @PaidDate='2026-07-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@T2a OUTPUT;

SELECT 'S2_PARTIAL' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID2 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=3;

-- Remaining: 2400
EXEC sp_RecordPayment @ContractId=@CID2, @InstallmentNo=3, @PaidAmount=2400,
    @PaidDate='2026-07-29', @PaymentMode='Cheque', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@T2b OUTPUT;

SELECT 'S2_FULL_PAID' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID2 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=3;

-- Delete only 2nd txn — inst should go back to Partial
EXEC sp_DeleteTxnRecord @Id=@T2b, @DeletedBy=1;
SELECT 'S2_AFTER_DEL_T2' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID2 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=3;

-- Cleanup
EXEC sp_DeleteTxnRecord @Id=@T2a, @DeletedBy=1;
SELECT 'S2_REVERTED' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID2 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo=3;
GO

-- ═══════════════════════════════════════════════════════════
-- TEST SCENARIO 3: Multi-installment auto-distribute
-- ═══════════════════════════════════════════════════════════
DECLARE @CID3 NVARCHAR(MAX) = 'CNT-000092';
DECLARE @T3 INT;

SELECT '=== SCENARIO 3: Multi-installment auto-distribute ===' AS Info;
SELECT 'S3_BEFORE' AS T, InstallmentNo, Amount, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID3 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(4,5) ORDER BY InstallmentNo;

-- Pay 2x installment (auto-distribute to 2 installments)
EXEC sp_RecordPayment @ContractId=@CID3, @InstallmentNo=0, @PaidAmount=9600,
    @PaidDate='2026-07-28', @PaymentMode='Bank Transfer', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@T3 OUTPUT;

SELECT 'S3_AFTER' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID3 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(4,5) ORDER BY InstallmentNo;
SELECT 'S3_TXN' AS T, Id, Amount, AppliedInstallments FROM TxnRecords WHERE Id=@T3;

-- Edit: increase to 3x
EXEC sp_UpdateTxnRecord @Id=@T3, @Amount=14400,
    @TxnDate='2026-07-28', @PaymentMode='Bank Transfer',
    @FundPoolId=29, @FundPoolName='TestPool', @Description='3 months';

SELECT 'S3_AFTER_EDIT' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID3 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(4,5,6) ORDER BY InstallmentNo;
SELECT 'S3_TXN_EDITED' AS T, Id, Amount, AppliedInstallments FROM TxnRecords WHERE Id=@T3;

-- Delete → all should revert
EXEC sp_DeleteTxnRecord @Id=@T3, @DeletedBy=1;
SELECT 'S3_REVERTED' AS T, InstallmentNo, PaidAmount, Status
FROM ContractInstallments WHERE ContractId=@CID3 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(4,5,6) ORDER BY InstallmentNo;
GO
