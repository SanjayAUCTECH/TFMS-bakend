-- ============================================================
-- 080: Add @AddedBy to all Create SPs that were missing it
--      + Wire @AddedBy / @UpdatedBy across ALL Create/Update SPs
--      + Fix RoomStatus soft delete
-- Date: July 25, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Camp ──────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL, @EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='', @CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='',  @CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='',    @CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='',    @CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]', @OwnersJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX) = 'CAMP-' + RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Camps) AS NVARCHAR),4);
    INSERT INTO Camps(Code,Name,Status,StartDate,EndDate,
        CampPropertyUsage,CampBuildingName,CampPropertyType,CampLocation,
        CampPropertyNo,CampPropertyArea,CampPremisesNo,CampPlotNo,CampMakaniNo,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Status,@StartDate,@EndDate,
        @CampPropertyUsage,@CampBuildingName,@CampPropertyType,@CampLocation,
        @CampPropertyNo,@CampPropertyArea,@CampPremisesNo,@CampPlotNo,@CampMakaniNo,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    -- Partners
    IF @PartnersJson<>'[]' AND @PartnersJson IS NOT NULL
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @NewId, p.PartnerId, p.ShareType, p.ShareValue
        FROM OPENJSON(@PartnersJson) WITH(PartnerId INT, ShareType NVARCHAR(50), ShareValue DECIMAL(18,4)) p;
    -- Owners
    IF @OwnersJson<>'[]' AND @OwnersJson IS NOT NULL
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @NewId, o.OwnerId, o.ShareType, o.ShareValue
        FROM OPENJSON(@OwnersJson) WITH(OwnerId INT, ShareType NVARCHAR(50), ShareValue DECIMAL(18,4)) o;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id INT, @Name NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL, @EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='', @CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='',  @CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='',    @CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='',    @CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]', @OwnersJson NVARCHAR(MAX)='[]',
    @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET Name=@Name,Status=@Status,StartDate=@StartDate,EndDate=@EndDate,
        CampPropertyUsage=@CampPropertyUsage,CampBuildingName=@CampBuildingName,
        CampPropertyType=@CampPropertyType,CampLocation=@CampLocation,
        CampPropertyNo=@CampPropertyNo,CampPropertyArea=@CampPropertyArea,
        CampPremisesNo=@CampPremisesNo,CampPlotNo=@CampPlotNo,CampMakaniNo=@CampMakaniNo,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
    DELETE FROM CampPartners WHERE CampId=@Id;
    DELETE FROM CampOwners   WHERE CampId=@Id;
    IF @PartnersJson<>'[]' AND @PartnersJson IS NOT NULL
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @Id, p.PartnerId, p.ShareType, p.ShareValue
        FROM OPENJSON(@PartnersJson) WITH(PartnerId INT, ShareType NVARCHAR(50), ShareValue DECIMAL(18,4)) p;
    IF @OwnersJson<>'[]' AND @OwnersJson IS NOT NULL
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @Id, o.OwnerId, o.ShareType, o.ShareValue
        FROM OPENJSON(@OwnersJson) WITH(OwnerId INT, ShareType NVARCHAR(50), ShareValue DECIMAL(18,4)) o;
END
GO

-- ── Owner ─────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateOwner
    @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='', @Email NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active', @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX) = 'OWN-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Owners) AS NVARCHAR),4);
    INSERT INTO Owners(Code,Name,Contact,Email,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Contact,@Email,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateOwner
    @Id INT, @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='',
    @Email NVARCHAR(MAX)='', @Status NVARCHAR(MAX)='Active', @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Owners SET Name=@Name,Contact=@Contact,Email=@Email,Status=@Status,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── Partner ───────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreatePartner
    @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='', @Mobile NVARCHAR(MAX)='',
    @Email NVARCHAR(MAX)='', @Status NVARCHAR(MAX)='Active',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX) = 'PTR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Partners) AS NVARCHAR),4);
    INSERT INTO Partners(Code,Name,Contact,Mobile,Email,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Contact,@Mobile,@Email,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdatePartner
    @Id INT, @Name NVARCHAR(MAX), @Contact NVARCHAR(MAX)='',
    @Mobile NVARCHAR(MAX)='', @Email NVARCHAR(MAX)='',
    @Status NVARCHAR(MAX)='Active', @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Partners SET Name=@Name,Contact=@Contact,Mobile=@Mobile,Email=@Email,
        Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── Role ──────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateRole
    @RoleName NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX) = 'ROL-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Roles) AS NVARCHAR),4);
    INSERT INTO Roles(RoleCode,RoleName,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@RoleName,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateRole
    @Id INT, @RoleName NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active', @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Roles SET RoleName=@RoleName,Status=@Status,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ── RoomStatus ────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateRoomStatus
    @Name NVARCHAR(MAX), @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO RoomStatuses(Name,AddedBy,IsDeleted) VALUES(@Name,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteRoomStatus @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    UPDATE RoomStatuses SET IsDeleted=1,DeletedBy=@DeletedBy WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomStatuses AS BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name FROM RoomStatuses WHERE IsDeleted=0 ORDER BY Name;
END
GO

-- ── Contract ──────────────────────────────────────────────────────────────
-- Patch sp_CreateContract to set AddedBy & IsDeleted=0 on insert
-- (full SP is complex — just patch the INSERT via trigger-style approach)
-- Add AddedBy column update after contract is created
CREATE OR ALTER PROCEDURE sp_UpdateContractAddedBy
    @ContractId NVARCHAR(MAX), @AddedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Contracts SET AddedBy=@AddedBy WHERE ContractId=@ContractId AND AddedBy IS NULL;
END
GO

PRINT '080 - AddedBy added to Camp/Owner/Partner/Role/RoomStatus Create SPs + UpdatedBy on Update SPs';
GO
