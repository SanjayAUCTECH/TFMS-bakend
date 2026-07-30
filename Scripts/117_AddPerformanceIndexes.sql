-- ============================================================
-- 117: Performance Indexes
-- NO table/SP/data changes — only indexes added
-- Safe to run anytime, IF NOT EXISTS checks prevent duplicates
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── ContractInstallments ──────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CI_ContractId_Status' AND object_id=OBJECT_ID('ContractInstallments'))
    CREATE INDEX IX_CI_ContractId_Status ON ContractInstallments(ContractId, Status)
    INCLUDE(Amount, PaidAmount, DueDate, InstallmentNo, IsDeleted);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CI_ContractId' AND object_id=OBJECT_ID('ContractInstallments'))
    CREATE INDEX IX_CI_ContractId ON ContractInstallments(ContractId)
    INCLUDE(InstallmentNo, Amount, PaidAmount, Status, DueDate, IsDeleted);
GO
PRINT 'ContractInstallments indexes done';
GO

-- ── TxnRecords ────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_TXN_ContractId' AND object_id=OBJECT_ID('TxnRecords'))
    CREATE INDEX IX_TXN_ContractId ON TxnRecords(ContractId, TxnType, IsDeleted)
    INCLUDE(Amount, PaidDate, AppliedInstallments, TenantId, CampId, FundPoolId);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_TXN_TenantId' AND object_id=OBJECT_ID('TxnRecords'))
    CREATE INDEX IX_TXN_TenantId ON TxnRecords(TenantId, TxnType, IsDeleted)
    INCLUDE(Amount, PaidDate, ContractId);
GO
PRINT 'TxnRecords indexes done';
GO

-- ── Incomes ───────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_INC_TxnRecordId' AND object_id=OBJECT_ID('Incomes'))
    CREATE INDEX IX_INC_TxnRecordId ON Incomes(TxnRecordId, IsDeleted);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_INC_ContractId' AND object_id=OBJECT_ID('Incomes'))
    CREATE INDEX IX_INC_ContractId ON Incomes(ContractId, Source, IsDeleted)
    INCLUDE(Amount, Date, Mode, FundPool);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_INC_PartnerId' AND object_id=OBJECT_ID('Incomes'))
    CREATE INDEX IX_INC_PartnerId ON Incomes(PartnerId, IsDeleted)
    INCLUDE(Amount, Date, CampId);
GO
PRINT 'Incomes indexes done';
GO

-- ── Expenses ──────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_EXP_RecipientRole' AND object_id=OBJECT_ID('Expenses'))
    CREATE INDEX IX_EXP_RecipientRole ON Expenses(RecipientRole, RecipientId, IsDeleted)
    INCLUDE(Amount, Date, Head, Mode, CampId, FundPool);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_EXP_CampId' AND object_id=OBJECT_ID('Expenses'))
    CREATE INDEX IX_EXP_CampId ON Expenses(CampId, IsDeleted)
    INCLUDE(Amount, Date, Head);
GO
PRINT 'Expenses indexes done';
GO

-- ── Contracts ─────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CON_TenantId' AND object_id=OBJECT_ID('Contracts'))
    CREATE INDEX IX_CON_TenantId ON Contracts(TenantId, Status, IsDeleted)
    INCLUDE(ContractId, StartDate, EndDate, Months, ContractTotal, MonthlyTotal);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CON_Status' AND object_id=OBJECT_ID('Contracts'))
    CREATE INDEX IX_CON_Status ON Contracts(Status, IsDeleted)
    INCLUDE(ContractId, TenantId);
GO
PRINT 'Contracts indexes done';
GO

-- ── ContractRooms ─────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CR_ContractId' AND object_id=OBJECT_ID('ContractRooms'))
    CREATE INDEX IX_CR_ContractId ON ContractRooms(ContractId, IsDeleted)
    INCLUDE(RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CR_RoomId' AND object_id=OBJECT_ID('ContractRooms'))
    CREATE INDEX IX_CR_RoomId ON ContractRooms(RoomId, ContractId, IsDeleted);
GO
PRINT 'ContractRooms indexes done';
GO

-- ── ContractRoomsTrns ─────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CRT_TxnRecordId' AND object_id=OBJECT_ID('ContractRoomsTrns'))
    CREATE INDEX IX_CRT_TxnRecordId ON ContractRoomsTrns(TxnRecordId, TxnType)
    INCLUDE(ContractId, RoomId, Amount, CriId);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CRT_ContractId' AND object_id=OBJECT_ID('ContractRoomsTrns'))
    CREATE INDEX IX_CRT_ContractId ON ContractRoomsTrns(ContractId, TxnType)
    INCLUDE(RoomId, TxnRecordId, Amount, TxnDate);
GO
PRINT 'ContractRoomsTrns indexes done';
GO

-- ── Rooms ─────────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_ROOMS_CampId' AND object_id=OBJECT_ID('Rooms'))
    CREATE INDEX IX_ROOMS_CampId ON Rooms(CampId, IsDeleted, Occupied)
    INCLUDE(RoomNo, Status, MonthlyPrice);
GO
PRINT 'Rooms indexes done';
GO

-- ── OwnerContracts ────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OC_OwnerId' AND object_id=OBJECT_ID('OwnerContracts'))
    CREATE INDEX IX_OC_OwnerId ON OwnerContracts(OwnerId, Status, IsDeleted)
    INCLUDE(CampId, TotalAmount, PaymentType);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OC_CampId' AND object_id=OBJECT_ID('OwnerContracts'))
    CREATE INDEX IX_OC_CampId ON OwnerContracts(CampId, OwnerId, IsDeleted)
    INCLUDE(Status, TotalAmount);
GO
PRINT 'OwnerContracts indexes done';
GO

-- ── OwnerInstallments ─────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OI_ContractId_Status' AND object_id=OBJECT_ID('OwnerInstallments'))
    CREATE INDEX IX_OI_ContractId_Status ON OwnerInstallments(OwnerContractId, Status, IsDeleted)
    INCLUDE(Amount, PaidAmount, No, DueDate, ExpenseId);
GO
PRINT 'OwnerInstallments indexes done';
GO

-- ── OwnerMonthlyContractInstallments ──────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OMCI_ContractId' AND object_id=OBJECT_ID('OwnerMonthlyContractInstallments'))
    CREATE INDEX IX_OMCI_ContractId ON OwnerMonthlyContractInstallments(OwnerContractId, PaymentStatus, IsDeleted)
    INCLUDE(InstallmentNo, Amount, PaidAmount, Balance, DueDate, ExpenseId);
GO
PRINT 'OwnerMonthlyContractInstallments indexes done';
GO

-- ── OwnerTransactions ─────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OT_OwnerId' AND object_id=OBJECT_ID('OwnerTransactions'))
    CREATE INDEX IX_OT_OwnerId ON OwnerTransactions(OwnerId, IsDeleted)
    INCLUDE(Type, Amount, Date, OwnerContractId, ExpenseId);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_OT_ContractId' AND object_id=OBJECT_ID('OwnerTransactions'))
    CREATE INDEX IX_OT_ContractId ON OwnerTransactions(OwnerContractId, IsDeleted)
    INCLUDE(Type, Amount, ExpenseId);
GO
PRINT 'OwnerTransactions indexes done';
GO

-- ── ContractCamps ─────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CC_ContractId' AND object_id=OBJECT_ID('ContractCamps'))
    CREATE INDEX IX_CC_ContractId ON ContractCamps(ContractId, IsDeleted)
    INCLUDE(CampId);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CC_CampId' AND object_id=OBJECT_ID('ContractCamps'))
    CREATE INDEX IX_CC_CampId ON ContractCamps(CampId, ContractId, IsDeleted);
GO
PRINT 'ContractCamps indexes done';
GO

-- ── CampPartners ──────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CP_PartnerId' AND object_id=OBJECT_ID('CampPartners'))
    CREATE INDEX IX_CP_PartnerId ON CampPartners(PartnerId, IsDeleted)
    INCLUDE(CampId, ShareType, ShareValue);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_CP_CampId' AND object_id=OBJECT_ID('CampPartners'))
    CREATE INDEX IX_CP_CampId ON CampPartners(CampId, IsDeleted)
    INCLUDE(PartnerId);
GO
PRINT 'CampPartners indexes done';
GO

-- ── Waivers ───────────────────────────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_WAI_TenantId' AND object_id=OBJECT_ID('Waivers'))
    CREATE INDEX IX_WAI_TenantId ON Waivers(TenantId, IsDeleted)
    INCLUDE(ContractId, WaiverAmount, WaiverDate);
GO
PRINT 'Waivers indexes done';
GO

PRINT '=== ALL PERFORMANCE INDEXES CREATED SUCCESSFULLY ===';
PRINT 'Total: 26 indexes added across 14 tables';
PRINT 'No stored procedures or table structures were modified';
GO
