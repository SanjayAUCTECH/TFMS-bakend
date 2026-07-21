-- ============================================================
-- 047c: Patch sp_CreateContract & sp_UpdateContract
--       Add EXEC sp_GenerateContractRoomInstallments at end
-- Date: July 21, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Patch sp_CreateContract ───────────────────────────────────
DECLARE @spDef NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_CreateContract'));

-- Check if already patched
IF CHARINDEX('sp_GenerateContractRoomInstallments', @spDef) = 0
BEGIN
    -- Find last END and insert before it
    DECLARE @insertPos INT = LEN(@spDef) - CHARINDEX(REVERSE('END'), REVERSE(@spDef)) + 1 - 2;
    DECLARE @newSP NVARCHAR(MAX) =
        LEFT(@spDef, @insertPos) +
        CHAR(13) + CHAR(10) +
        '    -- Auto-generate room-wise installments' + CHAR(13) + CHAR(10) +
        '    EXEC sp_GenerateContractRoomInstallments @NewContractId;' + CHAR(13) + CHAR(10) +
        RIGHT(@spDef, LEN(@spDef) - @insertPos);

    -- Replace CREATE with ALTER
    SET @newSP = REPLACE(@newSP, 'CREATE PROCEDURE', 'ALTER PROCEDURE');
    EXEC sp_executesql @newSP;
    PRINT 'sp_CreateContract patched - room installments will be auto-generated.';
END
ELSE
    PRINT 'sp_CreateContract already patched.';
GO

-- ── Patch sp_UpdateContract ───────────────────────────────────
DECLARE @spDef2 NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_UpdateContract'));

IF CHARINDEX('sp_GenerateContractRoomInstallments', @spDef2) = 0
BEGIN
    DECLARE @insertPos2 INT = LEN(@spDef2) - CHARINDEX(REVERSE('END'), REVERSE(@spDef2)) + 1 - 2;
    DECLARE @newSP2 NVARCHAR(MAX) =
        LEFT(@spDef2, @insertPos2) +
        CHAR(13) + CHAR(10) +
        '    -- Regenerate room-wise installments on update' + CHAR(13) + CHAR(10) +
        '    EXEC sp_GenerateContractRoomInstallments @ContractId;' + CHAR(13) + CHAR(10) +
        RIGHT(@spDef2, LEN(@spDef2) - @insertPos2);

    SET @newSP2 = REPLACE(@newSP2, 'CREATE PROCEDURE', 'ALTER PROCEDURE');
    EXEC sp_executesql @newSP2;
    PRINT 'sp_UpdateContract patched - room installments will be regenerated on update.';
END
ELSE
    PRINT 'sp_UpdateContract already patched.';
GO

PRINT '047c - sp_CreateContract + sp_UpdateContract patched successfully.';
GO
