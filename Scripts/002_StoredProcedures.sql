-- ============================================================
-- TFMS Software - All Stored Procedures
-- Database: TFMS_softwareDB
-- ============================================================
USE TFMS_softwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- DASHBOARD
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetDashboardStats
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ThisMonth INT = MONTH(GETUTCDATE()), @ThisYear INT = YEAR(GETUTCDATE());
    SELECT
        (SELECT COUNT(*) FROM Camps    WHERE Status='Active') AS TotalCamps,
        (SELECT COUNT(*) FROM Rooms)                          AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Occupied=1)         AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Occupied=0)         AS VacantRooms,
        (SELECT COUNT(*) FROM Tenants)                        AS TotalTenants,
        (SELECT COUNT(*) FROM Tenants  WHERE Status='Active') AS ActiveTenants,
        (SELECT COUNT(*) FROM Partners WHERE Status='Active') AS TotalPartners,
        (SELECT COUNT(*) FROM Contracts WHERE Status='Active') AS ActiveContracts,
        ISNULL((SELECT SUM(Amount)     FROM Payments WHERE MONTH(DueDate)=@ThisMonth AND YEAR(DueDate)=@ThisYear),0) AS TotalDueThisMonth,
        ISNULL((SELECT SUM(PaidAmount) FROM Payments WHERE MONTH(DueDate)=@ThisMonth AND YEAR(DueDate)=@ThisYear),0) AS TotalCollectedThisMonth,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM Payments WHERE Status IN('Pending','Partial','Overdue')),0) AS OutstandingBalance,
        (SELECT COUNT(*) FROM Payments WHERE Status='Overdue') AS OverduePayments;
END
GO

-- ══════════════════════════════════════════════════════════════
-- PARTNERS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetPartners
    @PageNumber    INT, @PageSize INT,
    @SearchText    NVARCHAR(200) = NULL,
    @SortBy        NVARCHAR(50)  = NULL,
    @SortDirection NVARCHAR(4)   = 'ASC',
    @Status        NVARCHAR(20)  = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords = COUNT(*)
    FROM Partners
    WHERE (@Status     IS NULL OR Status LIKE @Status)
      AND (@SearchText IS NULL OR Name    LIKE '%'+@SearchText+'%'
                               OR Contact LIKE '%'+@SearchText+'%'
                               OR Mobile  LIKE '%'+@SearchText+'%'
                               OR Email   LIKE '%'+@SearchText+'%'
                               OR Code    LIKE '%'+@SearchText+'%');

    SELECT Id,Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt
    FROM Partners
    WHERE (@Status     IS NULL OR Status LIKE @Status)
      AND (@SearchText IS NULL OR Name    LIKE '%'+@SearchText+'%'
                               OR Contact LIKE '%'+@SearchText+'%'
                               OR Mobile  LIKE '%'+@SearchText+'%'
                               OR Email   LIKE '%'+@SearchText+'%'
                               OR Code    LIKE '%'+@SearchText+'%')
    ORDER BY
        CASE WHEN @SortBy='Name'      AND @SortDirection='ASC'  THEN Name      END ASC,
        CASE WHEN @SortBy='Name'      AND @SortDirection='DESC' THEN Name      END DESC,
        CASE WHEN @SortBy='Code'      AND @SortDirection='ASC'  THEN Code      END ASC,
        CASE WHEN @SortBy='Code'      AND @SortDirection='DESC' THEN Code      END DESC,
        CASE WHEN @SortBy='CreatedAt' AND @SortDirection='DESC' THEN CreatedAt END DESC,
        CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt FROM Partners WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreatePartner
    @Name NVARCHAR(200), @Contact NVARCHAR(100), @Mobile NVARCHAR(20),
    @Email NVARCHAR(150), @Status NVARCHAR(20), @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20) = 'PRT-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Partners) AS NVARCHAR),6);
    INSERT INTO Partners(Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Contact,@Mobile,@Email,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdatePartner
    @Id INT, @Name NVARCHAR(200), @Contact NVARCHAR(100),
    @Mobile NVARCHAR(20), @Email NVARCHAR(150), @Status NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Partners SET Name=@Name,Contact=@Contact,Mobile=@Mobile,Email=@Email,
        Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_DeletePartner @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Partners WHERE Id=@Id;
END
GO

-- ══════════════════════════════════════════════════════════════
-- OWNERS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetOwners
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL, @SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Owners
    WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Email LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt FROM Owners
    WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Email LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC,
             CASE WHEN @SortBy='Name' AND @SortDirection='DESC' THEN Name END DESC,
             CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetOwnerById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt FROM Owners WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateOwner @Name NVARCHAR(200),@Contact NVARCHAR(20),@Email NVARCHAR(150),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='OWN-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Owners) AS NVARCHAR),6);
    INSERT INTO Owners(Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt) VALUES(@Code,@Name,@Contact,@Email,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateOwner @Id INT,@Name NVARCHAR(200),@Contact NVARCHAR(20),@Email NVARCHAR(150),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE Owners SET Name=@Name,Contact=@Contact,Email=@Email,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteOwner @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Owners WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- FLOORS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetFloors
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Floors WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT Id,Name,Number,Status,CreatedAt,UpdatedAt FROM Floors
    WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Number' AND @SortDirection='ASC' THEN Number END ASC,
             CASE WHEN @SortBy='Name'   AND @SortDirection='ASC' THEN Name   END ASC,
             Number ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetFloorById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Name,Number,Status,CreatedAt,UpdatedAt FROM Floors WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateFloor @Name NVARCHAR(100),@Number INT,@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN SET NOCOUNT ON; INSERT INTO Floors(Name,Number,Status,CreatedAt,UpdatedAt) VALUES(@Name,@Number,@Status,GETUTCDATE(),GETUTCDATE()); SET @NewId=SCOPE_IDENTITY(); END
GO
CREATE OR ALTER PROCEDURE sp_UpdateFloor @Id INT,@Name NVARCHAR(100),@Number INT,@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE Floors SET Name=@Name,Number=@Number,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteFloor @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Floors WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- ROOM STATUSES / PAYMENT MODES
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetRoomStatuses AS BEGIN SET NOCOUNT ON; SELECT Id,Name FROM RoomStatuses ORDER BY Name; END
GO
CREATE OR ALTER PROCEDURE sp_CreateRoomStatus @Name NVARCHAR(50),@NewId INT OUTPUT AS BEGIN SET NOCOUNT ON; INSERT INTO RoomStatuses(Name) VALUES(@Name); SET @NewId=SCOPE_IDENTITY(); END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRoomStatus @Id INT,@Name NVARCHAR(50) AS BEGIN SET NOCOUNT ON; UPDATE RoomStatuses SET Name=@Name WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRoomStatus @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM RoomStatuses WHERE Id=@Id; END
GO

CREATE OR ALTER PROCEDURE sp_GetPaymentModes @Status NVARCHAR(20)=NULL AS
BEGIN SET NOCOUNT ON; SELECT Id,Name,Status FROM PaymentModes WHERE (@Status IS NULL OR Status=@Status) ORDER BY Name; END
GO
CREATE OR ALTER PROCEDURE sp_CreatePaymentMode @Name NVARCHAR(50),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN SET NOCOUNT ON; INSERT INTO PaymentModes(Name,Status) VALUES(@Name,@Status); SET @NewId=SCOPE_IDENTITY(); END
GO
CREATE OR ALTER PROCEDURE sp_UpdatePaymentMode @Id INT,@Name NVARCHAR(50),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE PaymentModes SET Name=@Name,Status=@Status WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeletePaymentMode @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM PaymentModes WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- FUND POOLS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetFundPools
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM FundPools WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Name,Status,Balance,CreatedAt,UpdatedAt FROM FundPools
    WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC,
             CASE WHEN @SortBy='Balance' AND @SortDirection='DESC' THEN Balance END DESC,
             CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetFundPoolById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Code,Name,Status,Balance,CreatedAt,UpdatedAt FROM FundPools WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateFundPool @Name NVARCHAR(200),@Balance DECIMAL(18,2),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='FP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM FundPools) AS NVARCHAR),6);
    INSERT INTO FundPools(Code,Name,Balance,Status,CreatedAt,UpdatedAt) VALUES(@Code,@Name,@Balance,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateFundPool @Id INT,@Name NVARCHAR(200),@Balance DECIMAL(18,2),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE FundPools SET Name=@Name,Balance=@Balance,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteFundPool @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM FundPools WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- ACCOUNTS HEADS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetAccountsHeads
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@Type NVARCHAR(30)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM AccountsHeads
    WHERE (@Status IS NULL OR Status=@Status) AND (@Type IS NULL OR Type=@Type)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Name,Type,Status,CreatedAt,UpdatedAt FROM AccountsHeads
    WHERE (@Status IS NULL OR Status=@Status) AND (@Type IS NULL OR Type=@Type)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC,
             CASE WHEN @SortBy='Type' AND @SortDirection='ASC' THEN Type END ASC,
             Name ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetAccountsHeadById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Code,Name,Type,Status,CreatedAt,UpdatedAt FROM AccountsHeads WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateAccountsHead @Name NVARCHAR(200),@Type NVARCHAR(30),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='AH-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AccountsHeads) AS NVARCHAR),6);
    INSERT INTO AccountsHeads(Code,Name,Type,Status,CreatedAt,UpdatedAt) VALUES(@Code,@Name,@Type,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateAccountsHead @Id INT,@Name NVARCHAR(200),@Type NVARCHAR(30),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE AccountsHeads SET Name=@Name,Type=@Type,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteAccountsHead @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM AccountsHeads WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- DESIGNATIONS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetDesignations
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Designations WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Name,Status,CreatedAt,UpdatedAt FROM Designations
    WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC, Name ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetDesignationById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Code,Name,Status,CreatedAt,UpdatedAt FROM Designations WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateDesignation @Name NVARCHAR(100),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='DES-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Designations) AS NVARCHAR),6);
    INSERT INTO Designations(Code,Name,Status,CreatedAt,UpdatedAt) VALUES(@Code,@Name,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateDesignation @Id INT,@Name NVARCHAR(100),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE Designations SET Name=@Name,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteDesignation @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Designations WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- OTHER PERSONS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetOtherPersons
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@Designation NVARCHAR(50)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OtherPersons
    WHERE (@Status IS NULL OR Status=@Status) AND (@Designation IS NULL OR Designation=@Designation)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Mobile LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt
    FROM OtherPersons
    WHERE (@Status IS NULL OR Status=@Status) AND (@Designation IS NULL OR Designation=@Designation)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%' OR Mobile LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC, Name ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetOtherPersonById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt FROM OtherPersons WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateOtherPerson
    @Designation NVARCHAR(50),@Name NVARCHAR(200),@Mobile NVARCHAR(20),@Email NVARCHAR(150),
    @Address NVARCHAR(300),@City NVARCHAR(100),@State NVARCHAR(100),@Pincode NVARCHAR(10),
    @Remarks NVARCHAR(300),@Status NVARCHAR(20),@NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='OP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OtherPersons) AS NVARCHAR),6);
    INSERT INTO OtherPersons(Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt)
    VALUES(@Code,@Designation,@Name,@Mobile,@Email,@Address,@City,@State,@Pincode,@Remarks,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateOtherPerson
    @Id INT,@Designation NVARCHAR(50),@Name NVARCHAR(200),@Mobile NVARCHAR(20),@Email NVARCHAR(150),
    @Address NVARCHAR(300),@City NVARCHAR(100),@State NVARCHAR(100),@Pincode NVARCHAR(10),
    @Remarks NVARCHAR(300),@Status NVARCHAR(20)
AS
BEGIN SET NOCOUNT ON; UPDATE OtherPersons SET Designation=@Designation,Name=@Name,Mobile=@Mobile,Email=@Email,Address=@Address,City=@City,State=@State,Pincode=@Pincode,Remarks=@Remarks,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteOtherPerson @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM OtherPersons WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- ROLES
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetRoles
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Roles WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%');
    SELECT Id,RoleCode,RoleName,Status,CreatedAt,UpdatedAt FROM Roles
    WHERE (@Status IS NULL OR Status=@Status) AND (@SearchText IS NULL OR RoleName LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='RoleName' AND @SortDirection='ASC' THEN RoleName END ASC, RoleName ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoleById @Id INT AS BEGIN SET NOCOUNT ON; SELECT Id,RoleCode,RoleName,Status,CreatedAt,UpdatedAt FROM Roles WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_CreateRole @RoleName NVARCHAR(100),@Status NVARCHAR(20),@NewId INT OUTPUT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='ROL-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Roles) AS NVARCHAR),6);
    INSERT INTO Roles(RoleCode,RoleName,Status,CreatedAt,UpdatedAt) VALUES(@Code,@RoleName,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRole @Id INT,@RoleName NVARCHAR(100),@Status NVARCHAR(20) AS
BEGIN SET NOCOUNT ON; UPDATE Roles SET RoleName=@RoleName,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id; END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRole @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Roles WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- CAMPS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetCamps
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Camps WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT Id,Code,Name,Rooms,Floors,Status,CreatedAt,UpdatedAt FROM Camps
    WHERE (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN Name END ASC, Name ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCampById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id,c.Code,c.Name,c.Rooms,c.Floors,c.Status,c.CreatedAt,c.UpdatedAt,
           cp.Id CampPartnerId, cp.PartnerId, p.Name PartnerName, cp.ShareType PartnerShareType, cp.ShareValue PartnerShareValue,
           co.Id CampOwnerId,   co.OwnerId,   o.Name OwnerName,   co.ShareType OwnerShareType,   co.ShareValue OwnerShareValue
    FROM Camps c
    LEFT JOIN CampPartners cp ON cp.CampId=c.Id LEFT JOIN Partners p ON p.Id=cp.PartnerId
    LEFT JOIN CampOwners   co ON co.CampId=c.Id LEFT JOIN Owners   o ON o.Id=co.OwnerId
    WHERE c.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name NVARCHAR(200),@Status NVARCHAR(20),
    @PartnersJson NVARCHAR(MAX),@OwnersJson NVARCHAR(MAX),@NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(20)='CMP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Camps) AS NVARCHAR),6);
    INSERT INTO Camps(Code,Name,Status,CreatedAt,UpdatedAt) VALUES(@Code,@Name,@Status,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    -- Partners
    INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
    SELECT @NewId,PartnerId,ShareType,ShareValue FROM OPENJSON(@PartnersJson)
    WITH(PartnerId INT,ShareType NVARCHAR(20),ShareValue DECIMAL(18,2));
    -- Owners
    INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
    SELECT @NewId,OwnerId,ShareType,ShareValue FROM OPENJSON(@OwnersJson)
    WITH(OwnerId INT,ShareType NVARCHAR(20),ShareValue DECIMAL(18,2));
    -- Update counts
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@NewId),
                     Floors=(SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@NewId)
    WHERE Id=@NewId;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id INT,@Name NVARCHAR(200),@Status NVARCHAR(20),
    @PartnersJson NVARCHAR(MAX),@OwnersJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET Name=@Name,Status=@Status,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    DELETE FROM CampPartners WHERE CampId=@Id;
    DELETE FROM CampOwners   WHERE CampId=@Id;
    INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
    SELECT @Id,PartnerId,ShareType,ShareValue FROM OPENJSON(@PartnersJson)
    WITH(PartnerId INT,ShareType NVARCHAR(20),ShareValue DECIMAL(18,2));
    INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
    SELECT @Id,OwnerId,ShareType,ShareValue FROM OPENJSON(@OwnersJson)
    WITH(OwnerId INT,ShareType NVARCHAR(20),ShareValue DECIMAL(18,2));
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteCamp @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Camps WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- ROOMS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetRooms
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@CampId INT=NULL,@FloorId INT=NULL,
    @RoomStatus NVARCHAR(30)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Rooms r
    JOIN Camps c ON c.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId
    WHERE (@CampId IS NULL OR r.CampId=@CampId) AND (@FloorId IS NULL OR r.FloorId=@FloorId)
      AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%' OR c.Name LIKE '%'+@SearchText+'%');

    SELECT r.Id,r.RoomNo,r.CampId,c.Name CampName,r.FloorId,f.Name FloorName,
           r.Occupied,r.MonthlyPrice,r.Status,r.OtherDetails,r.CreatedAt,r.UpdatedAt
    FROM Rooms r JOIN Camps c ON c.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId
    WHERE (@CampId IS NULL OR r.CampId=@CampId) AND (@FloorId IS NULL OR r.FloorId=@FloorId)
      AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%' OR c.Name LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='RoomNo' AND @SortDirection='ASC' THEN r.RoomNo END ASC,
             CASE WHEN @SortBy='MonthlyPrice' AND @SortDirection='DESC' THEN r.MonthlyPrice END DESC,
             r.RoomNo ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetRoomById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.Id,r.RoomNo,r.CampId,c.Name CampName,r.FloorId,f.Name FloorName,
           r.Occupied,r.MonthlyPrice,r.Status,r.OtherDetails,r.CreatedAt,r.UpdatedAt
    FROM Rooms r JOIN Camps c ON c.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId WHERE r.Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateRoom
    @RoomNo NVARCHAR(20),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2),
    @Status NVARCHAR(30),@OtherDetails NVARCHAR(200),@NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Rooms(RoomNo,CampId,FloorId,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt)
    VALUES(@RoomNo,@CampId,@FloorId,@MonthlyPrice,@Status,@OtherDetails,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId),
                     Floors=(SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId) WHERE Id=@CampId;
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateRoom
    @Id INT,@RoomNo NVARCHAR(20),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2),
    @Status NVARCHAR(30),@OtherDetails NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Rooms SET RoomNo=@RoomNo,CampId=@CampId,FloorId=@FloorId,MonthlyPrice=@MonthlyPrice,
        Status=@Status,OtherDetails=@OtherDetails,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CampId INT=(SELECT CampId FROM Rooms WHERE Id=@Id);
    DELETE FROM Rooms WHERE Id=@Id;
    IF @CampId IS NOT NULL
        UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId),
                         Floors=(SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId) WHERE Id=@CampId;
END
GO

-- ══════════════════════════════════════════════════════════════
-- TENANTS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetTenants
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@Type NVARCHAR(20)=NULL,@CampId INT=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Tenants t
    WHERE (@Status IS NULL OR t.Status=@Status) AND (@Type IS NULL OR t.Type=@Type)
      AND (@CampId IS NULL OR t.Id IN (SELECT TenantId FROM Contracts WHERE CampId=@CampId AND Status='Active'))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.Email LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%');

    SELECT t.Id,t.Type,t.Name,t.Passport,t.Nationality,t.EmiratesId,t.Contact,t.Whatsapp,
           t.Email,t.Address,t.Status,t.Company,t.TradeLicense,t.LicensingAuthority,t.NumberOfCoOccupants,
           t.PlotNo,t.MakaniNo,t.PropertyArea,t.PremisesNo,t.LessorName,t.LessorEid,t.LessorLicense,
           t.LessorLicAuthority,t.LessorEmail,t.LessorPhone,t.CreatedAt,t.UpdatedAt
    FROM Tenants t
    WHERE (@Status IS NULL OR t.Status=@Status) AND (@Type IS NULL OR t.Type=@Type)
      AND (@CampId IS NULL OR t.Id IN (SELECT TenantId FROM Contracts WHERE CampId=@CampId AND Status='Active'))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.Email LIKE '%'+@SearchText+'%' OR t.EmiratesId LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='Name' AND @SortDirection='ASC' THEN t.Name END ASC,
             CASE WHEN @SortBy='Name' AND @SortDirection='DESC' THEN t.Name END DESC,
             t.CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
CREATE OR ALTER PROCEDURE sp_GetTenantById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id,Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
           Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,
           PremisesNo,LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,
           CreatedAt,UpdatedAt FROM Tenants WHERE Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_CreateTenant
    @Type NVARCHAR(20),@Name NVARCHAR(200),@Passport NVARCHAR(50),@Nationality NVARCHAR(50),
    @EmiratesId NVARCHAR(30),@Contact NVARCHAR(20),@Whatsapp NVARCHAR(20),@Email NVARCHAR(150),
    @Address NVARCHAR(500),@Status NVARCHAR(20),@Company NVARCHAR(200),@TradeLicense NVARCHAR(100),
    @LicensingAuthority NVARCHAR(100),@NumberOfCoOccupants NVARCHAR(10),@PlotNo NVARCHAR(30),
    @MakaniNo NVARCHAR(30),@PropertyArea NVARCHAR(20),@PremisesNo NVARCHAR(30),
    @LessorName NVARCHAR(200),@LessorEid NVARCHAR(30),@LessorLicense NVARCHAR(100),
    @LessorLicAuthority NVARCHAR(100),@LessorEmail NVARCHAR(150),@LessorPhone NVARCHAR(20),@NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
        Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
        LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
    VALUES(@Type,@Name,@Passport,@Nationality,@EmiratesId,@Contact,@Whatsapp,@Email,@Address,@Status,
        @Company,@TradeLicense,@LicensingAuthority,@NumberOfCoOccupants,@PlotNo,@MakaniNo,@PropertyArea,@PremisesNo,
        @LessorName,@LessorEid,@LessorLicense,@LessorLicAuthority,@LessorEmail,@LessorPhone,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_UpdateTenant
    @Id INT,@Type NVARCHAR(20),@Name NVARCHAR(200),@Passport NVARCHAR(50),@Nationality NVARCHAR(50),
    @EmiratesId NVARCHAR(30),@Contact NVARCHAR(20),@Whatsapp NVARCHAR(20),@Email NVARCHAR(150),
    @Address NVARCHAR(500),@Status NVARCHAR(20),@Company NVARCHAR(200),@TradeLicense NVARCHAR(100),
    @LicensingAuthority NVARCHAR(100),@NumberOfCoOccupants NVARCHAR(10),@PlotNo NVARCHAR(30),
    @MakaniNo NVARCHAR(30),@PropertyArea NVARCHAR(20),@PremisesNo NVARCHAR(30),
    @LessorName NVARCHAR(200),@LessorEid NVARCHAR(30),@LessorLicense NVARCHAR(100),
    @LessorLicAuthority NVARCHAR(100),@LessorEmail NVARCHAR(150),@LessorPhone NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Tenants SET Type=@Type,Name=@Name,Passport=@Passport,Nationality=@Nationality,EmiratesId=@EmiratesId,
        Contact=@Contact,Whatsapp=@Whatsapp,Email=@Email,Address=@Address,Status=@Status,Company=@Company,
        TradeLicense=@TradeLicense,LicensingAuthority=@LicensingAuthority,NumberOfCoOccupants=@NumberOfCoOccupants,
        PlotNo=@PlotNo,MakaniNo=@MakaniNo,PropertyArea=@PropertyArea,PremisesNo=@PremisesNo,
        LessorName=@LessorName,LessorEid=@LessorEid,LessorLicense=@LessorLicense,LessorLicAuthority=@LessorLicAuthority,
        LessorEmail=@LessorEmail,LessorPhone=@LessorPhone,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteTenant @Id INT AS BEGIN SET NOCOUNT ON; DELETE FROM Tenants WHERE Id=@Id; END
GO

-- ══════════════════════════════════════════════════════════════
-- CONTRACTS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetContracts
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @Status NVARCHAR(20)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
    @DateFrom NVARCHAR(20)=NULL,@DateTo NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Contracts c
    JOIN Tenants t ON t.Id=c.TenantId JOIN Camps ca ON ca.Id=c.CampId
    WHERE (@Status IS NULL OR c.Status=@Status) AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@DateFrom IS NULL OR c.StartDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR c.StartDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%' OR t.Name LIKE '%'+@SearchText+'%');

    SELECT c.Id,c.ContractId,c.TenantId,t.Name TenantName,c.CampId,ca.Name CampName,
           c.StartDate,c.Months,c.EndDate,c.MonthlyTotal,c.ContractTotal,c.Status,c.CreatedAt,c.UpdatedAt
    FROM Contracts c JOIN Tenants t ON t.Id=c.TenantId JOIN Camps ca ON ca.Id=c.CampId
    WHERE (@Status IS NULL OR c.Status=@Status) AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@DateFrom IS NULL OR c.StartDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR c.StartDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%' OR t.Name LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='StartDate' AND @SortDirection='DESC' THEN c.StartDate END DESC,
             c.CreatedAt DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetContractById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id,c.ContractId,c.TenantId,t.Name TenantName,c.CampId,ca.Name CampName,
           c.StartDate,c.Months,c.EndDate,c.MonthlyTotal,c.ContractTotal,c.Status,c.CreatedAt,c.UpdatedAt
    FROM Contracts c JOIN Tenants t ON t.Id=c.TenantId JOIN Camps ca ON ca.Id=c.CampId WHERE c.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetContractByContractId @ContractId NVARCHAR(20) AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id,c.ContractId,c.TenantId,t.Name TenantName,c.CampId,ca.Name CampName,
           c.StartDate,c.Months,c.EndDate,c.MonthlyTotal,c.ContractTotal,c.Status,c.CreatedAt,c.UpdatedAt
    FROM Contracts c JOIN Tenants t ON t.Id=c.TenantId JOIN Camps ca ON ca.Id=c.CampId WHERE c.ContractId=@ContractId;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId INT,@CampId INT,@StartDate DATE,@Months INT,
    @RoomIdsJson NVARCHAR(MAX),@NewContractId NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Generate ContractId
    SET @NewContractId='CNT-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Contracts) AS NVARCHAR),6);
    -- Calculate total from rooms
    DECLARE @MonthlyTotal DECIMAL(18,2)=0, @EndDate DATE=DATEADD(MONTH,@Months,@StartDate);
    SELECT @MonthlyTotal=SUM(r.MonthlyPrice) FROM Rooms r
    JOIN OPENJSON(@RoomIdsJson) WITH(RoomId INT '$') j ON j.RoomId=r.Id;
    INSERT INTO Contracts(ContractId,TenantId,CampId,StartDate,Months,EndDate,MonthlyTotal,ContractTotal,Status,CreatedAt,UpdatedAt)
    VALUES(@NewContractId,@TenantId,@CampId,@StartDate,@Months,@EndDate,@MonthlyTotal,@MonthlyTotal*@Months,'Active',GETUTCDATE(),GETUTCDATE());
    -- Link rooms
    INSERT INTO ContractRooms(ContractId,RoomId) SELECT @NewContractId,RoomId FROM OPENJSON(@RoomIdsJson) WITH(RoomId INT '$');
    -- Mark rooms occupied
    UPDATE Rooms SET Occupied=1,Status='Occupied',UpdatedAt=GETUTCDATE()
    WHERE Id IN(SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH(RoomId INT '$'));
    -- Generate installments (one per month)
    DECLARE @i INT=1;
    WHILE @i<=@Months
    BEGIN
        INSERT INTO Payments(ContractId,InstallmentNo,Amount,DueDate,PaidAmount,Status)
        VALUES(@NewContractId,@i,@MonthlyTotal,DATEADD(MONTH,@i-1,@StartDate),0,'Pending');
        SET @i+=1;
    END
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateContractStatus @ContractId NVARCHAR(20),@Status NVARCHAR(20) AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Contracts SET Status=@Status,UpdatedAt=GETUTCDATE() WHERE ContractId=@ContractId;
    IF @Status IN('Expired','Terminated')
        UPDATE Rooms SET Occupied=0,Status='Vacant',UpdatedAt=GETUTCDATE()
        WHERE Id IN(SELECT RoomId FROM ContractRooms WHERE ContractId=@ContractId);
END
GO
CREATE OR ALTER PROCEDURE sp_DeleteContract @Id INT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CID NVARCHAR(20)=(SELECT ContractId FROM Contracts WHERE Id=@Id);
    DELETE FROM Payments WHERE ContractId=@CID;
    DELETE FROM ContractRooms WHERE ContractId=@CID;
    DELETE FROM Contracts WHERE Id=@Id;
END
GO

-- ══════════════════════════════════════════════════════════════
-- PAYMENTS (Monthly Due)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetPayments
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @ContractId NVARCHAR(20)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
    @Month NVARCHAR(20)=NULL,@Year NVARCHAR(6)=NULL,
    @PaymentStatus NVARCHAR(20)=NULL,@PaymentModeId INT=NULL,
    @DateFrom NVARCHAR(20)=NULL,@DateTo NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Payments p
    JOIN Contracts c  ON c.ContractId=p.ContractId
    JOIN Tenants t    ON t.Id=c.TenantId
    JOIN Camps ca     ON ca.Id=c.CampId
    JOIN ContractRooms cr ON cr.ContractId=p.ContractId
    JOIN Rooms r      ON r.Id=cr.RoomId
    JOIN Floors f     ON f.Id=r.FloorId
    WHERE (@ContractId    IS NULL OR p.ContractId=@ContractId)
      AND (@TenantId      IS NULL OR c.TenantId=@TenantId)
      AND (@CampId        IS NULL OR c.CampId=@CampId)
      AND (@PaymentStatus IS NULL OR p.Status=@PaymentStatus)
      AND (@PaymentModeId IS NULL OR p.PaymentModeId=@PaymentModeId)
      AND (@Month IS NULL OR DATENAME(MONTH,p.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(p.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR p.ContractId LIKE '%'+@SearchText+'%' OR r.RoomNo LIKE '%'+@SearchText+'%');

    SELECT p.Id,p.ContractId,t.Name TenantName,'' TenantCode,r.RoomNo,ca.Name CampName,f.Name FloorName,
           p.InstallmentNo,p.Amount,p.DueDate,p.PaidAmount,(p.Amount-p.PaidAmount) BalanceAmount,
           p.PaidDate,p.Status,p.PaymentMode,p.PaymentModeId,p.ChequeNumber,p.ClearanceDate,
           p.Description,p.ReceivedBy,p.ReceivedContact,p.FundPoolId,p.FundPoolName,p.IssuedBy
    FROM Payments p
    JOIN Contracts c  ON c.ContractId=p.ContractId
    JOIN Tenants t    ON t.Id=c.TenantId
    JOIN Camps ca     ON ca.Id=c.CampId
    JOIN ContractRooms cr ON cr.ContractId=p.ContractId
    JOIN Rooms r      ON r.Id=cr.RoomId
    JOIN Floors f     ON f.Id=r.FloorId
    WHERE (@ContractId    IS NULL OR p.ContractId=@ContractId)
      AND (@TenantId      IS NULL OR c.TenantId=@TenantId)
      AND (@CampId        IS NULL OR c.CampId=@CampId)
      AND (@PaymentStatus IS NULL OR p.Status=@PaymentStatus)
      AND (@PaymentModeId IS NULL OR p.PaymentModeId=@PaymentModeId)
      AND (@Month IS NULL OR DATENAME(MONTH,p.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(p.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR p.ContractId LIKE '%'+@SearchText+'%' OR r.RoomNo LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='DueDate' AND @SortDirection='ASC'  THEN p.DueDate END ASC,
             CASE WHEN @SortBy='DueDate' AND @SortDirection='DESC' THEN p.DueDate END DESC,
             p.DueDate ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPaymentById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.Id,p.ContractId,t.Name TenantName,'' TenantCode,r.RoomNo,ca.Name CampName,f.Name FloorName,
           p.InstallmentNo,p.Amount,p.DueDate,p.PaidAmount,(p.Amount-p.PaidAmount) BalanceAmount,
           p.PaidDate,p.Status,p.PaymentMode,p.PaymentModeId,p.ChequeNumber,p.ClearanceDate,
           p.Description,p.ReceivedBy,p.ReceivedContact,p.FundPoolId,p.FundPoolName,p.IssuedBy
    FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId JOIN Tenants t ON t.Id=c.TenantId
    JOIN Camps ca ON ca.Id=c.CampId
    JOIN ContractRooms cr ON cr.ContractId=p.ContractId JOIN Rooms r ON r.Id=cr.RoomId
    JOIN Floors f ON f.Id=r.FloorId WHERE p.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId NVARCHAR(20),@InstallmentNo INT,@PaidAmount DECIMAL(18,2),@PaidDate DATE,
    @PaymentModeId INT=NULL,@PaymentMode NVARCHAR(50),@ChequeNumber NVARCHAR(50),
    @ClearanceDate NVARCHAR(50),@Description NVARCHAR(500),@ReceivedBy NVARCHAR(200),
    @ReceivedContact NVARCHAR(20),@FundPoolId INT=NULL,@FundPoolName NVARCHAR(200),@IssuedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Amount DECIMAL(18,2)=(SELECT Amount FROM Payments WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo);
    IF @Amount IS NULL BEGIN RAISERROR('Installment not found.',16,1); RETURN; END
    DECLARE @NewPaid DECIMAL(18,2)=@PaidAmount;
    DECLARE @NewStatus NVARCHAR(20)=CASE WHEN @NewPaid>=@Amount THEN 'Paid' WHEN @NewPaid>0 THEN 'Partial' ELSE 'Pending' END;
    UPDATE Payments SET PaidAmount=@NewPaid,PaidDate=@PaidDate,Status=@NewStatus,
        PaymentModeId=@PaymentModeId,PaymentMode=@PaymentMode,ChequeNumber=@ChequeNumber,
        ClearanceDate=@ClearanceDate,Description=@Description,ReceivedBy=@ReceivedBy,
        ReceivedContact=@ReceivedContact,FundPoolId=@FundPoolId,FundPoolName=@FundPoolName,IssuedBy=@IssuedBy
    WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo;
    -- Update fund pool balance
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance=Balance+@NewPaid,UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;
END
GO

-- ══════════════════════════════════════════════════════════════
-- WAIVERS
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetWaivers
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(200)=NULL,
    @SortBy NVARCHAR(50)=NULL,@SortDirection NVARCHAR(4)='ASC',
    @TenantId INT=NULL,@ContractId NVARCHAR(20)=NULL,
    @DateFrom NVARCHAR(20)=NULL,@DateTo NVARCHAR(20)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Waivers w
    JOIN Tenants t ON t.Id=w.TenantId
    WHERE (@TenantId   IS NULL OR w.TenantId=@TenantId)
      AND (@ContractId IS NULL OR w.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR w.WaiverDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%');

    SELECT w.Id,w.TenantId,t.Name TenantName,w.ContractId,w.InstallmentNo,
           w.OriginalAmount,w.WaiverAmount,w.BalanceAmount,w.Remark,w.WaiverDate
    FROM Waivers w JOIN Tenants t ON t.Id=w.TenantId
    WHERE (@TenantId   IS NULL OR w.TenantId=@TenantId)
      AND (@ContractId IS NULL OR w.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR w.WaiverDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY CASE WHEN @SortBy='WaiverDate' AND @SortDirection='DESC' THEN w.WaiverDate END DESC,
             w.WaiverDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetWaiverById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT w.Id,w.TenantId,t.Name TenantName,w.ContractId,w.InstallmentNo,
           w.OriginalAmount,w.WaiverAmount,w.BalanceAmount,w.Remark,w.WaiverDate
    FROM Waivers w JOIN Tenants t ON t.Id=w.TenantId WHERE w.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_CreateWaiver
    @TenantId INT,@ContractId NVARCHAR(20),@InstallmentNo INT,
    @WaiverAmount DECIMAL(18,2),@Remark NVARCHAR(300),@WaiverDate DATE,@NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OriginalAmount DECIMAL(18,2)=(SELECT Amount FROM Payments WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo);
    DECLARE @BalanceAmount DECIMAL(18,2)=@OriginalAmount-@WaiverAmount;
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,BalanceAmount,Remark,WaiverDate)
    VALUES(@TenantId,@ContractId,@InstallmentNo,@OriginalAmount,@WaiverAmount,@BalanceAmount,@Remark,@WaiverDate);
    SET @NewId=SCOPE_IDENTITY();
    -- Reduce the payment amount for this installment
    UPDATE Payments SET Amount=@BalanceAmount,
        Status=CASE WHEN PaidAmount>=@BalanceAmount THEN 'Paid' WHEN PaidAmount>0 THEN 'Partial' ELSE 'Pending' END
    WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteWaiver @Id INT AS
BEGIN
    SET NOCOUNT ON;
    -- Restore original payment amount before deleting waiver
    DECLARE @ContractId NVARCHAR(20),@InstallmentNo INT,@OriginalAmount DECIMAL(18,2);
    SELECT @ContractId=ContractId,@InstallmentNo=InstallmentNo,@OriginalAmount=OriginalAmount FROM Waivers WHERE Id=@Id;
    UPDATE Payments SET Amount=@OriginalAmount WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo;
    DELETE FROM Waivers WHERE Id=@Id;
END
GO
