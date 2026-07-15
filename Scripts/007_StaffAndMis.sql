-- ============================================================
-- TFMS Software - Staff Table + MIS + Owner Report SPs
-- Run on: DESKTOP-01\SQLEXPRESS  |  Database: TFMS_softwareDB
-- ============================================================
USE TFMS_softwareDB;
GO

-- ── STAFF TABLE ───────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='Staff')
CREATE TABLE Staff (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    StaffId     NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name        NVARCHAR(MAX) NOT NULL,
    Role        NVARCHAR(MAX)  NOT NULL DEFAULT 'Staff',
    Contact     NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Email       NVARCHAR(MAX) NOT NULL DEFAULT '',
    Address     NVARCHAR(MAX) NOT NULL DEFAULT '',
    Username    NVARCHAR(MAX)  NOT NULL UNIQUE,
    Password    NVARCHAR(MAX) NOT NULL DEFAULT '',
    LoginAccess NVARCHAR(MAX)  NOT NULL DEFAULT 'enabled',
    Status      NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    Remarks     NVARCHAR(MAX) NOT NULL DEFAULT '',
    CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ── STAFF STORED PROCEDURES ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetStaff
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @SortBy NVARCHAR(MAX)=NULL,
    @SortDirection NVARCHAR(MAX)='ASC', @Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Staff
    WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
                               OR StaffId LIKE '%'+@SearchText+'%'
                               OR Username LIKE '%'+@SearchText+'%');
    SELECT Id,StaffId,Name,Role,Contact,Email,Address,Username,Password,
           LoginAccess,Status,Remarks,CreatedAt,UpdatedAt
    FROM Staff
    WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
                               OR StaffId LIKE '%'+@SearchText+'%'
                               OR Username LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC,
             CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetStaffById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,StaffId,Name,Role,Contact,Email,Address,Username,Password,
           LoginAccess,Status,Remarks,CreatedAt,UpdatedAt FROM Staff WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateStaff
    @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX), @Email NVARCHAR(MAX),
    @Address NVARCHAR(MAX), @Username NVARCHAR(MAX), @Password NVARCHAR(MAX),
    @LoginAccess NVARCHAR(MAX), @Status NVARCHAR(MAX), @Remarks NVARCHAR(MAX),
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StaffId NVARCHAR(MAX)='STF-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Staff) AS NVARCHAR),6);
    INSERT INTO Staff(StaffId,Name,Role,Contact,Email,Address,Username,Password,LoginAccess,Status,Remarks,CreatedAt,UpdatedAt)
    VALUES(@StaffId,'Staff',@Name,@Contact,@Email,@Address,@Username,@Password,@LoginAccess,@Status,@Remarks,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    -- Also create AppUser login for this staff
    IF NOT EXISTS(SELECT 1 FROM AppUsers WHERE Username=@Username)
    BEGIN
        DECLARE @UserId NVARCHAR(MAX)='USR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6);
        INSERT INTO AppUsers(UserId,Name,Username,PasswordHash,Role,Source,SourceId,Contact,Email,LoginAccess,Status,MenuAccess,IsAdmin,CreatedAt,UpdatedAt)
        VALUES(@UserId,@Name,@Username,@Password,'Staff','Staff Master',@NewId,@Contact,@Email,@LoginAccess,@Status,'{}',0,GETUTCDATE(),GETUTCDATE());
    END
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateStaff
    @Id INT, @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX), @Email NVARCHAR(MAX),
    @Address NVARCHAR(MAX), @Username NVARCHAR(MAX), @Password NVARCHAR(MAX)=NULL,
    @LoginAccess NVARCHAR(MAX), @Status NVARCHAR(MAX), @Remarks NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Staff SET Name=@Name,Contact=@Contact,Email=@Email,Address=@Address,
        Username=@Username,LoginAccess=@LoginAccess,Status=@Status,Remarks=@Remarks,
        UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;
    IF @Password IS NOT NULL AND LEN(@Password)>0
        UPDATE Staff SET Password=@Password WHERE Id=@Id;
    -- Sync AppUser
    UPDATE AppUsers SET Name=@Name,Contact=@Contact,Email=@Email,
        LoginAccess=@LoginAccess,Status=@Status,UpdatedAt=GETUTCDATE()
    WHERE Source='Staff Master' AND SourceId=@Id;
    IF @Password IS NOT NULL AND LEN(@Password)>0
        UPDATE AppUsers SET PasswordHash=@Password WHERE Source='Staff Master' AND SourceId=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteStaff @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM AppUsers WHERE Source='Staff Master' AND SourceId=@Id;
    DELETE FROM Staff WHERE Id=@Id;
END
GO

-- ── USER MANAGEMENT STORED PROCEDURES ────────────────────────
CREATE OR ALTER PROCEDURE sp_GetUsers
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @Role NVARCHAR(MAX)=NULL, @Source NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM AppUsers
    WHERE (@Role   IS NULL OR Role=@Role)
      AND (@Source IS NULL OR Source=@Source)
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
                               OR Username LIKE '%'+@SearchText+'%'
                               OR UserId LIKE '%'+@SearchText+'%');
    SELECT Id,UserId,Name,Username,Role,Source,SourceId,Contact,Email,
           IsAdmin,LoginAccess,Status,MenuAccess,LastLogin,CreatedAt,UpdatedAt
    FROM AppUsers
    WHERE (@Role   IS NULL OR Role=@Role)
      AND (@Source IS NULL OR Source=@Source)
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
                               OR Username LIKE '%'+@SearchText+'%'
                               OR UserId LIKE '%'+@SearchText+'%')
    ORDER BY CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetUserById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,UserId,Name,Username,Role,Source,SourceId,Contact,Email,
           IsAdmin,LoginAccess,Status,MenuAccess,LastLogin,CreatedAt,UpdatedAt
    FROM AppUsers WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateUser
    @Name NVARCHAR(MAX), @Username NVARCHAR(MAX), @PasswordHash NVARCHAR(MAX),
    @Role NVARCHAR(MAX), @Source NVARCHAR(MAX), @SourceId INT=NULL,
    @Contact NVARCHAR(MAX), @Email NVARCHAR(MAX), @IsAdmin BIT,
    @LoginAccess NVARCHAR(MAX), @Status NVARCHAR(MAX), @MenuAccess NVARCHAR(MAX),
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId NVARCHAR(MAX)='USR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6);
    INSERT INTO AppUsers(UserId,Name,Username,PasswordHash,Role,Source,SourceId,Contact,Email,IsAdmin,LoginAccess,Status,MenuAccess,CreatedAt,UpdatedAt)
    VALUES(@UserId,@Name,@Username,@PasswordHash,@Role,@Source,@SourceId,@Contact,@Email,@IsAdmin,@LoginAccess,@Status,@MenuAccess,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateUser
    @Id INT, @Name NVARCHAR(MAX), @Role NVARCHAR(MAX), @Source NVARCHAR(MAX),
    @SourceId INT=NULL, @Contact NVARCHAR(MAX), @Email NVARCHAR(MAX),
    @IsAdmin BIT, @LoginAccess NVARCHAR(MAX), @Status NVARCHAR(MAX), @MenuAccess NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE AppUsers SET Name=@Name,Role=@Role,Source=@Source,SourceId=@SourceId,
        Contact=@Contact,Email=@Email,IsAdmin=@IsAdmin,LoginAccess=@LoginAccess,
        Status=@Status,MenuAccess=@MenuAccess,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteUser @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM AppUsers WHERE Id=@Id;
END
GO

-- ── MIS DASHBOARD STORED PROCEDURE ───────────────────────────
CREATE OR ALTER PROCEDURE sp_GetMisStats
    @CampId    INT          = NULL,
    @Month     NVARCHAR(MAX) = NULL,   -- format: '2026-06'
    @PartnerId INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: KPI Totals
    SELECT
        ISNULL(SUM(p.Amount),0)                                                    AS TotalRental,
        ISNULL(SUM(CASE WHEN p.Status='Paid'    THEN p.PaidAmount ELSE 0 END),0)   AS TotalCollected,
        ISNULL(SUM(CASE WHEN p.Status='Pending' THEN p.Amount     ELSE 0 END),0)   AS TotalOutstanding,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e
                WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO')
                  AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0) AS TotalExpenses,
        ISNULL(SUM(CASE WHEN p.Status='Paid' THEN p.PaidAmount ELSE 0 END),0)
          - ISNULL((SELECT SUM(e.Amount) FROM Expenses e
                    WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO')
                      AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0) AS NetProfit,
        COUNT(DISTINCT r.Id)                                                        AS TotalUnits,
        COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END)                AS OccupiedUnits,
        COUNT(DISTINCT CASE WHEN r.Status='Vacant'   THEN r.Id END)                AS VacantUnits,
        CASE WHEN COUNT(r.Id)>0
             THEN CAST(COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END)*100.0/COUNT(r.Id) AS DECIMAL(5,1))
             ELSE 0 END                                                             AS OccupancyPct
    FROM Rooms r
    JOIN Camps ca ON ca.Id=r.CampId
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c  ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN Payments  p  ON p.ContractId=c.ContractId
        AND (@Month IS NULL OR LEFT(CAST(p.DueDate AS NVARCHAR),7)=@Month)
    WHERE (@CampId IS NULL OR r.CampId=@CampId)
      AND (@PartnerId IS NULL OR r.CampId IN (SELECT CampId FROM CampPartners WHERE PartnerId=@PartnerId));

    -- Result set 2: Camp breakdown
    SELECT ca.Id CampId, ca.Name CampName,
           COUNT(DISTINCT r.Id) TotalRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
           ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN r.MonthlyPrice ELSE 0 END),0) MonthlyRevenue,
           ISNULL(SUM(CASE WHEN p.Status='Paid'    THEN p.PaidAmount ELSE 0 END),0) TotalCollected,
           ISNULL(SUM(CASE WHEN p.Status='Pending' THEN p.Amount     ELSE 0 END),0) TotalOutstanding
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN Payments p ON p.ContractId=c.ContractId
        AND (@Month IS NULL OR LEFT(CAST(p.DueDate AS NVARCHAR),7)=@Month)
    WHERE ca.Status='Active'
      AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id,ca.Name ORDER BY ca.Name;

    -- Result set 3: Monthly collections (last 12 months)
    SELECT FORMAT(p.DueDate,'MMM yyyy') [Month],
           ISNULL(SUM(CASE WHEN p.Status='Paid' THEN p.PaidAmount ELSE 0 END),0) Collected,
           ISNULL(SUM(p.Amount),0) Due,
           0 Expenses, 0 NetProfit
    FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId
    WHERE (@CampId IS NULL OR c.CampId=@CampId)
      AND p.DueDate >= DATEADD(MONTH,-11,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))
    GROUP BY FORMAT(p.DueDate,'MMM yyyy'), YEAR(p.DueDate), MONTH(p.DueDate)
    ORDER BY YEAR(p.DueDate), MONTH(p.DueDate);

    -- Result set 4: Expense by head
    SELECT e.Head, SUM(e.Amount) Amount
    FROM Expenses e
    WHERE (@CampId IS NULL OR e.Nature='HO' OR (e.Nature='Camp' AND e.CampId=@CampId))
      AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)
    GROUP BY e.Head ORDER BY Amount DESC;
END
GO

-- ── OWNER REPORT ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerReport
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Owners o
    WHERE (@Status IS NULL OR o.Status=@Status)
      AND (@SearchText IS NULL OR o.Name LIKE '%'+@SearchText+'%' OR o.Code LIKE '%'+@SearchText+'%');

    SELECT o.Id OwnerId, o.Code OwnerCode, o.Name OwnerName,
           o.Contact, o.Email, o.Status,
           COUNT(DISTINCT co.CampId) TotalCamps,
           ISNULL(STRING_AGG(c.Name,', '),'' ) CampNames,
           ISNULL(AVG(co.ShareValue),0) ShareValue,
           ISNULL(MAX(co.ShareType),'') ShareType
    FROM Owners o
    LEFT JOIN CampOwners co ON co.OwnerId=o.Id
    LEFT JOIN Camps c ON c.Id=co.CampId
    WHERE (@Status IS NULL OR o.Status=@Status)
      AND (@SearchText IS NULL OR o.Name LIKE '%'+@SearchText+'%' OR o.Code LIKE '%'+@SearchText+'%')
    GROUP BY o.Id,o.Code,o.Name,o.Contact,o.Email,o.Status
    ORDER BY o.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── INCOME STORED PROCEDURES ──────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetIncomes
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL, @SortDirection NVARCHAR(MAX)='ASC',
    @DateFrom NVARCHAR(MAX)=NULL, @DateTo NVARCHAR(MAX)=NULL,
    @Head NVARCHAR(MAX)=NULL, @FundPool NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Incomes i
    JOIN FundPools fp ON fp.Code=i.FundPool
    WHERE (@Head IS NULL OR i.Head=@Head) AND (@FundPool IS NULL OR i.FundPool=@FundPool)
      AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR i.Date<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR i.Head LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%' OR i.IncomeId LIKE '%'+@SearchText+'%');
    SELECT i.Id,i.IncomeId,i.Date,i.Mode,i.Head,i.FundPool,fp.Name FundPoolName,
           i.Amount,i.Purpose,i.Source,i.SourceRef,i.CreatedAt,i.UpdatedAt
    FROM Incomes i JOIN FundPools fp ON fp.Code=i.FundPool
    WHERE (@Head IS NULL OR i.Head=@Head) AND (@FundPool IS NULL OR i.FundPool=@FundPool)
      AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR i.Date<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR i.Head LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%' OR i.IncomeId LIKE '%'+@SearchText+'%')
    ORDER BY i.Date DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetIncomeById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT i.Id,i.IncomeId,i.Date,i.Mode,i.Head,i.FundPool,fp.Name FundPoolName,
           i.Amount,i.Purpose,i.Source,i.SourceRef,i.CreatedAt,i.UpdatedAt
    FROM Incomes i JOIN FundPools fp ON fp.Code=i.FundPool WHERE i.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateIncome
    @Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Purpose NVARCHAR(MAX),@Source NVARCHAR(MAX),@SourceRef NVARCHAR(MAX),
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IncomeId NVARCHAR(MAX)='INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
    INSERT INTO Incomes(IncomeId,Date,Mode,Head,FundPool,FundPoolName,Amount,Purpose,Source,SourceRef,CreatedAt,UpdatedAt)
    SELECT @IncomeId,@Date,@Mode,@Head,@FundPool,fp.Name,@Amount,@Purpose,@Source,@SourceRef,GETUTCDATE(),GETUTCDATE()
    FROM FundPools fp WHERE fp.Code=@FundPool;
    SET @NewId=SCOPE_IDENTITY();
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateIncome
    @Id INT,@Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Purpose NVARCHAR(MAX),@Source NVARCHAR(MAX),@SourceRef NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2), @OldPool NVARCHAR(MAX);
    SELECT @OldAmount=Amount, @OldPool=FundPool FROM Incomes WHERE Id=@Id;
    UPDATE Incomes SET Date=@Date,Mode=@Mode,Head=@Head,FundPool=@FundPool,
        FundPoolName=(SELECT Name FROM FundPools WHERE Code=@FundPool),
        Amount=@Amount,Purpose=@Purpose,Source=@Source,SourceRef=@SourceRef,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;
    UPDATE FundPools SET Balance=Balance-@OldAmount,UpdatedAt=GETUTCDATE() WHERE Code=@OldPool;
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE()  WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteIncome @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(18,2), @FundPool NVARCHAR(MAX);
    SELECT @Amount=Amount, @FundPool=FundPool FROM Incomes WHERE Id=@Id;
    DELETE FROM Incomes WHERE Id=@Id;
    UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

-- ── EXPENSE STORED PROCEDURES ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetExpenses
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
    @Head NVARCHAR(MAX)=NULL,@Nature NVARCHAR(MAX)=NULL,
    @CampId INT=NULL,@RecipientRole NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Expenses e
    JOIN FundPools fp ON fp.Code=e.FundPool
    WHERE (@Head IS NULL OR e.Head=@Head) AND (@Nature IS NULL OR e.Nature=@Nature)
      AND (@CampId IS NULL OR e.CampId=@CampId) AND (@RecipientRole IS NULL OR e.RecipientRole=@RecipientRole)
      AND (@DateFrom IS NULL OR e.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR e.Date<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR e.Head LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%'
                               OR e.RecipientName LIKE '%'+@SearchText+'%' OR e.ExpenseId LIKE '%'+@SearchText+'%');
    SELECT e.Id,e.ExpenseId,e.Date,e.Mode,e.Head,e.FundPool,fp.Name FundPoolName,
           e.Amount,e.Nature,e.CampId,ISNULL(c.Name,'') CampName,
           e.RecipientRole,e.RecipientName,e.Purpose,e.CreatedAt,e.UpdatedAt
    FROM Expenses e JOIN FundPools fp ON fp.Code=e.FundPool LEFT JOIN Camps c ON c.Id=e.CampId
    WHERE (@Head IS NULL OR e.Head=@Head) AND (@Nature IS NULL OR e.Nature=@Nature)
      AND (@CampId IS NULL OR e.CampId=@CampId) AND (@RecipientRole IS NULL OR e.RecipientRole=@RecipientRole)
      AND (@DateFrom IS NULL OR e.Date>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR e.Date<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR e.Head LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%'
                               OR e.RecipientName LIKE '%'+@SearchText+'%' OR e.ExpenseId LIKE '%'+@SearchText+'%')
    ORDER BY e.Date DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetExpenseById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.Id,e.ExpenseId,e.Date,e.Mode,e.Head,e.FundPool,fp.Name FundPoolName,
           e.Amount,e.Nature,e.CampId,ISNULL(c.Name,'') CampName,
           e.RecipientRole,e.RecipientName,e.Purpose,e.CreatedAt,e.UpdatedAt
    FROM Expenses e JOIN FundPools fp ON fp.Code=e.FundPool LEFT JOIN Camps c ON c.Id=e.CampId
    WHERE e.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Nature NVARCHAR(MAX),@CampId INT=NULL,
    @RecipientRole NVARCHAR(MAX),@RecipientName NVARCHAR(MAX),@Purpose NVARCHAR(MAX),
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ExpenseId NVARCHAR(MAX)='EXP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR),6);
    DECLARE @FundPoolName NVARCHAR(MAX)=(SELECT Name FROM FundPools WHERE Code=@FundPool);
    DECLARE @CampName NVARCHAR(MAX)=ISNULL((SELECT Name FROM Camps WHERE Id=@CampId),'');
    INSERT INTO Expenses(ExpenseId,Date,Mode,Head,FundPool,FundPoolName,Amount,Nature,CampId,CampName,RecipientRole,RecipientName,Purpose,CreatedAt,UpdatedAt)
    VALUES(@ExpenseId,@Date,@Mode,@Head,@FundPool,@FundPoolName,@Amount,@Nature,@CampId,@CampName,@RecipientRole,@RecipientName,@Purpose,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id INT,@Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Nature NVARCHAR(MAX),@CampId INT=NULL,
    @RecipientRole NVARCHAR(MAX),@RecipientName NVARCHAR(MAX),@Purpose NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2),@OldPool NVARCHAR(MAX);
    SELECT @OldAmount=Amount,@OldPool=FundPool FROM Expenses WHERE Id=@Id;
    DECLARE @CampName NVARCHAR(MAX)=ISNULL((SELECT Name FROM Camps WHERE Id=@CampId),'');
    UPDATE Expenses SET Date=@Date,Mode=@Mode,Head=@Head,FundPool=@FundPool,
        FundPoolName=(SELECT Name FROM FundPools WHERE Code=@FundPool),
        Amount=@Amount,Nature=@Nature,CampId=@CampId,CampName=@CampName,
        RecipientRole=@RecipientRole,RecipientName=@RecipientName,Purpose=@Purpose,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;
    UPDATE FundPools SET Balance=Balance+@OldAmount,UpdatedAt=GETUTCDATE() WHERE Code=@OldPool;
    UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE()   WHERE Code=@FundPool;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteExpense @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(18,2),@FundPool NVARCHAR(MAX);
    SELECT @Amount=Amount,@FundPool=FundPool FROM Expenses WHERE Id=@Id;
    DELETE FROM Expenses WHERE Id=@Id;
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

PRINT 'Script 007 completed successfully!';
GO
