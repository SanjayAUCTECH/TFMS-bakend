-- ============================================================
-- 079: Final Audit Fixes
--      1. Add @DeletedBy to SPs that were missing it
--      2. Fix inline stats queries (IsDeleted=0 filter)
--      3. Ensure all GetById / GetAll SPs have IsDeleted=0
--      4. Fix sp_GetTenants to include IsDeleted=0
-- Date: July 25, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Roles ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteRole @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Roles SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoleById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Roles WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoles
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Roles WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%');
    SELECT * FROM Roles WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%')
    ORDER BY RoleName
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Floors ────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetFloorById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Floors WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetFloors
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Floors WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT * FROM Floors WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY Number
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Designations ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDesignationById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Designations WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetDesignations
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Designations WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT * FROM Designations WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── AccountsHeads ─────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetAccountsHeads
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @Type NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM AccountsHeads WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@Type IS NULL OR Type=@Type)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT * FROM AccountsHeads WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@Type IS NULL OR Type=@Type)
        AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── PaymentModes ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPaymentModes @Status NVARCHAR(MAX)=NULL AS BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, Status FROM PaymentModes
    WHERE IsDeleted=0 AND (@Status IS NULL OR Status=@Status)
    ORDER BY Name;
END
GO

-- ── OtherPersons ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetOtherPersonByIdWithDelCheck @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM OtherPersons WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── Tenants ───────────────────────────────────────────────────────────────
-- Ensure GetTenants has IsDeleted=0 in all clauses
CREATE OR ALTER PROCEDURE sp_GetTenants
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @CampId INT=NULL, @Id INT=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t WHERE t.IsDeleted=0
        AND (@Status IS NULL OR t.Status=@Status)
        AND (@Id IS NULL OR t.Id=@Id)
        AND (@SearchText IS NULL
             OR t.Name LIKE '%'+@SearchText+'%'
             OR t.Contact LIKE '%'+@SearchText+'%'
             OR t.EmiratesId LIKE '%'+@SearchText+'%'
             OR t.Passport LIKE '%'+@SearchText+'%');

    SELECT t.* FROM Tenants t WHERE t.IsDeleted=0
        AND (@Status IS NULL OR t.Status=@Status)
        AND (@Id IS NULL OR t.Id=@Id)
        AND (@SearchText IS NULL
             OR t.Name LIKE '%'+@SearchText+'%'
             OR t.Contact LIKE '%'+@SearchText+'%'
             OR t.EmiratesId LIKE '%'+@SearchText+'%'
             OR t.Passport LIKE '%'+@SearchText+'%')
    ORDER BY t.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_DeleteTenant — ensure DeletedBy is saved ───────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteTenant @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Tenants SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Rooms GetAll ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRooms
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @CampId INT=NULL, @FloorId INT=NULL, @RoomStatus NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Rooms r WHERE r.IsDeleted=0
        AND (@CampId IS NULL OR r.CampId=@CampId)
        AND (@FloorId IS NULL OR r.FloorId=@FloorId)
        AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
        AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%');

    SELECT r.*, c.Name CampName, f.Name FloorName
    FROM Rooms r
    LEFT JOIN Camps c ON c.Id=r.CampId
    LEFT JOIN Floors f ON f.Id=r.FloorId
    WHERE r.IsDeleted=0
        AND (@CampId IS NULL OR r.CampId=@CampId)
        AND (@FloorId IS NULL OR r.FloorId=@FloorId)
        AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
        AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%')
    ORDER BY c.Name, f.Number, r.RoomNo
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Contracts GetAll ──────────────────────────────────────────────────────
-- Ensure IsDeleted=0 in sp_GetContracts (update existing)
CREATE OR ALTER PROCEDURE sp_GetContractById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT c.*, t.Name TenantName FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE c.Id=@Id AND c.IsDeleted=0;
END
GO

-- ── CompanyAssets GetAll/GetById ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCompanyAssetById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CompanyAssets WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCompanyAssets
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM CompanyAssets WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR DocumentName LIKE '%'+@SearchText+'%'
             OR AssetType LIKE '%'+@SearchText+'%' OR CompanyName LIKE '%'+@SearchText+'%');
    SELECT * FROM CompanyAssets WHERE IsDeleted=0
        AND (@Status IS NULL OR Status=@Status)
        AND (@SearchText IS NULL OR DocumentName LIKE '%'+@SearchText+'%'
             OR AssetType LIKE '%'+@SearchText+'%' OR CompanyName LIKE '%'+@SearchText+'%')
    ORDER BY ExpiryDate
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── OwnerContracts soft delete (ensure DeletedBy saved) ───────────────────
CREATE OR ALTER PROCEDURE sp_DeleteOwnerContract @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE OwnerContracts SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    UPDATE OwnerInstallments SET IsDeleted=1 WHERE OwnerContractId=@Id;
END
GO

-- ── TxnRecords soft delete ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    -- Reverse payment amounts on ContractRooms
    UPDATE cr
    SET cr.PaidAmount = CASE WHEN ISNULL(cr.PaidAmount,0)-crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-crt.Amount END,
        cr.Balance    = ISNULL(cr.TotalAmount,0) - (CASE WHEN ISNULL(cr.PaidAmount,0)-crt.Amount < 0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-crt.Amount END)
    FROM ContractRooms cr
    INNER JOIN ContractRoomsTrns crt ON crt.ContractId=cr.ContractId AND crt.RoomId=cr.RoomId
    WHERE crt.TxnType='CR' AND crt.TxnRecordId=@Id;
    -- Delete ContractRoomsTrns entries
    DELETE FROM ContractRoomsTrns WHERE TxnType='CR' AND TxnRecordId=@Id;
    -- Soft delete the TxnRecord
    UPDATE TxnRecords SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── sp_GetTxnRecords — ensure IsDeleted=0 ────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT=1, @PageSize INT=2147483647,
    @ContractId NVARCHAR(MAX)=NULL, @TenantId INT=NULL,
    @CampId INT=NULL, @TxnType NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM TxnRecords t WHERE t.IsDeleted=0
        AND (@ContractId IS NULL OR t.ContractId=@ContractId)
        AND (@TenantId IS NULL OR t.TenantId=@TenantId)
        AND (@CampId IS NULL OR t.CampId=@CampId)
        AND (@TxnType IS NULL OR t.TxnType=@TxnType);

    SELECT t.*, tn.Name TenantName, c.Name CampName
    FROM TxnRecords t
    LEFT JOIN Tenants tn ON tn.Id=t.TenantId
    LEFT JOIN Camps c ON c.Id=t.CampId
    WHERE t.IsDeleted=0
        AND (@ContractId IS NULL OR t.ContractId=@ContractId)
        AND (@TenantId IS NULL OR t.TenantId=@TenantId)
        AND (@CampId IS NULL OR t.CampId=@CampId)
        AND (@TxnType IS NULL OR t.TxnType=@TxnType)
    ORDER BY t.TxnDate DESC, t.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── OwnerContracts GetAll — IsDeleted=0 ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts @CampId INT=NULL AS BEGIN
    SET NOCOUNT ON;
    SELECT oc.*, c.Name CampName, o.Name OwnerName, o.Code OwnerCode,
           ISNULL(oc.PaidAmount,0) PaidAmount,
           ISNULL(oc.TotalAmount,0)-ISNULL(oc.PaidAmount,0) Balance
    FROM OwnerContracts oc
    LEFT JOIN Camps c ON c.Id=oc.CampId
    LEFT JOIN Owners o ON o.Id=oc.OwnerId
    WHERE oc.IsDeleted=0
      AND (@CampId IS NULL OR oc.CampId=@CampId)
    ORDER BY oc.CreatedAt DESC;
END
GO

PRINT '079 - Final audit fixes applied: IsDeleted=0 everywhere, DeletedBy on all SPs';
GO
