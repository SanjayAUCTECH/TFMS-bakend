USE TFMS_TestSoftwareDB;
GO

-- BEFORE state
SELECT 'OI_BEFORE' AS T, Id, No, Amount, PaidAmount, Status FROM OwnerInstallments WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0 ORDER BY No;
SELECT 'MCI_BEFORE' AS T, Id, InstallmentNo, Amount, PaidAmount, Balance, PaymentStatus FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;
SELECT 'OT_COUNT_BEFORE' AS T, COUNT(*) AS Cnt FROM OwnerTransactions WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0;

-- Create Expense for Owner 66, Camp 81, Amount=48 (matches 1 installment)
DECLARE @NewExpId INT;
EXEC sp_CreateExpense
    @Date='2026-07-28', @Head='Owner Payment', @Nature='Owner',
    @CampId=81, @CampName='Camps1',
    @RecipientRole='Owner', @RecipientId=66, @RecipientName='Owner1',
    @Amount=48, @FundPool='FP029', @FundPoolId=29, @FundPoolName='TestPool',
    @Mode='Cash', @Purpose='Monthly owner payment',
    @AddedBy=1, @NewId=@NewExpId OUTPUT;

SELECT 'NEW_EXPENSE_ID' AS T, @NewExpId AS Val;

-- AFTER state
SELECT 'OI_AFTER' AS T, Id, No, Amount, PaidAmount, Status FROM OwnerInstallments WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0 ORDER BY No;
SELECT 'MCI_AFTER' AS T, Id, InstallmentNo, Amount, PaidAmount, Balance, PaymentStatus FROM OwnerMonthlyContractInstallments WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0 AND InstallmentNo<=3 ORDER BY InstallmentNo;
SELECT 'OT_AFTER' AS T, TxnCode, Type, Amount, ExpenseId, InstallmentNos FROM OwnerTransactions WHERE OwnerContractId=108 AND ISNULL(IsDeleted,0)=0 ORDER BY Id DESC;
GO
