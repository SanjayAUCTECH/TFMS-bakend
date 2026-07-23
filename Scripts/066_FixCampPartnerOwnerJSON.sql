-- ============================================================
-- Fix Camp Partner/Owner Assignment - JSON property case mismatch
-- Issue: C# sends PascalCase (PartnerId), SP expects camelCase (partnerId)
-- Solution: Update OPENJSON paths to PascalCase
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name             NVARCHAR(MAX),
    @Status           NVARCHAR(MAX),
    @StartDate        DATE          = NULL,
    @EndDate          DATE          = NULL,
    @CampPropertyUsage NVARCHAR(MAX) = '',
    @CampBuildingName  NVARCHAR(MAX) = '',
    @CampPropertyType  NVARCHAR(MAX) = '',
    @CampLocation      NVARCHAR(MAX) = '',
    @CampPropertyNo    NVARCHAR(MAX) = '',
    @CampPropertyArea  NVARCHAR(MAX) = '',
    @CampPremisesNo    NVARCHAR(MAX) = '',
    @CampPlotNo        NVARCHAR(MAX) = '',
    @CampMakaniNo      NVARCHAR(MAX) = '',
    @PartnersJson      NVARCHAR(MAX) = '[]',
    @OwnersJson        NVARCHAR(MAX) = '[]',
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Code NVARCHAR(50) = 'CMP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Camps) AS NVARCHAR), 6);
    
    INSERT INTO Camps (
        Code, Name, Status, StartDate, EndDate,
        CampPropertyUsage, CampBuildingName, CampPropertyType, CampLocation,
        CampPropertyNo, CampPropertyArea, CampPremisesNo, CampPlotNo, CampMakaniNo,
        CreatedAt, UpdatedAt
    ) VALUES (
        @Code, @Name, @Status, @StartDate, @EndDate,
        @CampPropertyUsage, @CampBuildingName, @CampPropertyType, @CampLocation,
        @CampPropertyNo, @CampPropertyArea, @CampPremisesNo, @CampPlotNo, @CampMakaniNo,
        GETUTCDATE(), GETUTCDATE()
    );
    
    SET @NewId = SCOPE_IDENTITY();
    
    -- Insert Partners with PascalCase JSON paths
    IF @PartnersJson IS NOT NULL AND LEN(@PartnersJson) > 2
        INSERT INTO CampPartners (CampId, PartnerId, ShareType, ShareValue)
        SELECT @NewId, PartnerId, ShareType, ShareValue
        FROM OPENJSON(@PartnersJson) WITH (
            PartnerId  INT            '$.PartnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );
    
    -- Insert Owners with PascalCase JSON paths
    IF @OwnersJson IS NOT NULL AND LEN(@OwnersJson) > 2
        INSERT INTO CampOwners (CampId, OwnerId, ShareType, ShareValue)
        SELECT @NewId, OwnerId, ShareType, ShareValue
        FROM OPENJSON(@OwnersJson) WITH (
            OwnerId    INT            '$.OwnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );
    
    -- Update room/floor counts
    UPDATE Camps SET
        Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@NewId),
        Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@NewId)
    WHERE Id = @NewId;
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id                INT,
    @Name              NVARCHAR(MAX),
    @Status            NVARCHAR(MAX),
    @StartDate         DATE          = NULL,
    @EndDate           DATE          = NULL,
    @CampPropertyUsage NVARCHAR(MAX) = '',
    @CampBuildingName  NVARCHAR(MAX) = '',
    @CampPropertyType  NVARCHAR(MAX) = '',
    @CampLocation      NVARCHAR(MAX) = '',
    @CampPropertyNo    NVARCHAR(MAX) = '',
    @CampPropertyArea  NVARCHAR(MAX) = '',
    @CampPremisesNo    NVARCHAR(MAX) = '',
    @CampPlotNo        NVARCHAR(MAX) = '',
    @CampMakaniNo      NVARCHAR(MAX) = '',
    @PartnersJson      NVARCHAR(MAX) = '[]',
    @OwnersJson        NVARCHAR(MAX) = '[]'
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Camps SET
        Name               = @Name,
        Status             = @Status,
        StartDate          = @StartDate,
        EndDate            = @EndDate,
        CampPropertyUsage  = ISNULL(@CampPropertyUsage, ''),
        CampBuildingName   = ISNULL(@CampBuildingName,  ''),
        CampPropertyType   = ISNULL(@CampPropertyType,  ''),
        CampLocation       = ISNULL(@CampLocation,      ''),
        CampPropertyNo     = ISNULL(@CampPropertyNo,    ''),
        CampPropertyArea   = ISNULL(@CampPropertyArea,  ''),
        CampPremisesNo     = ISNULL(@CampPremisesNo,    ''),
        CampPlotNo         = ISNULL(@CampPlotNo,        ''),
        CampMakaniNo       = ISNULL(@CampMakaniNo,      ''),
        UpdatedAt          = GETUTCDATE()
    WHERE Id = @Id;

    -- Delete existing partners
    DELETE FROM CampPartners WHERE CampId = @Id;
    
    -- Insert Partners with PascalCase JSON paths
    IF @PartnersJson IS NOT NULL AND LEN(@PartnersJson) > 2
        INSERT INTO CampPartners (CampId, PartnerId, ShareType, ShareValue)
        SELECT @Id, PartnerId, ShareType, ShareValue
        FROM OPENJSON(@PartnersJson) WITH (
            PartnerId  INT            '$.PartnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );

    -- Delete existing owners
    DELETE FROM CampOwners WHERE CampId = @Id;
    
    -- Insert Owners with PascalCase JSON paths
    IF @OwnersJson IS NOT NULL AND LEN(@OwnersJson) > 2
        INSERT INTO CampOwners (CampId, OwnerId, ShareType, ShareValue)
        SELECT @Id, OwnerId, ShareType, ShareValue
        FROM OPENJSON(@OwnersJson) WITH (
            OwnerId    INT            '$.OwnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );
END
GO

PRINT '✅ sp_CreateCamp and sp_UpdateCamp fixed - now using PascalCase JSON paths';
GO
