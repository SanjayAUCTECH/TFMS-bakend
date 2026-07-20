DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_GetContractById'));
SET @def = REPLACE(@def, 
    'ISNULL(c.SecurityDeposit, 0)  SecurityDeposit,',
    'ISNULL(c.SecurityDeposit, 0) SecurityDeposit, ISNULL(c.SecurityDepositStatus,''Pending'') SecurityDepositStatus, ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,');
DROP PROCEDURE sp_GetContractById;
EXEC sp_executesql @def;
GO
