-- ============================================================
-- TFMS Software Database Setup
-- Server : DESKTOP-01\SQLEXPRESS
-- Database: TFMS_softwareDB
-- ============================================================

USE master;
GO
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TFMS_softwareDB')
    CREATE DATABASE TFMS_softwareDB;
GO
USE TFMS_softwareDB;
GO

-- ── MASTERS ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS Partners (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name        NVARCHAR(MAX) NOT NULL,
    Contact     NVARCHAR(MAX) NOT NULL DEFAULT '',
    Mobile      NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Email       NVARCHAR(MAX) NOT NULL DEFAULT '',
    Status      NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Owners (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name      NVARCHAR(MAX) NOT NULL,
    Contact   NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Email     NVARCHAR(MAX) NOT NULL DEFAULT '',
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Floors (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Name      NVARCHAR(MAX) NOT NULL,
    Number    INT           NOT NULL DEFAULT 0,
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE RoomStatuses (
    Id   INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(MAX) NOT NULL UNIQUE
);

CREATE TABLE PaymentModes (
    Id     INT IDENTITY(1,1) PRIMARY KEY,
    Name   NVARCHAR(MAX) NOT NULL UNIQUE,
    Status NVARCHAR(MAX) NOT NULL DEFAULT 'Active'
);

CREATE TABLE FundPools (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name      NVARCHAR(MAX) NOT NULL,
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    Balance   DECIMAL(18,2) NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE AccountsHeads (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name      NVARCHAR(MAX) NOT NULL,
    Type      NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Designations (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name      NVARCHAR(MAX) NOT NULL,
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE OtherPersons (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(MAX)  NOT NULL UNIQUE,
    Designation NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Name        NVARCHAR(MAX) NOT NULL,
    Mobile      NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Email       NVARCHAR(MAX) NOT NULL DEFAULT '',
    Address     NVARCHAR(MAX) NOT NULL DEFAULT '',
    City        NVARCHAR(MAX) NOT NULL DEFAULT '',
    State       NVARCHAR(MAX) NOT NULL DEFAULT '',
    Pincode     NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Remarks     NVARCHAR(MAX) NOT NULL DEFAULT '',
    Status      NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Roles (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    RoleCode  NVARCHAR(MAX)  NOT NULL UNIQUE,
    RoleName  NVARCHAR(MAX) NOT NULL,
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── CAMPS & ROOMS ─────────────────────────────────────────────

CREATE TABLE Camps (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(MAX)  NOT NULL UNIQUE,
    Name      NVARCHAR(MAX) NOT NULL,
    Rooms     INT           NOT NULL DEFAULT 0,
    Floors    INT           NOT NULL DEFAULT 0,
    Status    NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE CampPartners (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    CampId      INT           NOT NULL REFERENCES Camps(Id)    ON DELETE CASCADE,
    PartnerId   INT           NOT NULL REFERENCES Partners(Id) ON DELETE CASCADE,
    ShareType   NVARCHAR(MAX)  NOT NULL DEFAULT 'percentage',
    ShareValue  DECIMAL(18,2) NOT NULL DEFAULT 0
);

CREATE TABLE CampOwners (
    Id         INT IDENTITY(1,1) PRIMARY KEY,
    CampId     INT           NOT NULL REFERENCES Camps(Id)  ON DELETE CASCADE,
    OwnerId    INT           NOT NULL REFERENCES Owners(Id) ON DELETE CASCADE,
    ShareType  NVARCHAR(MAX)  NOT NULL DEFAULT 'percentage',
    ShareValue DECIMAL(18,2) NOT NULL DEFAULT 0
);

CREATE TABLE Rooms (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    RoomNo       NVARCHAR(MAX)  NOT NULL,
    CampId       INT           NOT NULL REFERENCES Camps(Id),
    FloorId      INT           NOT NULL REFERENCES Floors(Id),
    Occupied     BIT           NOT NULL DEFAULT 0,
    MonthlyPrice DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status       NVARCHAR(MAX)  NOT NULL DEFAULT 'Vacant',
    OtherDetails NVARCHAR(MAX) NOT NULL DEFAULT '',
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── TENANTS & CONTRACTS ───────────────────────────────────────

CREATE TABLE Tenants (
    Id                   INT IDENTITY(1,1) PRIMARY KEY,
    Type                 NVARCHAR(MAX)  NOT NULL DEFAULT 'Individual',
    Name                 NVARCHAR(MAX) NOT NULL,
    Passport             NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Nationality          NVARCHAR(MAX)  NOT NULL DEFAULT '',
    EmiratesId           NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Contact              NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Whatsapp             NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Email                NVARCHAR(MAX) NOT NULL DEFAULT '',
    Address              NVARCHAR(MAX) NOT NULL DEFAULT '',
    Status               NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    Company              NVARCHAR(MAX) NOT NULL DEFAULT '',
    TradeLicense         NVARCHAR(MAX) NOT NULL DEFAULT '',
    LicensingAuthority   NVARCHAR(MAX) NOT NULL DEFAULT '',
    NumberOfCoOccupants  NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PlotNo               NVARCHAR(MAX)  NOT NULL DEFAULT '',
    MakaniNo             NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PropertyArea         NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PremisesNo           NVARCHAR(MAX)  NOT NULL DEFAULT '',
    LessorName           NVARCHAR(MAX) NOT NULL DEFAULT '',
    LessorEid            NVARCHAR(MAX)  NOT NULL DEFAULT '',
    LessorLicense        NVARCHAR(MAX) NOT NULL DEFAULT '',
    LessorLicAuthority   NVARCHAR(MAX) NOT NULL DEFAULT '',
    LessorEmail          NVARCHAR(MAX) NOT NULL DEFAULT '',
    LessorPhone          NVARCHAR(MAX)  NOT NULL DEFAULT '',
    CreatedAt            DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt            DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Contracts (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    ContractId    NVARCHAR(MAX)  NOT NULL UNIQUE,
    TenantId      INT           NOT NULL REFERENCES Tenants(Id),
    CampId        INT           NOT NULL REFERENCES Camps(Id),
    StartDate     DATE          NOT NULL,
    Months        INT           NOT NULL DEFAULT 12,
    EndDate       DATE          NOT NULL,
    MonthlyTotal  DECIMAL(18,2) NOT NULL DEFAULT 0,
    ContractTotal DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status        NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE ContractRooms (
    Id         INT IDENTITY(1,1) PRIMARY KEY,
    ContractId NVARCHAR(MAX) NOT NULL REFERENCES Contracts(ContractId) ON DELETE CASCADE,
    RoomId     INT          NOT NULL REFERENCES Rooms(Id)
);

-- ── PAYMENTS ─────────────────────────────────────────────────

CREATE TABLE Payments (
    Id               INT IDENTITY(1,1) PRIMARY KEY,
    ContractId       NVARCHAR(MAX)  NOT NULL REFERENCES Contracts(ContractId),
    InstallmentNo    INT           NOT NULL,
    Amount           DECIMAL(18,2) NOT NULL DEFAULT 0,
    DueDate          DATE          NOT NULL,
    PaidAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaidDate         DATE          NULL,
    Status           NVARCHAR(MAX)  NOT NULL DEFAULT 'Pending',
    PaymentMode      NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PaymentModeId    INT           NULL,
    ChequeNumber     NVARCHAR(MAX)  NOT NULL DEFAULT '',
    ClearanceDate    NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Description      NVARCHAR(MAX) NOT NULL DEFAULT '',
    ReceivedBy       NVARCHAR(MAX) NOT NULL DEFAULT '',
    ReceivedContact  NVARCHAR(MAX)  NOT NULL DEFAULT '',
    FundPoolId       INT           NULL,
    FundPoolName     NVARCHAR(MAX) NOT NULL DEFAULT '',
    IssuedBy         NVARCHAR(MAX)  NOT NULL DEFAULT ''
);

CREATE TABLE Waivers (
    Id             INT IDENTITY(1,1) PRIMARY KEY,
    TenantId       INT           NOT NULL REFERENCES Tenants(Id),
    ContractId     NVARCHAR(MAX)  NOT NULL REFERENCES Contracts(ContractId),
    InstallmentNo  INT           NOT NULL,
    OriginalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    WaiverAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
    BalanceAmount  DECIMAL(18,2) NOT NULL DEFAULT 0,
    Remark         NVARCHAR(MAX) NOT NULL DEFAULT '',
    WaiverDate     DATE          NOT NULL
);

CREATE TABLE TxnRecords (
    Id                  INT IDENTITY(1,1) PRIMARY KEY,
    TxnId               NVARCHAR(MAX)  NOT NULL UNIQUE,
    ContractId          NVARCHAR(MAX)  NOT NULL REFERENCES Contracts(ContractId),
    Amount              DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaidDate            DATE          NOT NULL,
    PaymentMode         NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PaymentModeId       INT           NULL,
    ChequeNumber        NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Description         NVARCHAR(MAX) NOT NULL DEFAULT '',
    IssuedBy            NVARCHAR(MAX) NOT NULL DEFAULT '',
    ReceivedBy          NVARCHAR(MAX) NOT NULL DEFAULT '',
    ReceivedContact     NVARCHAR(MAX)  NOT NULL DEFAULT '',
    FundPoolId          INT           NULL,
    FundPoolName        NVARCHAR(MAX) NOT NULL DEFAULT '',
    AppliedInstallments NVARCHAR(MAX) NOT NULL DEFAULT '',
    Unallocated         DECIMAL(18,2) NOT NULL DEFAULT 0
);

-- ── INCOME / EXPENSE ─────────────────────────────────────────

CREATE TABLE Incomes (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    IncomeId     NVARCHAR(MAX)  NOT NULL UNIQUE,
    Date         DATE          NOT NULL,
    Mode         NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Head         NVARCHAR(MAX) NOT NULL DEFAULT '',
    FundPool     NVARCHAR(MAX)  NOT NULL DEFAULT '',
    FundPoolName NVARCHAR(MAX) NOT NULL DEFAULT '',
    Amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    Purpose      NVARCHAR(MAX) NOT NULL DEFAULT '',
    Source       NVARCHAR(MAX)  NOT NULL DEFAULT '',
    SourceRef    NVARCHAR(MAX)  NOT NULL DEFAULT '',
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Expenses (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    ExpenseId     NVARCHAR(MAX)  NOT NULL UNIQUE,
    Date          DATE          NOT NULL,
    Mode          NVARCHAR(MAX)  NOT NULL DEFAULT '',
    Head          NVARCHAR(MAX) NOT NULL DEFAULT '',
    FundPool      NVARCHAR(MAX)  NOT NULL DEFAULT '',
    FundPoolName  NVARCHAR(MAX) NOT NULL DEFAULT '',
    Amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    Nature        NVARCHAR(MAX)  NOT NULL DEFAULT 'HO',
    CampId        INT           NULL,
    CampName      NVARCHAR(MAX) NOT NULL DEFAULT '',
    RecipientRole NVARCHAR(MAX)  NOT NULL DEFAULT '',
    RecipientName NVARCHAR(MAX) NOT NULL DEFAULT '',
    Purpose       NVARCHAR(MAX) NOT NULL DEFAULT '',
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── OWNER CONTRACTS ──────────────────────────────────────────

CREATE TABLE OwnerContracts (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    OcCode      NVARCHAR(MAX)  NOT NULL UNIQUE,
    CampId      INT           NOT NULL REFERENCES Camps(Id),
    CampName    NVARCHAR(MAX) NOT NULL DEFAULT '',
    OwnerId     INT           NOT NULL REFERENCES Owners(Id),
    OwnerName   NVARCHAR(MAX) NOT NULL DEFAULT '',
    OwnerCode   NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PaymentType NVARCHAR(MAX)  NOT NULL DEFAULT 'monthly',
    TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    StartDate   DATE          NOT NULL,
    Status      NVARCHAR(MAX)  NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE OwnerInstallments (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    OwnerContractId INT           NOT NULL REFERENCES OwnerContracts(Id) ON DELETE CASCADE,
    No              INT           NOT NULL,
    Amount          DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaidAmount      DECIMAL(18,2) NOT NULL DEFAULT 0,
    DueDate         DATE          NOT NULL,
    PaidDate        DATE          NULL,
    Status          NVARCHAR(MAX)  NOT NULL DEFAULT 'Pending',
    ExpenseId       INT           NULL
);

CREATE TABLE OwnerTransactions (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    TxnCode         NVARCHAR(MAX)  NOT NULL UNIQUE,
    OwnerContractId INT           NULL REFERENCES OwnerContracts(Id),
    OcCode          NVARCHAR(MAX)  NOT NULL DEFAULT '',
    CampId          INT           NULL,
    CampName        NVARCHAR(MAX) NOT NULL DEFAULT '',
    OwnerId         INT           NOT NULL,
    OwnerName       NVARCHAR(MAX) NOT NULL DEFAULT '',
    Type            NVARCHAR(MAX)   NOT NULL DEFAULT 'DR',
    Amount          DECIMAL(18,2) NOT NULL DEFAULT 0,
    Date            DATE          NOT NULL,
    Description     NVARCHAR(MAX) NOT NULL DEFAULT '',
    InstallmentNos  NVARCHAR(MAX) NOT NULL DEFAULT '',
    ExpenseId       INT           NULL
);

-- ── USERS ────────────────────────────────────────────────────

CREATE TABLE AppUsers (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    UserId       NVARCHAR(MAX)     NOT NULL UNIQUE,
    Name         NVARCHAR(MAX)    NOT NULL,
    Username     NVARCHAR(MAX)     NOT NULL UNIQUE,
    PasswordHash NVARCHAR(MAX)    NOT NULL,
    Role         NVARCHAR(MAX)     NOT NULL DEFAULT '',
    Source       NVARCHAR(MAX)     NOT NULL DEFAULT '',
    SourceId     INT              NULL,
    Contact      NVARCHAR(MAX)     NOT NULL DEFAULT '',
    Email        NVARCHAR(MAX)    NOT NULL DEFAULT '',
    LoginAccess  NVARCHAR(MAX)     NOT NULL DEFAULT 'enabled',
    Status       NVARCHAR(MAX)     NOT NULL DEFAULT 'Active',
    LastLogin    DATETIME2        NULL,
    MenuAccess   NVARCHAR(MAX)    NOT NULL DEFAULT '{}',
    IsAdmin      BIT              NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2        NOT NULL DEFAULT GETUTCDATE()
);

-- ── SEED: Admin user (password: Admin@123) ───────────────────
INSERT INTO AppUsers (UserId, Name, Username, PasswordHash, Role, IsAdmin, Status, LoginAccess, MenuAccess)
VALUES (
  'USR-000001',
  'System Administrator',
  'admin',
  '$2a$11$K8F4wVpIkq6U2xN3mZP1YeO8dEqRpLvCvMjHj9nTuSGmWzXpDkEwy',
  'Admin',
  1,
  'Active',
  'enabled',
  '{}'
);
GO
