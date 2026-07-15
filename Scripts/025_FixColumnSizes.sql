-- ============================================================
-- Script 025: All NVARCHAR columns → NVARCHAR(MAX)
-- Database: TFMS_TestSoftwareDB
-- Run on  : SQL Server 2016+
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

PRINT '=== Script 025: Setting all string columns to NVARCHAR(MAX) ===';
GO

-- ============================================================
-- Partners
-- ============================================================
ALTER TABLE Partners ALTER COLUMN Code     NVARCHAR(MAX) NOT NULL;
ALTER TABLE Partners ALTER COLUMN Name     NVARCHAR(MAX) NOT NULL;
ALTER TABLE Partners ALTER COLUMN Contact  NVARCHAR(MAX) NOT NULL;
ALTER TABLE Partners ALTER COLUMN Mobile   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Partners ALTER COLUMN Email    NVARCHAR(MAX) NOT NULL;
ALTER TABLE Partners ALTER COLUMN Status   NVARCHAR(MAX) NOT NULL;
PRINT 'Partners — done';
GO

-- ============================================================
-- Owners
-- ============================================================
ALTER TABLE Owners ALTER COLUMN Code    NVARCHAR(MAX) NOT NULL;
ALTER TABLE Owners ALTER COLUMN Name    NVARCHAR(MAX) NOT NULL;
ALTER TABLE Owners ALTER COLUMN Contact NVARCHAR(MAX) NOT NULL;
ALTER TABLE Owners ALTER COLUMN Email   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Owners ALTER COLUMN Status  NVARCHAR(MAX) NOT NULL;
PRINT 'Owners — done';
GO

-- ============================================================
-- Floors
-- ============================================================
ALTER TABLE Floors ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Floors ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
PRINT 'Floors — done';
GO

-- ============================================================
-- RoomStatuses
-- ============================================================
-- NOTE: NVARCHAR(MAX) cannot be UNIQUE — drop old unique constraint first
DECLARE @uc NVARCHAR(200) = (
    SELECT name FROM sys.indexes
    WHERE object_id = OBJECT_ID('RoomStatuses') AND is_unique = 1 AND type_desc = 'NONCLUSTERED'
);
IF @uc IS NOT NULL
    EXEC('ALTER TABLE RoomStatuses DROP CONSTRAINT [' + @uc + ']');
ALTER TABLE RoomStatuses ALTER COLUMN Name NVARCHAR(MAX) NOT NULL;
PRINT 'RoomStatuses — done';
GO

-- ============================================================
-- PaymentModes
-- ============================================================
DECLARE @uc2 NVARCHAR(200) = (
    SELECT name FROM sys.indexes
    WHERE object_id = OBJECT_ID('PaymentModes') AND is_unique = 1 AND type_desc = 'NONCLUSTERED'
);
IF @uc2 IS NOT NULL
    EXEC('ALTER TABLE PaymentModes DROP CONSTRAINT [' + @uc2 + ']');
ALTER TABLE PaymentModes ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE PaymentModes ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
PRINT 'PaymentModes — done';
GO

-- ============================================================
-- FundPools
-- ============================================================
ALTER TABLE FundPools ALTER COLUMN Code   NVARCHAR(MAX) NOT NULL;
ALTER TABLE FundPools ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE FundPools ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
PRINT 'FundPools — done';
GO

-- ============================================================
-- AccountsHeads
-- ============================================================
ALTER TABLE AccountsHeads ALTER COLUMN Code   NVARCHAR(MAX) NOT NULL;
ALTER TABLE AccountsHeads ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE AccountsHeads ALTER COLUMN Type   NVARCHAR(MAX) NOT NULL;
ALTER TABLE AccountsHeads ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
PRINT 'AccountsHeads — done';
GO

-- ============================================================
-- Designations
-- ============================================================
ALTER TABLE Designations ALTER COLUMN Code   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Designations ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Designations ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
PRINT 'Designations — done';
GO

-- ============================================================
-- OtherPersons
-- ============================================================
ALTER TABLE OtherPersons ALTER COLUMN Code        NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Designation NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Name        NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Mobile      NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Email       NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Address     NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN City        NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN State       NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Pincode     NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Remarks     NVARCHAR(MAX) NOT NULL;
ALTER TABLE OtherPersons ALTER COLUMN Status      NVARCHAR(MAX) NOT NULL;
PRINT 'OtherPersons — done';
GO

-- ============================================================
-- Roles
-- ============================================================
ALTER TABLE Roles ALTER COLUMN RoleCode NVARCHAR(MAX) NOT NULL;
ALTER TABLE Roles ALTER COLUMN RoleName NVARCHAR(MAX) NOT NULL;
ALTER TABLE Roles ALTER COLUMN Status   NVARCHAR(MAX) NOT NULL;
PRINT 'Roles — done';
GO

-- ============================================================
-- Camps
-- ============================================================
ALTER TABLE Camps ALTER COLUMN Code   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Camps ALTER COLUMN Name   NVARCHAR(MAX) NOT NULL;
ALTER TABLE Camps ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;

IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPropertyUsage')
    ALTER TABLE Camps ALTER COLUMN CampPropertyUsage NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampBuildingName')
    ALTER TABLE Camps ALTER COLUMN CampBuildingName  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPropertyType')
    ALTER TABLE Camps ALTER COLUMN CampPropertyType  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampLocation')
    ALTER TABLE Camps ALTER COLUMN CampLocation      NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPropertyNo')
    ALTER TABLE Camps ALTER COLUMN CampPropertyNo    NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPropertyArea')
    ALTER TABLE Camps ALTER COLUMN CampPropertyArea  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPremisesNo')
    ALTER TABLE Camps ALTER COLUMN CampPremisesNo    NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampPlotNo')
    ALTER TABLE Camps ALTER COLUMN CampPlotNo        NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Camps') AND name='CampMakaniNo')
    ALTER TABLE Camps ALTER COLUMN CampMakaniNo      NVARCHAR(MAX) NOT NULL;
PRINT 'Camps — done';
GO

-- ============================================================
-- CampPartners / CampOwners
-- ============================================================
ALTER TABLE CampPartners ALTER COLUMN ShareType NVARCHAR(MAX) NOT NULL;
ALTER TABLE CampOwners   ALTER COLUMN ShareType NVARCHAR(MAX) NOT NULL;
PRINT 'CampPartners / CampOwners — done';
GO

-- ============================================================
-- Rooms
-- ============================================================
ALTER TABLE Rooms ALTER COLUMN RoomNo       NVARCHAR(MAX) NOT NULL;
ALTER TABLE Rooms ALTER COLUMN Status       NVARCHAR(MAX) NOT NULL;
ALTER TABLE Rooms ALTER COLUMN OtherDetails NVARCHAR(MAX) NOT NULL;
PRINT 'Rooms — done';
GO

-- ============================================================
-- Tenants
-- ============================================================
ALTER TABLE Tenants ALTER COLUMN Type                NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Name                NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Passport            NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Nationality         NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN EmiratesId          NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Contact             NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Whatsapp            NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Email               NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Address             NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Status              NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN Company             NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN TradeLicense        NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LicensingAuthority  NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN NumberOfCoOccupants NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN PlotNo              NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN MakaniNo            NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN PropertyArea        NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN PremisesNo          NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorName          NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorEid           NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorLicense       NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorLicAuthority  NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorEmail         NVARCHAR(MAX) NOT NULL;
ALTER TABLE Tenants ALTER COLUMN LessorPhone         NVARCHAR(MAX) NOT NULL;
PRINT 'Tenants — done';
GO

-- ============================================================
-- Contracts
-- ============================================================
-- ContractId has FK reference — cannot alter directly; skip UNIQUE constraint
ALTER TABLE Contracts ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;

IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='InstallmentType')
    ALTER TABLE Contracts ALTER COLUMN InstallmentType NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='IssuedBy')
    ALTER TABLE Contracts ALTER COLUMN IssuedBy        NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='Notes')
    ALTER TABLE Contracts ALTER COLUMN Notes           NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPropertyUsage')
    ALTER TABLE Contracts ALTER COLUMN ContractPropertyUsage NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractBuildingName')
    ALTER TABLE Contracts ALTER COLUMN ContractBuildingName  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPropertyType')
    ALTER TABLE Contracts ALTER COLUMN ContractPropertyType  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractLocation')
    ALTER TABLE Contracts ALTER COLUMN ContractLocation      NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPropertyNo')
    ALTER TABLE Contracts ALTER COLUMN ContractPropertyNo    NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPropertyArea')
    ALTER TABLE Contracts ALTER COLUMN ContractPropertyArea  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPremisesNo')
    ALTER TABLE Contracts ALTER COLUMN ContractPremisesNo    NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPaymentMode')
    ALTER TABLE Contracts ALTER COLUMN ContractPaymentMode   NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractPlotNo')
    ALTER TABLE Contracts ALTER COLUMN ContractPlotNo        NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='ContractMakaniNo')
    ALTER TABLE Contracts ALTER COLUMN ContractMakaniNo      NVARCHAR(MAX) NOT NULL;
PRINT 'Contracts — done';
GO

-- ============================================================
-- Payments / ContractInstallments
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='Payments')
BEGIN
    ALTER TABLE Payments ALTER COLUMN Status          NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN PaymentMode     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN ChequeNumber    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN ClearanceDate   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN Description     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN ReceivedBy      NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN ReceivedContact NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN FundPoolName    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Payments ALTER COLUMN IssuedBy        NVARCHAR(MAX) NOT NULL;
    PRINT 'Payments — done';
END
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE name='ContractInstallments')
BEGIN
    ALTER TABLE ContractInstallments ALTER COLUMN Status          NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN PaymentMode     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN ChequeNumber    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN ClearanceDate   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN Description     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN ReceivedBy      NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN ReceivedContact NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN FundPoolName    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE ContractInstallments ALTER COLUMN IssuedBy        NVARCHAR(MAX) NOT NULL;
    PRINT 'ContractInstallments — done';
END
GO

-- ============================================================
-- Waivers
-- ============================================================
ALTER TABLE Waivers ALTER COLUMN Remark NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Waivers') AND name='WaiverCode')
    ALTER TABLE Waivers ALTER COLUMN WaiverCode NVARCHAR(MAX) NOT NULL;
PRINT 'Waivers — done';
GO

-- ============================================================
-- AppUsers
-- ============================================================
ALTER TABLE AppUsers ALTER COLUMN UserId       NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Name         NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN PasswordHash NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Role         NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Source       NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Contact      NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Email        NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN LoginAccess  NVARCHAR(MAX) NOT NULL;
ALTER TABLE AppUsers ALTER COLUMN Status       NVARCHAR(MAX) NOT NULL;
-- MenuAccess already NVARCHAR(MAX) — skip
-- Username has UNIQUE index — cannot change to MAX
PRINT 'AppUsers — done (Username skipped: has UNIQUE index)';
GO

-- ============================================================
-- Staff
-- ============================================================
ALTER TABLE Staff ALTER COLUMN StaffId     NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Name        NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Role        NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Contact     NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Email       NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Address     NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Password    NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN LoginAccess NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Status      NVARCHAR(MAX) NOT NULL;
ALTER TABLE Staff ALTER COLUMN Remarks     NVARCHAR(MAX) NOT NULL;
-- Username has UNIQUE index — skip

IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='Designation')
    ALTER TABLE Staff ALTER COLUMN Designation NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='EmiratesId')
    ALTER TABLE Staff ALTER COLUMN EmiratesId  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='PassportNo')
    ALTER TABLE Staff ALTER COLUMN PassportNo  NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='Nationality')
    ALTER TABLE Staff ALTER COLUMN Nationality NVARCHAR(MAX) NOT NULL;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='JobTitle')
    ALTER TABLE Staff ALTER COLUMN JobTitle    NVARCHAR(MAX) NOT NULL;
PRINT 'Staff — done (Username skipped: has UNIQUE index)';
GO

-- ============================================================
-- Incomes
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='Incomes')
BEGIN
    ALTER TABLE Incomes ALTER COLUMN IncomeId    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Incomes ALTER COLUMN Mode        NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Incomes ALTER COLUMN Head        NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Incomes ALTER COLUMN FundPool    NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='FundPoolName')
        ALTER TABLE Incomes ALTER COLUMN FundPoolName NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='Purpose')
        ALTER TABLE Incomes ALTER COLUMN Purpose      NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='Source')
        ALTER TABLE Incomes ALTER COLUMN Source       NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='SourceRef')
        ALTER TABLE Incomes ALTER COLUMN SourceRef    NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='CampName')
        ALTER TABLE Incomes ALTER COLUMN CampName     NVARCHAR(MAX) NOT NULL;
    PRINT 'Incomes — done';
END
GO

-- ============================================================
-- Expenses
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='Expenses')
BEGIN
    ALTER TABLE Expenses ALTER COLUMN ExpenseId    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN Mode         NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN Head         NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN FundPool     NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Expenses') AND name='FundPoolName')
        ALTER TABLE Expenses ALTER COLUMN FundPoolName   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN Nature       NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Expenses') AND name='CampName')
        ALTER TABLE Expenses ALTER COLUMN CampName       NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN RecipientRole NVARCHAR(MAX) NOT NULL;
    ALTER TABLE Expenses ALTER COLUMN RecipientName NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Expenses') AND name='Purpose')
        ALTER TABLE Expenses ALTER COLUMN Purpose        NVARCHAR(MAX) NOT NULL;
    PRINT 'Expenses — done';
END
GO

-- ============================================================
-- OwnerContracts
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerContracts')
BEGIN
    ALTER TABLE OwnerContracts ALTER COLUMN OcCode      NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerContracts ALTER COLUMN CampName    NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerContracts ALTER COLUMN OwnerName   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerContracts ALTER COLUMN OwnerCode   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerContracts ALTER COLUMN PaymentType NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerContracts ALTER COLUMN Status      NVARCHAR(MAX) NOT NULL;
    PRINT 'OwnerContracts — done';
END
GO

-- ============================================================
-- OwnerInstallments
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerInstallments')
BEGIN
    ALTER TABLE OwnerInstallments ALTER COLUMN Status NVARCHAR(MAX) NOT NULL;
    PRINT 'OwnerInstallments — done';
END
GO

-- ============================================================
-- OwnerTransactions
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerTransactions')
BEGIN
    ALTER TABLE OwnerTransactions ALTER COLUMN TxnCode       NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN OcCode        NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN CampName      NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN OwnerName     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN Type          NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN Description   NVARCHAR(MAX) NOT NULL;
    ALTER TABLE OwnerTransactions ALTER COLUMN InstallmentNos NVARCHAR(MAX) NOT NULL;
    PRINT 'OwnerTransactions — done';
END
GO

-- ============================================================
-- TxnRecords
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.tables WHERE name='TxnRecords')
BEGIN
    ALTER TABLE TxnRecords ALTER COLUMN PaymentMode         NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN ChequeNumber        NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN Description         NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN IssuedBy            NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN ReceivedBy          NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN ReceivedContact     NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN FundPoolName        NVARCHAR(MAX) NOT NULL;
    ALTER TABLE TxnRecords ALTER COLUMN AppliedInstallments NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='TxnType')
        ALTER TABLE TxnRecords ALTER COLUMN TxnType     NVARCHAR(MAX) NOT NULL;
    IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='ContractCode')
        ALTER TABLE TxnRecords ALTER COLUMN ContractCode NVARCHAR(MAX) NOT NULL;
    PRINT 'TxnRecords — done';
END
GO

PRINT '=== Script 025 complete — All string columns set to NVARCHAR(MAX) ===';
GO
