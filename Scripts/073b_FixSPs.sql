USE TFMS_TestSoftwareDB;
GO

-- Fix sp_UpdateExpense (no FundPoolId column)
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
    -- Revert old pool, apply new pool
    IF @OldFPool IS NOT NULL AND @OldAmount>0
        UPDATE FundPools SET Balance=Balance+@OldAmount,UpdatedAt=GETUTCDATE() WHERE Code=@OldFPool;
    IF @FundPool IS NOT NULL AND @Amount>0
        UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

-- Fix sp_CreateUser (column is PasswordHash not Password)
CREATE OR ALTER PROCEDURE sp_CreateUser
    @Name NVARCHAR(MAX),@Username NVARCHAR(MAX),@PasswordHash NVARCHAR(MAX),
    @Role NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',@SourceId INT=NULL,
    @Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @IsAdmin BIT=0,@LoginAccess NVARCHAR(MAX)='enabled',@Status NVARCHAR(MAX)='Active',
    @MenuAccess NVARCHAR(MAX)='{}',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId NVARCHAR(MAX)='USR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6);
    INSERT INTO AppUsers(UserId,Name,Username,PasswordHash,Role,Source,SourceId,Contact,Email,IsAdmin,LoginAccess,Status,MenuAccess,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@UserId,@Name,@Username,@PasswordHash,@Role,@Source,@SourceId,@Contact,@Email,@IsAdmin,@LoginAccess,@Status,@MenuAccess,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

PRINT '073b - Expense/User SPs fixed';
GO
