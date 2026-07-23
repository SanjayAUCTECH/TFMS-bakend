-- ============================================================
-- 999: Clear All Data Except Master Reference Tables
--       Leaves AppUsers, Floors, RoomStatuses, PaymentModes, Roles
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.ContractRoomInstallments', 'U') IS NOT NULL DELETE FROM dbo.ContractRoomInstallments;
IF OBJECT_ID('dbo.ContractRoomsTrns',       'U') IS NOT NULL DELETE FROM dbo.ContractRoomsTrns;
IF OBJECT_ID('dbo.ContractInstallments',    'U') IS NOT NULL DELETE FROM dbo.ContractInstallments;
IF OBJECT_ID('dbo.ContractCancellations',   'U') IS NOT NULL DELETE FROM dbo.ContractCancellations;
IF OBJECT_ID('dbo.ContractRenewals',        'U') IS NOT NULL DELETE FROM dbo.ContractRenewals;
IF OBJECT_ID('dbo.ContractTerms',           'U') IS NOT NULL DELETE FROM dbo.ContractTerms;
IF OBJECT_ID('dbo.ContractRooms',           'U') IS NOT NULL DELETE FROM dbo.ContractRooms;
IF OBJECT_ID('dbo.ContractCamps',           'U') IS NOT NULL DELETE FROM dbo.ContractCamps;
IF OBJECT_ID('dbo.Payments',                'U') IS NOT NULL DELETE FROM dbo.Payments;
IF OBJECT_ID('dbo.Waivers',                 'U') IS NOT NULL DELETE FROM dbo.Waivers;
IF OBJECT_ID('dbo.TxnRecords',              'U') IS NOT NULL DELETE FROM dbo.TxnRecords;
IF OBJECT_ID('dbo.OwnerInstallments',       'U') IS NOT NULL DELETE FROM dbo.OwnerInstallments;
IF OBJECT_ID('dbo.OwnerTransactions',       'U') IS NOT NULL DELETE FROM dbo.OwnerTransactions;
IF OBJECT_ID('dbo.OwnerContracts',          'U') IS NOT NULL DELETE FROM dbo.OwnerContracts;
IF OBJECT_ID('dbo.OutgoingPayments',        'U') IS NOT NULL DELETE FROM dbo.OutgoingPayments;
IF OBJECT_ID('dbo.Incomes',                 'U') IS NOT NULL DELETE FROM dbo.Incomes;
IF OBJECT_ID('dbo.Expenses',                'U') IS NOT NULL DELETE FROM dbo.Expenses;
IF OBJECT_ID('dbo.ActivityLogs',            'U') IS NOT NULL DELETE FROM dbo.ActivityLogs;
IF OBJECT_ID('dbo.Rooms',                   'U') IS NOT NULL DELETE FROM dbo.Rooms;
IF OBJECT_ID('dbo.Camps',                   'U') IS NOT NULL DELETE FROM dbo.Camps;
IF OBJECT_ID('dbo.CampOwners',              'U') IS NOT NULL DELETE FROM dbo.CampOwners;
IF OBJECT_ID('dbo.CampPartners',            'U') IS NOT NULL DELETE FROM dbo.CampPartners;
IF OBJECT_ID('dbo.Tenants',                 'U') IS NOT NULL DELETE FROM dbo.Tenants;
IF OBJECT_ID('dbo.OtherPersons',            'U') IS NOT NULL DELETE FROM dbo.OtherPersons;
IF OBJECT_ID('dbo.AccountsHeads',           'U') IS NOT NULL DELETE FROM dbo.AccountsHeads;
IF OBJECT_ID('dbo.FundPools',               'U') IS NOT NULL DELETE FROM dbo.FundPools;
IF OBJECT_ID('dbo.Partners',                'U') IS NOT NULL DELETE FROM dbo.Partners;
IF OBJECT_ID('dbo.Owners',                  'U') IS NOT NULL DELETE FROM dbo.Owners;
IF OBJECT_ID('dbo.Staff',                   'U') IS NOT NULL DELETE FROM dbo.Staff;

COMMIT TRANSACTION;
GO
