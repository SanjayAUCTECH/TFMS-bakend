USE TFMS_TestSoftwareDB;
GO
-- Test sp_RecordPayment directly
EXEC sp_RecordPayment
    @ContractId      = 'CNT-000090',
    @InstallmentNo   = 1,
    @PaidAmount      = 1000,
    @PaidDate        = '2026-07-14',
    @PaymentModeId   = 1,
    @PaymentMode     = 'Cash',
    @ChequeNumber    = '',
    @ClearanceDate   = '',
    @Description     = 'Test payment',
    @ReceivedBy      = 'Admin',
    @ReceivedContact = '0501234567',
    @FundPoolId      = 1,
    @FundPoolName    = 'Main Fund',
    @IssuedBy        = 'Admin';
PRINT 'sp_RecordPayment test done';

-- Check result
SELECT ContractId, InstallmentNo, PaidAmount, Status
FROM ContractInstallments
WHERE ContractId='CNT-000090' AND InstallmentNo=1;

-- Revert
UPDATE ContractInstallments SET PaidAmount=0, Status='Pending', PaidDate=NULL WHERE ContractId='CNT-000090' AND InstallmentNo=1;
DELETE FROM TxnRecords WHERE ContractId='CNT-000090' AND InstallmentNo=1;
PRINT 'Reverted';
GO
