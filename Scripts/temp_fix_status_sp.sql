DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_UpdateContractStatus'));
SET @def = REPLACE(@def, 
    'IF @Status IN(''Expired'',''Terminated'')',
    'IF @Status IN(''Expired'',''Terminated'',''Completed'',''Cancelled'')');
DROP PROCEDURE sp_UpdateContractStatus;
EXEC sp_executesql @def;
GO
