-- ============================================================
-- 087: Patch Remaining Issues Found in Final Validation
-- Date: July 25, 2026
-- Fixes:
--   1. sp_CreateContract - add @AddedBy
--   2. sp_RecordPayment - add @AddedBy
--   3. sp_UpdateUser - add missing params (LoginAccess, IsAdmin, Source, SourceId, MenuAccess)
--   4. sp_CreateTxnRecord - verify AddedBy IS actually saved
-- ============================================================
USE TFMS_TestSoftwareDB;
GO
PRINT '=== Fix 1: sp_CreateContract add @AddedBy ===';
GO
