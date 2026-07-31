-- ============================================================
-- 126: Clear ALL Data — Keep Master Tables Only
-- Keep:   AppUsers, Floors, RoomStatuses, PaymentModes, Roles
-- Delete: Everything else (child → parent order)
-- Database: TFMS_TestSoftwareDB
-- Date: July 31, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- ── Step 1: Disable all FK constraints ──────────────────────
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';

-- ── Step 2: Delete child tables first ───────────────────────

-- Contract installments & room-wise data
IF OBJECT_ID('dbo.ContractRoomInstallments',       'U') IS NOT NULL DELETE FROM dbo.ContractRoomInstallments;
IF OBJECT_ID('dbo.ContractRoomsTrns',              'U') IS NOT NULL DELETE FROM dbo.ContractRoomsTrns;
IF OBJECT_ID('dbo.ContractInstallments',           'U') IS NOT NULL DELETE FROM dbo.ContractInstallments;
IF OBJECT_ID('dbo.ContractCancellations',          'U') IS NOT NULL DELETE FROM dbo.ContractCancellations;
IF OBJECT_ID('dbo.ContractRenewals',               'U') IS NOT NULL DELETE FROM dbo.ContractRenewals;
IF OBJECT_ID('dbo.ContractTerms',                  'U') IS NOT NULL DELETE FROM dbo.ContractTerms;
IF OBJECT_ID('dbo.ContractRooms',                  'U') IS NOT NULL DELETE FROM dbo.ContractRooms;
IF OBJECT_ID('dbo.ContractCamps',                  'U') IS NOT NULL DELETE FROM dbo.ContractCamps;

-- Payments & Transactions
IF OBJECT_ID('dbo.Waivers',                        'U') IS NOT NULL DELETE FROM dbo.Waivers;
IF OBJECT_ID('dbo.TxnRecords',                     'U') IS NOT NULL DELETE FROM dbo.TxnRecords;
IF OBJECT_ID('dbo.Payments',                       'U') IS NOT NULL DELETE FROM dbo.Payments;
IF OBJECT_ID('dbo.OutgoingPayments',               'U') IS NOT NULL DELETE FROM dbo.OutgoingPayments;

-- Contracts
IF OBJECT_ID('dbo.Contracts',                      'U') IS NOT NULL DELETE FROM dbo.Contracts;

-- Owner contracts & transactions
IF OBJECT_ID('dbo.OwnerMonthlyContractInstallments','U') IS NOT NULL DELETE FROM dbo.OwnerMonthlyContractInstallments;
IF OBJECT_ID('dbo.OwnerInstallments',              'U') IS NOT NULL DELETE FROM dbo.OwnerInstallments;
IF OBJECT_ID('dbo.OwnerTransactions',              'U') IS NOT NULL DELETE FROM dbo.OwnerTransactions;
IF OBJECT_ID('dbo.OwnerContracts',                 'U') IS NOT NULL DELETE FROM dbo.OwnerContracts;

-- Security Deposit tracking
IF OBJECT_ID('dbo.SecurityDepositRecords',         'U') IS NOT NULL DELETE FROM dbo.SecurityDepositRecords;
IF OBJECT_ID('dbo.SecurityDepositRoomTracking',    'U') IS NOT NULL DELETE FROM dbo.SecurityDepositRoomTracking;

-- Income / Expense
IF OBJECT_ID('dbo.Incomes',                        'U') IS NOT NULL DELETE FROM dbo.Incomes;
IF OBJECT_ID('dbo.Expenses',                       'U') IS NOT NULL DELETE FROM dbo.Expenses;

-- Rooms (depends on Camps, Floors)
IF OBJECT_ID('dbo.Rooms',                          'U') IS NOT NULL DELETE FROM dbo.Rooms;

-- Camp relationships
IF OBJECT_ID('dbo.CampPartners',                   'U') IS NOT NULL DELETE FROM dbo.CampPartners;
IF OBJECT_ID('dbo.CampOwners',                     'U') IS NOT NULL DELETE FROM dbo.CampOwners;
IF OBJECT_ID('dbo.Camps',                          'U') IS NOT NULL DELETE FROM dbo.Camps;

-- Persons
IF OBJECT_ID('dbo.Tenants',                        'U') IS NOT NULL DELETE FROM dbo.Tenants;
IF OBJECT_ID('dbo.Partners',                       'U') IS NOT NULL DELETE FROM dbo.Partners;
IF OBJECT_ID('dbo.Owners',                         'U') IS NOT NULL DELETE FROM dbo.Owners;
IF OBJECT_ID('dbo.OtherPersons',                   'U') IS NOT NULL DELETE FROM dbo.OtherPersons;
IF OBJECT_ID('dbo.Staff',                          'U') IS NOT NULL DELETE FROM dbo.Staff;

-- Finance masters
IF OBJECT_ID('dbo.FundPools',                      'U') IS NOT NULL DELETE FROM dbo.FundPools;
IF OBJECT_ID('dbo.AccountsHeads',                  'U') IS NOT NULL DELETE FROM dbo.AccountsHeads;
IF OBJECT_ID('dbo.Designations',                   'U') IS NOT NULL DELETE FROM dbo.Designations;

-- Logs
IF OBJECT_ID('dbo.ActivityLogs',                   'U') IS NOT NULL DELETE FROM dbo.ActivityLogs;
IF OBJECT_ID('dbo.ActivityLog',                    'U') IS NOT NULL DELETE FROM dbo.ActivityLog;

-- ── Step 3: Reseed all identity columns to 0 ────────────────
DBCC CHECKIDENT ('ContractRoomInstallments', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ContractInstallments',     RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ContractCancellations',    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ContractRenewals',         RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ContractRooms',            RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ContractCamps',            RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Waivers',                  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('TxnRecords',               RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Payments',                 RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('OutgoingPayments',         RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Contracts',                RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('OwnerInstallments',        RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('OwnerTransactions',        RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('OwnerContracts',           RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Incomes',                  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Expenses',                 RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Rooms',                    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('CampPartners',             RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('CampOwners',               RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Camps',                    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Tenants',                  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Partners',                 RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Owners',                   RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('OtherPersons',             RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('Staff',                    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('FundPools',                RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('AccountsHeads',            RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('ActivityLogs',             RESEED, 0) WITH NO_INFOMSGS;

-- ── Step 4: Re-enable all FK constraints ────────────────────
EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';

COMMIT TRANSACTION;
GO

PRINT '✅ 126 - All data cleared. Kept: AppUsers, Floors, RoomStatuses, PaymentModes, Roles';
GO
