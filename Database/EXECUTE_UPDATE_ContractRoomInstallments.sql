-- =============================================
-- Execute Update for sp_GetContractRoomInstallments
-- =============================================
-- Current Status: @ContractId is ALREADY optional in database
-- Main Change: Adding JOINs to return CampName and RoomNo
-- =============================================

USE TFMS_TestSoftwareDB;
GO

PRINT '========================================';
PRINT 'Updating sp_GetContractRoomInstallments';
PRINT 'Adding JOINs for CampName and RoomNo';
PRINT '========================================';
PRINT '';

-- Check if procedure exists
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetContractRoomInstallments]') AND type in (N'P', N'PC'))
BEGIN
    PRINT 'Procedure exists. Updating with JOINs...';
    PRINT '';
    
    ALTER PROCEDURE [dbo].[sp_GetContractRoomInstallments]
        @ContractId NVARCHAR(MAX) = NULL,
        @CampId INT = NULL,
        @RoomId INT = NULL,
        @Status NVARCHAR(MAX) = NULL,
        @Month NVARCHAR(MAX) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;
        
        SELECT 
            cri.Id,
            cri.ContractId,
            cri.CampId,
            ISNULL(c.CampName, '') AS CampName,
            cri.RoomId,
            ISNULL(r.RoomNo, '') AS RoomNo,
            cri.InstallmentNo,
            cri.InstallAmount,
            cri.DueDate,
            cri.Month,
            cri.PaymentMode,
            cri.ReferenceNo,
            cri.ClearanceDate,
            cri.Status,
            cri.PaidAmount,
            cri.Balance,
            cri.PaidDate,
            cri.CreatedAt,
            cri.UpdatedAt
        FROM ContractRoomInstallments cri
        LEFT JOIN Camps c ON cri.CampId = c.CampId
        LEFT JOIN Rooms r ON cri.RoomId = r.RoomId
        WHERE 
            cri.IsDeleted = 0
            AND (@ContractId IS NULL OR cri.ContractId = @ContractId)
            AND (@CampId IS NULL OR cri.CampId = @CampId)
            AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
            AND (@Status IS NULL OR cri.Status = @Status)
            AND (@Month IS NULL OR cri.Month = @Month)
        ORDER BY 
            cri.ContractId,
            cri.InstallmentNo;
    END
    
    PRINT '✓ Procedure updated successfully!';
    PRINT '';
    PRINT 'Changes made:';
    PRINT '  - Added LEFT JOIN with Camps table for CampName';
    PRINT '  - Added LEFT JOIN with Rooms table for RoomNo';
    PRINT '  - @ContractId remains optional (was already optional)';
    PRINT '';
END
ELSE
BEGIN
    PRINT '✗ Procedure does not exist!';
    PRINT 'Please create the procedure first.';
    PRINT '';
END

GO

-- =============================================
-- Verify the changes
-- =============================================
PRINT '========================================';
PRINT 'Verifying Procedure Parameters';
PRINT '========================================';
PRINT '';

SELECT 
    p.name AS ParameterName,
    TYPE_NAME(p.user_type_id) AS DataType,
    p.max_length AS MaxLength,
    p.is_nullable AS IsNullable,
    CASE 
        WHEN p.default_value IS NULL THEN 'NULL (Optional)'
        ELSE CAST(p.default_value AS NVARCHAR(50))
    END AS DefaultValue
FROM sys.parameters p
WHERE p.object_id = OBJECT_ID('sp_GetContractRoomInstallments')
ORDER BY p.parameter_id;

PRINT '';
PRINT '========================================';
PRINT 'Update Complete!';
PRINT '========================================';
PRINT '';
PRINT 'You can now call the procedure with or without @ContractId:';
PRINT '';
PRINT '-- Example 1: With ContractId';
PRINT 'EXEC sp_GetContractRoomInstallments @ContractId = ''CNT-001'';';
PRINT '';
PRINT '-- Example 2: Without ContractId, filter by CampId';
PRINT 'EXEC sp_GetContractRoomInstallments @CampId = 1;';
PRINT '';
PRINT '-- Example 3: Get all installments';
PRINT 'EXEC sp_GetContractRoomInstallments;';
PRINT '';

GO
