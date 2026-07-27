-- ============================================================
-- 075: Fix column name mismatches
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Floors - no CampId column (standalone table)
CREATE OR ALTER PROCEDURE sp_GetFloors
    @PageNumber INT=1,@PageSize INT=2147483647,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Floors WHERE IsDeleted=0;
    SELECT * FROM Floors WHERE IsDeleted=0
    ORDER BY Id OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetFloorById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Floors WHERE Id=@Id AND IsDeleted=0;
END
GO

-- CompanyAssets - no Name column (has DocumentName, CompanyName)
CREATE OR ALTER PROCEDURE sp_GetCompanyAssets
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM CompanyAssets WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR DocumentName LIKE '%'+@SearchText+'%' OR CompanyName LIKE '%'+@SearchText+'%');
    SELECT * FROM CompanyAssets WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR DocumentName LIKE '%'+@SearchText+'%' OR CompanyName LIKE '%'+@SearchText+'%')
    ORDER BY Id OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- OtherPersons - columns: Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status
CREATE OR ALTER PROCEDURE sp_CreateOtherPerson
    @Code NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Mobile NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Designation NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',@City NVARCHAR(MAX)='',
    @State NVARCHAR(MAX)='',@Pincode NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO OtherPersons(Code,Name,Mobile,Email,Designation,Address,City,State,Pincode,Remarks,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Mobile,@Email,@Designation,@Address,@City,@State,@Pincode,@Remarks,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_GetOtherPersons
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OtherPersons WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%');
    SELECT * FROM OtherPersons WHERE IsDeleted=0
      AND (@Status IS NULL OR Status=@Status)
      AND (@SearchText IS NULL OR Name LIKE '%'+@SearchText+'%' OR Code LIKE '%'+@SearchText+'%')
    ORDER BY Name OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetOtherPersonById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM OtherPersons WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateOtherPerson
    @Id INT,@Code NVARCHAR(MAX)='',@Name NVARCHAR(MAX),@Mobile NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Designation NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',@City NVARCHAR(MAX)='',
    @State NVARCHAR(MAX)='',@Pincode NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE OtherPersons SET Code=@Code,Name=@Name,Mobile=@Mobile,Email=@Email,Designation=@Designation,
        Address=@Address,City=@City,State=@State,Pincode=@Pincode,Remarks=@Remarks,
        Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

PRINT '075 - Column mismatch SPs fixed';
GO
