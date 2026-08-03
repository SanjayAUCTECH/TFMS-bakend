-- ============================================================
-- 142: Drop trg_CampOwners_Delete trigger
--      Reason: Trigger CampOwner delete hone pe OwnerContracts
--              bhi delete kar deta tha — yeh galat behavior hai
--              OwnerContracts independent hain, CampOwner
--              assignment se unka koi direct relation nahi hona chahiye
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

IF OBJECT_ID('trg_CampOwners_Delete', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER trg_CampOwners_Delete;
    PRINT '✅ trg_CampOwners_Delete trigger dropped successfully';
END
ELSE
    PRINT '⚠️ Trigger trg_CampOwners_Delete not found (already dropped)';
GO

PRINT '';
PRINT '✅✅ 142 - CampOwner delete pe ab OwnerContracts DELETE nahi honge';
GO
