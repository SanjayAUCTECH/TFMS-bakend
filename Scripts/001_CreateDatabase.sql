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
    Code        NVARCHAR(20)  NOT NULL UNIQUE,
    Name        NVARCHAR(200) NOT NULL,
    Contact     NVARCHAR(100) NOT NULL DEFAULT '',
    Mobile      NVARCHAR(20)  NOT NULL DEFAULT '',
    Email       NVARCHAR(150) NOT NULL DEFAULT '',
    Status      NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Owners (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(20)  NOT NULL UNIQUE,
    Name      NVARCHAR(200) NOT NULL,
    Contact   NVARCHAR(20)  NOT NULL DEFAULT '',
    Email     NVARCHAR(150) NOT NULL DEFAULT '',
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Floors (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Name      NVARCHAR(100) NOT NULL,
    Number    INT           NOT NULL DEFAULT 0,
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE RoomStatuses (
    Id   INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE PaymentModes (
    Id     INT IDENTITY(1,1) PRIMARY KEY,
    Name   NVARCHAR(50) NOT NULL UNIQUE,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE FundPools (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(20)  NOT NULL UNIQUE,
    Name      NVARCHAR(200) NOT NULL,
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    Balance   DECIMAL(18,2) NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE AccountsHeads (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(20)  NOT NULL UNIQUE,
    Name      NVARCHAR(200) NOT NULL,
    Type      NVARCHAR(30)  NOT NULL DEFAULT '',
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Designations (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(20)  NOT NULL UNIQUE,
    Name      NVARCHAR(100) NOT NULL,
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE OtherPersons (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(20)  NOT NULL UNIQUE,
    Designation NVARCHAR(50)  NOT NULL DEFAULT '',
    Name        NVARCHAR(200) NOT NULL,
    Mobile      NVARCHAR(20)  NOT NULL DEFAULT '',
    Email       NVARCHAR(150) NOT NULL DEFAULT '',
    Address     NVARCHAR(300) NOT NULL DEFAULT '',
    City        NVARCHAR(100) NOT NULL DEFAULT '',
    State       NVARCHAR(100) NOT NULL DEFAULT '',
    Pincode     NVARCHAR(10)  NOT NULL DEFAULT '',
    Remarks     NVARCHAR(300) NOT NULL DEFAULT '',
    Status      NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Roles (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    RoleCode  NVARCHAR(20)  NOT NULL UNIQUE,
    RoleName  NVARCHAR(100) NOT NULL,
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── CAMPS & ROOMS ─────────────────────────────────────────────

CREATE TABLE Camps (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    Code      NVARCHAR(20)  NOT NULL UNIQUE,
    Name      NVARCHAR(200) NOT NULL,
    Rooms     INT           NOT NULL DEFAULT 0,
    Floors    INT           NOT NULL DEFAULT 0,
    Status    NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE CampPartners (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    CampId      INT           NOT NULL REFERENCES Camps(Id)    ON DELETE CASCADE,
    PartnerId   INT           NOT NULL REFERENCES Partners(Id) ON DELETE CASCADE,
    ShareType   NVARCHAR(20)  NOT NULL DEFAULT 'percentage',
    ShareValue  DECIMAL(18,2) NOT NULL DEFAULT 0
);

CREATE TABLE CampOwners (
    Id         INT IDENTITY(1,1) PRIMARY KEY,
    CampId     INT           NOT NULL REFERENCES Camps(Id)  ON DELETE CASCADE,
    OwnerId    INT           NOT NULL REFERENCES Owners(Id) ON DELETE CASCADE,
    ShareType  NVARCHAR(20)  NOT NULL DEFAULT 'percentage',
    ShareValue DECIMAL(18,2) NOT NULL DEFAULT 0
);

CREATE TABLE Rooms (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    RoomNo       NVARCHAR(20)  NOT NULL,
    CampId       INT           NOT NULL REFERENCES Camps(Id),
    FloorId      INT           NOT NULL REFERENCES Floors(Id),
    Occupied     BIT           NOT NULL DEFAULT 0,
    MonthlyPrice DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status       NVARCHAR(30)  NOT NULL DEFAULT 'Vacant',
    OtherDetails NVARCHAR(200) NOT NULL DEFAULT '',
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── TENANTS & CONTRACTS ───────────────────────────────────────

CREATE TABLE Tenants (
    Id                   INT IDENTITY(1,1) PRIMARY KEY,
    Type                 NVARCHAR(20)  NOT NULL DEFAULT 'Individual',
    Name                 NVARCHAR(200) NOT NULL,
    Passport             NVARCHAR(50)  NOT NULL DEFAULT '',
    Nationality          NVARCHAR(50)  NOT NULL DEFAULT '',
    EmiratesId           NVARCHAR(30)  NOT NULL DEFAULT '',
    Contact              NVARCHAR(20)  NOT NULL DEFAULT '',
    Whatsapp             NVARCHAR(20)  NOT NULL DEFAULT '',
    Email                NVARCHAR(150) NOT NULL DEFAULT '',
    Address              NVARCHAR(500) NOT NULL DEFAULT '',
    Status               NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    Company              NVARCHAR(200) NOT NULL DEFAULT '',
    TradeLicense         NVARCHAR(100) NOT NULL DEFAULT '',
    LicensingAuthority   NVARCHAR(100) NOT NULL DEFAULT '',
    NumberOfCoOccupants  NVARCHAR(10)  NOT NULL DEFAULT '',
    PlotNo               NVARCHAR(30)  NOT NULL DEFAULT '',
    MakaniNo             NVARCHAR(30)  NOT NULL DEFAULT '',
    PropertyArea         NVARCHAR(20)  NOT NULL DEFAULT '',
    PremisesNo           NVARCHAR(30)  NOT NULL DEFAULT '',
    LessorName           NVARCHAR(200) NOT NULL DEFAULT '',
    LessorEid            NVARCHAR(30)  NOT NULL DEFAULT '',
    LessorLicense        NVARCHAR(100) NOT NULL DEFAULT '',
    LessorLicAuthority   NVARCHAR(100) NOT NULL DEFAULT '',
    LessorEmail          NVARCHAR(150) NOT NULL DEFAULT '',
    LessorPhone          NVARCHAR(20)  NOT NULL DEFAULT '',
    CreatedAt            DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt            DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Contracts (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    ContractId    NVARCHAR(20)  NOT NULL UNIQUE,
    TenantId      INT           NOT NULL REFERENCES Tenants(Id),
    CampId        INT           NOT NULL REFERENCES Camps(Id),
    StartDate     DATE          NOT NULL,
    Months        INT           NOT NULL DEFAULT 12,
    EndDate       DATE          NOT NULL,
    MonthlyTotal  DECIMAL(18,2) NOT NULL DEFAULT 0,
    ContractTotal DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status        NVARCHAR(20)  NOT NULL DEFAULT 'Active',
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE ContractRooms (
    Id         INT IDENTITY(1,1) PRIMARY KEY,
    ContractId NVARCHAR(20) NOT NULL REFERENCES Contracts(ContractId) ON DELETE CASCADE,
    RoomId     INT          NOT NULL REFERENCES Rooms(Id)
);

-- ── PAYMENTS ─────────────────────────────────────────────────

CREATE TABLE Payments (
    Id               INT IDENTITY(1,1) PRIMARY KEY,
    ContractId       NVARCHAR(20)  NOT NULL REFERENCES Contracts(ContractId),
    InstallmentNo    INT           NOT NULL,
    Amount           DECIMAL(18,2) NOT NULL DEFAULT 0,
    DueDate          DATE          NOT NULL,
    PaidAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaidDate         DATE          NULL,
    Status           NVARCHAR(20)  NOT NULL DEFAULT 'Pending',
    PaymentMode      NVARCHAR(50)  NOT NULL DEFAULT '',
    PaymentModeId    INT           NULL,
    ChequeNumber     NVARCHAR(50)  NOT NULL DEFAULT '',
    ClearanceDate    NVARCHAR(50)  NOT NULL DEFAULT '',
    Description      NVARCHAR(500) NOT NULL DEFAULT '',
    ReceivedBy       NVARCHAR(200) NOT NULL DEFAULT '',
    ReceivedContact  NVARCHAR(20)  NOT NULL DEFAULT '',
    FundPoolId       INT           NULL,
    FundPoolName     NVARCHAR(200) NOT NULL DEFAULT '',
    IssuedBy         NVARCHAR(50)  NOT NULL DEFAULT ''
);

CREATE TABLE Waivers (
    Id             INT IDENTITY(1,1) PRIMARY KEY,
    TenantId       INT           NOT NULL REFERENCES Tenants(Id),
    ContractId     NVARCHAR(20)  NOT NULL REFERENCES Contracts(ContractId),
    InstallmentNo  INT           NOT NULL,
    OriginalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    WaiverAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
    BalanceAmount  DECIMAL(18,2) NOT NULL DEFAULT 0,
    Remark         NVARCHAR(300) NOT NULL DEFAULT '',
    WaiverDate     DATE          NOT NULL
);

CREATE TABLE TxnRecords (
    Id                  INT IDENTITY(1,1) PRIMARY KEY,
    TxnId               NVARCHAR(20)  NOT NULL UNIQUE,
    ContractId          NVARCHAR(20)  NOT NULL REFERENCES Contracts(ContractId),
    Amount              DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaidDate            DATE          NOT NULL,
    PaymentMode         NVARCHAR(50)  NOT NULL DEFAULT '',
    PaymentModeId       INT           NULL,
    ChequeNumber        NVARCHAR(50)  NOT NULL DEFAULT '',
    Description         NVARCHAR(500) NOT NULL DEFAULT '',
    IssuedBy            NVARCHAR(100) NOT NULL DEFAULT '',
    ReceivedBy          NVARCHAR(200) NOT NULL DEFAULT '',
    ReceivedContact     NVARCHAR(20)  NOT NULL DEFAULT '',
    FundPoolId          INT           NULL,
    FundPoolName        NVARCHAR(200) NOT NULL DEFAULT '',
    AppliedInstallments NVARCHAR(200) NOT NULL DEFAULT '',
    Unallocated         DECIMAL(18,2) NOT NULL DEFAULT 0
);

-- ── INCOME / EXPENSE ─────────────────────────────────────────

CREATE TABLE Incomes (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    IncomeId     NVARCHAR(20)  NOT NULL UNIQUE,
    Date         DATE          NOT NULL,
    Mode         NVARCHAR(50)  NOT NULL DEFAULT '',
    Head         NVARCHAR(200) NOT NULL DEFAULT '',
    FundPool     NVARCHAR(20)  NOT NULL DEFAULT '',
    FundPoolName NVARCHAR(200) NOT NULL DEFAULT '',
    Amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
    Purpose      NVARCHAR(500) NOT NULL DEFAULT '',
    Source       NVARCHAR(50)  NOT NULL DEFAULT '',
    SourceRef    NVARCHAR(50)  NOT NULL DEFAULT '',
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE Expenses (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    ExpenseId     NVARCHAR(20)  NOT NULL UNIQUE,
    Date          DATE          NOT NULL,
    Mode          NVARCHAR(50)  NOT NULL DEFAULT '',
    Head          NVARCHAR(200) NOT NULL DEFAULT '',
    FundPool      NVARCHAR(20)  NOT NULL DEFAULT '',
    FundPoolName  NVARCHAR(200) NOT NULL DEFAULT '',
    Amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    Nature        NVARCHAR(30)  NOT NULL DEFAULT 'HO',
    CampId        INT           NULL,
    CampName      NVARCHAR(200) NOT NULL DEFAULT '',
    RecipientRole NVARCHAR(30)  NOT NULL DEFAULT '',
    RecipientName NVARCHAR(200) NOT NULL DEFAULT '',
    Purpose       NVARCHAR(500) NOT NULL DEFAULT '',
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- ── OWNER CONTRACTS ──────────────────────────────────────────

CREATE TABLE OwnerContracts (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    OcCode      NVARCHAR(20)  NOT NULL UNIQUE,
    CampId      INT           NOT NULL REFERENCES Camps(Id),
    CampName    NVARCHAR(200) NOT NULL DEFAULT '',
    OwnerId     INT           NOT NULL REFERENCES Owners(Id),
    OwnerName   NVARCHAR(200) NOT NULL DEFAULT '',
    OwnerCode   NVARCHAR(20)  NOT NULL DEFAULT '',
    PaymentType NVARCHAR(20)  NOT NULL DEFAULT 'monthly',
    TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    StartDate   DATE          NOT NULL,
    Status      NVARCHAR(20)  NOT NULL DEFAULT 'Active',
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
    Status          NVARCHAR(20)  NOT NULL DEFAULT 'Pending',
    ExpenseId       INT           NULL
);

CREATE TABLE OwnerTransactions (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    TxnCode         NVARCHAR(20)  NOT NULL UNIQUE,
    OwnerContractId INT           NULL REFERENCES OwnerContracts(Id),
    OcCode          NVARCHAR(20)  NOT NULL DEFAULT '',
    CampId          INT           NULL,
    CampName        NVARCHAR(200) NOT NULL DEFAULT '',
    OwnerId         INT           NOT NULL,
    OwnerName       NVARCHAR(200) NOT NULL DEFAULT '',
    Type            NVARCHAR(5)   NOT NULL DEFAULT 'DR',
    Amount          DECIMAL(18,2) NOT NULL DEFAULT 0,
    Date            DATE          NOT NULL,
    Description     NVARCHAR(500) NOT NULL DEFAULT '',
    InstallmentNos  NVARCHAR(200) NOT NULL DEFAULT '',
    ExpenseId       INT           NULL
);

-- ── USERS ────────────────────────────────────────────────────

CREATE TABLE AppUsers (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    UserId       NVARCHAR(20)     NOT NULL UNIQUE,
    Name         NVARCHAR(200)    NOT NULL,
    Username     NVARCHAR(50)     NOT NULL UNIQUE,
    PasswordHash NVARCHAR(300)    NOT NULL,
    Role         NVARCHAR(50)     NOT NULL DEFAULT '',
    Source       NVARCHAR(50)     NOT NULL DEFAULT '',
    SourceId     INT              NULL,
    Contact      NVARCHAR(20)     NOT NULL DEFAULT '',
    Email        NVARCHAR(150)    NOT NULL DEFAULT '',
    LoginAccess  NVARCHAR(20)     NOT NULL DEFAULT 'enabled',
    Status       NVARCHAR(20)     NOT NULL DEFAULT 'Active',
    LastLogin    DATETIME2        NULL,
    MenuAccess   NVARCHAR(MAX)    NOT NULL DEFAULT '{}',
    IsAdmin      BIT              NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt    DATETIME2        NOT NULL DEFAULT GETUTCDATE()
);

-- ── SEED: Admin user (password: Admin@123) ───────────────────
-- BCrypt hash of Admin@123
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
