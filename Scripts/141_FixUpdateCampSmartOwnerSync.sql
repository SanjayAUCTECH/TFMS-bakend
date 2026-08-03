-- ============================================================
-- 141: Fix sp_UpdateCamp — Smart owner sync
--      Problem: DELETE FROM CampOwners → trigger fires →
--               OwnerContracts bhi delete ho jaati hain
--      Fix: Sirf truly removed owners delete karo (MERGE approach)
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateCamp
    @Id                  INT,
    @Name                NVARCHAR(MAX),
    @Status              NVARCHAR(MAX) = 'Active',
    @StartDate           DATE          = NULL,
    @EndDate             DATE          = NULL,
    @CampPropertyUsage   NVARCHAR(MAX) = '',
    @CampBuildingName    NVARCHAR(MAX) = '',
    @CampPropertyType    NVARCHAR(MAX) = '',
    @CampLocation        NVARCHAR(MAX) = '',
    @CampPropertyNo      NVARCHAR(MAX) = '',
    @CampPropertyArea    NVARCHAR(MAX) = '',
    @CampPremisesNo      NVARCHAR(MAX) = '',
    @CampPlotNo          NVARCHAR(MAX) = '',
    @CampMakaniNo        NVARCHAR(MAX) = '',
    @OwnerContractStatus NVARCHAR(MAX) = '',
    @PartnersJson        NVARCHAR(MAX) = '[]',
    @OwnersJson          NVARCHAR(MAX) = '[]',
    @UpdatedBy           INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ── 1. Camp main fields update ────────────────────────────
    UPDATE Camps SET
        Name               = @Name,
        Status             = @Status,
        StartDate          = @StartDate,
        EndDate            = @EndDate,
        CampPropertyUsage  = ISNULL(@CampPropertyUsage,  ''),
        CampBuildingName   = ISNULL(@CampBuildingName,   ''),
        CampPropertyType   = ISNULL(@CampPropertyType,   ''),
        CampLocation       = ISNULL(@CampLocation,       ''),
        CampPropertyNo     = ISNULL(@CampPropertyNo,     ''),
        CampPropertyArea   = ISNULL(@CampPropertyArea,   ''),
        CampPremisesNo     = ISNULL(@CampPremisesNo,     ''),
        CampPlotNo         = ISNULL(@CampPlotNo,         ''),
        CampMakaniNo       = ISNULL(@CampMakaniNo,       ''),
        OwnerContractStatus= ISNULL(@OwnerContractStatus,''),
        UpdatedBy          = @UpdatedBy,
        UpdatedAt          = GETUTCDATE()
    WHERE Id = @Id AND IsDeleted = 0;

    -- ── 2. Partners: DELETE all + re-insert (partners ke koi contracts nahi) ──
    DELETE FROM CampPartners WHERE CampId = @Id;

    IF @PartnersJson IS NOT NULL AND @PartnersJson <> '[]' AND @PartnersJson <> 'null'
        INSERT INTO CampPartners(CampId, PartnerId, ShareType, ShareValue)
        SELECT @Id,
            ISNULL(j.PascalPartnerId, j.CamelPartnerId),
            ISNULL(j.PascalShareType,  ISNULL(j.CamelShareType,  'percentage')),
            ISNULL(j.PascalShareValue, ISNULL(j.CamelShareValue, 0))
        FROM OPENJSON(@PartnersJson) WITH(
            PascalPartnerId  INT            '$.PartnerId',  CamelPartnerId  INT            '$.partnerId',
            PascalShareType  NVARCHAR(50)   '$.ShareType',  CamelShareType  NVARCHAR(50)   '$.shareType',
            PascalShareValue DECIMAL(18,2)  '$.ShareValue', CamelShareValue DECIMAL(18,2)  '$.shareValue') j
        WHERE ISNULL(j.PascalPartnerId, j.CamelPartnerId) > 0;

    -- ── 3. Owners: SMART sync — sirf truly removed owners delete karo ──
    --      Agar DELETE FROM CampOwners WHERE CampId=@Id karo toh
    --      trg_CampOwners_Delete trigger fire hoga aur OwnerContracts bhi
    --      delete ho jaayengi — isliye MERGE approach use karo

    DECLARE @NewOwners TABLE (OwnerId INT, ShareType NVARCHAR(MAX), ShareValue DECIMAL(18,2));

    IF @OwnersJson IS NOT NULL AND @OwnersJson <> '[]' AND @OwnersJson <> 'null'
        INSERT INTO @NewOwners(OwnerId, ShareType, ShareValue)
        SELECT
            ISNULL(j.PascalOwnerId, j.CamelOwnerId),
            ISNULL(j.PascalShareType,  ISNULL(j.CamelShareType,  'percentage')),
            ISNULL(j.PascalShareValue, ISNULL(j.CamelShareValue, 0))
        FROM OPENJSON(@OwnersJson) WITH(
            PascalOwnerId    INT            '$.OwnerId',   CamelOwnerId    INT            '$.ownerId',
            PascalShareType  NVARCHAR(50)   '$.ShareType', CamelShareType  NVARCHAR(50)   '$.shareType',
            PascalShareValue DECIMAL(18,2)  '$.ShareValue',CamelShareValue DECIMAL(18,2)  '$.shareValue') j
        WHERE ISNULL(j.PascalOwnerId, j.CamelOwnerId) > 0;

    -- Sirf woh owners delete karo jo new list mein nahi hain
    DELETE FROM CampOwners
    WHERE CampId = @Id
      AND OwnerId NOT IN (SELECT OwnerId FROM @NewOwners);

    -- Naye owners insert karo jo already exist nahi karte
    INSERT INTO CampOwners(CampId, OwnerId, ShareType, ShareValue)
    SELECT @Id, n.OwnerId, n.ShareType, n.ShareValue
    FROM @NewOwners n
    WHERE NOT EXISTS (
        SELECT 1 FROM CampOwners co
        WHERE co.CampId = @Id AND co.OwnerId = n.OwnerId);

    -- Existing owners ka ShareType/ShareValue update karo agar change hua
    UPDATE co
    SET ShareType  = n.ShareType,
        ShareValue = n.ShareValue
    FROM CampOwners co
    JOIN @NewOwners n ON co.CampId = @Id AND co.OwnerId = n.OwnerId;
END
GO

PRINT '✅ 141 - sp_UpdateCamp fixed: Smart owner sync — OwnerContracts delete nahi hongi';
GO
