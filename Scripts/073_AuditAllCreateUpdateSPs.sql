-- ============================================================
-- 073: Add @AddedBy / @UpdatedBy to all remaining Create/Update SPs
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Incomes ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateIncome
    @Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Purpose NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',
    @SourceRef NVARCHAR(MAX)='',@CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @PartnerId INT=NULL,@PartnerName NVARCHAR(MAX)='',
    @ContractId NVARCHAR(MAX)='',@ContractCode NVARCHAR(MAX)='',
    @TenantId INT=NULL,@TenantName NVARCHAR(MAX)='',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @IncomeId NVARCHAR(MAX)='INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
    INSERT INTO Incomes(IncomeId,Date,Mode,Head,FundPool,FundPoolName,Amount,Purpose,Source,SourceRef,
        CampId,CampName,PartnerId,PartnerName,ContractId,ContractCode,TenantId,TenantName,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    SELECT @IncomeId,@Date,@Mode,@Head,@FundPool,fp.Name,@Amount,@Purpose,@Source,@SourceRef,
        @CampId,ISNULL(@CampName,''),@PartnerId,ISNULL(@PartnerName,''),@ContractId,@ContractCode,@TenantId,@TenantName,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE()
    FROM FundPools fp WHERE fp.Code=@FundPool;
    SET @NewId=SCOPE_IDENTITY();
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateIncome
    @Id INT,@Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Purpose NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',
    @SourceRef NVARCHAR(MAX)='',@CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @PartnerId INT=NULL,@PartnerName NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2),@OldPool NVARCHAR(MAX);
    SELECT @OldAmount=Amount,@OldPool=FundPool FROM Incomes WHERE Id=@Id;
    UPDATE Incomes SET Date=@Date,Mode=@Mode,Head=@Head,FundPool=@FundPool,
        FundPoolName=(SELECT Name FROM FundPools WHERE Code=@FundPool),
        Amount=@Amount,Purpose=@Purpose,Source=@Source,SourceRef=@SourceRef,
        CampId=@CampId,CampName=ISNULL(@CampName,''),PartnerId=@PartnerId,PartnerName=ISNULL(@PartnerName,''),
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
    UPDATE FundPools SET Balance=Balance-@OldAmount,UpdatedAt=GETUTCDATE() WHERE Code=@OldPool;
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

-- ── Expenses ──────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id INT,@Date DATE,@Head NVARCHAR(MAX),@Nature NVARCHAR(MAX)='Camp',
    @CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @RecipientRole NVARCHAR(MAX)='',@RecipientId INT=NULL,@RecipientName NVARCHAR(MAX)='',
    @Amount DECIMAL(18,2),@FundPool NVARCHAR(MAX)='',@FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Mode NVARCHAR(MAX)='',@Purpose NVARCHAR(MAX)='',@ExpenseId NVARCHAR(MAX)='',
    @OldRole NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2),@OldFundPoolId INT;
    SELECT @OldAmount=Amount,@OldFundPoolId=FundPoolId FROM Expenses WHERE Id=@Id;
    UPDATE Expenses SET Date=@Date,Head=@Head,Nature=@Nature,CampId=@CampId,CampName=@CampName,
        RecipientRole=@RecipientRole,RecipientId=@RecipientId,RecipientName=@RecipientName,
        Amount=@Amount,FundPool=@FundPool,FundPoolId=@FundPoolId,FundPoolName=@FundPoolName,
        Mode=@Mode,Purpose=@Purpose,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
    IF @OldFundPoolId IS NOT NULL UPDATE FundPools SET Balance=Balance+@OldAmount,UpdatedAt=GETUTCDATE() WHERE Id=@OldFundPoolId;
    IF @FundPoolId IS NOT NULL UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;
END
GO

-- ── Users ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateUser
    @Name NVARCHAR(MAX),@Username NVARCHAR(MAX),@PasswordHash NVARCHAR(MAX),
    @Role NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',@SourceId INT=NULL,
    @Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @IsAdmin BIT=0,@LoginAccess NVARCHAR(MAX)='enabled',@Status NVARCHAR(MAX)='Active',
    @MenuAccess NVARCHAR(MAX)='{}',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId NVARCHAR(MAX)='USR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6);
    INSERT INTO AppUsers(UserId,Name,Username,Password,Role,Source,SourceId,Contact,Email,IsAdmin,LoginAccess,Status,MenuAccess,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@UserId,@Name,@Username,@PasswordHash,@Role,@Source,@SourceId,@Contact,@Email,@IsAdmin,@LoginAccess,@Status,@MenuAccess,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── FundPools ─────────────────────────────────────────────────────────────
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

-- ── Waivers ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateWaiver
    @TenantId INT,@ContractId NVARCHAR(MAX),@InstallmentNo INT,
    @OriginalAmount DECIMAL(18,2),@WaiverAmount DECIMAL(18,2),
    @Remark NVARCHAR(MAX)='',@WaiverDate DATE,@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,
        BalanceAmount,Remark,WaiverDate,AddedBy,IsDeleted)
    VALUES(@TenantId,@ContractId,@InstallmentNo,@OriginalAmount,@WaiverAmount,
        @OriginalAmount-@WaiverAmount,@Remark,@WaiverDate,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

PRINT '073 - AddedBy/UpdatedBy added to all Create/Update SPs';
GO
