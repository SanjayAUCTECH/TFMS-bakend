-- ═══════════════════════════════════════════════════════════════════
-- Create Missing Sequences for AccountMaster and VoucherNo
-- ═══════════════════════════════════════════════════════════════════

PRINT 'Creating missing sequences...';
GO

-- ─────────────────────────────────────────────────────────────────
-- Sequence for AccountMaster ID generation
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_AccountMaster')
BEGIN
    CREATE SEQUENCE dbo.seq_AccountMaster
        AS INT
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        NO MAXVALUE
        NO CYCLE
        CACHE 50;
    
    PRINT '✓ seq_AccountMaster sequence created';
END
ELSE
BEGIN
    PRINT '• seq_AccountMaster sequence already exists';
END
GO

-- ─────────────────────────────────────────────────────────────────
-- Sequence for VoucherNo generation
-- ─────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'seq_VoucherNo')
BEGIN
    CREATE SEQUENCE dbo.seq_VoucherNo
        AS INT
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        NO MAXVALUE
        NO CYCLE
        CACHE 50;
    
    PRINT '✓ seq_VoucherNo sequence created';
END
ELSE
BEGIN
    PRINT '• seq_VoucherNo sequence already exists';
END
GO

-- ─────────────────────────────────────────────────────────────────
-- Verify sequences exist
-- ─────────────────────────────────────────────────────────────────
SELECT 
    name AS SequenceName,
    start_value AS StartValue,
    increment AS IncrementBy,
    current_value AS CurrentValue
FROM sys.sequences
WHERE name IN ('seq_AccountMaster', 'seq_VoucherNo');
GO

PRINT '═══════════════════════════════════════════════════════════════════';
PRINT 'Missing Sequences Created Successfully!';
PRINT '═══════════════════════════════════════════════════════════════════';
GO
