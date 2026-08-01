-- ============================================================
-- 130: Add OwnerContractStatus to Camps table + update SPs
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Camps') AND name = 'OwnerContractStatus')
    ALTER TABLE Camps ADD OwnerContractStatus NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

PRINT '✅ OwnerContractStatus column added to Camps';
GO

CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL, @EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='', @CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='', @CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='', @CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='', @CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @OwnerContractStatus NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]', @OwnersJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Camps(Code,Name,Rooms,Floors,Status,CampPropertyUsage,CampBuildingName,
        CampPropertyType,CampLocation,CampPropertyNo,CampPropertyArea,CampPremisesNo,
        CampPlotNo,CampMakaniNo,OwnerContractStatus,StartDate,EndDate,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES('TMP',@Name,0,0,@Status,@CampPropertyUsage,@CampBuildingName,
        @CampPropertyType,@CampLocation,@CampPropertyNo,@CampPropertyArea,@CampPremisesNo,
        @CampPlotNo,@CampMakaniNo,@OwnerContractStatus,@StartDate,@EndDate,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    UPDATE Camps SET Code=CONCAT('CAMP-',RIGHT('000'+CAST(@NewId AS NVARCHAR),3)) WHERE Id=@NewId;

    IF @PartnersJson IS NOT NULL AND @PartnersJson<>'[]' AND @PartnersJson<>'null'
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @NewId,ISNULL(j.PascalPartnerId,j.CamelPartnerId),
            ISNULL(j.PascalShareType,ISNULL(j.CamelShareType,'percentage')),
            ISNULL(j.PascalShareValue,ISNULL(j.CamelShareValue,0))
        FROM OPENJSON(@PartnersJson) WITH(
            PascalPartnerId INT '$.PartnerId', CamelPartnerId INT '$.partnerId',
            PascalShareType NVARCHAR(50) '$.ShareType', CamelShareType NVARCHAR(50) '$.shareType',
            PascalShareValue DECIMAL(18,2) '$.ShareValue', CamelShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE ISNULL(j.PascalPartnerId,j.CamelPartnerId)>0;

    IF @OwnersJson IS NOT NULL AND @OwnersJson<>'[]' AND @OwnersJson<>'null'
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @NewId,ISNULL(j.PascalOwnerId,j.CamelOwnerId),
            ISNULL(j.PascalShareType,ISNULL(j.CamelShareType,'percentage')),
            ISNULL(j.PascalShareValue,ISNULL(j.CamelShareValue,0))
        FROM OPENJSON(@OwnersJson) WITH(
            PascalOwnerId INT '$.OwnerId', CamelOwnerId INT '$.ownerId',
            PascalShareType NVARCHAR(50) '$.ShareType', CamelShareType NVARCHAR(50) '$.shareType',
            PascalShareValue DECIMAL(18,2) '$.ShareValue', CamelShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE ISNULL(j.PascalOwnerId,j.CamelOwnerId)>0;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id INT, @Name NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL, @EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='', @CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='', @CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='', @CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='', @CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @OwnerContractStatus NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]', @OwnersJson NVARCHAR(MAX)='[]',
    @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Camps SET Name=@Name,Status=@Status,StartDate=@StartDate,EndDate=@EndDate,
        CampPropertyUsage=@CampPropertyUsage,CampBuildingName=@CampBuildingName,
        CampPropertyType=@CampPropertyType,CampLocation=@CampLocation,
        CampPropertyNo=@CampPropertyNo,CampPropertyArea=@CampPropertyArea,
        CampPremisesNo=@CampPremisesNo,CampPlotNo=@CampPlotNo,CampMakaniNo=@CampMakaniNo,
        OwnerContractStatus=@OwnerContractStatus,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;

    DELETE FROM CampPartners WHERE CampId=@Id;
    IF @PartnersJson IS NOT NULL AND @PartnersJson<>'[]' AND @PartnersJson<>'null'
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @Id,ISNULL(j.PascalPartnerId,j.CamelPartnerId),
            ISNULL(j.PascalShareType,ISNULL(j.CamelShareType,'percentage')),
            ISNULL(j.PascalShareValue,ISNULL(j.CamelShareValue,0))
        FROM OPENJSON(@PartnersJson) WITH(
            PascalPartnerId INT '$.PartnerId', CamelPartnerId INT '$.partnerId',
            PascalShareType NVARCHAR(50) '$.ShareType', CamelShareType NVARCHAR(50) '$.shareType',
            PascalShareValue DECIMAL(18,2) '$.ShareValue', CamelShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE ISNULL(j.PascalPartnerId,j.CamelPartnerId)>0;

    DELETE FROM CampOwners WHERE CampId=@Id;
    IF @OwnersJson IS NOT NULL AND @OwnersJson<>'[]' AND @OwnersJson<>'null'
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @Id,ISNULL(j.PascalOwnerId,j.CamelOwnerId),
            ISNULL(j.PascalShareType,ISNULL(j.CamelShareType,'percentage')),
            ISNULL(j.PascalShareValue,ISNULL(j.CamelShareValue,0))
        FROM OPENJSON(@OwnersJson) WITH(
            PascalOwnerId INT '$.OwnerId', CamelOwnerId INT '$.ownerId',
            PascalShareType NVARCHAR(50) '$.ShareType', CamelShareType NVARCHAR(50) '$.shareType',
            PascalShareValue DECIMAL(18,2) '$.ShareValue', CamelShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE ISNULL(j.PascalOwnerId,j.CamelOwnerId)>0;
END
GO

PRINT '✅ 130 - OwnerContractStatus added to Camps + sp_CreateCamp/sp_UpdateCamp updated';
GO
