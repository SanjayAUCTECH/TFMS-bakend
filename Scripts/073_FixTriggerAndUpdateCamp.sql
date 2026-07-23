-- ============================================================
-- Fix: trg_CampOwners_Delete was deleting OwnerContracts even
--      when owner was just being re-inserted by sp_UpdateCamp
-- 
-- Root Cause: sp_UpdateCamp does DELETE all + INSERT all.
--             Trigger fired on DELETE, wiped contracts.
--
-- Solution: Change sp_UpdateCamp to use MERGE (only delete
--           owners that are truly removed, keep existing ones)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. Update sp_UpdateCamp to use MERGE instead of DELETE+INSERT ─
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

    -- Update camp details
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

    -- ── Partners: DELETE all + re-insert (partners have no contracts) ──
    DELETE FROM CampPartners WHERE CampId = @Id;

    IF @PartnersJson IS NOT NULL AND LEN(@PartnersJson) > 2
        INSERT INTO CampPartners (CampId, PartnerId, ShareType, ShareValue)
        SELECT @Id, PartnerId, ShareType, ShareValue
        FROM OPENJSON(@PartnersJson) WITH (
            PartnerId  INT            '$.PartnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );

    -- ── Owners: SMART update — only delete truly removed owners ──
    -- Parse new owners from JSON into temp table
    DECLARE @NewOwners TABLE (OwnerId INT, ShareType NVARCHAR(MAX), ShareValue DECIMAL(18,2));

    IF @OwnersJson IS NOT NULL AND LEN(@OwnersJson) > 2
        INSERT INTO @NewOwners (OwnerId, ShareType, ShareValue)
        SELECT OwnerId, ShareType, ShareValue
        FROM OPENJSON(@OwnersJson) WITH (
            OwnerId    INT            '$.OwnerId',
            ShareType  NVARCHAR(MAX)  '$.ShareType',
            ShareValue DECIMAL(18,2)  '$.ShareValue'
        );

    -- Delete ONLY owners that are no longer in the new list
    -- (trigger will fire only for truly removed owners)
    DELETE FROM CampOwners
    WHERE CampId = @Id
      AND OwnerId NOT IN (SELECT OwnerId FROM @NewOwners);

    -- Insert ONLY new owners that don't already exist
    INSERT INTO CampOwners (CampId, OwnerId, ShareType, ShareValue)
    SELECT @Id, n.OwnerId, n.ShareType, n.ShareValue
    FROM @NewOwners n
    WHERE NOT EXISTS (
        SELECT 1 FROM CampOwners co
        WHERE co.CampId = @Id AND co.OwnerId = n.OwnerId
    );

    -- Update ShareType/ShareValue for existing owners if changed
    UPDATE co
    SET ShareType  = n.ShareType,
        ShareValue = n.ShareValue
    FROM CampOwners co
    JOIN @NewOwners n ON co.CampId = @Id AND co.OwnerId = n.OwnerId;
END
GO

PRINT '✅ sp_UpdateCamp fixed - smart owner sync (only deletes truly removed owners)';
GO
