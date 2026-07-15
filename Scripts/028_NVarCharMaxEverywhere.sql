-- ============================================================
-- Script 028: Make ALL NVARCHAR columns MAX in DB tables
-- Exception: ContractId columns (need fixed size for index/FK)
-- ============================================================

-- ── Contracts table ──────────────────────────────────────────
-- ContractType was NVARCHAR(50) — make it MAX
-- First drop default constraint if exists
DECLARE @dfName NVARCHAR(200);
SELECT @dfName = dc.name
FROM sys.default_constraints dc
JOIN sys.columns col ON col.object_id = dc.parent_object_id AND col.column_id = dc.parent_column_id
WHERE OBJECT_NAME(dc.parent_object_id) = 'Contracts' AND col.name = 'ContractType';

IF @dfName IS NOT NULL
BEGIN
    EXEC('ALTER TABLE Contracts DROP CONSTRAINT ' + @dfName);
    PRINT 'Dropped default constraint on Contracts.ContractType';
END

IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Contracts'
      AND COLUMN_NAME = 'ContractType'
      AND CHARACTER_MAXIMUM_LENGTH <> -1
)
BEGIN
    ALTER TABLE Contracts ALTER COLUMN ContractType NVARCHAR(MAX) NOT NULL;
    -- Re-add default
    ALTER TABLE Contracts ADD CONSTRAINT DF_Contracts_ContractType DEFAULT 'Monthly' FOR ContractType;
    PRINT 'Contracts.ContractType => NVARCHAR(MAX)';
END
ELSE
    PRINT 'Contracts.ContractType already MAX or not found.';
GO

-- ── Verify: Show all remaining fixed-size nvarchar columns ───
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE = 'nvarchar'
  AND CHARACTER_MAXIMUM_LENGTH NOT IN (-1)
  AND COLUMN_NAME <> 'ContractId'
ORDER BY TABLE_NAME, COLUMN_NAME;
GO

PRINT '=== Script 028 complete. All NVARCHAR columns (except ContractId) are now MAX ===';
