DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_GetContractByContractId'));
SET @def = REPLACE(@def, 
    'ISNULL(c.SecurityDeposit, 0)  SecurityDeposit,',
    'ISNULL(c.SecurityDeposit, 0) SecurityDeposit, ISNULL(c.SecurityDepositStatus,''Pending'') SecurityDepositStatus, ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,');
DROP PROCEDURE sp_GetContractByContractId;
EXEC sp_executesql @def;
GO
