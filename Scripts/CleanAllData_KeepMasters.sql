-- ============================================================
-- TFMS: Delete ALL data EXCEPT AppUsers, Floors, RoomStatuses, PaymentModes, Roles
-- Database: TFMS_TestSoftwareDB
-- Run Order: Child tables first (FK constraints)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Disable all FK checks temporarily for clean deletion
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';
GO

-- ══════════════════════════════════════════════════════════════
-- 1. PAYMENTS & TRANSACTIONS (deepest children)
-- ══════════════════════════════════════════════════════════════
DELETE FROM Waivers;
DELETE FROM TxnRecords;
DELETE FROM Payments;

-- ══════════════════════════════════════════════════════════════
-- 2. CONTRACT RELATED
-- ══════════════════════════════════════════════════════════════
DELETE FROM ContractRooms;
IF OBJECT_ID('ContractCamps', 'U') IS NOT NULL DELETE FROM ContractCamps;
DELETE FROM Contracts;

-- ══════════════════════════════════════════════════════════════
-- 3. OWNER CONTRACTS & TRANSACTIONS
-- ══════════════════════════════════════════════════════════════
DELETE FROM OwnerTransactions;
DELETE FROM OwnerInstallments;
DELETE FROM OwnerContracts;

-- ══════════════════════════════════════════════════════════════
-- 4. INCOME / EXPENSE
-- ══════════════════════════════════════════════════════════════
DELETE FROM Incomes;
DELETE FROM Expenses;

-- ══════════════════════════════════════════════════════════════
-- 5. ROOMS (depends on Camps, Floors)
-- ══════════════════════════════════════════════════════════════
DELETE FROM Rooms;

-- ══════════════════════════════════════════════════════════════
-- 6. CAMP RELATIONSHIPS
-- ══════════════════════════════════════════════════════════════
DELETE FROM CampPartners;
DELETE FROM CampOwners;
DELETE FROM Camps;

-- ══════════════════════════════════════════════════════════════
-- 7. TENANTS
-- ══════════════════════════════════════════════════════════════
DELETE FROM Tenants;

-- ══════════════════════════════════════════════════════════════
-- 8. OTHER MASTERS (NOT AppUsers, Floors, RoomStatuses, PaymentModes, Roles)
-- ══════════════════════════════════════════════════════════════
DELETE FROM Partners;
DELETE FROM Owners;
DELETE FROM FundPools;
DELETE FROM AccountsHeads;
DELETE FROM Designations;
DELETE FROM OtherPersons;

-- ══════════════════════════════════════════════════════════════
-- 9. ACTIVITY LOGS (if exists)
-- ══════════════════════════════════════════════════════════════
IF OBJECT_ID('ActivityLogs', 'U') IS NOT NULL DELETE FROM ActivityLogs;

-- ══════════════════════════════════════════════════════════════
-- 10. RESEED IDENTITY COLUMNS (reset to 0)
-- ══════════════════════════════════════════════════════════════
DBCC CHECKIDENT ('Waivers', RESEED, 0);
DBCC CHECKIDENT ('TxnRecords', RESEED, 0);
DBCC CHECKIDENT ('Payments', RESEED, 0);
DBCC CHECKIDENT ('ContractRooms', RESEED, 0);
DBCC CHECKIDENT ('Contracts', RESEED, 0);
DBCC CHECKIDENT ('OwnerTransactions', RESEED, 0);
DBCC CHECKIDENT ('OwnerInstallments', RESEED, 0);
DBCC CHECKIDENT ('OwnerContracts', RESEED, 0);
DBCC CHECKIDENT ('Incomes', RESEED, 0);
DBCC CHECKIDENT ('Expenses', RESEED, 0);
DBCC CHECKIDENT ('Rooms', RESEED, 0);
DBCC CHECKIDENT ('CampPartners', RESEED, 0);
DBCC CHECKIDENT ('CampOwners', RESEED, 0);
DBCC CHECKIDENT ('Camps', RESEED, 0);
DBCC CHECKIDENT ('Tenants', RESEED, 0);
DBCC CHECKIDENT ('Partners', RESEED, 0);
DBCC CHECKIDENT ('Owners', RESEED, 0);
DBCC CHECKIDENT ('FundPools', RESEED, 0);
DBCC CHECKIDENT ('AccountsHeads', RESEED, 0);
DBCC CHECKIDENT ('Designations', RESEED, 0);
DBCC CHECKIDENT ('OtherPersons', RESEED, 0);

-- Re-enable all FK checks
EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';
GO

PRINT '✅ All data deleted successfully. Kept: AppUsers, Floors, RoomStatuses, PaymentModes, Roles';
GO
