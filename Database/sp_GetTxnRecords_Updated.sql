-- =============================================
-- Updated Stored Procedure: sp_GetTxnRecords
-- Description: Added JOIN with ContractRoomsTrns table
-- New Columns: PaymentStatus, Month from ContractRoomsTrns
-- =============================================

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
    
    -- Calculate offset for pagination
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    
    -- Get total count for filtered records
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
    
    -- Get paginated results with JOIN
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
        -- NEW: From ContractRoomsTrns JOIN
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
GO

-- =============================================
-- Key Changes Made:
-- =============================================
-- 1. Added LEFT JOIN with ContractRoomsTrns table
-- 2. JOIN condition: ContractId match AND TxnDate match (date only)
-- 3. Added PaymentStatus column from ContractRoomsTrns
-- 4. Added Month column from ContractRoomsTrns
-- 5. Used LEFT JOIN so records without match still appear
-- =============================================

-- =============================================
-- Test Cases
-- =============================================

-- Test 1: Get all transactions with pagination
-- EXEC sp_GetTxnRecords @PageNumber = 1, @PageSize = 10, @TotalRecords = 0

-- Test 2: Filter by ContractId
-- EXEC sp_GetTxnRecords @ContractId = 'CNT-000002', @PageNumber = 1, @PageSize = 10, @TotalRecords = 0

-- Test 3: Filter by TxnType
-- EXEC sp_GetTxnRecords @TxnType = 'CR', @PageNumber = 1, @PageSize = 10, @TotalRecords = 0

-- Test 4: Filter by CampId
-- EXEC sp_GetTxnRecords @CampId = 1, @PageNumber = 1, @PageSize = 10, @TotalRecords = 0
