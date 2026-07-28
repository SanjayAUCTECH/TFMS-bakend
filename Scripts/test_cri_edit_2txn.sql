USE TFMS_TestSoftwareDB;
GO
-- Scenario: 2 payments on same contract, edit 2nd → 1st CRI must stay unchanged

DECLARE @CID NVARCHAR(MAX) = 'CNT-000088';

-- Show CRI before
SELECT 'CRI_BEFORE' AS T, Id, RoomId, InstallmentNo, Month, PaidAmount, Balance, Status
FROM ContractRoomInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(2,3)
ORDER BY InstallmentNo, RoomId;

-- Txn1: Pay InstNo=2 (Nov26) for all 3 rooms
DECLARE @T1 INT;
EXEC sp_RecordPayment @ContractId=@CID, @InstallmentNo=2, @PaidAmount=3600,
    @PaidDate='2026-11-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@T1 OUTPUT;
SELECT 'TXN1_ID' AS T, @T1 AS Id;

-- Manually update ContractRoomsTrns + CRI for T1 (simulating room payments)
INSERT INTO ContractRoomsTrns(ContractId,RoomId,CampId,TxnType,TxnRecordId,TotalAmount,Amount,TxnDate,Month,Description,CriId,InstallmentNo,CreatedAt)
SELECT ContractId, RoomId, CampId,'CR',@T1,InstallAmount,InstallAmount,'2026-11-28','Nov26','T1 payment',Id,InstallmentNo,GETDATE()
FROM ContractRoomInstallments WHERE ContractId=@CID AND InstallmentNo=2 AND ISNULL(IsDeleted,0)=0;

UPDATE cri SET PaidAmount=InstallAmount, Balance=0, Status='Paid', PaidDate='2026-11-28', UpdatedAt=GETDATE()
FROM ContractRoomInstallments cri WHERE ContractId=@CID AND InstallmentNo=2 AND ISNULL(IsDeleted,0)=0;

SELECT 'CRI_AFTER_T1' AS T, Id, InstallmentNo, PaidAmount, Balance, Status
FROM ContractRoomInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(2,3)
ORDER BY InstallmentNo, RoomId;

-- Txn2: Pay InstNo=3 (Dec26) for all 3 rooms
DECLARE @T2 INT;
EXEC sp_RecordPayment @ContractId=@CID, @InstallmentNo=3, @PaidAmount=3600,
    @PaidDate='2026-12-28', @PaymentMode='Cash', @FundPoolId=29, @FundPoolName='TestPool',
    @AddedBy=1, @NewTxnRecordId=@T2 OUTPUT;
SELECT 'TXN2_ID' AS T, @T2 AS Id;

INSERT INTO ContractRoomsTrns(ContractId,RoomId,CampId,TxnType,TxnRecordId,TotalAmount,Amount,TxnDate,Month,Description,CriId,InstallmentNo,CreatedAt)
SELECT ContractId,RoomId,CampId,'CR',@T2,InstallAmount,InstallAmount,'2026-12-28','Dec26','T2 payment',Id,InstallmentNo,GETDATE()
FROM ContractRoomInstallments WHERE ContractId=@CID AND InstallmentNo=3 AND ISNULL(IsDeleted,0)=0;

UPDATE cri SET PaidAmount=InstallAmount,Balance=0,Status='Paid',PaidDate='2026-12-28',UpdatedAt=GETDATE()
FROM ContractRoomInstallments cri WHERE ContractId=@CID AND InstallmentNo=3 AND ISNULL(IsDeleted,0)=0;

SELECT 'CRI_AFTER_T2' AS T, Id, InstallmentNo, PaidAmount, Balance, Status
FROM ContractRoomInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(2,3)
ORDER BY InstallmentNo, RoomId;
-- Expected: Both InstNo=2 AND InstNo=3 = Paid

-- NOW EDIT T2 (Dec) → T2 mein roomPayments bhi hain
-- sp_UpdateTxnRecord calls C# UpdateAsync which reverts CRI via ContractRoomsTrns
-- Problem: Does it affect T1's CRI (Nov)?
-- Simulate: TxnRecord edit (amount change)
EXEC sp_UpdateTxnRecord @Id=@T2, @Amount=1800,
    @TxnDate='2026-12-28', @PaymentMode='Cash',
    @FundPoolId=29, @FundPoolName='TestPool';

SELECT 'CRI_AFTER_EDIT_T2' AS T, Id, InstallmentNo, PaidAmount, Balance, Status
FROM ContractRoomInstallments WHERE ContractId=@CID AND ISNULL(IsDeleted,0)=0 AND InstallmentNo IN(2,3)
ORDER BY InstallmentNo, RoomId;
-- Expected: InstNo=2 (Nov) UNCHANGED=Paid, InstNo=3 (Dec) = reverted by room C# code

-- Cleanup
DELETE FROM ContractRoomsTrns WHERE TxnRecordId IN(@T1,@T2);
UPDATE ContractRoomInstallments SET PaidAmount=0,Balance=InstallAmount,Status='Pending',PaidDate=NULL WHERE ContractId=@CID AND InstallmentNo IN(2,3);
EXEC sp_DeleteTxnRecord @Id=@T2, @DeletedBy=1;
EXEC sp_DeleteTxnRecord @Id=@T1, @DeletedBy=1;
SELECT 'CLEANUP_DONE' AS T;
GO
