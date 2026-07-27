-- ============================================================
-- 074: Fix ALL remaining SPs - IsDeleted filter + Audit columns
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ═══════════════════════════════════════════════════════════════
-- GET SPs - Add IsDeleted=0 filter where missing
-- ═══════════════════════════════════════════════════════════════

-- Camps GET
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
    ORDER BY Name OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCampById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Camps WHERE Id=@Id AND IsDeleted=0;
END
GO

-- Rooms GET
CREATE OR ALTER PROCEDURE sp_GetRooms
    @PageNumber INT=1,@PageSize INT=2147483647,
    @CampId INT=NULL,@FloorId INT=NULL,@Status NVARCHAR(MAX)=NULL,
    @SearchText NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Rooms r WHERE r.IsDeleted=0
      AND (@CampId IS NULL OR r.CampId=@CampId)
      AND (@FloorId IS NULL OR r.FloorId=@FloorId)
      AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%');
    SELECT r.*,f.Name FloorName,c.Name CampName FROM Rooms r
    LEFT JOIN Floors f ON f.Id=r.FloorId
    LEFT JOIN Camps c ON c.Id=r.CampId
    WHERE r.IsDeleted=0
      AND (@CampId IS NULL OR r.CampId=@CampId)
      AND (@FloorId IS NULL OR r.FloorId=@FloorId)
      AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%')
    ORDER BY r.RoomNo OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT r.*,f.Name FloorName,c.Name CampName FROM Rooms r
    LEFT JOIN Floors f ON f.Id=r.FloorId
    LEFT JOIN Camps c ON c.Id=r.CampId
    WHERE r.Id=@Id AND r.IsDeleted=0;
END
GO

-- Tenants GET
CREATE OR ALTER PROCEDURE sp_GetTenantById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Tenants WHERE Id=@Id AND IsDeleted=0;
END
GO

-- Contracts GET
CREATE OR ALTER PROCEDURE sp_GetContracts
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
    @TenantId INT=NULL,@CampId INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Contracts c WHERE c.IsDeleted=0
      AND (@Status IS NULL OR c.Status=@Status)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId));
    SELECT c.*,t.Name TenantName FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE c.IsDeleted=0
      AND (@Status IS NULL OR c.Status=@Status)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId))
    ORDER BY c.CreatedAt DESC OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- Partners GET
CREATE OR ALTER PROCEDURE sp_GetPartnerById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Partners WHERE Id=@Id AND IsDeleted=0;
END
GO

-- Owners GET
CREATE OR ALTER PROCEDURE sp_GetOwnerById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Owners WHERE Id=@Id AND IsDeleted=0;
END
GO

-- Floors GET
CREATE OR ALTER PROCEDURE sp_GetFloors
    @PageNumber INT=1,@PageSize INT=2147483647,
    @CampId INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Floors WHERE IsDeleted=0
      AND (@CampId IS NULL OR CampId=@CampId);
    SELECT f.*,c.Name CampName FROM Floors f
    LEFT JOIN Camps c ON c.Id=f.CampId
    WHERE f.IsDeleted=0 AND (@CampId IS NULL OR f.CampId=@CampId)
    ORDER BY f.Id OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetFloorById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT f.*,c.Name CampName FROM Floors f
    LEFT JOIN Camps c ON c.Id=f.CampId
    WHERE f.Id=@Id AND f.IsDeleted=0;
END
GO

-- Designations GET
CREATE OR ALTER PROCEDURE sp_GetDesignations
    @PageNumber INT=1,@PageSize INT=2147483647,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Designations WHERE IsDeleted=0;
    SELECT * FROM Designations WHERE IsDeleted=0
    ORDER BY Name OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetDesignationById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Designations WHERE Id=@Id AND IsDeleted=0;
END
GO

-- AccountsHeads GET
CREATE OR ALTER PROCEDURE sp_GetAccountsHeads
    @PageNumber INT=1,@PageSize INT=2147483647,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM AccountsHeads WHERE IsDeleted=0;
    SELECT * FROM AccountsHeads WHERE IsDeleted=0
    ORDER BY Name OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- PaymentModes GET
CREATE OR ALTER PROCEDURE sp_GetPaymentModes
    @Status NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM PaymentModes WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
    ORDER BY Name;
END
GO

-- CompanyAssets GET
CREATE OR ALTER PROCEDURE sp_GetCompanyAssets
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM CompanyAssets WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT * FROM CompanyAssets WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY Name OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ═══════════════════════════════════════════════════════════════
-- DELETE SPs - Fix remaining (soft delete)
-- ═══════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Rooms SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteStaff @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE Staff SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteUser @Id INT,@DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE AppUsers SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ═══════════════════════════════════════════════════════════════
-- CREATE SPs - Add @AddedBy, IsDeleted=0 where missing
-- ═══════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE sp_CreateRoom
    @RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT=NULL,
    @MonthlyPrice DECIMAL(18,2)=0,@Status NVARCHAR(MAX)='Vacant',
    @OtherDetails NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Rooms(RoomNo,CampId,FloorId,MonthlyPrice,Status,Occupied,OtherDetails,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@RoomNo,@CampId,@FloorId,@MonthlyPrice,@Status,0,@OtherDetails,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_CreateStaff
    @StaffId NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Role NVARCHAR(MAX)='',
    @Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',
    @Designation NVARCHAR(MAX)='',@EmiratesId NVARCHAR(MAX)='',@PassportNo NVARCHAR(MAX)='',
    @Nationality NVARCHAR(MAX)='',@JobTitle NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @MoveInDate DATE=NULL,@VisaExpiry DATE=NULL,@EmiratesIdIssueDate DATE=NULL,@EmiratesIdExpiryDate DATE=NULL,
    @PassportIssueDate DATE=NULL,@PassportExpiryDate DATE=NULL,@LabourCardIssueDate DATE=NULL,@LabourCardExpiryDate DATE=NULL,
    @IloeIssueDate DATE=NULL,@IloeExpiryDate DATE=NULL,@InsuranceIssueDate DATE=NULL,@InsuranceExpiryDate DATE=NULL,
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Staff(StaffId,Name,Role,Contact,Email,Status,Designation,EmiratesId,PassportNo,Nationality,JobTitle,Remarks,
        MoveInDate,VisaExpiry,EmiratesIdIssueDate,EmiratesIdExpiryDate,PassportIssueDate,PassportExpiryDate,
        LabourCardIssueDate,LabourCardExpiryDate,IloeIssueDate,IloeExpiryDate,InsuranceIssueDate,InsuranceExpiryDate,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@StaffId,@Name,@Role,@Contact,@Email,@Status,@Designation,@EmiratesId,@PassportNo,@Nationality,@JobTitle,@Remarks,
        @MoveInDate,@VisaExpiry,@EmiratesIdIssueDate,@EmiratesIdExpiryDate,@PassportIssueDate,@PassportExpiryDate,
        @LabourCardIssueDate,@LabourCardExpiryDate,@IloeIssueDate,@IloeExpiryDate,@InsuranceIssueDate,@InsuranceExpiryDate,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_CreateOtherPerson
    @Code NVARCHAR(MAX),@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Role NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO OtherPersons(Code,Name,Contact,Email,Role,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Contact,@Email,@Role,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date DATE,@Head NVARCHAR(MAX),@Nature NVARCHAR(MAX)='Camp',
    @CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @RecipientRole NVARCHAR(MAX)='',@RecipientId INT=NULL,@RecipientName NVARCHAR(MAX)='',
    @Amount DECIMAL(18,2),@FundPool NVARCHAR(MAX)='',@FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Mode NVARCHAR(MAX)='',@Purpose NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @ExpenseId NVARCHAR(MAX)='EXP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR),6);
    INSERT INTO Expenses(ExpenseId,Date,Head,Nature,CampId,CampName,RecipientRole,RecipientId,RecipientName,
        Amount,FundPool,FundPoolName,Mode,Purpose,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@ExpenseId,@Date,@Head,@Nature,@CampId,@CampName,@RecipientRole,@RecipientId,@RecipientName,
        @Amount,@FundPool,@FundPoolName,@Mode,@Purpose,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    IF @FundPool IS NOT NULL AND @Amount>0
        UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateFundPool
    @Code NVARCHAR(MAX),@Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',
    @Balance DECIMAL(18,2)=0,@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO FundPools(Code,Name,Status,Balance,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Status,@Balance,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ═══════════════════════════════════════════════════════════════
-- UPDATE SPs - Add @UpdatedBy, IsDeleted=0 where missing
-- ═══════════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id INT,@Code NVARCHAR(MAX),@Name NVARCHAR(MAX),@Rooms INT=0,@Floors INT=0,@Status NVARCHAR(MAX)='Active',
    @CampPropertyUsage NVARCHAR(MAX)='',@CampBuildingName NVARCHAR(MAX)='',@CampPropertyType NVARCHAR(MAX)='',
    @CampLocation NVARCHAR(MAX)='',@CampPropertyNo NVARCHAR(MAX)='',@CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='',@CampPlotNo NVARCHAR(MAX)='',@CampMakaniNo NVARCHAR(MAX)='',
    @StartDate DATE=NULL,@EndDate DATE=NULL,@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET Code=@Code,Name=@Name,Rooms=@Rooms,Floors=@Floors,Status=@Status,
        CampPropertyUsage=@CampPropertyUsage,CampBuildingName=@CampBuildingName,CampPropertyType=@CampPropertyType,
        CampLocation=@CampLocation,CampPropertyNo=@CampPropertyNo,CampPropertyArea=@CampPropertyArea,
        CampPremisesNo=@CampPremisesNo,CampPlotNo=@CampPlotNo,CampMakaniNo=@CampMakaniNo,
        StartDate=@StartDate,EndDate=@EndDate,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateRoom
    @Id INT,@RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT=NULL,
    @MonthlyPrice DECIMAL(18,2)=0,@Status NVARCHAR(MAX)='Vacant',
    @OtherDetails NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Rooms SET RoomNo=@RoomNo,CampId=@CampId,FloorId=@FloorId,MonthlyPrice=@MonthlyPrice,
        Status=@Status,OtherDetails=@OtherDetails,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateStaff
    @Id INT,@StaffId NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Role NVARCHAR(MAX)='',
    @Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',
    @Designation NVARCHAR(MAX)='',@EmiratesId NVARCHAR(MAX)='',@PassportNo NVARCHAR(MAX)='',
    @Nationality NVARCHAR(MAX)='',@JobTitle NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @MoveInDate DATE=NULL,@VisaExpiry DATE=NULL,@EmiratesIdIssueDate DATE=NULL,@EmiratesIdExpiryDate DATE=NULL,
    @PassportIssueDate DATE=NULL,@PassportExpiryDate DATE=NULL,@LabourCardIssueDate DATE=NULL,@LabourCardExpiryDate DATE=NULL,
    @IloeIssueDate DATE=NULL,@IloeExpiryDate DATE=NULL,@InsuranceIssueDate DATE=NULL,@InsuranceExpiryDate DATE=NULL,
    @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Staff SET StaffId=@StaffId,Name=@Name,Role=@Role,Contact=@Contact,Email=@Email,Status=@Status,
        Designation=@Designation,EmiratesId=@EmiratesId,PassportNo=@PassportNo,Nationality=@Nationality,
        JobTitle=@JobTitle,Remarks=@Remarks,MoveInDate=@MoveInDate,VisaExpiry=@VisaExpiry,
        EmiratesIdIssueDate=@EmiratesIdIssueDate,EmiratesIdExpiryDate=@EmiratesIdExpiryDate,
        PassportIssueDate=@PassportIssueDate,PassportExpiryDate=@PassportExpiryDate,
        LabourCardIssueDate=@LabourCardIssueDate,LabourCardExpiryDate=@LabourCardExpiryDate,
        IloeIssueDate=@IloeIssueDate,IloeExpiryDate=@IloeExpiryDate,
        InsuranceIssueDate=@InsuranceIssueDate,InsuranceExpiryDate=@InsuranceExpiryDate,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateUser
    @Id INT,@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Role NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE AppUsers SET Name=@Name,Contact=@Contact,Email=@Email,
        Role=ISNULL(@Role,Role),Status=ISNULL(@Status,Status),
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateOwner
    @Id INT,@Code NVARCHAR(MAX),@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Owners SET Code=@Code,Name=@Name,Contact=@Contact,Email=@Email,
        Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id INT,@Date DATE,@Head NVARCHAR(MAX),@Nature NVARCHAR(MAX)='Camp',
    @CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @RecipientRole NVARCHAR(MAX)='',@RecipientId INT=NULL,@RecipientName NVARCHAR(MAX)='',
    @Amount DECIMAL(18,2),@FundPool NVARCHAR(MAX)='',@FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Mode NVARCHAR(MAX)='',@Purpose NVARCHAR(MAX)='',@ExpenseId NVARCHAR(MAX)='',
    @OldRole NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2),@OldFPool NVARCHAR(MAX);
    SELECT @OldAmount=Amount,@OldFPool=FundPool FROM Expenses WHERE Id=@Id;
    UPDATE Expenses SET Date=@Date,Head=@Head,Nature=@Nature,CampId=@CampId,CampName=@CampName,
        RecipientRole=@RecipientRole,RecipientId=@RecipientId,RecipientName=@RecipientName,
        Amount=@Amount,FundPool=@FundPool,FundPoolName=@FundPoolName,
        Mode=@Mode,Purpose=@Purpose,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
    IF @OldFPool IS NOT NULL AND @OldAmount>0
        UPDATE FundPools SET Balance=Balance+@OldAmount,UpdatedAt=GETUTCDATE() WHERE Code=@OldFPool;
    IF @FundPool IS NOT NULL AND @Amount>0
        UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateFundPool
    @Id INT,@Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',
    @Balance DECIMAL(18,2)=NULL,@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE FundPools SET Name=@Name,Status=@Status,
        Balance=ISNULL(@Balance,Balance),
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateOtherPerson
    @Id INT,@Code NVARCHAR(MAX),@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',
    @Email NVARCHAR(MAX)='',@Role NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE OtherPersons SET Code=@Code,Name=@Name,Contact=@Contact,Email=@Email,
        Role=@Role,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

PRINT '074 - All missing SPs fixed with IsDeleted filter + audit columns';
GO
