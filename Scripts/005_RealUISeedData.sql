-- ============================================================
-- TFMS Real UI Seed Data — Extracted from tfms-app.js
-- initSampleData() + _generateDemoFinancials()
-- ============================================================
USE TFMS_softwareDB;
GO

-- Clear existing seed data (safe re-run)
DELETE FROM Waivers;
DELETE FROM Payments;
DELETE FROM ContractRooms;
DELETE FROM Contracts;
DELETE FROM Rooms;
DELETE FROM CampOwners;
DELETE FROM CampPartners;
DELETE FROM Camps;
DELETE FROM Tenants;
DELETE FROM OtherPersons;
DELETE FROM FundPools;
DELETE FROM AccountsHeads;
DELETE FROM Designations;
DELETE FROM Roles;
DELETE FROM Owners;
DELETE FROM Partners;
DELETE FROM Floors;
DELETE FROM RoomStatuses;
DELETE FROM PaymentModes;
DBCC CHECKIDENT('Partners',     RESEED, 0);
DBCC CHECKIDENT('Owners',       RESEED, 0);
DBCC CHECKIDENT('Floors',       RESEED, 0);
DBCC CHECKIDENT('RoomStatuses', RESEED, 0);
DBCC CHECKIDENT('PaymentModes', RESEED, 0);
DBCC CHECKIDENT('FundPools',    RESEED, 0);
DBCC CHECKIDENT('AccountsHeads',RESEED, 0);
DBCC CHECKIDENT('Designations', RESEED, 0);
DBCC CHECKIDENT('Roles',        RESEED, 0);
DBCC CHECKIDENT('OtherPersons', RESEED, 0);
DBCC CHECKIDENT('Camps',        RESEED, 0);
DBCC CHECKIDENT('CampPartners', RESEED, 0);
DBCC CHECKIDENT('CampOwners',   RESEED, 0);
DBCC CHECKIDENT('Rooms',        RESEED, 0);
DBCC CHECKIDENT('Tenants',      RESEED, 0);
DBCC CHECKIDENT('Contracts',    RESEED, 0);
DBCC CHECKIDENT('Payments',     RESEED, 0);
DBCC CHECKIDENT('Waivers',      RESEED, 0);
GO

PRINT '>>> Payment Modes';
INSERT INTO PaymentModes(Name,Status) VALUES
('Cheque','Active'),('Cash','Active'),('Bank Transfer','Active'),
('Credit Card','Active'),('Debit Card','Active'),('Online Payment','Active');
GO

PRINT '>>> Room Statuses';
INSERT INTO RoomStatuses(Name) VALUES
('Vacant'),('Occupied'),('Reserved'),('Maintenance'),('Blocked');
GO

PRINT '>>> Floors';
INSERT INTO Floors(Name,Number,Status,CreatedAt,UpdatedAt) VALUES
('Ground Floor',0,'Active',GETUTCDATE(),GETUTCDATE()),
('First Floor', 1,'Active',GETUTCDATE(),GETUTCDATE()),
('Second Floor',2,'Active',GETUTCDATE(),GETUTCDATE()),
('Third Floor', 3,'Active',GETUTCDATE(),GETUTCDATE()),
('Fourth Floor',4,'Active',GETUTCDATE(),GETUTCDATE()),
('Fifth Floor', 5,'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Designations';
INSERT INTO Designations(Code,Name,Status,CreatedAt,UpdatedAt) VALUES
('DES-001','Manager',       'Active',GETUTCDATE(),GETUTCDATE()),
('DES-002','Supervisor',    'Active',GETUTCDATE(),GETUTCDATE()),
('DES-003','Accountant',    'Active',GETUTCDATE(),GETUTCDATE()),
('DES-004','Security Guard','Active',GETUTCDATE(),GETUTCDATE()),
('DES-005','Technician',    'Active',GETUTCDATE(),GETUTCDATE()),
('DES-006','Cleaner',       'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Roles';
INSERT INTO Roles(RoleCode,RoleName,Status,CreatedAt,UpdatedAt) VALUES
('RL-000001','Admin',          'Active',GETUTCDATE(),GETUTCDATE()),
('RL-000002','Staff',          'Active',GETUTCDATE(),GETUTCDATE()),
('RL-000003','Partner',        'Active',GETUTCDATE(),GETUTCDATE()),
('RL-000004','Owner',          'Active',GETUTCDATE(),GETUTCDATE()),
('RL-000005','Tenant',         'Active',GETUTCDATE(),GETUTCDATE()),
('RL-000006','Other Accounts', 'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Accounts Heads (31 records from UI)';
INSERT INTO AccountsHeads(Code,Name,Type,Status,CreatedAt,UpdatedAt) VALUES
('AH-001','Cash in Hand',                'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-002','Cash at Bank',                'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-003','Petty Cash',                  'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-004','Accounts Receivable',         'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-005','Security Deposit (Received)', 'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-006','Advance Rent Received',       'Asset',    'Active',GETUTCDATE(),GETUTCDATE()),
('AH-007','Security Deposit Payable',    'Liability','Active',GETUTCDATE(),GETUTCDATE()),
('AH-008','Accounts Payable',            'Liability','Active',GETUTCDATE(),GETUTCDATE()),
('AH-009','Advance from Tenant',         'Liability','Active',GETUTCDATE(),GETUTCDATE()),
('AH-010','Salaries Payable',            'Liability','Active',GETUTCDATE(),GETUTCDATE()),
('AH-011','Rent Income',                 'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-012','Room Rent',                   'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-013','Maintenance Charge Income',   'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-014','Parking Charge Income',       'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-015','Service Charge Income',       'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-016','Late Payment Penalty',        'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-017','Miscellaneous Income',        'Income',   'Active',GETUTCDATE(),GETUTCDATE()),
('AH-018','Maintenance Expense',         'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-019','Electricity Expense',         'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-020','Water & Sewage Expense',      'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-021','Cleaning & Housekeeping',     'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-022','Security Expense',            'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-023','Salaries & Wages',            'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-024','Repair & Renovation',         'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-025','Administrative Expense',      'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-026','Insurance Expense',           'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-027','Bank Charges',                'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-028','Miscellaneous Expense',       'Expense',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-029','Owner Capital',               'Capital',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-030','Partner Capital',             'Capital',  'Active',GETUTCDATE(),GETUTCDATE()),
('AH-031','Retained Earnings',           'Capital',  'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Fund Pools';
INSERT INTO FundPools(Code,Name,Balance,Status,CreatedAt,UpdatedAt) VALUES
('FP-000001','Main Operations',     485000,'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000002','Maintenance Reserve', 128000,'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000003','Security Deposit',    342000,'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000004','Owner Payouts',       218000,'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000005','Partner Commissions',  96000,'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Partners (7 from UI)';
INSERT INTO Partners(Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt) VALUES
('PRT-000001','Al Habtoor Group',   'Ahmed Al Habtoor', '0501112222','info@alhabtoor.ae', 'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000002','Emaar Properties',   'Mohammed Alabbar', '0503334444','info@emaar.com',    'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000003','Nakheel LLC',        'Ali Rashid',       '0505556666','info@nakheel.ae',   'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000004','Dubai Properties',   'Saeed Al Marri',   '0507778888','info@dubaiprops.ae','Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000005','Meraas Holding',     'Abdulla Habbai',   '0509990000','info@meraas.ae',    'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000006','Damac Properties',   'Hussain Sajwani',  '0501234567','info@damac.ae',     'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000007','Azizi Developments', 'Farhad Azizi',     '0502345678','info@azizi.ae',     'Inactive',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Owners (6 from UI)';
INSERT INTO Owners(Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt) VALUES
('OWN-000001','Abdullah Al Maktoum','0501234567','abdullah@owner.ae', 'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000002','Fatima Al Sharji',   '0509876543','fatima@owner.ae',   'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000003','Mohammed Al Gergawi','0504567890','mohammed@owner.ae', 'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000004','Saeed Al Tayer',     '0507890123','saeed@owner.ae',    'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000005','Mariam Al Suwaidi',  '0508901234','mariam@owner.ae',   'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000006','Khalid Al Falasi',   '0509012345','khalid@owner.ae',   'Inactive',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Other Persons (5 from UI)';
INSERT INTO OtherPersons(Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt) VALUES
('OP-001','Manager',       'Ramesh Verma',  '9876543210','ramesh@example.com','12, MG Road',          'Mumbai',  'Maharashtra', '400001','',          'Active',  GETUTCDATE(),GETUTCDATE()),
('OP-002','Accountant',    'Sunita Sharma', '9876543211','sunita@example.com','45, Civil Lines',       'Lucknow', 'Uttar Pradesh','226001','Part time', 'Active',  GETUTCDATE(),GETUTCDATE()),
('OP-003','Security Guard','Mohan Das',     '9876543212','',                  'Near Bus Stand',        'Jaipur',  'Rajasthan',   '302001','',          'Inactive',GETUTCDATE(),GETUTCDATE()),
('OP-004','Supervisor',    'Vikram Singh',  '9876543213','vikram@example.com','34, Lal Bahadur Nagar','Delhi',   'Delhi',       '110001','Day shift', 'Active',  GETUTCDATE(),GETUTCDATE()),
('OP-005','Technician',    'Anwar Hussain', '9876543214','anwar@example.com', '22, Shivaji Marg',     'Pune',    'Maharashtra', '411001','AC expert', 'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Camps (6 from UI)';
INSERT INTO Camps(Code,Name,Rooms,Floors,Status,CreatedAt,UpdatedAt) VALUES
('CMP001','Al Nahda Camp',       23,3,'Active',GETUTCDATE(),GETUTCDATE()),
('CMP002','Dubai Silicon Oasis', 16,2,'Active',GETUTCDATE(),GETUTCDATE()),
('CMP003','Jebel Ali Village',   13,2,'Active',GETUTCDATE(),GETUTCDATE()),
('CMP004','Deira Waterfront',    34,4,'Active',GETUTCDATE(),GETUTCDATE()),
('CMP005','Dubai Marina Towers', 18,3,'Active',GETUTCDATE(),GETUTCDATE()),
('CMP006','Al Barsha Heights',   26,4,'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Camp Partners (from UI appData.camps)';
-- Camp 1: P1=20%, P2=5000 fixed
INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue) VALUES
(1,1,'percentage',20),(1,2,'fixed',5000),
(2,3,'fixed',3000),
(3,4,'percentage',25),
(4,5,'fixed',7000),(4,6,'percentage',15),
(5,7,'percentage',18),
(6,1,'fixed',4000);
GO

PRINT '>>> Camp Owners';
INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue) VALUES
(1,1,'percentage',15),
(2,2,'percentage',10),
(3,3,'percentage',12),
(4,4,'percentage',8),
(5,5,'percentage',12),
(6,6,'percentage',10);
GO

PRINT '>>> Rooms (129 rooms matching UI room generation logic)';
-- Camp1=Al Nahda(id=1), Camp2=Dubai Silicon Oasis(id=2), etc.
-- Floor ids: Ground=1,First=2,Second=3,Third=4,Fourth=5,Fifth=6
-- UI floor logic: floorId=1 means First floor in UI (number=1) -> maps to DB id=2

-- Al Nahda Camp - Floor 1 (101-115) price=1200
INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
('NA101',1,2,0,1200,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('NA102',1,2,1,1300,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('NA103',1,2,0,1250,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('NA104',1,2,1,1200,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('NA105',1,2,0,1300,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('NA106',1,2,1,1200,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('NA107',1,2,0,1250,'Maintenance','Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('NA108',1,2,1,1300,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('NA109',1,2,0,1200,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('NA110',1,2,1,1300,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('NA111',1,2,0,1200,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE()),
('NA112',1,2,1,1300,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('NA113',1,2,0,1250,'Reserved',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('NA114',1,2,1,1200,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('NA115',1,2,0,1300,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
-- Al Nahda Camp - Floor 2 (201-210) price=1500
('NA201',1,3,1,1500,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('NA202',1,3,0,1600,'Vacant',     'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('NA203',1,3,1,1550,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('NA204',1,3,0,1500,'Maintenance','Studio',         GETUTCDATE(),GETUTCDATE()),
('NA205',1,3,1,1600,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('NA206',1,3,0,1500,'Vacant',     'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('NA207',1,3,1,1550,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('NA208',1,3,0,1500,'Reserved',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('NA209',1,3,1,1600,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('NA210',1,3,0,1500,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE());
GO

INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
-- Dubai Silicon Oasis - Floor 1 (101-112) price=1800
('DS101',2,2,1,1800,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('DS102',2,2,0,1900,'Vacant',     'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DS103',2,2,1,1850,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DS104',2,2,0,1800,'Maintenance','Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DS105',2,2,1,1900,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('DS106',2,2,0,1800,'Vacant',     'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('DS107',2,2,1,1850,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DS108',2,2,0,1800,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('DS109',2,2,1,1900,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DS110',2,2,0,1800,'Reserved',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DS111',2,2,1,1850,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DS112',2,2,0,1800,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
-- Dubai Silicon Oasis - Floor 2 (201-207) price=2100
('DS201',2,3,1,2100,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('DS202',2,3,0,2200,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DS203',2,3,1,2150,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('DS204',2,3,0,2100,'Maintenance','Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DS205',2,3,1,2200,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DS206',2,3,0,2100,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DS207',2,3,1,2150,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE());
GO

INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
-- Jebel Ali Village - Floor 1 (101-108) price=2200
('JA101',3,2,1,2200,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('JA102',3,2,0,2300,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE()),
('JA103',3,2,1,2250,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('JA104',3,2,0,2200,'Maintenance','Executive Suite',GETUTCDATE(),GETUTCDATE()),
('JA105',3,2,1,2300,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('JA106',3,2,0,2200,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('JA107',3,2,1,2250,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('JA108',3,2,0,2200,'Reserved',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
-- Jebel Ali Village - Floor 2 (201-207) price=2500
('JA201',3,3,1,2500,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('JA202',3,3,0,2600,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('JA203',3,3,1,2550,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('JA204',3,3,0,2500,'Vacant',     'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('JA205',3,3,1,2600,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('JA206',3,3,0,2500,'Maintenance','Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('JA207',3,3,1,2550,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE());
GO

INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
-- Deira Waterfront - Floor 1 (101-114) price=1300
('DW101',4,2,1,1300,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DW102',4,2,0,1400,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('DW103',4,2,1,1350,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DW104',4,2,0,1300,'Maintenance','Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DW105',4,2,1,1400,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DW106',4,2,0,1300,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('DW107',4,2,1,1350,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('DW108',4,2,0,1300,'Reserved',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DW109',4,2,1,1400,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('DW110',4,2,0,1300,'Vacant',     'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DW111',4,2,1,1350,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DW112',4,2,0,1300,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DW113',4,2,1,1400,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('DW114',4,2,0,1300,'Maintenance','Unfurnished',    GETUTCDATE(),GETUTCDATE()),
-- Deira Waterfront - Floor 2 (201-212) price=1600
('DW201',4,3,1,1600,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DW202',4,3,0,1700,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('DW203',4,3,1,1650,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DW204',4,3,0,1600,'Reserved',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DW205',4,3,1,1700,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DW206',4,3,0,1600,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('DW207',4,3,1,1650,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('DW208',4,3,0,1600,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DW209',4,3,1,1700,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('DW210',4,3,0,1600,'Maintenance','Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DW211',4,3,1,1650,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DW212',4,3,0,1600,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
-- Deira Waterfront - Floor 3 (301-308) price=1900
('DW301',4,4,1,1900,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('DW302',4,4,0,2000,'Vacant',     'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('DW303',4,4,1,1950,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('DW304',4,4,0,1900,'Maintenance','Studio',         GETUTCDATE(),GETUTCDATE()),
('DW305',4,4,1,2000,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('DW306',4,4,0,1900,'Vacant',     'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('DW307',4,4,1,1950,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('DW308',4,4,0,1900,'Reserved',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE());
GO

INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
-- Dubai Marina Towers - Floor 1 (101-109) price=2500
('MT101',5,2,1,2500,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('MT102',5,2,0,2600,'Vacant',     'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('MT103',5,2,1,2550,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('MT104',5,2,0,2500,'Maintenance','Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('MT105',5,2,1,2600,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('MT106',5,2,0,2500,'Vacant',     'Balcony',        GETUTCDATE(),GETUTCDATE()),
('MT107',5,2,1,2550,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('MT108',5,2,0,2500,'Reserved',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('MT109',5,2,1,2600,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
-- Dubai Marina Towers - Floor 2 (201-207) price=2800
('MT201',5,3,1,2800,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('MT202',5,3,0,2900,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('MT203',5,3,1,2850,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('MT204',5,3,0,2800,'Maintenance','Balcony',        GETUTCDATE(),GETUTCDATE()),
('MT205',5,3,1,2900,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('MT206',5,3,0,2800,'Vacant',     'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('MT207',5,3,1,2850,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
-- Al Barsha Heights - Floor 1 (101-113) price=1400
('BH101',6,2,1,1400,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('BH102',6,2,0,1500,'Vacant',     'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('BH103',6,2,1,1450,'Occupied',   'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('BH104',6,2,0,1400,'Maintenance','Balcony',        GETUTCDATE(),GETUTCDATE()),
('BH105',6,2,1,1500,'Occupied',   'Studio',         GETUTCDATE(),GETUTCDATE()),
('BH106',6,2,0,1400,'Vacant',     'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('BH107',6,2,1,1450,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('BH108',6,2,0,1400,'Reserved',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('BH109',6,2,1,1500,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('BH110',6,2,0,1400,'Vacant',     'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('BH111',6,2,1,1450,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('BH112',6,2,0,1400,'Maintenance','Studio',         GETUTCDATE(),GETUTCDATE()),
('BH113',6,2,1,1500,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
-- Al Barsha Heights - Floor 2 (201-209) price=1700
('BH201',6,3,1,1700,'Occupied',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('BH202',6,3,0,1800,'Vacant',     'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
('BH203',6,3,1,1750,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('BH204',6,3,0,1700,'Maintenance','Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('BH205',6,3,1,1800,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('BH206',6,3,0,1700,'Vacant',     'Studio',         GETUTCDATE(),GETUTCDATE()),
('BH207',6,3,1,1750,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('BH208',6,3,0,1700,'Reserved',   'Deluxe Room',    GETUTCDATE(),GETUTCDATE()),
('BH209',6,3,1,1800,'Occupied',   'Fully Furnished',GETUTCDATE(),GETUTCDATE()),
-- Al Barsha Heights - Floor 3 (301-306) price=2000
('BH301',6,4,1,2000,'Occupied',   'Semi-Furnished', GETUTCDATE(),GETUTCDATE()),
('BH302',6,4,0,2100,'Vacant',     'Unfurnished',    GETUTCDATE(),GETUTCDATE()),
('BH303',6,4,1,2050,'Occupied',   'Balcony',        GETUTCDATE(),GETUTCDATE()),
('BH304',6,4,0,2000,'Maintenance','Studio',         GETUTCDATE(),GETUTCDATE()),
('BH305',6,4,1,2100,'Occupied',   'Executive Suite',GETUTCDATE(),GETUTCDATE()),
('BH306',6,4,0,2000,'Vacant',     'Deluxe Room',    GETUTCDATE(),GETUTCDATE());
GO

-- Update camp room counts
UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=Camps.Id),
                 Floors=(SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=Camps.Id);
GO

PRINT '>>> Tenants (10 from UI)';
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt) VALUES
('Individual','Ahmed Mohammed Al Rashidi','A123456','UAE','784-1980-1234567-1','0501112233','0501112233','ahmed@example.com','Villa 12, Al Nahda, Dubai','Active','','','','2','123-456','22334455','48','00112233','Abdullah Al Maktoum','784-1960-1111111-1','LL-2020-001','Dubai Land Department','abdullah@owner.ae','0501234567',GETUTCDATE(),GETUTCDATE()),
('Company','Al Shamsi Trading LLC','B789012','UAE','784-1985-9876543-2','0504445566','0504445566','info@alshamsi.ae','Office 301, Business Bay, Dubai','Active','Al Shamsi Trading LLC','TL-2023-001','Dubai Economy','5','789-012','33445566','120','00223344','Fatima Al Sharji','784-1970-2222222-2','LL-2019-002','Dubai Land Department','fatima@owner.ae','0509876543',GETUTCDATE(),GETUTCDATE()),
('Individual','Khalid Yusuf Al Falasi','C345678','Egypt','784-1990-4567890-3','0507778899','0507778899','khalid@example.com','Flat 5B, Deira, Dubai','Active','','','','1','321-654','44556677','35','00334455','Mohammed Al Gergawi','784-1965-3333333-3','LL-2021-003','Dubai Land Department','mohammed@owner.ae','0504567890',GETUTCDATE(),GETUTCDATE()),
('Individual','Mariam Jaber Al Suwaidi','D901234','UAE','784-1992-5678901-4','0508889900','0508889900','mariam@example.com','Villa 7, Jumeirah, Dubai','Active','','','','3','654-321','55667788','62','00445566','Saeed Al Tayer','784-1958-4444444-4','LL-2018-004','Dubai Land Department','saeed@owner.ae','0507890123',GETUTCDATE(),GETUTCDATE()),
('Company','Al Mazrouei Group','E567890','UAE','784-1988-2345678-5','0506667788','0506667788','info@almazrouei.ae','Floor 8, DIFC, Dubai','Active','Al Mazrouei Group','TL-2024-002','DIFC Authority','10','987-654','66778899','250','00556677','Mariam Al Suwaidi','784-1972-5555555-5','LL-2022-005','Dubai Land Department','mariam@owner.ae','0508901234',GETUTCDATE(),GETUTCDATE()),
('Individual','Noora Hassan Al Kaabi','F234567','UAE','784-1995-3456789-6','0509990011','0509990011','noora@example.com','Flat 2A, Al Barsha, Dubai','Active','','','','1','111-222','77889900','40','00667788','Khalid Al Falasi','784-1962-6666666-6','LL-2020-006','Dubai Land Department','khalid@owner.ae','0509012345',GETUTCDATE(),GETUTCDATE()),
('Company','Al Ghurair Group LLC','G456789','UAE','784-1983-4567890-7','0501122334','0501122334','info@alghurair.com','Al Ghurair Tower, Deira, Dubai','Active','Al Ghurair Group','TL-2023-007','Dubai Economy','20','333-444','88990011','500','00778899','Abdullah Al Maktoum','784-1960-1111111-1','LL-2017-007','Dubai Land Department','abdullah@owner.ae','0501234567',GETUTCDATE(),GETUTCDATE()),
('Individual','Rashid Salem Al Maktoum','H789012','UAE','784-1975-5678901-8','0502233445','0502233445','rashid@example.com','Palm Villa 3, Palm Jumeirah, Dubai','Active','','','','4','555-666','99001122','180','00889900','Saeed Al Tayer','784-1958-4444444-4','LL-2019-008','Dubai Land Department','saeed@owner.ae','0507890123',GETUTCDATE(),GETUTCDATE()),
('Individual','Priya Sharma','IN9876','India','784-1991-6789012-9','0503344556','0503344556','priya@example.com','Flat 8C, Bur Dubai, Dubai','Active','','','','2','222-333','11223344','42','00990011','Mohammed Al Gergawi','784-1965-3333333-3','LL-2020-009','Dubai Land Department','mohammed@owner.ae','0504567890',GETUTCDATE(),GETUTCDATE()),
('Company','TechBridge Solutions FZCO','PK5543','Pakistan','784-1987-7890123-0','0504455667','0504455667','info@techbridge.ae','Office 12, Dubai Internet City','Active','TechBridge Solutions FZCO','TL-2022-010','DIFC Authority','15','444-555','22334455','320','01001122','Fatima Al Sharji','784-1970-2222222-2','LL-2021-010','Dubai Land Department','fatima@owner.ae','0509876543',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Contracts (10 contracts, one per tenant, matching UI _generateDemoFinancials)';
INSERT INTO Contracts(ContractId,TenantId,CampId,StartDate,Months,EndDate,MonthlyTotal,ContractTotal,Status,CreatedAt,UpdatedAt) VALUES
('CNT0001',1,1,'2025-01-01',12,'2025-12-28',2700, 32400, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0002',2,2,'2025-02-01',15,'2026-04-28',3900, 58500, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0003',3,3,'2025-03-01',12,'2026-02-28',4700, 56400, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0004',4,4,'2025-04-01',15,'2026-06-28',2900, 43500, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0005',5,5,'2025-05-01',12,'2026-04-28',5100, 61200, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0006',6,6,'2025-06-01',15,'2026-08-28',2900, 43500, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0007',7,1,'2025-07-01',12,'2026-06-28',2700, 32400, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0008',8,2,'2025-08-01',15,'2026-10-28',3700, 55500, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0009',9,3,'2025-09-01',12,'2026-08-28',4450, 53400, 'Active',   GETUTCDATE(),GETUTCDATE()),
('CNT0010',10,4,'2025-10-01',15,'2027-12-28',2700, 40500,'Completed',GETUTCDATE(),GETUTCDATE());
GO

-- Link rooms to contracts
INSERT INTO ContractRooms(ContractId,RoomId) VALUES
('CNT0001',(SELECT Id FROM Rooms WHERE RoomNo='NA101')),
('CNT0001',(SELECT Id FROM Rooms WHERE RoomNo='NA102')),
('CNT0002',(SELECT Id FROM Rooms WHERE RoomNo='DS101')),
('CNT0002',(SELECT Id FROM Rooms WHERE RoomNo='DS103')),
('CNT0003',(SELECT Id FROM Rooms WHERE RoomNo='JA101')),
('CNT0003',(SELECT Id FROM Rooms WHERE RoomNo='JA103')),
('CNT0004',(SELECT Id FROM Rooms WHERE RoomNo='DW101')),
('CNT0005',(SELECT Id FROM Rooms WHERE RoomNo='MT101')),
('CNT0005',(SELECT Id FROM Rooms WHERE RoomNo='MT103')),
('CNT0006',(SELECT Id FROM Rooms WHERE RoomNo='BH101')),
('CNT0007',(SELECT Id FROM Rooms WHERE RoomNo='NA201')),
('CNT0008',(SELECT Id FROM Rooms WHERE RoomNo='DS201')),
('CNT0009',(SELECT Id FROM Rooms WHERE RoomNo='JA201')),
('CNT0010',(SELECT Id FROM Rooms WHERE RoomNo='DW201'));
GO

PRINT '>>> Generating Payments (installments for all 10 contracts)';
-- Match UI logic: even installments = Paid, ci<8 means contract 1-8 mostly paid
DECLARE @ci INT = 0;
DECLARE @contractIds TABLE(cid NVARCHAR(MAX), months INT, startDate DATE, monthly DECIMAL(18,2), rn INT);
INSERT INTO @contractIds SELECT ContractId, Months, StartDate, MonthlyTotal, ROW_NUMBER() OVER(ORDER BY Id)-1 FROM Contracts;

DECLARE @cid NVARCHAR(MAX), @months INT, @sd DATE, @monthly DECIMAL(18,2), @rn INT;
DECLARE cc CURSOR FOR SELECT cid,months,startDate,monthly,rn FROM @contractIds;
OPEN cc; FETCH NEXT FROM cc INTO @cid,@months,@sd,@monthly,@rn;
WHILE @@FETCH_STATUS=0
BEGIN
    DECLARE @inst INT=1;
    WHILE @inst<=@months
    BEGIN
        DECLARE @dd DATE = DATEADD(MONTH,@inst-1,@sd);
        DECLARE @paid BIT = CASE WHEN (@inst%2=0 OR @rn<8 OR @inst%3=1) THEN 1 ELSE 0 END;
        DECLARE @pmId INT = ((@inst-1) % 6) + 1;
        DECLARE @pmName NVARCHAR(MAX) = (SELECT Name FROM PaymentModes WHERE Id=@pmId);
        DECLARE @fpId INT = ((@inst-1) % 3) + 1;
        DECLARE @fpName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Id=@fpId);
        INSERT INTO Payments(ContractId,InstallmentNo,Amount,DueDate,PaidAmount,PaidDate,Status,
            PaymentMode,PaymentModeId,ChequeNumber,ClearanceDate,Description,
            ReceivedBy,ReceivedContact,FundPoolId,FundPoolName,IssuedBy)
        VALUES(@cid,@inst,@monthly,@dd,
            CASE WHEN @paid=1 THEN @monthly ELSE 0 END,
            CASE WHEN @paid=1 THEN @dd ELSE NULL END,
            CASE WHEN @paid=1 THEN 'Paid' ELSE 'Pending' END,
            @pmName,@pmId,
            CASE WHEN @paid=1 AND @pmName='Cheque' THEN 'CHQ'+CAST(1000+@inst AS NVARCHAR) ELSE '' END,
            CASE WHEN @paid=1 THEN CAST(@dd AS NVARCHAR) ELSE '' END,
            CASE WHEN @paid=1 THEN 'Monthly rent payment' ELSE 'Due rent' END,
            '','',
            CASE WHEN @paid=1 THEN @fpId ELSE NULL END,
            CASE WHEN @paid=1 THEN @fpName ELSE '' END,
            'admin');
        SET @inst+=1;
    END
    FETCH NEXT FROM cc INTO @cid,@months,@sd,@monthly,@rn;
END
CLOSE cc; DEALLOCATE cc;
GO

-- Mark overdue payments (past due date, not paid)
UPDATE Payments SET Status='Overdue'
WHERE Status='Pending' AND DueDate < CAST(GETUTCDATE() AS DATE);
GO

PRINT '>>> Waivers (8 sample waivers on pending installments)';
DECLARE @wid INT=1;
DECLARE @pid INT, @pcid NVARCHAR(MAX), @pinst INT, @pamt DECIMAL(18,2), @ptid INT;
DECLARE wc CURSOR FOR
    SELECT TOP 8 p.Id, p.ContractId, p.InstallmentNo, p.Amount, c.TenantId
    FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId
    WHERE p.Status IN('Pending','Overdue') ORDER BY p.Id;
OPEN wc; FETCH NEXT FROM wc INTO @pid,@pcid,@pinst,@pamt,@ptid;
WHILE @@FETCH_STATUS=0
BEGIN
    DECLARE @wa DECIMAL(18,2) = ROUND(@pamt*0.05, 2);
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,BalanceAmount,Remark,WaiverDate)
    VALUES(@ptid,@pcid,@pinst,@pamt,@wa,@pamt-@wa,'Early payment discount','2026-03-15');
    UPDATE Payments SET Amount=@pamt-@wa WHERE Id=@pid;
    SET @wid+=1;
    FETCH NEXT FROM wc INTO @pid,@pcid,@pinst,@pamt,@ptid;
END
CLOSE wc; DEALLOCATE wc;
GO

PRINT '============================================';
PRINT 'REAL UI DATA SEEDED SUCCESSFULLY!';
SELECT 'Partners'      AS [Table], COUNT(*) AS [Rows] FROM Partners     UNION ALL
SELECT 'Owners',       COUNT(*) FROM Owners        UNION ALL
SELECT 'Floors',       COUNT(*) FROM Floors         UNION ALL
SELECT 'Designations', COUNT(*) FROM Designations   UNION ALL
SELECT 'AccountsHeads',COUNT(*) FROM AccountsHeads  UNION ALL
SELECT 'FundPools',    COUNT(*) FROM FundPools       UNION ALL
SELECT 'Roles',        COUNT(*) FROM Roles           UNION ALL
SELECT 'OtherPersons', COUNT(*) FROM OtherPersons    UNION ALL
SELECT 'Camps',        COUNT(*) FROM Camps           UNION ALL
SELECT 'Rooms',        COUNT(*) FROM Rooms           UNION ALL
SELECT 'Tenants',      COUNT(*) FROM Tenants         UNION ALL
SELECT 'Contracts',    COUNT(*) FROM Contracts       UNION ALL
SELECT 'Payments',     COUNT(*) FROM Payments        UNION ALL
SELECT 'Waivers',      COUNT(*) FROM Waivers;
GO
