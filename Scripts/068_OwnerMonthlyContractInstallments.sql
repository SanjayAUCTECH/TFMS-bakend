-- ============================================================
-- Create OwnerMonthlyContractInstallments table
-- Tracks monthly installment details for owner contracts
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Create the table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='OwnerMonthlyContractInstallments')
CREATE TABLE OwnerMonthlyContractInstallments (
    Id                           INT IDENTITY(1,1) PRIMARY KEY,
    MonthlyContractInstallmentId NVARCHAR(MAX)  NOT NULL,
    OwnerContractId              INT            NOT NULL REFERENCES OwnerContracts(Id) ON DELETE CASCADE,
    OwnerId                      INT            NOT NULL,
    CampId                       INT            NOT NULL,
    InstallmentNo                INT            NOT NULL,
    Amount                       DECIMAL(18,2)  NOT NULL DEFAULT 0,
    PaidAmount                   DECIMAL(18,2)  NOT NULL DEFAULT 0,
    Balance                      DECIMAL(18,2)  NOT NULL DEFAULT 0,
    DueDate                      DATE           NOT NULL,
    PaidDate                     DATE           NULL,
    Status                       NVARCHAR(MAX)  NOT NULL DEFAULT 'Pending',
    ExpenseId                    INT            NULL,
    PaymentMode                  NVARCHAR(MAX)  NOT NULL DEFAULT '',
    PaymentStatus                NVARCHAR(MAX)  NOT NULL DEFAULT 'Pending',
    CreatedAt                    DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt                    DATETIME2      NOT NULL DEFAULT GETUTCDATE()
);
GO

PRINT '✅ Table OwnerMonthlyContractInstallments created';
GO
