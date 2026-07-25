-- ============================================================
-- 070: Add Audit Columns to all tables
--      AddedBy, UpdatedBy, DeletedBy (INT NULL) — UserId
--      IsDeleted (BIT NOT NULL DEFAULT 0)
-- Date: July 24, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Helper macro: add columns if not exists
DECLARE @tables TABLE (tbl NVARCHAR(128));
INSERT INTO @tables VALUES
  ('AccountsHeads'),('AppUsers'),('CampOwners'),('CampPartners'),
  ('Camps'),('CompanyAssets'),('ContractCamps'),('ContractCancellations'),
  ('ContractInstallments'),('ContractRenewals'),('ContractRoomInstallments'),
  ('ContractRooms'),('ContractRoomsTrns'),('Contracts'),('ContractTerms'),
  ('Designations'),('Expenses'),('Floors'),('FundPools'),('Incomes'),
  ('OtherPersons'),('OutgoingPayments'),('OwnerContracts'),('OwnerInstallments'),
  ('OwnerMonthlyContractInstallments'),('Owners'),('OwnerTransactions'),
  ('Partners'),('PaymentModes'),('Payments'),('Rooms'),('Staff'),
  ('Tenants'),('TxnRecords'),('Waivers');

DECLARE @tbl NVARCHAR(128);
DECLARE @sql NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT tbl FROM @tables;
OPEN cur;
FETCH NEXT FROM cur INTO @tbl;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- AddedBy
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='AddedBy')
    BEGIN
        SET @sql = 'ALTER TABLE ' + QUOTENAME(@tbl) + ' ADD AddedBy INT NULL';
        EXEC sp_executesql @sql;
        PRINT 'Added AddedBy to ' + @tbl;
    END

    -- UpdatedBy
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='UpdatedBy')
    BEGIN
        SET @sql = 'ALTER TABLE ' + QUOTENAME(@tbl) + ' ADD UpdatedBy INT NULL';
        EXEC sp_executesql @sql;
        PRINT 'Added UpdatedBy to ' + @tbl;
    END

    -- DeletedBy
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='DeletedBy')
    BEGIN
        SET @sql = 'ALTER TABLE ' + QUOTENAME(@tbl) + ' ADD DeletedBy INT NULL';
        EXEC sp_executesql @sql;
        PRINT 'Added DeletedBy to ' + @tbl;
    END

    -- IsDeleted
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(@tbl) AND name='IsDeleted')
    BEGIN
        SET @sql = 'ALTER TABLE ' + QUOTENAME(@tbl) + ' ADD IsDeleted BIT NOT NULL DEFAULT 0';
        EXEC sp_executesql @sql;
        PRINT 'Added IsDeleted to ' + @tbl;
    END

    FETCH NEXT FROM cur INTO @tbl;
END;

CLOSE cur; DEALLOCATE cur;
GO

PRINT '070 - Audit columns added to all tables';
GO
