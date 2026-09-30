-- =============================================
-- CURRENT PROCEDURE FROM DATABASE:
-- sp_GetContractRoomInstallments
-- @ContractId is already OPTIONAL (default NULL)
-- =============================================
-- Problem: Using cri.* doesn't return CampName, RoomNo needed by C# controller
-- Solution: Add JOINs with Camps and Rooms tables for complete data
-- =============================================

ALTER PROCEDURE [dbo].[sp_GetContractRoomInstallments]
    @ContractId NVARCHAR(MAX) = NULL,  -- Already optional in current DB
    @CampId INT = NULL,
    @RoomId INT = NULL,
    @Status NVARCHAR(MAX) = NULL,
    @Month NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Updated to include Camp and Room details via JOINs
    SELECT 
        cri.Id,
        cri.ContractId,
        cri.CampId,
        ISNULL(c.CampName, '') AS CampName,  -- Added from Camps table
        cri.RoomId,
        ISNULL(r.RoomNo, '') AS RoomNo,      -- Added from Rooms table
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
    LEFT JOIN Camps c ON cri.CampId = c.CampId  -- LEFT JOIN to handle missing camps
    LEFT JOIN Rooms r ON cri.RoomId = r.RoomId  -- LEFT JOIN to handle missing rooms
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
GO

-- =============================================
-- Test Cases for Updated Procedure
-- =============================================

-- Test 1: With ContractId (Original behavior - still works)
EXEC sp_GetContractRoomInstallments @ContractId = 'CNT-001'

-- Test 2: Without ContractId, with CampId filter
EXEC sp_GetContractRoomInstallments @CampId = 1

-- Test 3: Without ContractId, with Status filter
EXEC sp_GetContractRoomInstallments @Status = 'Pending'

-- Test 4: With RoomId filter only
EXEC sp_GetContractRoomInstallments @RoomId = 5

-- Test 5: With Month filter
EXEC sp_GetContractRoomInstallments @Month = '2026-09'

-- Test 6: Multiple filters without ContractId
EXEC sp_GetContractRoomInstallments 
    @CampId = 1, 
    @Status = 'Paid', 
    @Month = '2026-09'

-- Test 7: All records (no filters at all)
EXEC sp_GetContractRoomInstallments

-- =============================================
-- Summary of Changes Made:
-- =============================================
-- ✓ @ContractId was ALREADY optional in database (= NULL)
-- ✓ Added JOINs with Camps and Rooms tables
-- ✓ Now returns CampName and RoomNo (required by C# controller)
-- ✓ Used LEFT JOIN to handle potential missing camp/room references
-- ✓ Added IsDeleted=0 filter (already in original)
-- ✓ All existing parameters remain optional
-- ✓ Backward compatible - all existing API calls will work
-- =============================================
