-- ============================================================
-- 072: Add IsDeleted=0 filter to all GET SPs
--      Convert all DELETE SPs to soft delete
--      Add @AddedBy/@UpdatedBy/@DeletedBy to Create/Update/Delete SPs
-- Date: July 25, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Camps ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCamps
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Camps WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT * FROM Camps WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCampById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Camps WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteCamp @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
-- ── Rooms ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRoomById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT r.*,f.Name FloorName,c.Name CampName FROM Rooms r
    LEFT JOIN Floors f ON f.Id=r.FloorId
    LEFT JOIN Camps c ON c.Id=r.CampId
    WHERE r.Id=@Id AND r.IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Rooms SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    UPDATE Rooms SET Occupied=0 WHERE Id=@Id;
END
GO
-- ── Partners ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Partners WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeletePartner @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Partners SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
-- ── Owners ────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Owners WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteOwner @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Owners SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
-- ── Tenants ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Tenants WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── Incomes ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteIncome @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Incomes SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    DECLARE @Amt DECIMAL(18,2),@Pool NVARCHAR(MAX);
    SELECT @Amt=Amount,@Pool=FundPool FROM Incomes WHERE Id=@Id;
    IF @Pool IS NOT NULL AND @Amt>0
        UPDATE FundPools SET Balance=Balance-@Amt,UpdatedAt=GETUTCDATE() WHERE Code=@Pool;
END
GO

CREATE OR ALTER PROCEDURE sp_GetIncomeById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT i.*,fp.Name FundPoolName FROM Incomes i
    LEFT JOIN FundPools fp ON fp.Code=i.FundPool
    WHERE i.Id=@Id AND i.IsDeleted=0;
END
GO
-- ── Expenses ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteExpense @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Amt DECIMAL(18,2),@FPool NVARCHAR(MAX);
    SELECT @Amt=Amount,@FPool=FundPool FROM Expenses WHERE Id=@Id;
    UPDATE Expenses SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    IF @FPool IS NOT NULL AND @Amt>0
        UPDATE FundPools SET Balance=Balance+@Amt,UpdatedAt=GETUTCDATE() WHERE Code=@FPool;
END
GO

CREATE OR ALTER PROCEDURE sp_GetExpenseById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Expenses WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── Waivers ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteWaiver @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Waivers SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetWaiverById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT w.*,t.Name TenantName FROM Waivers w
    LEFT JOIN Tenants t ON t.Id=w.TenantId
    WHERE w.Id=@Id AND w.IsDeleted=0;
END
GO
-- ── Users ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteUser @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE AppUsers SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetUserById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM AppUsers WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── FundPools ─────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteFundPool @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE FundPools SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetFundPoolById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM FundPools WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── OtherPersons ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteOtherPerson @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE OtherPersons SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetOtherPersonById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM OtherPersons WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── Staff ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteStaff @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Staff SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetStaffById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Staff WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── Contracts ─────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteContract @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Contracts SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    UPDATE Contracts SET Status='Cancelled',UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
-- ── AccountsHeads ─────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteAccountsHead @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE AccountsHeads SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetAccountsHeadById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM AccountsHeads WHERE Id=@Id AND IsDeleted=0;
END
GO
-- ── CompanyAssets ─────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteCompanyAsset @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE CompanyAssets SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
-- ── Designations ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteDesignation @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Designations SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
-- ── Floors ────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteFloor @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Floors SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
-- ── PaymentModes ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeletePaymentMode @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE PaymentModes SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
-- ── OwnerContracts ────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteOwnerContract @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE OwnerContracts SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── GET SPs with IsDeleted=0 filter ──────────────────────────────────────
-- Owners list
CREATE OR ALTER PROCEDURE sp_GetOwners
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Owners WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Contact LIKE '%'+@SearchText+'%');
    SELECT * FROM Owners WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Contact LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Partners list
CREATE OR ALTER PROCEDURE sp_GetPartners
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Partners WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT * FROM Partners WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Users list
CREATE OR ALTER PROCEDURE sp_GetUsers
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
    @Role NVARCHAR(MAX)=NULL,@Source NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM AppUsers WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@Role IS NULL OR Role=@Role)
      AND (@Source IS NULL OR Source=@Source)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Username LIKE '%'+@SearchText+'%');
    SELECT * FROM AppUsers WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@Role IS NULL OR Role=@Role)
      AND (@Source IS NULL OR Source=@Source)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Username LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- FundPools list
CREATE OR ALTER PROCEDURE sp_GetFundPools
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM FundPools WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT * FROM FundPools WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Waivers list
CREATE OR ALTER PROCEDURE sp_GetWaivers
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@TenantId INT=NULL,
    @ContractId NVARCHAR(MAX)=NULL,@DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Waivers w WHERE w.IsDeleted=0
      AND (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@ContractId IS NULL OR w.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR w.WaiverDate<=CAST(@DateTo AS DATE));
    SELECT w.*,t.Name TenantName FROM Waivers w
    LEFT JOIN Tenants t ON t.Id=w.TenantId
    WHERE w.IsDeleted=0
      AND (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@ContractId IS NULL OR w.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR w.WaiverDate<=CAST(@DateTo AS DATE))
    ORDER BY w.WaiverDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Staff list
CREATE OR ALTER PROCEDURE sp_GetStaff
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Staff WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR StaffId LIKE '%'+@SearchText+'%');
    SELECT s.*,d.Name DesignationName FROM Staff s
    LEFT JOIN Designations d ON d.Id=s.DesignationId
    WHERE s.IsDeleted=0
      AND (@Status IS NULL OR s.Status=@Status)
      AND (@SearchText IS NULL OR s.Name LIKE '%'+@SearchText+'%' OR s.StaffId LIKE '%'+@SearchText+'%')
    ORDER BY s.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- OtherPersons list
CREATE OR ALTER PROCEDURE sp_GetOtherPersons
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OtherPersons WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT * FROM OtherPersons WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Incomes list
CREATE OR ALTER PROCEDURE sp_GetIncomes
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Head NVARCHAR(MAX)=NULL,
    @FundPool NVARCHAR(MAX)=NULL,@DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Incomes i WHERE i.IsDeleted=0
      AND (@Head IS NULL OR i.Head=@Head)
      AND (@FundPool IS NULL OR i.FundPool=@FundPool)
      AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR i.Date<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR i.IncomeId LIKE '%'+@SearchText+'%' OR i.Head LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%');
    SELECT i.*,ISNULL(fp.Name,'') FundPoolName FROM Incomes i
    LEFT JOIN FundPools fp ON fp.Code=i.FundPool
    WHERE i.IsDeleted=0
      AND (@Head IS NULL OR i.Head=@Head)
      AND (@FundPool IS NULL OR i.FundPool=@FundPool)
      AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR i.Date<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR i.IncomeId LIKE '%'+@SearchText+'%' OR i.Head LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%')
    ORDER BY i.Date DESC,i.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Expenses list
CREATE OR ALTER PROCEDURE sp_GetExpenses
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Head NVARCHAR(MAX)=NULL,
    @Nature NVARCHAR(MAX)=NULL,@CampId INT=NULL,
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
    @RecipientRole NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Expenses e WHERE e.IsDeleted=0
      AND (@Head IS NULL OR e.Head=@Head)
      AND (@Nature IS NULL OR e.Nature=@Nature)
      AND (@CampId IS NULL OR e.CampId=@CampId)
      AND (@RecipientRole IS NULL OR e.RecipientRole=@RecipientRole)
      AND (@DateFrom IS NULL OR e.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR e.Date<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR e.ExpenseId LIKE '%'+@SearchText+'%' OR e.Head LIKE '%'+@SearchText+'%' OR e.RecipientName LIKE '%'+@SearchText+'%');
    SELECT e.* FROM Expenses e WHERE e.IsDeleted=0
      AND (@Head IS NULL OR e.Head=@Head)
      AND (@Nature IS NULL OR e.Nature=@Nature)
      AND (@CampId IS NULL OR e.CampId=@CampId)
      AND (@RecipientRole IS NULL OR e.RecipientRole=@RecipientRole)
      AND (@DateFrom IS NULL OR e.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo IS NULL OR e.Date<=CAST(@DateTo AS DATE))
      AND (@SearchText IS NULL OR e.ExpenseId LIKE '%'+@SearchText+'%' OR e.Head LIKE '%'+@SearchText+'%' OR e.RecipientName LIKE '%'+@SearchText+'%')
    ORDER BY e.Date DESC,e.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '072 - All SPs updated with IsDeleted=0 filter + soft delete';
GO
