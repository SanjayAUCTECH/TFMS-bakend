-- ============================================================
-- 076: Fix remaining SPs - IsDeleted filter + @DeletedBy
-- Only main data tables (not system/report SPs)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Roles & RoomStatuses (system tables - soft delete) ──────
CREATE OR ALTER PROCEDURE sp_DeleteRole @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Roles SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoles AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Roles WHERE IsDeleted=0 ORDER BY Name;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoleById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Roles WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteRoomStatus @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE RoomStatuses SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomStatuses AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM RoomStatuses WHERE IsDeleted=0 ORDER BY Name;
END
GO

-- ── TxnRecords soft delete ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT=1,@PageSize INT=2147483647,
    @ContractId NVARCHAR(MAX)=NULL,@TenantId INT=NULL,
    @CampId INT=NULL,@TxnType NVARCHAR(MAX)=NULL,
    @DateFrom DATE=NULL,@DateTo DATE=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM TxnRecords t WHERE t.IsDeleted=0
      AND (@ContractId IS NULL OR t.ContractId=@ContractId)
      AND (@TenantId IS NULL OR t.TenantId=@TenantId)
      AND (@CampId IS NULL OR t.CampId=@CampId)
      AND (@TxnType IS NULL OR t.TxnType=@TxnType)
      AND (@DateFrom IS NULL OR t.PaidDate>=@DateFrom)
      AND (@DateTo IS NULL OR t.PaidDate<=@DateTo);
    SELECT t.*,ten.Name TenantName,c.Name CampName
    FROM TxnRecords t
    LEFT JOIN Tenants ten ON ten.Id=t.TenantId
    LEFT JOIN Camps c ON c.Id=t.CampId
    WHERE t.IsDeleted=0
      AND (@ContractId IS NULL OR t.ContractId=@ContractId)
      AND (@TenantId IS NULL OR t.TenantId=@TenantId)
      AND (@CampId IS NULL OR t.CampId=@CampId)
      AND (@TxnType IS NULL OR t.TxnType=@TxnType)
      AND (@DateFrom IS NULL OR t.PaidDate>=@DateFrom)
      AND (@DateTo IS NULL OR t.PaidDate<=@DateTo)
    ORDER BY t.PaidDate DESC,t.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Payments GET ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPayments
    @PageNumber INT=1,@PageSize INT=2147483647,
    @ContractId NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM ContractInstallments ci WHERE ci.IsDeleted=0
      AND (@ContractId IS NULL OR ci.ContractId=@ContractId)
      AND (@Status IS NULL OR ci.Status=@Status);
    SELECT ci.* FROM ContractInstallments ci WHERE ci.IsDeleted=0
      AND (@ContractId IS NULL OR ci.ContractId=@ContractId)
      AND (@Status IS NULL OR ci.Status=@Status)
    ORDER BY ci.InstallmentNo
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Contracts main queries ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetContractById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT c.*,t.Name TenantName FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE c.Id=@Id AND c.IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetContractByContractId @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT c.*,t.Name TenantName FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0;
END
GO

-- ── UpdateContract ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateContractStatus
    @ContractId NVARCHAR(MAX),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Contracts SET Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE ContractId=@ContractId AND IsDeleted=0;
END
GO

-- ── Staff GET ────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetStaffById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Staff WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── Designations CRUD ────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDesignationById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Designations WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateDesignation
    @Name NVARCHAR(MAX),@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Designations(Name,AddedBy,IsDeleted)
    VALUES(@Name,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateDesignation
    @Id INT,@Name NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Designations SET Name=@Name,UpdatedBy=@UpdatedBy WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteDesignation @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Designations SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

-- ── AccountsHeads ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateAccountsHead
    @Name NVARCHAR(MAX),@Type NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO AccountsHeads(Name,Type,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Name,@Type,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateAccountsHead
    @Id INT,@Name NVARCHAR(MAX),@Type NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE AccountsHeads SET Name=@Name,Type=@Type,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── Floors ───────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateFloor
    @Name NVARCHAR(MAX),@Number INT=0,@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Floors(Name,Number,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Name,@Number,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateFloor
    @Id INT,@Name NVARCHAR(MAX),@Number INT=0,@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Floors SET Name=@Name,Number=@Number,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── PaymentModes ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreatePaymentMode
    @Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO PaymentModes(Name,Status,AddedBy,IsDeleted)
    VALUES(@Name,@Status,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdatePaymentMode
    @Id INT,@Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE PaymentModes SET Name=@Name,Status=@Status,UpdatedBy=@UpdatedBy WHERE Id=@Id AND IsDeleted=0;
END
GO

PRINT '076 - Remaining SPs fixed with IsDeleted + audit';
GO
