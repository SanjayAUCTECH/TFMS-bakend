-- =============================================
-- QUICK FIX: Add @CampbossId to sp_GetDueReport
-- Run this in SQL Server Management Studio (SSMS)
-- =============================================

USE [TFMS_TestSoftwareDB];  -- Change if your database name is different
GO

-- Drop old procedure if exists
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetDueReport')
    DROP PROCEDURE sp_GetDueReport;
GO

-- Create procedure with ALL parameters including @CampbossId
CREATE PROCEDURE sp_GetDueReport
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TenantId INT = NULL,
    @CampId INT = NULL,
    @CampbossId INT = NULL,              -- ✅ NEW PARAMETER
    @ContractId VARCHAR(50) = NULL,
    @Month VARCHAR(7) = NULL,
    @DateFrom DATE = NULL,
    @DateTo DATE = NULL,
    @Status VARCHAR(20) = NULL,
    @SearchText VARCHAR(100) = NULL,
    @Mode VARCHAR(50) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Count total records
    SELECT @TotalRecords = COUNT(*)
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t ON t.Id = ct.TenantId
    WHERE ci.Status IN ('Pending', 'Partial', 'Overdue')
        AND (@TenantId IS NULL OR ct.TenantId = @TenantId)
        AND (@CampId IS NULL OR EXISTS (
            SELECT 1 FROM ContractCamps 
            WHERE ContractId = ct.ContractId AND CampId = @CampId
        ))
        AND (@CampbossId IS NULL OR ct.ContractId IN (
            SELECT DISTINCT cc.ContractId 
            FROM ContractCamps cc
            WHERE cc.CampId IN (
                SELECT CampId FROM CampCampbosses 
                WHERE CampbossId = @CampbossId 
                  AND ISNULL(IsDeleted, 0) = 0
            )
        ))
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        AND (@Month IS NULL OR FORMAT(ci.DueDate, 'yyyy-MM') = @Month)
        AND (@DateFrom IS NULL OR ci.DueDate >= @DateFrom)
        AND (@DateTo IS NULL OR ci.DueDate <= @DateTo)
        AND (@Status IS NULL OR 
            (@Status = 'Overdue' AND ci.DueDate < GETDATE()) OR
            (@Status = 'Pending' AND ci.DueDate >= GETDATE())
        )
        AND (@SearchText IS NULL OR 
            t.Name LIKE '%' + @SearchText + '%' OR
            ci.ContractId LIKE '%' + @SearchText + '%'
        )
        AND (@Mode IS NULL OR ci.PaymentMode = @Mode);
    
    -- Get paginated data
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
        ISNULL(t.Name, '') AS TenantName,
        ISNULL(ct.TenantId, 0) AS TenantId,
        ISNULL(t.Contact, '') AS TenantContact,
        ISNULL((SELECT TOP 1 ca2.Id FROM ContractCamps cc2
                JOIN Camps ca2 ON ca2.Id = cc2.CampId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), 0) AS CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2
                JOIN Camps ca2 ON ca2.Id = cc2.CampId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), '') AS CampName,
        ISNULL((SELECT TOP 1 cb.Name FROM ContractCamps cc2
                JOIN CampCampbosses ccb ON ccb.CampId = cc2.CampId
                    AND ISNULL(ccb.IsDeleted, 0) = 0
                JOIN Campbosses cb ON cb.Id = ccb.CampbossId
                WHERE cc2.ContractId = ct.ContractId
                ORDER BY cc2.Id), '') AS CampbossName,
        ISNULL(rm.RoomNo, '') AS RoomNo,
        CASE WHEN ci.DueDate < GETDATE() THEN 'Overdue' ELSE 'Pending' END AS DueStatus
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId = ci.ContractId
    LEFT JOIN Tenants t ON t.Id = ct.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId = ci.ContractId
    LEFT JOIN Rooms rm ON rm.Id = cr.RoomId
    WHERE ci.Status IN ('Pending', 'Partial', 'Overdue')
        AND (@TenantId IS NULL OR ct.TenantId = @TenantId)
        AND (@CampId IS NULL OR EXISTS (
            SELECT 1 FROM ContractCamps 
            WHERE ContractId = ct.ContractId AND CampId = @CampId
        ))
        AND (@CampbossId IS NULL OR ct.ContractId IN (
            SELECT DISTINCT cc.ContractId 
            FROM ContractCamps cc
            WHERE cc.CampId IN (
                SELECT CampId FROM CampCampbosses 
                WHERE CampbossId = @CampbossId 
                  AND ISNULL(IsDeleted, 0) = 0
            )
        ))
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        AND (@Month IS NULL OR FORMAT(ci.DueDate, 'yyyy-MM') = @Month)
        AND (@DateFrom IS NULL OR ci.DueDate >= @DateFrom)
        AND (@DateTo IS NULL OR ci.DueDate <= @DateTo)
        AND (@Status IS NULL OR 
            (@Status = 'Overdue' AND ci.DueDate < GETDATE()) OR
            (@Status = 'Pending' AND ci.DueDate >= GETDATE())
        )
        AND (@SearchText IS NULL OR 
            t.Name LIKE '%' + @SearchText + '%' OR
            ci.ContractId LIKE '%' + @SearchText + '%'
        )
        AND (@Mode IS NULL OR ci.PaymentMode = @Mode)
    ORDER BY ci.DueDate
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

PRINT '✅ Stored Procedure sp_GetDueReport created successfully with @CampbossId parameter!';
GO

-- Test it
PRINT 'Testing procedure...';
DECLARE @Total INT;
EXEC sp_GetDueReport 
    @PageNumber = 1,
    @PageSize = 10,
    @TotalRecords = @Total OUTPUT;
SELECT @Total AS TotalRecords;
GO

PRINT '✅ Test complete! Now restart your application.';
