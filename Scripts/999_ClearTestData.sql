-- ============================================================
-- 999: Clear Test Data
--      Inventory, Contracts, Collection, Account Management
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Collection ────────────────────────────────────────────────
DELETE FROM ContractRoomInstallments;
DELETE FROM ContractRoomsTrns;
DELETE FROM ContractInstallments;
DELETE FROM TxnRecords;
DELETE FROM Waivers;

-- ── Contracts ────────────────────────────────────────────────
DELETE FROM ContractCancellations;
DELETE FROM ContractRenewals;
DELETE FROM ContractRooms;
DELETE FROM ContractCamps;
DELETE FROM Contracts;

-- ── Account Management ───────────────────────────────────────
DELETE FROM Incomes;
DELETE FROM Expenses;

-- Reset FundPool balances to 0
UPDATE FundPools SET Balance = 0, UpdatedAt = GETDATE();

-- ── Inventory ────────────────────────────────────────────────
-- Rooms ko Vacant mark karo (delete nahi — structure rakho)
UPDATE Rooms SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETDATE();

-- ActivityLogs bhi clear karo
DELETE FROM ActivityLogs;

-- Reset identity counters (optional — new records fresh IDs se start hoge)
DBCC CHECKIDENT ('Contracts',           RESEED, 0);
DBCC CHECKIDENT ('ContractInstallments',RESEED, 0);
DBCC CHECKIDENT ('ContractRooms',       RESEED, 0);
DBCC CHECKIDENT ('ContractCamps',       RESEED, 0);
DBCC CHECKIDENT ('ContractRoomInstallments', RESEED, 0);
DBCC CHECKIDENT ('ContractRoomsTrns',   RESEED, 0);
DBCC CHECKIDENT ('TxnRecords',          RESEED, 0);
DBCC CHECKIDENT ('Incomes',             RESEED, 0);
DBCC CHECKIDENT ('Expenses',            RESEED, 0);
DBCC CHECKIDENT ('Waivers',             RESEED, 0);
DBCC CHECKIDENT ('ActivityLogs',        RESEED, 0);
DBCC CHECKIDENT ('ContractCancellations', RESEED, 0);
DBCC CHECKIDENT ('ContractRenewals',    RESEED, 0);

PRINT 'Test data cleared successfully!';
GO
