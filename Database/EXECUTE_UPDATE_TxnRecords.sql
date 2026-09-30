-- =============================================
-- Execute Update for sp_GetTxnRecords
-- =============================================
-- This will update the stored procedure to add ContractRoomsTrns JOIN

USE TFMS_TestSoftwareDB;
GO

PRINT '========================================';
PRINT 'Updating sp_GetTxnRecords';
PRINT 'Adding ContractRoomsTrns JOIN';
PRINT '========================================';
PRINT '';

-- Check if procedure exists
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTxnRecords]') AND type in (N'P', N'PC'))
BEGIN
    PRINT 'Procedure exists. Updating...';
    PRINT '';
    
    ALTER PROCEDURE [dbo].[sp_GetTxnRecords]
        @PageNumber INT = 1,
        @PageSize INT = 500,
        @ContractId NVARCHAR(MAX) = NULL,
        @TenantId INT = NULL,
        @CampId INT = NULL,
        @TxnType NVARCHAR(MAX) = NULL,
        @Month NVARCHAR(MAX) = NULL,
        @TotalRecords INT OUTPUT
    AS
    BEGIN
        SET NOCOUNT ON;
        
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        
        SELECT @TotalRecords = COUNT(*)
        FROM TxnRecords tr
        LEFT JOIN Tenants t ON tr.TenantId = t.TenantId
        LEFT JOIN Camps c ON tr.CampId = c.CampId
        LEFT JOIN ContractRoomsTrns crt ON tr.ContractId = crt.ContractId 
            AND CAST(tr.TxnDate AS DATE) = CAST(crt.TxnDate AS DATE)
        WHERE tr.IsDeleted = 0
            AND (@ContractId IS NULL OR tr.ContractId = @ContractId)
            AND (@TenantId IS NULL OR tr.TenantId = @TenantId)
            AND (@CampId IS NULL OR tr.CampId = @CampId)
            AND (@TxnType IS NULL OR tr.TxnType = @TxnType)
            AND (@Month IS NULL OR tr.Month = @Month);
        
        SELECT 
            tr.Id,
            tr.TxnId,
            tr.TxnType,
            tr.ContractId,
            tr.ContractCode,
            tr.TenantId,
            ISNULL(t.TenantName, '') AS TenantName,
            tr.CampId,
            ISNULL(c.CampName, '') AS CampName,
            tr.TotalAmount,
            tr.Amount,
            tr.TxnDate,
            tr.FromDate,
            tr.ToDate,
            tr.PaymentMode,
            tr.PaymentModeId,
            tr.ChequeNumber,
            tr.FundPoolId,
            tr.FundPoolName,
            tr.Description,
            tr.ReceivedBy,
            tr.ReceivedContact,
            tr.IssuedBy,
            tr.InstallmentNo,
            tr.AppliedInstallments,
            tr.Unallocated,
            tr.CreatedAt,
            tr.UpdatedAt,
            crt.PaymentStatus,
            crt.Month
        FROM TxnRecords tr
        LEFT JOIN Tenants t ON tr.TenantId = t.TenantId
        LEFT JOIN Camps c ON tr.CampId = c.CampId
        LEFT JOIN ContractRoomsTrns crt ON tr.ContractId = crt.ContractId 
            AND CAST(tr.TxnDate AS DATE) = CAST(crt.TxnDate AS DATE)
        WHERE tr.IsDeleted = 0
            AND (@ContractId IS NULL OR tr.ContractId = @ContractId)
            AND (@TenantId IS NULL OR tr.TenantId = @TenantId)
            AND (@CampId IS NULL OR tr.CampId = @CampId)
            AND (@TxnType IS NULL OR tr.TxnType = @TxnType)
            AND (@Month IS NULL OR tr.Month = @Month)
        ORDER BY tr.TxnDate DESC, tr.Id DESC
        OFFSET @Offset ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END
    
    PRINT '✓ Procedure updated successfully!';
    PRINT '';
    PRINT 'Changes applied:';
    PRINT '  - Added LEFT JOIN with ContractRoomsTrns table';
    PRINT '  - JOIN on ContractId AND TxnDate (date match)';
    PRINT '  - Added PaymentStatus column';
    PRINT '  - Added Month column';
    PRINT '';
END
ELSE
BEGIN
    PRINT '✗ Procedure does not exist!';
    PRINT 'Please create the procedure first.';
    PRINT '';
END

GO

PRINT '========================================';
PRINT 'Update Complete!';
PRINT '========================================';
PRINT '';
PRINT 'New columns available in API response:';
PRINT '  - paymentStatus (from ContractRoomsTrns)';
PRINT '  - month (from ContractRoomsTrns)';
PRINT '';

GO
