-- ============================================================
-- TFMS — Fix missing columns & tables (UI audit)
-- Database: TFMS_softwareDB
-- ============================================================
USE TFMS_softwareDB;
GO

-- ── 1. CONTRACTS — add missing columns ───────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='SecurityDeposit')
    ALTER TABLE Contracts ADD SecurityDeposit DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='InstallmentType')
    ALTER TABLE Contracts ADD InstallmentType NVARCHAR(20) NOT NULL DEFAULT 'monthly';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='IssuedBy')
    ALTER TABLE Contracts ADD IssuedBy NVARCHAR(100) NOT NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Contracts') AND name='Notes')
    ALTER TABLE Contracts ADD Notes NVARCHAR(1000) NOT NULL DEFAULT '';
GO

-- ── 2. WAIVERS — add WaiverCode ──────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Waivers') AND name='WaiverCode')
    ALTER TABLE Waivers ADD WaiverCode NVARCHAR(20) NOT NULL DEFAULT '';
GO
-- Backfill existing waivers
UPDATE Waivers SET WaiverCode = 'WAI-' + RIGHT('000000'+CAST(Id AS NVARCHAR),6) WHERE WaiverCode='';
GO

-- ── 3. STAFF — add Designation column ────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Staff') AND name='Designation')
    ALTER TABLE Staff ADD Designation NVARCHAR(100) NOT NULL DEFAULT '';
GO

-- ── 4. INCOMES — add CampId, CampName ────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='CampId')
    ALTER TABLE Incomes ADD CampId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='CampName')
    ALTER TABLE Incomes ADD CampName NVARCHAR(200) NOT NULL DEFAULT '';
GO

-- ── 5. OWNER CONTRACTS table ─────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerContracts')
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
    CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ── 6. OWNER INSTALLMENTS table ──────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerInstallments')
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
GO

-- ── 7. OWNER TRANSACTIONS table ──────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerTransactions')
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
    ExpenseId       INT           NULL,
    CreatedAt       DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ── 8. TXN RECORDS table (payment transactions) ──────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='TxnRecords')
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
    Unallocated         DECIMAL(18,2) NOT NULL DEFAULT 0,
    CreatedAt           DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

PRINT 'Schema fixes applied!';
GO
