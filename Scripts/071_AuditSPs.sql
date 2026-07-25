-- ============================================================
-- 071: Update all major SPs to support audit columns
--      AddedBy on INSERT, UpdatedBy on UPDATE, 
--      DeletedBy+IsDeleted=1 on DELETE (soft delete)
--      IsDeleted=0 filter on all SELECT
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Tenants ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateTenant
    @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='', @Email NVARCHAR(MAX)='',
    @EmiratesId NVARCHAR(MAX)='', @Nationality NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active', @Type NVARCHAR(MAX)='Individual',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Tenants(Name,Contact,Email,EmiratesId,Nationality,Status,Type,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Name,@Contact,@Email,@EmiratesId,@Nationality,@Status,@Type,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateTenant
    @Id INT, @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='', @Email NVARCHAR(MAX)='',
    @EmiratesId NVARCHAR(MAX)='', @Nationality NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active', @Type NVARCHAR(MAX)='Individual',
    @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Tenants SET Name=@Name,Contact=@Contact,Email=@Email,EmiratesId=@EmiratesId,
    Nationality=@Nationality,Status=@Status,Type=@Type,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteTenant @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Tenants SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTenants
    @PageNumber INT=1, @PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @Type NVARCHAR(MAX)=NULL, @CampId INT=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Tenants t
    WHERE t.IsDeleted=0
      AND (@Status IS NULL OR t.Status=@Status)
      AND (@Type IS NULL OR t.Type=@Type)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM Contracts c JOIN ContractCamps cc ON cc.ContractId=c.ContractId WHERE c.TenantId=t.Id AND cc.CampId=@CampId));

    SELECT t.Id,t.Name,t.Contact,t.Email,t.EmiratesId,t.Nationality,t.Status,t.Type,t.CreatedAt,t.UpdatedAt,t.AddedBy,t.UpdatedBy
    FROM Tenants t
    WHERE t.IsDeleted=0
      AND (@Status IS NULL OR t.Status=@Status)
      AND (@Type IS NULL OR t.Type=@Type)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM Contracts c JOIN ContractCamps cc ON cc.ContractId=c.ContractId WHERE c.TenantId=t.Id AND cc.CampId=@CampId))
    ORDER BY CASE WHEN @SortDirection='DESC' THEN t.Name END DESC, t.Name ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Camps ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteCamp @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Rooms ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Rooms SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Partners ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeletePartner @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Partners SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Owners ────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteOwner @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Owners SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Incomes ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteIncome @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Incomes SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    -- Revert fund pool balance
    DECLARE @Amt DECIMAL(18,2), @Pool NVARCHAR(MAX);
    SELECT @Amt=Amount, @Pool=FundPool FROM Incomes WHERE Id=@Id;
    UPDATE FundPools SET Balance=Balance-@Amt, UpdatedAt=GETUTCDATE() WHERE Code=@Pool;
END
GO

-- ── Expenses ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteExpense @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    -- Revert fund pool
    DECLARE @Amt DECIMAL(18,2), @FPId INT, @OcId INT, @Role NVARCHAR(MAX);
    SELECT @Amt=Amount, @FPId=FundPoolId, @OcId=OcId, @Role=RecipientRole FROM Expenses WHERE Id=@Id;
    UPDATE Expenses SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    IF @FPId IS NOT NULL UPDATE FundPools SET Balance=Balance+@Amt, UpdatedAt=GETUTCDATE() WHERE Id=@FPId;
END
GO

-- ── Waivers ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteWaiver @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Waivers SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── AppUsers ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteUser @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE AppUsers SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── FundPools ─────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteFundPool @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE FundPools SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

PRINT '071 - Audit SPs updated (soft delete + AddedBy/UpdatedBy/DeletedBy)';
GO
