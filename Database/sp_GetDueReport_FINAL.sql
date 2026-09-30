-- =============================================
-- Stored Procedure: sp_GetDueReport (FINAL VERSION)
-- Description: Get due report with ALL filters and fields
--              Includes: TenantContact, CampId, CampbossName, CampbossId filter
-- Last Updated: 2026-09-30
-- =============================================

CREATE OR ALTER PROCEDURE sp_GetDueReport
    @TenantId INT = NULL,
    @CampId INT = NULL,
    @CampbossId INT = NULL,              -- NEW PARAMETER
    @ContractId VARCHAR(50) = NULL,
    @Month VARCHAR(7) = NULL,
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL,
    @Status VARCHAR(20) = NULL,
    @SearchText VARCHAR(100) = NULL,
    @Mode VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        ci.Id,
        ci.ContractId,
        ci.InstallmentNo,
        ci.Amount,
        ci.PaidAmount,
        ci.Amount - ci.PaidAmount AS BalanceAmount,
        ci.DueDate,
        ci.Status,
        ISNULL(ci.PaymentMode, '') AS PaymentMode,
        
        -- Tenant Information
        ISNULL(t.Name, '') AS TenantName,
        ISNULL(ct.TenantId, 0) AS TenantId,
        ISNULL(t.Contact, '') AS TenantContact,     -- NEW FIELD
        
        -- Camp Information
        ISNULL((
            SELECT TOP 1 ca2.Id 
            FROM ContractCamps cc2 
            JOIN Camps ca2 ON ca2.Id = cc2.CampId 
            WHERE cc2.ContractId = ct.ContractId 
            ORDER BY cc2.Id
        ), 0) AS CampId,                             -- NEW FIELD
        ISNULL((
            SELECT TOP 1 ca2.Name 
            FROM ContractCamps cc2 
            JOIN Camps ca2 ON ca2.Id = cc2.CampId 
            WHERE cc2.ContractId = ct.ContractId 
            ORDER BY cc2.Id
        ), '') AS CampName,
        
        -- Campboss Information (NEW FIELD)
        ISNULL((
            SELECT TOP 1 cb.Name 
            FROM ContractCamps cc2
            JOIN CampCampbosses ccb ON ccb.CampId = cc2.CampId 
                AND ISNULL(ccb.IsDeleted, 0) = 0
            JOIN Campbosses cb ON cb.Id = ccb.CampbossId
            WHERE cc2.ContractId = ct.ContractId
            ORDER BY cc2.Id
        ), '') AS CampbossName,
        
        -- Room Information
        ISNULL(rm.RoomNo, '') AS RoomNo,
        
        -- Due Status
        CASE 
            WHEN ci.DueDate < GETDATE() THEN 'Overdue' 
            ELSE 'Pending' 
        END AS DueStatus
        
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t ON t.Id = ct.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId = ci.ContractId
    LEFT JOIN Rooms rm ON rm.Id = cr.RoomId
    
    WHERE ci.Status IN ('Pending', 'Partial', 'Overdue')
    
        -- Tenant Filter
        AND (@TenantId IS NULL OR ct.TenantId = @TenantId)
        
        -- Camp Filter (FIXED with EXISTS)
        AND (@CampId IS NULL OR EXISTS (
            SELECT 1 FROM ContractCamps 
            WHERE ContractId = ct.ContractId AND CampId = @CampId
        ))
        
        -- Campboss Filter (NEW)
        AND (@CampbossId IS NULL OR ct.ContractId IN (
            SELECT DISTINCT cc.ContractId 
            FROM ContractCamps cc
            WHERE cc.CampId IN (
                SELECT CampId 
                FROM CampCampbosses 
                WHERE CampbossId = @CampbossId 
                  AND ISNULL(IsDeleted, 0) = 0
            )
        ))
        
        -- Contract Filter
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        
        -- Month Filter (format: yyyy-MM)
        AND (@Month IS NULL OR FORMAT(ci.DueDate, 'yyyy-MM') = @Month)
        
        -- Date Range Filters
        AND (@DateFrom IS NULL OR ci.DueDate >= @DateFrom)
        AND (@DateTo IS NULL OR ci.DueDate <= @DateTo)
        
        -- Status Filter (Overdue or Pending)
        AND (@Status IS NULL OR 
            (@Status = 'Overdue' AND ci.DueDate < GETDATE()) OR
            (@Status = 'Pending' AND ci.DueDate >= GETDATE())
        )
        
        -- Search Filter
        AND (@SearchText IS NULL OR 
            t.Name LIKE '%' + @SearchText + '%' OR
            ci.ContractId LIKE '%' + @SearchText + '%'
        )
        
        -- Payment Mode Filter (FIXED)
        AND (@Mode IS NULL OR ci.PaymentMode = @Mode)
    
    ORDER BY ci.DueDate;
END;
GO

-- =============================================
-- Test Scripts
-- =============================================

/*
-- Test 1: Get all due reports
EXEC sp_GetDueReport;

-- Test 2: Filter by CampId
EXEC sp_GetDueReport @CampId = 1;

-- Test 3: Filter by CampbossId (NEW)
EXEC sp_GetDueReport @CampbossId = 5;

-- Test 4: Filter by Camp + Month
EXEC sp_GetDueReport @CampId = 2, @Month = '2026-09';

-- Test 5: Filter by Mode (Cash payments)
EXEC sp_GetDueReport @Mode = 'Cash';

-- Test 6: Overdue payments only
EXEC sp_GetDueReport @Status = 'Overdue';

-- Test 7: Search by tenant name
EXEC sp_GetDueReport @SearchText = 'John';

-- Test 8: Combined filters
EXEC sp_GetDueReport 
    @CampbossId = 5,
    @Month = '2026-09',
    @Status = 'Overdue';

-- Test 9: Date range
EXEC sp_GetDueReport 
    @DateFrom = '2026-09-01',
    @DateTo = '2026-09-30';

-- Test 10: Multiple filters
EXEC sp_GetDueReport 
    @CampId = 2,
    @TenantId = 10,
    @Status = 'Pending',
    @Mode = 'Cash';
*/
