-- ============================================================
-- 065: Fix sp_UpdateCamp — all columns properly updated
-- ============================================================
USE TFMS_TestSoftwareDB;
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

    -- Partners
    DELETE FROM CampPartners WHERE CampId = @Id;
    IF @PartnersJson IS NOT NULL AND LEN(@PartnersJson) > 2
        INSERT INTO CampPartners (CampId, PartnerId, ShareType, ShareValue)
        SELECT @Id, PartnerId, ShareType, ShareValue
        FROM OPENJSON(@PartnersJson) WITH (
            PartnerId  INT            '$.partnerId',
            ShareType  NVARCHAR(MAX)  '$.shareType',
            ShareValue DECIMAL(18,2)  '$.shareValue'
        );

    -- Owners
    DELETE FROM CampOwners WHERE CampId = @Id;
    IF @OwnersJson IS NOT NULL AND LEN(@OwnersJson) > 2
        INSERT INTO CampOwners (CampId, OwnerId, ShareType, ShareValue)
        SELECT @Id, OwnerId, ShareType, ShareValue
        FROM OPENJSON(@OwnersJson) WITH (
            OwnerId    INT            '$.ownerId',
            ShareType  NVARCHAR(MAX)  '$.shareType',
            ShareValue DECIMAL(18,2)  '$.shareValue'
        );
END
GO

PRINT '065 - sp_UpdateCamp fixed: all columns + camelCase JSON paths';
GO
