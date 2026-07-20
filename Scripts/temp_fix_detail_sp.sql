-- Fix sp_GetContractByContractId to include SecurityDepositStatus and SecurityDepositPaid
DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_GetContractByContractId'));

-- Add columns after SecurityDeposit
SET @def = REPLACE(@def, 
    'ISNULL(c.SecurityDeposit,0) SecurityDeposit,',
    'ISNULL(c.SecurityDeposit,0) SecurityDeposit, ISNULL(c.SecurityDepositStatus,''Pending'') SecurityDepositStatus, ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,');

-- Drop and recreate
DROP PROCEDURE sp_GetContractByContractId;
EXEC sp_executesql @def;
GO
