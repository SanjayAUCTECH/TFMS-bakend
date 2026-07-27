USE TFMS_TestSoftwareDB;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name NVARCHAR(MAX), @Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL, @EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='', @CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='', @CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='', @CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='', @CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]', @OwnersJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Camps(Code,Name,Rooms,Floors,Status,CampPropertyUsage,CampBuildingName,
        CampPropertyType,CampLocation,CampPropertyNo,CampPropertyArea,CampPremisesNo,
        CampPlotNo,CampMakaniNo,StartDate,EndDate,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES('TMP',@Name,0,0,@Status,@CampPropertyUsage,@CampBuildingName,
        @CampPropertyType,@CampLocation,@CampPropertyNo,@CampPropertyArea,@CampPremisesNo,
        @CampPlotNo,@CampMakaniNo,@StartDate,@EndDate,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    UPDATE Camps SET Code=CONCAT('CAMP-',RIGHT('000'+CAST(@NewId AS NVARCHAR),3)) WHERE Id=@NewId;
    IF @PartnersJson IS NOT NULL AND @PartnersJson<>'[]'
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @NewId,j.PartnerId,ISNULL(j.ShareType,'percentage'),ISNULL(j.ShareValue,0)
        FROM OPENJSON(@PartnersJson) WITH(PartnerId INT '$.partnerId',ShareType NVARCHAR(50) '$.shareType',ShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE j.PartnerId>0;
    IF @OwnersJson IS NOT NULL AND @OwnersJson<>'[]'
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @NewId,j.OwnerId,ISNULL(j.ShareType,'percentage'),ISNULL(j.ShareValue,0)
        FROM OPENJSON(@OwnersJson) WITH(OwnerId INT '$.ownerId',ShareType NVARCHAR(50) '$.shareType',ShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE j.OwnerId>0;
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
    IF @PartnersJson IS NOT NULL AND @PartnersJson<>'[]'
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @Id,j.PartnerId,ISNULL(j.ShareType,'percentage'),ISNULL(j.ShareValue,0)
        FROM OPENJSON(@PartnersJson) WITH(PartnerId INT '$.partnerId',ShareType NVARCHAR(50) '$.shareType',ShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE j.PartnerId>0;
    DELETE FROM CampOwners WHERE CampId=@Id;
    IF @OwnersJson IS NOT NULL AND @OwnersJson<>'[]'
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @Id,j.OwnerId,ISNULL(j.ShareType,'percentage'),ISNULL(j.ShareValue,0)
        FROM OPENJSON(@OwnersJson) WITH(OwnerId INT '$.ownerId',ShareType NVARCHAR(50) '$.shareType',ShareValue DECIMAL(18,2) '$.shareValue') j
        WHERE j.OwnerId>0;
END
GO
PRINT 'Camp SPs FIXED';
GO
