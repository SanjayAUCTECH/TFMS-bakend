-- 047b: Fix ContractRoomInstallments index
USE TFMS_TestSoftwareDB;
GO

-- ContractId column change to NVARCHAR(450) for index support
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomInstallments') AND name='ContractId' AND max_length=-1)
BEGIN
    ALTER TABLE ContractRoomInstallments ALTER COLUMN ContractId NVARCHAR(450) NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_ContractId' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_ContractId ON ContractRoomInstallments (ContractId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_RoomId' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_RoomId ON ContractRoomInstallments (RoomId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_DueDate' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_DueDate ON ContractRoomInstallments (DueDate);
GO

PRINT '047b - ContractRoomInstallments indexes created.';
GO
