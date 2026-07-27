-- ============================================================
-- 086: FINAL END-TO-END AUDIT FIX
-- Cross-verified: DB columns vs Models vs Repos vs SPs vs Controllers
-- Date: July 25, 2026
-- FIXES:
--   1. Audit columns in ALL tables (AddedBy/UpdatedBy/DeletedBy/IsDeleted)
--   2. ALL GET SPs: IsDeleted=0 filter
--   3. ALL DELETE SPs: Soft delete only
--   4. ALL CREATE SPs: AddedBy included
--   5. ALL UPDATE SPs: UpdatedBy included
-- ============================================================
USE TFMS_TestSoftwareDB;
GO
PRINT '=== STEP 1: Add Missing Audit Columns to ALL Tables ===';
GO
DECLARE @tbl NVARCHAR(128), @sql NVARCHAR(MAX);
DECLARE @tables TABLE (tbl NVARCHAR(128));
INSERT INTO @tables VALUES
('AccountsHeads'),('AppUsers'),('CampOwners'),('CampPartners'),
('Camps'),('CompanyAssets'),('ContractCamps'),('ContractCancellations'),
('ContractInstallments'),('ContractRenewals'),('ContractRoomInstallments'),
('ContractRooms'),('ContractRoomsTrns'),('Contracts'),('ContractTerms'),
('Designations'),('Expenses'),('Floors'),('FundPools'),('Incomes'),
('OtherPersons'),('OutgoingPayments'),('OwnerContracts'),('OwnerInstallments'),
('OwnerMonthlyContractInstallments'),('Owners'),('OwnerTransactions'),
('Partners'),('PaymentModes'),('Payments'),('Roles'),('Rooms'),
('RoomStatuses'),('Staff'),('Tenants'),('TxnRecords'),('Waivers'),('ActivityLog');
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT tbl FROM @tables;
OPEN cur; FETCH NEXT FROM cur INTO @tbl;
WHILE @@FETCH_STATUS=0
BEGIN
  IF OBJECT_ID(@tbl) IS NOT NULL
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='AddedBy')
    BEGIN SET @sql='ALTER TABLE '+QUOTENAME(@tbl)+' ADD AddedBy INT NULL'; EXEC sp_executesql @sql; PRINT 'Added AddedBy -> '+@tbl; END
    IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='UpdatedBy')
    BEGIN SET @sql='ALTER TABLE '+QUOTENAME(@tbl)+' ADD UpdatedBy INT NULL'; EXEC sp_executesql @sql; PRINT 'Added UpdatedBy -> '+@tbl; END
    IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='DeletedBy')
    BEGIN SET @sql='ALTER TABLE '+QUOTENAME(@tbl)+' ADD DeletedBy INT NULL'; EXEC sp_executesql @sql; PRINT 'Added DeletedBy -> '+@tbl; END
    IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='IsDeleted')
    BEGIN SET @sql='ALTER TABLE '+QUOTENAME(@tbl)+' ADD IsDeleted BIT NOT NULL DEFAULT 0'; EXEC sp_executesql @sql; PRINT 'Added IsDeleted -> '+@tbl; END
  END
  ELSE PRINT 'TABLE NOT FOUND: '+@tbl;
  FETCH NEXT FROM cur INTO @tbl;
END;
CLOSE cur; DEALLOCATE cur;
GO
PRINT 'STEP 1 DONE';
GO

PRINT '=== STEP 2: INFORMATION_SCHEMA Cross-Check Report ===';
GO
SELECT t.TABLE_NAME,
  MAX(CASE WHEN c.COLUMN_NAME='AddedBy'   THEN 'YES' ELSE 'NO' END) AS AddedBy,
  MAX(CASE WHEN c.COLUMN_NAME='UpdatedBy' THEN 'YES' ELSE 'NO' END) AS UpdatedBy,
  MAX(CASE WHEN c.COLUMN_NAME='DeletedBy' THEN 'YES' ELSE 'NO' END) AS DeletedBy,
  MAX(CASE WHEN c.COLUMN_NAME='IsDeleted' THEN 'YES' ELSE 'NO' END) AS IsDeleted
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c ON c.TABLE_NAME=t.TABLE_NAME
  AND c.COLUMN_NAME IN('AddedBy','UpdatedBy','DeletedBy','IsDeleted')
WHERE t.TABLE_TYPE='BASE TABLE'
  AND t.TABLE_NAME IN('AccountsHeads','AppUsers','CampOwners','CampPartners',
    'Camps','CompanyAssets','ContractCamps','ContractCancellations',
    'ContractInstallments','ContractRenewals','ContractRoomInstallments',
    'ContractRooms','ContractRoomsTrns','Contracts','ContractTerms',
    'Designations','Expenses','Floors','FundPools','Incomes',
    'OtherPersons','OutgoingPayments','OwnerContracts','OwnerInstallments',
    'OwnerMonthlyContractInstallments','Owners','OwnerTransactions',
    'Partners','PaymentModes','Payments','Roles','Rooms',
    'RoomStatuses','Staff','Tenants','TxnRecords','Waivers','ActivityLog')
GROUP BY t.TABLE_NAME ORDER BY t.TABLE_NAME;
GO
PRINT 'STEP 2 DONE -- All YES = PASS, any NO = check manually';
GO
PRINT '=== STEP 3: AccountsHeads SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetAccountsHeads
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@Type NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM AccountsHeads
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@Type IS NULL OR Type=@Type)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Name,Type,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM AccountsHeads
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@Type IS NULL OR Type=@Type)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetAccountsHeadById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Name,Type,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM AccountsHeads WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateAccountsHead
  @Name NVARCHAR(MAX),@Type NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',
  @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO AccountsHeads(Name,Type,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Type,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE AccountsHeads SET Code=CONCAT('AH',RIGHT('0000'+CAST(@NewId AS NVARCHAR),4)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateAccountsHead
  @Id INT,@Name NVARCHAR(MAX),@Type NVARCHAR(MAX),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE AccountsHeads SET Name=@Name,Type=@Type,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteAccountsHead @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE AccountsHeads SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'AccountsHeads SPs -- DONE';
GO

PRINT '=== STEP 4: Designations SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetDesignations
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Designations
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Name,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Designations
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetDesignationById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Name,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Designations WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateDesignation
  @Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Designations(Name,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Designations SET Code=CONCAT('DES',RIGHT('000'+CAST(@NewId AS NVARCHAR),3)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateDesignation
  @Id INT,@Name NVARCHAR(MAX),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Designations SET Name=@Name,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteDesignation @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Designations SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Designations SPs -- DONE';
GO
PRINT '=== STEP 5: Floors SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetFloors
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Floors
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
  SELECT Id,Name,Number,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Floors
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
  ORDER BY Number OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetFloorById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Name,Number,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Floors WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateFloor
  @Name NVARCHAR(MAX),@Number INT,@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Floors(Name,Number,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Number,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateFloor
  @Id INT,@Name NVARCHAR(MAX),@Number INT,@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Floors SET Name=@Name,Number=@Number,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteFloor @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Floors SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Floors SPs -- DONE';
GO

PRINT '=== STEP 6: FundPools SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetFundPools
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM FundPools
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Name,Status,Balance,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM FundPools
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetFundPoolById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Name,Status,Balance,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM FundPools WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateFundPool
  @Name NVARCHAR(MAX),@Balance DECIMAL(18,2)=0,@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO FundPools(Name,Balance,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Balance,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE FundPools SET Code=CONCAT('FP',RIGHT('000'+CAST(@NewId AS NVARCHAR),3)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateFundPool
  @Id INT,@Name NVARCHAR(MAX),@Balance DECIMAL(18,2),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE FundPools SET Name=@Name,Balance=@Balance,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteFundPool @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE FundPools SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'FundPools SPs -- DONE';
GO
PRINT '=== STEP 7: PaymentModes + RoomStatuses + Roles SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetPaymentModes @Status NVARCHAR(MAX)=NULL AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Name,Status FROM PaymentModes WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status) ORDER BY Name;
END
GO
CREATE OR ALTER PROCEDURE sp_CreatePaymentMode
  @Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO PaymentModes(Name,Status,AddedBy,IsDeleted) VALUES(@Name,@Status,@AddedBy,0);
  SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdatePaymentMode
  @Id INT,@Name NVARCHAR(MAX),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE PaymentModes SET Name=@Name,Status=@Status,UpdatedBy=@UpdatedBy WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeletePaymentMode @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE PaymentModes SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoomStatuses AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Name FROM RoomStatuses WHERE IsDeleted=0 ORDER BY Name;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateRoomStatus
  @Name NVARCHAR(MAX),@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO RoomStatuses(Name,AddedBy,IsDeleted) VALUES(@Name,@AddedBy,0);
  SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRoomStatus @Id INT,@Name NVARCHAR(MAX),@UpdatedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE RoomStatuses SET Name=@Name,UpdatedBy=@UpdatedBy WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRoomStatus @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE RoomStatuses SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoles
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Roles WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%');
  SELECT Id,RoleCode,RoleName,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Roles
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%')
  ORDER BY RoleName OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoleById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,RoleCode,RoleName,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Roles WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateRole
  @RoleName NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Roles(RoleName,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@RoleName,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Roles SET RoleCode=CONCAT('ROL',RIGHT('000'+CAST(@NewId AS NVARCHAR),3)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRole
  @Id INT,@RoleName NVARCHAR(MAX),@Status NVARCHAR(MAX),@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Roles SET RoleName=@RoleName,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRole @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Roles SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'PaymentModes + RoomStatuses + Roles SPs -- DONE';
GO

PRINT '=== STEP 8: OtherPersons SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetOtherPersons
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@Designation NVARCHAR(MAX)=NULL,@Id INT=NULL,
  @TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM OtherPersons
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@Designation IS NULL OR Designation=@Designation)
    AND(@Id IS NULL OR Id=@Id)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM OtherPersons
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@Designation IS NULL OR Designation=@Designation)
    AND(@Id IS NULL OR Id=@Id)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetOtherPersonById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM OtherPersons WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateOtherPerson
  @Designation NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Mobile NVARCHAR(MAX)='',
  @Email NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',@City NVARCHAR(MAX)='',
  @State NVARCHAR(MAX)='',@Pincode NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO OtherPersons(Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Designation,@Name,@Mobile,@Email,@Address,@City,@State,@Pincode,@Remarks,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE OtherPersons SET Code=CONCAT('OP',RIGHT('0000'+CAST(@NewId AS NVARCHAR),4)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateOtherPerson
  @Id INT,@Designation NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Mobile NVARCHAR(MAX)='',
  @Email NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',@City NVARCHAR(MAX)='',
  @State NVARCHAR(MAX)='',@Pincode NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE OtherPersons SET Designation=@Designation,Name=@Name,Mobile=@Mobile,Email=@Email,
    Address=@Address,City=@City,State=@State,Pincode=@Pincode,Remarks=@Remarks,
    Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteOtherPerson @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE OtherPersons SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'OtherPersons SPs -- DONE';
GO
PRINT '=== STEP 9: Owners SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetOwners
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@Id INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Owners
  WHERE IsDeleted=0 AND(@Id IS NULL OR Id=@Id) AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Owners
  WHERE IsDeleted=0 AND(@Id IS NULL OR Id=@Id) AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetOwnerById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Owners WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateOwner
  @Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Owners(Name,Contact,Email,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Contact,@Email,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Owners SET Code=CONCAT('OWN',RIGHT('0000'+CAST(@NewId AS NVARCHAR),4)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateOwner
  @Id INT,@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Owners SET Name=@Name,Contact=@Contact,Email=@Email,Status=@Status,
    UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteOwner @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Owners SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Owners SPs -- DONE';
GO

PRINT '=== STEP 10: Partners SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetPartners
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@Id INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Partners
  WHERE IsDeleted=0 AND(@Id IS NULL OR Id=@Id) AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
  SELECT Id,Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Partners
  WHERE IsDeleted=0 AND(@Id IS NULL OR Id=@Id) AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetPartnerById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt,AddedBy,UpdatedBy FROM Partners WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreatePartner
  @Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Mobile NVARCHAR(MAX)='',
  @Email NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Partners(Name,Contact,Mobile,Email,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Name,@Contact,@Mobile,@Email,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Partners SET Code=CONCAT('PAR',RIGHT('0000'+CAST(@NewId AS NVARCHAR),4)) WHERE Id=@NewId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdatePartner
  @Id INT,@Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Mobile NVARCHAR(MAX)='',
  @Email NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Partners SET Name=@Name,Contact=@Contact,Mobile=@Mobile,Email=@Email,Status=@Status,
    UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeletePartner @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Partners SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Partners SPs -- DONE';
GO
PRINT '=== STEP 11: Tenants SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetTenants
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@CampId INT=NULL,@Id INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Tenants t WHERE t.IsDeleted=0
    AND(@Status IS NULL OR t.Status=@Status) AND(@Id IS NULL OR t.Id=@Id)
    AND(@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%')
    AND(@CampId IS NULL OR EXISTS(SELECT 1 FROM Contracts c JOIN ContractCamps cc ON cc.ContractId=c.ContractId WHERE c.TenantId=t.Id AND cc.CampId=@CampId AND c.IsDeleted=0));
  SELECT t.Id,t.Name,t.Type,t.Passport,t.Nationality,t.EmiratesId,t.Contact,t.Whatsapp,t.Email,
    t.Address,t.Status,t.Company,t.TradeLicense,t.LicensingAuthority,t.NumberOfCoOccupants,
    t.PlotNo,t.MakaniNo,t.PropertyArea,t.PremisesNo,t.LessorName,t.LessorEid,t.LessorLicense,
    t.LessorLicAuthority,t.LessorEmail,t.LessorPhone,t.CreatedAt,t.UpdatedAt,t.AddedBy,t.UpdatedBy
  FROM Tenants t WHERE t.IsDeleted=0
    AND(@Status IS NULL OR t.Status=@Status) AND(@Id IS NULL OR t.Id=@Id)
    AND(@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%')
    AND(@CampId IS NULL OR EXISTS(SELECT 1 FROM Contracts c JOIN ContractCamps cc ON cc.ContractId=c.ContractId WHERE c.TenantId=t.Id AND cc.CampId=@CampId AND c.IsDeleted=0))
  ORDER BY t.Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetTenantById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,Name,Type,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,
    PremisesNo,LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,
    CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM Tenants WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateTenant
  @Type NVARCHAR(MAX)='Individual',@Name NVARCHAR(MAX),@Passport NVARCHAR(MAX)='',
  @Nationality NVARCHAR(MAX)='',@EmiratesId NVARCHAR(MAX)='',@Contact NVARCHAR(MAX)='',
  @Whatsapp NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@Company NVARCHAR(MAX)='',@TradeLicense NVARCHAR(MAX)='',
  @LicensingAuthority NVARCHAR(MAX)='',@NumberOfCoOccupants NVARCHAR(MAX)='',
  @PlotNo NVARCHAR(MAX)='',@MakaniNo NVARCHAR(MAX)='',@PropertyArea NVARCHAR(MAX)='',
  @PremisesNo NVARCHAR(MAX)='',@LessorName NVARCHAR(MAX)='',@LessorEid NVARCHAR(MAX)='',
  @LessorLicense NVARCHAR(MAX)='',@LessorLicAuthority NVARCHAR(MAX)='',
  @LessorEmail NVARCHAR(MAX)='',@LessorPhone NVARCHAR(MAX)='',
  @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,
    Status,Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,
    PropertyArea,PremisesNo,LessorName,LessorEid,LessorLicense,LessorLicAuthority,
    LessorEmail,LessorPhone,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@Type,@Name,@Passport,@Nationality,@EmiratesId,@Contact,@Whatsapp,@Email,@Address,
    @Status,@Company,@TradeLicense,@LicensingAuthority,@NumberOfCoOccupants,@PlotNo,@MakaniNo,
    @PropertyArea,@PremisesNo,@LessorName,@LessorEid,@LessorLicense,@LessorLicAuthority,
    @LessorEmail,@LessorPhone,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateTenant
  @Id INT,@Type NVARCHAR(MAX)='Individual',@Name NVARCHAR(MAX),@Passport NVARCHAR(MAX)='',
  @Nationality NVARCHAR(MAX)='',@EmiratesId NVARCHAR(MAX)='',@Contact NVARCHAR(MAX)='',
  @Whatsapp NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',
  @Status NVARCHAR(MAX)='Active',@Company NVARCHAR(MAX)='',@TradeLicense NVARCHAR(MAX)='',
  @LicensingAuthority NVARCHAR(MAX)='',@NumberOfCoOccupants NVARCHAR(MAX)='',
  @PlotNo NVARCHAR(MAX)='',@MakaniNo NVARCHAR(MAX)='',@PropertyArea NVARCHAR(MAX)='',
  @PremisesNo NVARCHAR(MAX)='',@LessorName NVARCHAR(MAX)='',@LessorEid NVARCHAR(MAX)='',
  @LessorLicense NVARCHAR(MAX)='',@LessorLicAuthority NVARCHAR(MAX)='',
  @LessorEmail NVARCHAR(MAX)='',@LessorPhone NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Tenants SET Type=@Type,Name=@Name,Passport=@Passport,Nationality=@Nationality,
    EmiratesId=@EmiratesId,Contact=@Contact,Whatsapp=@Whatsapp,Email=@Email,Address=@Address,
    Status=@Status,Company=@Company,TradeLicense=@TradeLicense,LicensingAuthority=@LicensingAuthority,
    NumberOfCoOccupants=@NumberOfCoOccupants,PlotNo=@PlotNo,MakaniNo=@MakaniNo,
    PropertyArea=@PropertyArea,PremisesNo=@PremisesNo,LessorName=@LessorName,LessorEid=@LessorEid,
    LessorLicense=@LessorLicense,LessorLicAuthority=@LessorLicAuthority,LessorEmail=@LessorEmail,
    LessorPhone=@LessorPhone,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteTenant @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Tenants SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Tenants SPs -- DONE';
GO

PRINT '=== STEP 12: Rooms SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetRooms
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@CampId INT=NULL,@FloorId INT=NULL,
  @RoomStatus NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Rooms r
  WHERE r.IsDeleted=0 AND(@Status IS NULL OR r.Status=@Status)
    AND(@CampId IS NULL OR r.CampId=@CampId) AND(@FloorId IS NULL OR r.FloorId=@FloorId)
    AND(@RoomStatus IS NULL OR r.Status=@RoomStatus)
    AND(@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%');
  SELECT r.Id,r.RoomNo,r.CampId,ISNULL(c.Name,'') CampName,r.FloorId,ISNULL(f.Name,'') FloorName,
    r.Occupied,r.MonthlyPrice,r.Status,ISNULL(r.OtherDetails,'') OtherDetails,
    r.CreatedAt,r.UpdatedAt,r.AddedBy,r.UpdatedBy
  FROM Rooms r
  LEFT JOIN Camps c ON c.Id=r.CampId AND c.IsDeleted=0
  LEFT JOIN Floors f ON f.Id=r.FloorId AND f.IsDeleted=0
  WHERE r.IsDeleted=0 AND(@Status IS NULL OR r.Status=@Status)
    AND(@CampId IS NULL OR r.CampId=@CampId) AND(@FloorId IS NULL OR r.FloorId=@FloorId)
    AND(@RoomStatus IS NULL OR r.Status=@RoomStatus)
    AND(@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%')
  ORDER BY c.Name,r.RoomNo OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoomById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT r.Id,r.RoomNo,r.CampId,ISNULL(c.Name,'') CampName,r.FloorId,ISNULL(f.Name,'') FloorName,
    r.Occupied,r.MonthlyPrice,r.Status,ISNULL(r.OtherDetails,'') OtherDetails,
    r.CreatedAt,r.UpdatedAt,r.AddedBy,r.UpdatedBy
  FROM Rooms r
  LEFT JOIN Camps c ON c.Id=r.CampId AND c.IsDeleted=0
  LEFT JOIN Floors f ON f.Id=r.FloorId AND f.IsDeleted=0
  WHERE r.Id=@Id AND r.IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateRoom
  @RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2)=0,
  @Status NVARCHAR(MAX)='Vacant',@OtherDetails NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@RoomNo,@CampId,@FloorId,0,@MonthlyPrice,@Status,@OtherDetails,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0) WHERE Id=@CampId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRoom
  @Id INT,@RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2)=0,
  @Status NVARCHAR(MAX)='Vacant',@OtherDetails NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @OldCampId INT; SELECT @OldCampId=CampId FROM Rooms WHERE Id=@Id;
  UPDATE Rooms SET RoomNo=@RoomNo,CampId=@CampId,FloorId=@FloorId,MonthlyPrice=@MonthlyPrice,
    Status=@Status,Occupied=CASE WHEN @Status='Occupied' THEN 1 ELSE 0 END,
    OtherDetails=@OtherDetails,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
  UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0) WHERE Id=@CampId;
  IF @OldCampId<>@CampId
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@OldCampId AND IsDeleted=0) WHERE Id=@OldCampId;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  DECLARE @CampId INT; SELECT @CampId=CampId FROM Rooms WHERE Id=@Id;
  UPDATE Rooms SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  IF @CampId IS NOT NULL
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0) WHERE Id=@CampId;
END
GO
CREATE OR ALTER PROCEDURE sp_BulkCreateRooms
  @CampId INT,@FloorId INT,@RoomsJson NVARCHAR(MAX),@Status NVARCHAR(MAX)='Vacant',
  @Price DECIMAL(18,2)=0,@OtherDetails NVARCHAR(MAX)=''
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @t TABLE(RoomNo NVARCHAR(MAX));
  INSERT INTO @t SELECT value FROM OPENJSON(@RoomsJson);
  DECLARE @created INT=0;
  INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,IsDeleted,CreatedAt,UpdatedAt)
  SELECT RoomNo,@CampId,@FloorId,0,@Price,@Status,@OtherDetails,0,GETUTCDATE(),GETUTCDATE()
  FROM @t WHERE NOT EXISTS(SELECT 1 FROM Rooms r2 WHERE r2.RoomNo=[@t].RoomNo AND r2.CampId=@CampId AND r2.IsDeleted=0);
  SET @created=@@ROWCOUNT;
  UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0) WHERE Id=@CampId;
  SELECT @created AS Created;
END
GO
PRINT 'Rooms SPs -- DONE';
GO

PRINT '=== STEP 13: Camps SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetCamps
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@PartnerId INT=NULL,@OwnerId INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(DISTINCT c.Id) FROM Camps c
  WHERE c.IsDeleted=0 AND(@Status IS NULL OR c.Status=@Status)
    AND(@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%')
    AND(@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId))
    AND(@OwnerId IS NULL OR EXISTS(SELECT 1 FROM CampOwners co WHERE co.CampId=c.Id AND co.OwnerId=@OwnerId));
  -- RS1: Camps
  SELECT c.Id,c.Code,c.Name,c.Rooms,c.Floors,c.Status,
    ISNULL(c.CampPropertyUsage,'') CampPropertyUsage,ISNULL(c.CampBuildingName,'') CampBuildingName,
    ISNULL(c.CampPropertyType,'') CampPropertyType,ISNULL(c.CampLocation,'') CampLocation,
    ISNULL(c.CampPropertyNo,'') CampPropertyNo,ISNULL(c.CampPropertyArea,'') CampPropertyArea,
    ISNULL(c.CampPremisesNo,'') CampPremisesNo,ISNULL(c.CampPlotNo,'') CampPlotNo,
    ISNULL(c.CampMakaniNo,'') CampMakaniNo,c.StartDate,c.EndDate,c.CreatedAt,c.UpdatedAt,c.AddedBy,c.UpdatedBy
  FROM Camps c
  WHERE c.IsDeleted=0 AND(@Status IS NULL OR c.Status=@Status)
    AND(@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%')
    AND(@PartnerId IS NULL OR EXISTS(SELECT 1 FROM CampPartners cp WHERE cp.CampId=c.Id AND cp.PartnerId=@PartnerId))
    AND(@OwnerId IS NULL OR EXISTS(SELECT 1 FROM CampOwners co WHERE co.CampId=c.Id AND co.OwnerId=@OwnerId))
  ORDER BY c.Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
  -- RS2: Partners for these camps
  SELECT cp.Id CampPartnerId,cp.CampId,cp.PartnerId,ISNULL(p.Name,'') PartnerName,
    ISNULL(cp.ShareType,'percentage') PartnerShareType,ISNULL(cp.ShareValue,0) PartnerShareValue
  FROM CampPartners cp JOIN Partners p ON p.Id=cp.PartnerId AND p.IsDeleted=0
  WHERE cp.CampId IN(SELECT c2.Id FROM Camps c2 WHERE c2.IsDeleted=0
    AND(@Status IS NULL OR c2.Status=@Status)
    AND(@SearchText IS NULL OR c2.Name LIKE '%'+@SearchText+'%'));
  -- RS3: Owners for these camps
  SELECT co.Id CampOwnerId,co.CampId,co.OwnerId,ISNULL(o.Name,'') OwnerName,
    ISNULL(co.ShareType,'percentage') OwnerShareType,ISNULL(co.ShareValue,0) OwnerShareValue
  FROM CampOwners co JOIN Owners o ON o.Id=co.OwnerId AND o.IsDeleted=0
  WHERE co.CampId IN(SELECT c3.Id FROM Camps c3 WHERE c3.IsDeleted=0
    AND(@Status IS NULL OR c3.Status=@Status)
    AND(@SearchText IS NULL OR c3.Name LIKE '%'+@SearchText+'%'));
END
GO
CREATE OR ALTER PROCEDURE sp_GetCampById @Id INT AS BEGIN
  SET NOCOUNT ON;
  -- RS1: Camp
  SELECT c.Id,c.Code,c.Name,c.Rooms,c.Floors,c.Status,
    ISNULL(c.CampPropertyUsage,'') CampPropertyUsage,ISNULL(c.CampBuildingName,'') CampBuildingName,
    ISNULL(c.CampPropertyType,'') CampPropertyType,ISNULL(c.CampLocation,'') CampLocation,
    ISNULL(c.CampPropertyNo,'') CampPropertyNo,ISNULL(c.CampPropertyArea,'') CampPropertyArea,
    ISNULL(c.CampPremisesNo,'') CampPremisesNo,ISNULL(c.CampPlotNo,'') CampPlotNo,
    ISNULL(c.CampMakaniNo,'') CampMakaniNo,c.StartDate,c.EndDate,c.CreatedAt,c.UpdatedAt,c.AddedBy,c.UpdatedBy
  FROM Camps c WHERE c.Id=@Id AND c.IsDeleted=0;
  -- RS2: Partners
  SELECT cp.Id CampPartnerId,cp.CampId,cp.PartnerId,ISNULL(p.Name,'') PartnerName,
    ISNULL(cp.ShareType,'percentage') PartnerShareType,ISNULL(cp.ShareValue,0) PartnerShareValue
  FROM CampPartners cp JOIN Partners p ON p.Id=cp.PartnerId AND p.IsDeleted=0 WHERE cp.CampId=@Id;
  -- RS3: Owners
  SELECT co.Id CampOwnerId,co.CampId,co.OwnerId,ISNULL(o.Name,'') OwnerName,
    ISNULL(co.ShareType,'percentage') OwnerShareType,ISNULL(co.ShareValue,0) OwnerShareValue
  FROM CampOwners co JOIN Owners o ON o.Id=co.OwnerId AND o.IsDeleted=0 WHERE co.CampId=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteCamp @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Camps SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  -- Soft delete associated rooms too
  UPDATE Rooms SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE CampId=@Id AND IsDeleted=0;
END
GO
PRINT 'Camps SPs -- DONE';
GO
PRINT '=== STEP 14: Users (AppUsers) SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetUsers
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Role NVARCHAR(MAX)=NULL,@Source NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,
  @TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM AppUsers
  WHERE IsDeleted=0 AND(@Role IS NULL OR Role=@Role) AND(@Source IS NULL OR Source=@Source)
    AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Username LIKE '%'+@SearchText+'%');
  SELECT Id,UserId,Name,Username,PasswordHash,Role,Source,SourceId,Contact,Email,IsAdmin,
    LoginAccess,Status,MenuAccess,LastLogin,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM AppUsers
  WHERE IsDeleted=0 AND(@Role IS NULL OR Role=@Role) AND(@Source IS NULL OR Source=@Source)
    AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Username LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetUserById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,UserId,Name,Username,PasswordHash,Role,Source,SourceId,Contact,Email,IsAdmin,
    LoginAccess,Status,MenuAccess,LastLogin,CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM AppUsers WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteUser @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE AppUsers SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'Users SPs -- DONE';
GO

PRINT '=== STEP 15: Incomes SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetIncomes
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
  @Head NVARCHAR(MAX)=NULL,@FundPool NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Incomes
  WHERE IsDeleted=0
    AND(@Head IS NULL OR Head=@Head) AND(@FundPool IS NULL OR FundPool=@FundPool)
    AND(@DateFrom IS NULL OR CAST(Date AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo IS NULL OR CAST(Date AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR IncomeId LIKE '%'+@SearchText+'%' OR Purpose LIKE '%'+@SearchText+'%');
  SELECT i.Id,i.IncomeId,i.Date,i.Mode,i.Head,i.FundPool,
    ISNULL((SELECT fp.Name FROM FundPools fp WHERE fp.Code=i.FundPool AND fp.IsDeleted=0),'') FundPoolName,
    i.Amount,i.Purpose,i.Source,i.SourceRef,i.CampId,
    ISNULL((SELECT ca.Name FROM Camps ca WHERE ca.Id=i.CampId AND ca.IsDeleted=0),'') CampName,
    i.PartnerId,ISNULL((SELECT p.Name FROM Partners p WHERE p.Id=i.PartnerId AND p.IsDeleted=0),'') PartnerName,
    ISNULL(i.ContractId,'') ContractId,ISNULL(i.ContractCode,'') ContractCode,
    i.CreatedAt,i.UpdatedAt,i.AddedBy,i.UpdatedBy
  FROM Incomes i
  WHERE i.IsDeleted=0
    AND(@Head IS NULL OR i.Head=@Head) AND(@FundPool IS NULL OR i.FundPool=@FundPool)
    AND(@DateFrom IS NULL OR CAST(i.Date AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo IS NULL OR CAST(i.Date AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR i.IncomeId LIKE '%'+@SearchText+'%' OR i.Purpose LIKE '%'+@SearchText+'%')
  ORDER BY i.Date DESC OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetIncomeById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT i.Id,i.IncomeId,i.Date,i.Mode,i.Head,i.FundPool,
    ISNULL((SELECT fp.Name FROM FundPools fp WHERE fp.Code=i.FundPool AND fp.IsDeleted=0),'') FundPoolName,
    i.Amount,i.Purpose,i.Source,i.SourceRef,i.CampId,
    ISNULL((SELECT ca.Name FROM Camps ca WHERE ca.Id=i.CampId AND ca.IsDeleted=0),'') CampName,
    i.PartnerId,ISNULL((SELECT p.Name FROM Partners p WHERE p.Id=i.PartnerId AND p.IsDeleted=0),'') PartnerName,
    ISNULL(i.ContractId,'') ContractId,ISNULL(i.ContractCode,'') ContractCode,
    i.CreatedAt,i.UpdatedAt,i.AddedBy,i.UpdatedBy
  FROM Incomes i WHERE i.Id=@Id AND i.IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteIncome @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  DECLARE @Amt DECIMAL(18,2),@Pool NVARCHAR(MAX);
  SELECT @Amt=Amount,@Pool=FundPool FROM Incomes WHERE Id=@Id;
  UPDATE Incomes SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  IF @Pool IS NOT NULL AND @Amt>0
    UPDATE FundPools SET Balance=Balance-@Amt,UpdatedAt=GETUTCDATE() WHERE Code=@Pool AND IsDeleted=0;
END
GO
PRINT 'Incomes SPs -- DONE';
GO
PRINT '=== STEP 16: Expenses SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetExpenses
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
  @Head NVARCHAR(MAX)=NULL,@Nature NVARCHAR(MAX)=NULL,
  @CampId INT=NULL,@RecipientRole NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Expenses
  WHERE IsDeleted=0 AND(@Head IS NULL OR Head=@Head) AND(@Nature IS NULL OR Nature=@Nature)
    AND(@CampId IS NULL OR CampId=@CampId) AND(@RecipientRole IS NULL OR RecipientRole=@RecipientRole)
    AND(@DateFrom IS NULL OR CAST(Date AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo IS NULL OR CAST(Date AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR ExpenseId LIKE '%'+@SearchText+'%' OR Purpose LIKE '%'+@SearchText+'%');
  SELECT e.Id,e.ExpenseId,e.Date,e.Mode,e.Head,e.FundPool,
    ISNULL((SELECT fp.Name FROM FundPools fp WHERE fp.Code=e.FundPool AND fp.IsDeleted=0),'') FundPoolName,
    e.Amount,e.Nature,e.CampId,ISNULL((SELECT ca.Name FROM Camps ca WHERE ca.Id=e.CampId AND ca.IsDeleted=0),'') CampName,
    e.RecipientRole,e.RecipientId,ISNULL(e.RecipientName,'') RecipientName,e.Purpose,
    e.CreatedAt,e.UpdatedAt,e.AddedBy,e.UpdatedBy
  FROM Expenses e
  WHERE e.IsDeleted=0 AND(@Head IS NULL OR e.Head=@Head) AND(@Nature IS NULL OR e.Nature=@Nature)
    AND(@CampId IS NULL OR e.CampId=@CampId) AND(@RecipientRole IS NULL OR e.RecipientRole=@RecipientRole)
    AND(@DateFrom IS NULL OR CAST(e.Date AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo IS NULL OR CAST(e.Date AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR e.ExpenseId LIKE '%'+@SearchText+'%' OR e.Purpose LIKE '%'+@SearchText+'%')
  ORDER BY e.Date DESC OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetExpenseById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT e.Id,e.ExpenseId,e.Date,e.Mode,e.Head,e.FundPool,
    ISNULL((SELECT fp.Name FROM FundPools fp WHERE fp.Code=e.FundPool AND fp.IsDeleted=0),'') FundPoolName,
    e.Amount,e.Nature,e.CampId,ISNULL((SELECT ca.Name FROM Camps ca WHERE ca.Id=e.CampId AND ca.IsDeleted=0),'') CampName,
    e.RecipientRole,e.RecipientId,ISNULL(e.RecipientName,'') RecipientName,e.Purpose,
    e.CreatedAt,e.UpdatedAt,e.AddedBy,e.UpdatedBy
  FROM Expenses e WHERE e.Id=@Id AND e.IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteExpense @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  DECLARE @Amt DECIMAL(18,2),@FPId INT;
  SELECT @Amt=Amount,@FPId=FundPoolId FROM Expenses WHERE Id=@Id;
  UPDATE Expenses SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  IF @FPId IS NOT NULL AND @Amt>0
    UPDATE FundPools SET Balance=Balance+@Amt,UpdatedAt=GETUTCDATE() WHERE Id=@FPId AND IsDeleted=0;
END
GO
PRINT 'Expenses SPs -- DONE';
GO

PRINT '=== STEP 17: Waivers SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetWaivers
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @TenantId INT=NULL,@ContractId NVARCHAR(MAX)=NULL,
  @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Waivers w
  WHERE w.IsDeleted=0
    AND(@TenantId IS NULL OR w.TenantId=@TenantId)
    AND(@ContractId IS NULL OR w.ContractId=@ContractId)
    AND(@DateFrom IS NULL OR CAST(w.WaiverDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(w.WaiverDate AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR w.ContractId LIKE '%'+@SearchText+'%');
  SELECT w.Id,w.TenantId,ISNULL(t.Name,'') TenantName,w.ContractId,w.InstallmentNo,
    w.OriginalAmount,w.WaiverAmount,w.BalanceAmount,ISNULL(w.Remark,'') Remark,w.WaiverDate,
    ISNULL(w.CreatedBy,'') CreatedBy,w.AddedBy
  FROM Waivers w
  LEFT JOIN Tenants t ON t.Id=w.TenantId AND t.IsDeleted=0
  WHERE w.IsDeleted=0
    AND(@TenantId IS NULL OR w.TenantId=@TenantId)
    AND(@ContractId IS NULL OR w.ContractId=@ContractId)
    AND(@DateFrom IS NULL OR CAST(w.WaiverDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(w.WaiverDate AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR w.ContractId LIKE '%'+@SearchText+'%')
  ORDER BY w.WaiverDate DESC OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetWaiverById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT w.Id,w.TenantId,ISNULL(t.Name,'') TenantName,w.ContractId,w.InstallmentNo,
    w.OriginalAmount,w.WaiverAmount,w.BalanceAmount,ISNULL(w.Remark,'') Remark,w.WaiverDate,
    ISNULL(w.CreatedBy,'') CreatedBy,w.AddedBy
  FROM Waivers w
  LEFT JOIN Tenants t ON t.Id=w.TenantId AND t.IsDeleted=0
  WHERE w.Id=@Id AND w.IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteWaiver @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Waivers SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO
PRINT 'Waivers SPs -- DONE';
GO
PRINT '=== STEP 18: TxnRecords SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
  @PageNumber INT=1,@PageSize INT=2147483647,
  @ContractId NVARCHAR(MAX)=NULL,@TenantId INT=NULL,
  @CampId INT=NULL,@TxnType NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM TxnRecords tr
  WHERE tr.IsDeleted=0
    AND(@ContractId IS NULL OR tr.ContractId=@ContractId)
    AND(@TenantId   IS NULL OR tr.TenantId=@TenantId)
    AND(@CampId     IS NULL OR tr.CampId=@CampId)
    AND(@TxnType    IS NULL OR tr.TxnType=@TxnType);
  SELECT tr.Id,tr.TxnId,tr.TxnType,tr.ContractId,tr.ContractCode,tr.TenantId,
    ISNULL(t.Name,'') TenantName,tr.CampId,ISNULL(c.Name,'') CampName,
    tr.TotalAmount,tr.Amount,tr.TxnDate,tr.FromDate,tr.ToDate,
    ISNULL(tr.PaymentMode,'') PaymentMode,tr.PaymentModeId,ISNULL(tr.ChequeNumber,'') ChequeNumber,
    tr.FundPoolId,ISNULL(tr.FundPoolName,'') FundPoolName,ISNULL(tr.Description,'') Description,
    ISNULL(tr.ReceivedBy,'') ReceivedBy,ISNULL(tr.ReceivedContact,'') ReceivedContact,
    ISNULL(tr.IssuedBy,'') IssuedBy,tr.InstallmentNo,
    ISNULL(tr.AppliedInstallments,'') AppliedInstallments,ISNULL(tr.Unallocated,0) Unallocated,
    tr.CreatedAt,tr.UpdatedAt,tr.AddedBy,tr.UpdatedBy
  FROM TxnRecords tr
  LEFT JOIN Tenants t ON t.Id=tr.TenantId AND t.IsDeleted=0
  LEFT JOIN Camps c ON c.Id=tr.CampId AND c.IsDeleted=0
  WHERE tr.IsDeleted=0
    AND(@ContractId IS NULL OR tr.ContractId=@ContractId)
    AND(@TenantId   IS NULL OR tr.TenantId=@TenantId)
    AND(@CampId     IS NULL OR tr.CampId=@CampId)
    AND(@TxnType    IS NULL OR tr.TxnType=@TxnType)
  ORDER BY tr.TxnDate DESC,tr.Id DESC
  OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  -- Reverse ContractInstallment paid amount if CR record
  DECLARE @TxnType NVARCHAR(10),@ContractId NVARCHAR(MAX),@InstNo INT,@Amt DECIMAL(18,2);
  SELECT @TxnType=TxnType,@ContractId=ContractId,@InstNo=InstallmentNo,@Amt=Amount FROM TxnRecords WHERE Id=@Id;
  IF @TxnType='CR' AND @ContractId IS NOT NULL AND @InstNo IS NOT NULL
  BEGIN
    UPDATE ContractInstallments
    SET PaidAmount=CASE WHEN ISNULL(PaidAmount,0)-@Amt<0 THEN 0 ELSE ISNULL(PaidAmount,0)-@Amt END,
        Status=CASE WHEN ISNULL(PaidAmount,0)-@Amt<=0 THEN 'Pending'
                    WHEN ISNULL(PaidAmount,0)-@Amt<Amount THEN 'Partial' ELSE 'Paid' END,
        PaidDate=NULL,UpdatedAt=GETUTCDATE()
    WHERE ContractId=@ContractId AND InstallmentNo=@InstNo;
  END
  UPDATE TxnRecords SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
PRINT 'TxnRecords SPs -- DONE';
GO

PRINT '=== STEP 19: Staff SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetStaff
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM Staff
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
        OR StaffId LIKE '%'+@SearchText+'%' OR Contact LIKE '%'+@SearchText+'%');
  SELECT Id,StaffId,Name,Role,Designation,Contact,Email,Address,Username,Password,LoginAccess,
    Status,Remarks,EmiratesId,PassportNo,Nationality,JobTitle,MoveInDate,VisaExpiry,
    EmiratesIdIssueDate,EmiratesIdExpiryDate,PassportIssueDate,PassportExpiryDate,
    LabourCardIssueDate,LabourCardExpiryDate,IloeIssueDate,IloeExpiryDate,
    InsuranceIssueDate,InsuranceExpiryDate,
    ISNULL(EmiratesIdDocument,'') EmiratesIdDocument,ISNULL(PassportDocument,'') PassportDocument,
    ISNULL(LabourCardDocument,'') LabourCardDocument,ISNULL(IloeDocument,'') IloeDocument,
    ISNULL(InsuranceDocument,'') InsuranceDocument,
    CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM Staff
  WHERE IsDeleted=0 AND(@Status IS NULL OR Status=@Status)
    AND(@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%'
        OR StaffId LIKE '%'+@SearchText+'%' OR Contact LIKE '%'+@SearchText+'%')
  ORDER BY Name OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetStaffById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT Id,StaffId,Name,Role,Designation,Contact,Email,Address,Username,Password,LoginAccess,
    Status,Remarks,EmiratesId,PassportNo,Nationality,JobTitle,MoveInDate,VisaExpiry,
    EmiratesIdIssueDate,EmiratesIdExpiryDate,PassportIssueDate,PassportExpiryDate,
    LabourCardIssueDate,LabourCardExpiryDate,IloeIssueDate,IloeExpiryDate,
    InsuranceIssueDate,InsuranceExpiryDate,
    ISNULL(EmiratesIdDocument,'') EmiratesIdDocument,ISNULL(PassportDocument,'') PassportDocument,
    ISNULL(LabourCardDocument,'') LabourCardDocument,ISNULL(IloeDocument,'') IloeDocument,
    ISNULL(InsuranceDocument,'') InsuranceDocument,
    CreatedAt,UpdatedAt,AddedBy,UpdatedBy
  FROM Staff WHERE Id=@Id AND IsDeleted=0;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteStaff @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  UPDATE Staff SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  -- Also soft-delete linked AppUser
  UPDATE AppUsers SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE()
  WHERE Source='Staff' AND SourceId=@Id AND IsDeleted=0;
END
GO
PRINT 'Staff SPs -- DONE';
GO
PRINT '=== STEP 20: Contracts SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetContracts
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @Status NVARCHAR(MAX)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
  @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(DISTINCT c.Id) FROM Contracts c
  WHERE c.IsDeleted=0
    AND(@Status IS NULL OR c.Status=@Status)
    AND(@TenantId IS NULL OR c.TenantId=@TenantId)
    AND(@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId))
    AND(@DateFrom IS NULL OR CAST(c.StartDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(c.StartDate AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%'
        OR EXISTS(SELECT 1 FROM Tenants t WHERE t.Id=c.TenantId AND t.Name LIKE '%'+@SearchText+'%'));
  SELECT c.Id,c.ContractId,c.TenantId,ISNULL(t.Name,'') TenantName,
    c.StartDate,c.Months,c.EndDate,c.MonthlyTotal,c.ContractTotal,
    ISNULL(c.SecurityDeposit,0) SecurityDeposit,
    ISNULL(c.SecurityDepositStatus,'Pending') SecurityDepositStatus,
    ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,
    ISNULL(c.ContractType,'Monthly') ContractType,
    ISNULL(c.InstallmentType,'monthly') InstallmentType,
    ISNULL(c.IssuedBy,'') IssuedBy,ISNULL(c.Notes,'') Notes,ISNULL(c.LessorAmount,0) LessorAmount,
    c.Status,
    ISNULL(c.ContractPropertyUsage,'') ContractPropertyUsage,
    ISNULL(c.ContractBuildingName,'')  ContractBuildingName,
    ISNULL(c.ContractPropertyType,'')  ContractPropertyType,
    ISNULL(c.ContractLocation,'')      ContractLocation,
    ISNULL(c.ContractPropertyNo,'')    ContractPropertyNo,
    ISNULL(c.ContractPropertyArea,'')  ContractPropertyArea,
    ISNULL(c.ContractPremisesNo,'')    ContractPremisesNo,
    ISNULL(c.ContractPaymentMode,'')   ContractPaymentMode,
    ISNULL(c.ContractPlotNo,'')        ContractPlotNo,
    ISNULL(c.ContractMakaniNo,'')      ContractMakaniNo,
    ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0),0) TotalPaid,
    ISNULL((SELECT SUM(Amount-PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status<>'Paid' AND ISNULL(ci.IsDeleted,0)=0),0) TotalDue,
    NULL LastPaymentAmount,NULL LastPaymentDate,
    0 SdForfeitAmount,0 SdRefundAmount,0 SdAdjustAmount,
    c.CreatedAt,c.UpdatedAt,c.AddedBy,c.UpdatedBy
  FROM Contracts c
  LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
  WHERE c.IsDeleted=0
    AND(@Status IS NULL OR c.Status=@Status)
    AND(@TenantId IS NULL OR c.TenantId=@TenantId)
    AND(@CampId IS NULL OR EXISTS(SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=c.ContractId AND cc.CampId=@CampId))
    AND(@DateFrom IS NULL OR CAST(c.StartDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(c.StartDate AS DATE)<=CAST(@DateTo AS DATE))
    AND(@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%'
        OR EXISTS(SELECT 1 FROM Tenants t2 WHERE t2.Id=c.TenantId AND t2.Name LIKE '%'+@SearchText+'%'))
  ORDER BY c.CreatedAt DESC OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteContract @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  DECLARE @CId NVARCHAR(MAX);
  SELECT @CId=ContractId FROM Contracts WHERE Id=@Id;
  UPDATE Contracts SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  -- Also soft-delete installments
  IF @CId IS NOT NULL
    UPDATE ContractInstallments SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE()
    WHERE ContractId=@CId AND ISNULL(IsDeleted,0)=0;
END
GO
PRINT 'Contracts SPs -- DONE';
GO

PRINT '=== STEP 21: Payments SPs ===';
GO
CREATE OR ALTER PROCEDURE sp_GetPayments
  @PageNumber INT=1,@PageSize INT=2147483647,@SearchText NVARCHAR(MAX)=NULL,
  @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
  @ContractId NVARCHAR(MAX)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
  @Month INT=NULL,@Year INT=NULL,@PaymentStatus NVARCHAR(MAX)=NULL,
  @PaymentModeId INT=NULL,@DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
  @TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  SELECT @TotalRecords=COUNT(*) FROM ContractInstallments ci
  JOIN Contracts c ON c.ContractId=ci.ContractId AND c.IsDeleted=0
  WHERE ISNULL(ci.IsDeleted,0)=0
    AND(@ContractId IS NULL OR ci.ContractId=@ContractId)
    AND(@TenantId IS NULL OR c.TenantId=@TenantId)
    AND(@PaymentStatus IS NULL OR ci.Status=@PaymentStatus)
    AND(@Month IS NULL OR MONTH(ci.DueDate)=@Month)
    AND(@Year  IS NULL OR YEAR(ci.DueDate)=@Year)
    AND(@DateFrom IS NULL OR CAST(ci.DueDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(ci.DueDate AS DATE)<=CAST(@DateTo AS DATE));
  SELECT ci.Id,ci.ContractId,ci.InstallmentNo,ci.Amount,ci.DueDate,
    ISNULL(ci.PaidAmount,0) PaidAmount,ci.PaidDate,ci.Status,
    ISNULL(ci.PaymentMode,'') PaymentMode,ci.PaymentModeId,
    ISNULL(ci.ChequeNumber,'') ChequeNumber,ISNULL(ci.ClearanceDate,'') ClearanceDate,
    ISNULL(ci.Description,'') Description,ISNULL(ci.ReceivedBy,'') ReceivedBy,
    ISNULL(ci.ReceivedContact,'') ReceivedContact,ci.FundPoolId,
    ISNULL(ci.FundPoolName,'') FundPoolName,ISNULL(ci.IssuedBy,'') IssuedBy,
    ISNULL(ci.AddedBy,NULL) AddedBy
  FROM ContractInstallments ci
  JOIN Contracts c ON c.ContractId=ci.ContractId AND c.IsDeleted=0
  WHERE ISNULL(ci.IsDeleted,0)=0
    AND(@ContractId IS NULL OR ci.ContractId=@ContractId)
    AND(@TenantId IS NULL OR c.TenantId=@TenantId)
    AND(@PaymentStatus IS NULL OR ci.Status=@PaymentStatus)
    AND(@Month IS NULL OR MONTH(ci.DueDate)=@Month)
    AND(@Year  IS NULL OR YEAR(ci.DueDate)=@Year)
    AND(@DateFrom IS NULL OR CAST(ci.DueDate AS DATE)>=CAST(@DateFrom AS DATE))
    AND(@DateTo   IS NULL OR CAST(ci.DueDate AS DATE)<=CAST(@DateTo AS DATE))
  ORDER BY ci.DueDate OFFSET(@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetPaymentById @Id INT AS BEGIN
  SET NOCOUNT ON;
  SELECT ci.Id,ci.ContractId,ci.InstallmentNo,ci.Amount,ci.DueDate,
    ISNULL(ci.PaidAmount,0) PaidAmount,ci.PaidDate,ci.Status,
    ISNULL(ci.PaymentMode,'') PaymentMode,ci.PaymentModeId,
    ISNULL(ci.ChequeNumber,'') ChequeNumber,ISNULL(ci.ClearanceDate,'') ClearanceDate,
    ISNULL(ci.Description,'') Description,ISNULL(ci.ReceivedBy,'') ReceivedBy,
    ISNULL(ci.ReceivedContact,'') ReceivedContact,ci.FundPoolId,
    ISNULL(ci.FundPoolName,'') FundPoolName,ISNULL(ci.IssuedBy,'') IssuedBy,
    ISNULL(ci.AddedBy,NULL) AddedBy
  FROM ContractInstallments ci WHERE ci.Id=@Id AND ISNULL(ci.IsDeleted,0)=0;
END
GO
PRINT 'Payments SPs -- DONE';
GO
PRINT '=== STEP 22: Final Verification Query ===';
GO
-- Check all soft-delete SPs exist
SELECT
  name AS SP_Name,
  CASE WHEN OBJECT_ID(name,'P') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS Status
FROM (VALUES
  ('sp_GetAccountsHeads'),('sp_GetAccountsHeadById'),('sp_CreateAccountsHead'),('sp_UpdateAccountsHead'),('sp_DeleteAccountsHead'),
  ('sp_GetDesignations'),('sp_GetDesignationById'),('sp_CreateDesignation'),('sp_UpdateDesignation'),('sp_DeleteDesignation'),
  ('sp_GetFloors'),('sp_GetFloorById'),('sp_CreateFloor'),('sp_UpdateFloor'),('sp_DeleteFloor'),
  ('sp_GetFundPools'),('sp_GetFundPoolById'),('sp_CreateFundPool'),('sp_UpdateFundPool'),('sp_DeleteFundPool'),
  ('sp_GetPaymentModes'),('sp_CreatePaymentMode'),('sp_UpdatePaymentMode'),('sp_DeletePaymentMode'),
  ('sp_GetRoomStatuses'),('sp_CreateRoomStatus'),('sp_UpdateRoomStatus'),('sp_DeleteRoomStatus'),
  ('sp_GetRoles'),('sp_GetRoleById'),('sp_CreateRole'),('sp_UpdateRole'),('sp_DeleteRole'),
  ('sp_GetOtherPersons'),('sp_GetOtherPersonById'),('sp_CreateOtherPerson'),('sp_UpdateOtherPerson'),('sp_DeleteOtherPerson'),
  ('sp_GetOwners'),('sp_GetOwnerById'),('sp_CreateOwner'),('sp_UpdateOwner'),('sp_DeleteOwner'),
  ('sp_GetPartners'),('sp_GetPartnerById'),('sp_CreatePartner'),('sp_UpdatePartner'),('sp_DeletePartner'),
  ('sp_GetTenants'),('sp_GetTenantById'),('sp_CreateTenant'),('sp_UpdateTenant'),('sp_DeleteTenant'),
  ('sp_GetRooms'),('sp_GetRoomById'),('sp_CreateRoom'),('sp_UpdateRoom'),('sp_DeleteRoom'),('sp_BulkCreateRooms'),
  ('sp_GetCamps'),('sp_GetCampById'),('sp_DeleteCamp'),
  ('sp_GetUsers'),('sp_GetUserById'),('sp_DeleteUser'),
  ('sp_GetIncomes'),('sp_GetIncomeById'),('sp_DeleteIncome'),
  ('sp_GetExpenses'),('sp_GetExpenseById'),('sp_DeleteExpense'),
  ('sp_GetWaivers'),('sp_GetWaiverById'),('sp_DeleteWaiver'),
  ('sp_GetTxnRecords'),('sp_DeleteTxnRecord'),
  ('sp_GetStaff'),('sp_GetStaffById'),('sp_DeleteStaff'),
  ('sp_GetContracts'),('sp_DeleteContract'),
  ('sp_GetPayments'),('sp_GetPaymentById')
) AS v(name);
GO
PRINT '=== STEP 23: Final PASS/FAIL Summary per Table ===';
GO
SELECT
  t.TABLE_NAME,
  CASE WHEN MAX(CASE WHEN c.COLUMN_NAME='AddedBy'   THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END AS AddedBy,
  CASE WHEN MAX(CASE WHEN c.COLUMN_NAME='UpdatedBy' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END AS UpdatedBy,
  CASE WHEN MAX(CASE WHEN c.COLUMN_NAME='DeletedBy' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END AS DeletedBy,
  CASE WHEN MAX(CASE WHEN c.COLUMN_NAME='IsDeleted' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END AS IsDeleted,
  CASE WHEN MAX(CASE WHEN c.COLUMN_NAME IN('AddedBy','UpdatedBy','DeletedBy','IsDeleted') THEN 1 ELSE 0 END)=1
       AND COUNT(DISTINCT c.COLUMN_NAME)=4 THEN 'ALL PASS' ELSE 'INCOMPLETE' END AS Overall
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c ON c.TABLE_NAME=t.TABLE_NAME
  AND c.COLUMN_NAME IN('AddedBy','UpdatedBy','DeletedBy','IsDeleted')
WHERE t.TABLE_TYPE='BASE TABLE'
  AND t.TABLE_NAME IN('AccountsHeads','AppUsers','CampOwners','CampPartners',
    'Camps','CompanyAssets','ContractCamps','ContractCancellations',
    'ContractInstallments','ContractRenewals','ContractRoomInstallments',
    'ContractRooms','ContractRoomsTrns','Contracts','ContractTerms',
    'Designations','Expenses','Floors','FundPools','Incomes',
    'OtherPersons','OutgoingPayments','OwnerContracts','OwnerInstallments',
    'OwnerMonthlyContractInstallments','Owners','OwnerTransactions',
    'Partners','PaymentModes','Payments','Roles','Rooms',
    'RoomStatuses','Staff','Tenants','TxnRecords','Waivers','ActivityLog')
GROUP BY t.TABLE_NAME ORDER BY t.TABLE_NAME;
GO
PRINT '====================================================';
PRINT '086 - FINAL END-TO-END AUDIT FIX COMPLETE';
PRINT 'Tables with ALL PASS = Fully Compliant';
PRINT 'SPs with EXISTS = Soft Delete + Audit Enforced';
PRINT '====================================================';
GO
