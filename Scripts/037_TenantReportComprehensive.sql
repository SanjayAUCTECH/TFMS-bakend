-- ============================================================
-- 037: Tenant Report — Comprehensive (Security Deposit + Multiple Camps + TxnRecords)
-- Date: July 20, 2026
-- Author: Kiro
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── sp_GetTenantReport ───────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Count distinct tenants
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%');
    
    -- Main query with comprehensive columns
    SELECT 
        -- Tenant Basic Info (Tenants table)
        t.Id TenantId, t.Name TenantName, t.Contact, t.Email, t.EmiratesId, t.Nationality,
        t.Status, ISNULL(t.Type,'Individual') [Type],
        
        -- Contract Info (Contracts table)
        ISNULL(c.ContractId,'') ContractId,
        c.StartDate ContractStart, c.EndDate ContractEnd,
        ISNULL(c.Status,'') ContractStatus,
        
        -- Security Deposit Info (Contracts table)
        ISNULL(c.SecurityDeposit,0) SecurityDeposit,
        ISNULL(c.SecurityDepositStatus,'Pending') SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,
        
        -- Camp Info (ContractCamps + Camps) — multiple camps support
        ISNULL((SELECT STRING_AGG(ca2.Name, ', ') 
                FROM ContractCamps cc2 
                JOIN Camps ca2 ON ca2.Id=cc2.CampId 
                WHERE cc2.ContractId=c.ContractId),'') CampName,
        
        ISNULL((SELECT COUNT(DISTINCT cc3.CampId) 
                FROM ContractCamps cc3 
                WHERE cc3.ContractId=c.ContractId),0) CampsCount,
        
        -- Room Info (ContractRooms + Rooms)
        ISNULL((SELECT STRING_AGG(r2.RoomNo, ', ') 
                FROM ContractRooms cr2 
                JOIN Rooms r2 ON r2.Id=cr2.RoomId 
                WHERE cr2.ContractId=c.ContractId),'') RoomNo,
        
        ISNULL((SELECT COUNT(*) 
                FROM ContractRooms cr3 
                WHERE cr3.ContractId=c.ContractId),0) RoomsBooked,
        
        -- Rent Amounts (Contracts table)
        ISNULL(c.MonthlyTotal,0) MonthlyRent,
        ISNULL(c.ContractTotal,0) ContractRentTotal,
        
        -- TOTAL AMOUNT = Rent + Security Deposit (for full payment due)
        ISNULL(c.ContractTotal,0) + ISNULL(c.SecurityDeposit,0) TotalAmount,
        
        -- Payment Info from TxnRecords (NOT ContractInstallments)
        -- Rent Payments (TxnType='CR')
        ISNULL((SELECT SUM(tr.Amount) 
                FROM TxnRecords tr 
                WHERE tr.ContractId=c.ContractId 
                  AND tr.TxnType='CR'),0) RentPaid,
        
        -- Security Deposit Payments (TxnType='SD-CR')  
        ISNULL((SELECT SUM(tr.Amount) 
                FROM TxnRecords tr 
                WHERE tr.ContractId=c.ContractId 
                  AND tr.TxnType='SD-CR'),0) SecurityDepositPaidAmount,
        
        -- Total Paid = RentPaid + SecurityDepositPaidAmount
        ISNULL((SELECT SUM(tr.Amount) 
                FROM TxnRecords tr 
                WHERE tr.ContractId=c.ContractId 
                  AND tr.TxnType IN ('CR','SD-CR')),0) TotalPaid,
        
        -- Total Due = (RentTotal + SecurityDeposit) - TotalPaid
        (ISNULL(c.ContractTotal,0) + ISNULL(c.SecurityDeposit,0)) - 
        ISNULL((SELECT SUM(tr.Amount) 
                FROM TxnRecords tr 
                WHERE tr.ContractId=c.ContractId 
                  AND tr.TxnType IN ('CR','SD-CR')),0) TotalDue,
        
        -- Balance (same as TotalDue for simplicity)
        (ISNULL(c.ContractTotal,0) + ISNULL(c.SecurityDeposit,0)) - 
        ISNULL((SELECT SUM(tr.Amount) 
                FROM TxnRecords tr 
                WHERE tr.ContractId=c.ContractId 
                  AND tr.TxnType IN ('CR','SD-CR')),0) Balance,
        
        -- Waiver Info (Waivers table)
        ISNULL((SELECT SUM(w.WaiverAmount) 
                FROM Waivers w 
                WHERE w.ContractId=c.ContractId),0) WaiverAmount
        
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
    ORDER BY t.Name, c.ContractId
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetTenantReportSummary (for cards/pie charts) ──────────
CREATE OR ALTER PROCEDURE sp_GetTenantReportSummary
    @Status NVARCHAR(MAX)=NULL, @CampId INT=NULL, @SearchText NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use CTE to calculate financials first
    WITH TenantFinancials AS (
        SELECT 
            t.Id TenantId,
            t.Status TenantStatus,
            t.Type TenantType,
            ISNULL(c.ContractTotal,0) ContractTotal,
            ISNULL(c.SecurityDeposit,0) SecurityDeposit,
            ISNULL((SELECT SUM(tr.Amount) 
                    FROM TxnRecords tr 
                    WHERE tr.ContractId=c.ContractId 
                      AND tr.TxnType='CR'),0) RentPaid,
            ISNULL((SELECT SUM(tr.Amount) 
                    FROM TxnRecords tr 
                    WHERE tr.ContractId=c.ContractId 
                      AND tr.TxnType='SD-CR'),0) SecurityDepositPaid,
            ISNULL((SELECT SUM(tr.Amount) 
                    FROM TxnRecords tr 
                    WHERE tr.ContractId=c.ContractId 
                      AND tr.TxnType IN ('CR','SD-CR')),0) TotalPaid
        FROM Tenants t
        LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
        LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
        WHERE (@Status IS NULL OR t.Status=@Status)
          AND (@CampId IS NULL OR cc.CampId=@CampId)
          AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
    )
    SELECT 
        -- Summary cards
        COUNT(DISTINCT TenantId) TotalTenants,
        COUNT(DISTINCT CASE WHEN TenantStatus='Active' THEN TenantId END) ActiveTenants,
        COUNT(DISTINCT CASE WHEN TenantStatus='Inactive' THEN TenantId END) InactiveTenants,
        COUNT(DISTINCT CASE WHEN TenantType='Company' THEN TenantId END) Companies,
        COUNT(DISTINCT CASE WHEN TenantType='Individual' OR TenantType IS NULL THEN TenantId END) Individuals,
        
        -- Financial summary
        SUM(ContractTotal) TotalRentAmount,
        SUM(SecurityDeposit) TotalSecurityDeposit,
        SUM(ContractTotal + SecurityDeposit) TotalAmountDue,
        SUM(RentPaid) TotalRentPaid,
        SUM(SecurityDepositPaid) TotalSecurityDepositPaid,
        SUM(TotalPaid) TotalPaidAmount,
        SUM((ContractTotal + SecurityDeposit) - TotalPaid) TotalDueAmount
        
    FROM TenantFinancials;
END
GO

PRINT '037 — Tenant Report comprehensive update applied!';
GO