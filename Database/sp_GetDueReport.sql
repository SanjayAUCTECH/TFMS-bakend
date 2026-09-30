-- =============================================
-- Stored Procedure: sp_GetDueReport
-- Description: Get Due Report with all filters
-- Created: 2026-09-30
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetDueReport')
    DROP PROCEDURE sp_GetDueReport;
GO

CREATE PROCEDURE sp_GetDueReport
    @TenantId INT = NULL,
    @CampId INT = NULL,
    @CampbossId INT = NULL,
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
        ISNULL(t.Contact, '') AS TenantContact,
        
        -- Camp Information
        ISNULL((SELECT TOP 1 ca2.Id 
                FROM ContractCamps cc2
                JOIN Camps ca2 ON ca2.Id = cc2.CampId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), 0) AS CampId,
        ISNULL((SELECT TOP 1 ca2.Name 
                FROM ContractCamps cc2
                JOIN Camps ca2 ON ca2.Id = cc2.CampId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), '') AS CampName,
        
        -- Campboss Information
        ISNULL((SELECT TOP 1 cb.Name 
                FROM ContractCamps cc2
                JOIN CampCampbosses ccb ON ccb.CampId = cc2.CampId 
                    AND ISNULL(ccb.IsDeleted, 0) = 0
                JOIN Campbosses cb ON cb.Id = ccb.CampbossId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), '') AS CampbossName,
        
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
        
        -- Camp Filter
        AND (@CampId IS NULL OR EXISTS (
            SELECT 1 FROM ContractCamps 
            WHERE ContractId = ct.ContractId AND CampId = @CampId
        ))
        
        -- Campboss Filter
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
        
        -- Month Filter
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
        
        -- Payment Mode Filter
        AND (@Mode IS NULL OR ci.PaymentMode = @Mode)
    
    ORDER BY ci.DueDate;
END;
GO

-- Test the procedure
-- EXEC sp_GetDueReport @CampId = 1;
-- EXEC sp_GetDueReport @CampbossId = 5, @Status = 'Overdue';
-- EXEC sp_GetDueReport @Month = '2026-09';
