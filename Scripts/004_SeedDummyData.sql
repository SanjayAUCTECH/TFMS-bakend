-- ============================================================
-- TFMS Software - UI Dummy Data Seed Script
-- All data extracted from React UI pages
-- ============================================================
USE TFMS_softwareDB;
GO

PRINT '>>> Inserting Partners...';
IF NOT EXISTS (SELECT 1 FROM Partners WHERE Code='PRT-000001')
INSERT INTO Partners(Code,Name,Contact,Mobile,Email,Status,CreatedAt,UpdatedAt) VALUES
('PRT-000001','ABC Construction',  'John Doe',      '9876543210','john@abcconstruction.com','Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000002','XYZ Builders',      'Jane Smith',    '9876543211','jane@xyzbuilders.com',    'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000003','Modern Infrastructure','Robert Brown','9876543212','robert@moderninfra.com', 'Inactive',GETUTCDATE(),GETUTCDATE()),
('PRT-000004','Urban Developers',  'Sarah Johnson', '9876543213','sarah@urbandev.com',      'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000005','Gulf Constructions','Ahmed Al-Farsi','9876543214','ahmed@gulfcon.com',        'Active',  GETUTCDATE(),GETUTCDATE()),
('PRT-000006','Royal Properties',  'Fatima Malik',  '9876543215','fatima@royalprop.com',    'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Owners...';
IF NOT EXISTS (SELECT 1 FROM Owners WHERE Code='OWN-000001')
INSERT INTO Owners(Code,Name,Contact,Email,Status,CreatedAt,UpdatedAt) VALUES
('OWN-000001','Sheikh Mohammed Al-Rashid','0501234567','sheikh@rashid.ae',      'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000002','Priya Kapoor',             '9876501001','priya.kapoor@email.com','Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000003','Rajesh Mehta',             '9876501002','rajesh@mehta.com',      'Active',  GETUTCDATE(),GETUTCDATE()),
('OWN-000004','Aisha Bin Hamdan',         '0507654321','aisha@binhamdan.ae',    'Inactive',GETUTCDATE(),GETUTCDATE()),
('OWN-000005','Vijay Singhania',          '9876501003','vijay@singhania.com',   'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Floors...';
IF NOT EXISTS (SELECT 1 FROM Floors WHERE Name='Ground Floor')
INSERT INTO Floors(Name,Number,Status,CreatedAt,UpdatedAt) VALUES
('Ground Floor',0,'Active',GETUTCDATE(),GETUTCDATE()),
('1st Floor',   1,'Active',GETUTCDATE(),GETUTCDATE()),
('2nd Floor',   2,'Active',GETUTCDATE(),GETUTCDATE()),
('3rd Floor',   3,'Active',GETUTCDATE(),GETUTCDATE()),
('4th Floor',   4,'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Designations...';
IF NOT EXISTS (SELECT 1 FROM Designations WHERE Code='DES-000001')
INSERT INTO Designations(Code,Name,Status,CreatedAt,UpdatedAt) VALUES
('DES-000001','Manager',        'Active',  GETUTCDATE(),GETUTCDATE()),
('DES-000002','Supervisor',     'Active',  GETUTCDATE(),GETUTCDATE()),
('DES-000003','Accountant',     'Active',  GETUTCDATE(),GETUTCDATE()),
('DES-000004','Security Guard', 'Inactive',GETUTCDATE(),GETUTCDATE()),
('DES-000005','Technician',     'Active',  GETUTCDATE(),GETUTCDATE()),
('DES-000006','Cleaner',        'Active',  GETUTCDATE(),GETUTCDATE()),
('DES-000007','Driver',         'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Accounts Heads...';
IF NOT EXISTS (SELECT 1 FROM AccountsHeads WHERE Code='AH-000001')
INSERT INTO AccountsHeads(Code,Name,Type,Status,CreatedAt,UpdatedAt) VALUES
('AH-000001','Cash Account',        'Asset',    'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000002','Bank Account',        'Asset',    'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000003','Rent Income',         'Income',   'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000004','Maintenance Expense', 'Expense',  'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000005','Security Deposit',    'Liability','Inactive',GETUTCDATE(),GETUTCDATE()),
('AH-000006','Salary Expense',      'Expense',  'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000007','Utility Expense',     'Expense',  'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000008','Capital Account',     'Capital',  'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000009','Advance Income',      'Income',   'Active',  GETUTCDATE(),GETUTCDATE()),
('AH-000010','Other Income',        'Income',   'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Fund Pools...';
IF NOT EXISTS (SELECT 1 FROM FundPools WHERE Code='FP-000001')
INSERT INTO FundPools(Code,Name,Balance,Status,CreatedAt,UpdatedAt) VALUES
('FP-000001','Main Operating Fund', 250000.00,'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000002','Maintenance Reserve', 85000.00, 'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000003','Emergency Fund',      50000.00, 'Active',GETUTCDATE(),GETUTCDATE()),
('FP-000004','West Camp Fund',      120000.00,'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Roles...';
IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleCode='ROL-000001')
INSERT INTO Roles(RoleCode,RoleName,Status,CreatedAt,UpdatedAt) VALUES
('ROL-000001','Admin',          'Active',GETUTCDATE(),GETUTCDATE()),
('ROL-000002','Manager',        'Active',GETUTCDATE(),GETUTCDATE()),
('ROL-000003','Accountant',     'Active',GETUTCDATE(),GETUTCDATE()),
('ROL-000004','Field Supervisor','Active',GETUTCDATE(),GETUTCDATE()),
('ROL-000005','Viewer',         'Active',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Other Persons...';
IF NOT EXISTS (SELECT 1 FROM OtherPersons WHERE Code='OP-000001')
INSERT INTO OtherPersons(Code,Designation,Name,Mobile,Email,Address,City,State,Pincode,Remarks,Status,CreatedAt,UpdatedAt) VALUES
('OP-000001','Manager',        'Ramesh Verma',  '9876543210','ramesh@example.com','12, MG Road',          'Mumbai',   'Maharashtra', '400001','',        'Active',  GETUTCDATE(),GETUTCDATE()),
('OP-000002','Accountant',     'Sunita Sharma', '9876543211','sunita@example.com','45, Civil Lines',       'Lucknow',  'Uttar Pradesh','226001','Part time','Active',  GETUTCDATE(),GETUTCDATE()),
('OP-000003','Security Guard', 'Mohan Das',     '9876543212','',                  'Near Bus Stand',        'Jaipur',   'Rajasthan',   '302001','',        'Inactive',GETUTCDATE(),GETUTCDATE()),
('OP-000004','Supervisor',     'Ali Hassan',    '0551234567','ali@example.com',   'Al Nahda Street',       'Dubai',    '',            '',      '',        'Active',  GETUTCDATE(),GETUTCDATE()),
('OP-000005','Technician',     'Kishore Pillai','9876543215','kishore@email.com', '7, Residency Road',     'Bangalore','Karnataka',   '560001','Plumber', 'Active',  GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Camps...';
IF NOT EXISTS (SELECT 1 FROM Camps WHERE Code='CMP-000001')
BEGIN
    INSERT INTO Camps(Code,Name,Rooms,Floors,Status,CreatedAt,UpdatedAt) VALUES
    ('CMP-000001','Main Camp',  0,0,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CMP-000002','East Camp',  0,0,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CMP-000003','West Camp',  0,0,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CMP-000004','North Camp', 0,0,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CMP-000005','South Camp', 0,0,'Inactive',GETUTCDATE(),GETUTCDATE());

    -- Link partners to camps
    INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue) VALUES
    (1,1,'percentage',40),(1,2,'percentage',35),(1,3,'percentage',25),
    (2,1,'percentage',50),(2,4,'percentage',50),
    (3,2,'percentage',60),(3,5,'percentage',40),
    (4,6,'percentage',100);

    -- Link owners to camps
    INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue) VALUES
    (1,1,'percentage',60),(1,2,'percentage',40),
    (2,3,'percentage',100),
    (3,1,'percentage',50),(3,5,'percentage',50),
    (4,2,'percentage',100);
END
GO

PRINT '>>> Inserting Rooms...';
IF NOT EXISTS (SELECT 1 FROM Rooms WHERE RoomNo='R-101')
BEGIN
    DECLARE @MainCamp INT=(SELECT Id FROM Camps WHERE Code='CMP-000001');
    DECLARE @EastCamp INT=(SELECT Id FROM Camps WHERE Code='CMP-000002');
    DECLARE @WestCamp INT=(SELECT Id FROM Camps WHERE Code='CMP-000003');
    DECLARE @F1 INT=(SELECT Id FROM Floors WHERE Number=1);
    DECLARE @F2 INT=(SELECT Id FROM Floors WHERE Number=2);
    DECLARE @F3 INT=(SELECT Id FROM Floors WHERE Number=3);

    -- Main Camp Rooms
    INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,CreatedAt,UpdatedAt) VALUES
    ('R-101',@MainCamp,@F1,1,8500, 'Occupied',   'AC Room',   GETUTCDATE(),GETUTCDATE()),
    ('R-102',@MainCamp,@F1,1,8500, 'Occupied',   'AC Room',   GETUTCDATE(),GETUTCDATE()),
    ('R-103',@MainCamp,@F1,0,12000,'Vacant',      'Deluxe',    GETUTCDATE(),GETUTCDATE()),
    ('R-104',@MainCamp,@F1,1,6000, 'Occupied',   '',           GETUTCDATE(),GETUTCDATE()),
    ('R-105',@MainCamp,@F1,1,7500, 'Occupied',   '',           GETUTCDATE(),GETUTCDATE()),
    ('R-106',@MainCamp,@F1,0,8500, 'Vacant',     '',           GETUTCDATE(),GETUTCDATE()),
    ('R-201',@MainCamp,@F2,1,9000, 'Occupied',   'Corner Room',GETUTCDATE(),GETUTCDATE()),
    ('R-202',@MainCamp,@F2,1,7800, 'Occupied',   '',           GETUTCDATE(),GETUTCDATE()),
    ('R-203',@MainCamp,@F2,1,8200, 'Occupied',   '',           GETUTCDATE(),GETUTCDATE()),
    ('R-204',@MainCamp,@F2,0,9000, 'Vacant',     '',           GETUTCDATE(),GETUTCDATE()),
    ('R-205',@MainCamp,@F2,0,9500, 'Maintenance','Under repair',GETUTCDATE(),GETUTCDATE()),
    -- East Camp Rooms
    ('R-E101',@EastCamp,@F1,1,9000, 'Occupied',  '',           GETUTCDATE(),GETUTCDATE()),
    ('R-E102',@EastCamp,@F1,0,9000, 'Vacant',    '',           GETUTCDATE(),GETUTCDATE()),
    ('R-E201',@EastCamp,@F2,1,9500, 'Occupied',  '',           GETUTCDATE(),GETUTCDATE()),
    ('R-E202',@EastCamp,@F2,1,9500, 'Occupied',  '',           GETUTCDATE(),GETUTCDATE()),
    -- West Camp Rooms
    ('R-W301',@WestCamp,@F3,1,11000,'Occupied',  'Premium',    GETUTCDATE(),GETUTCDATE()),
    ('R-W302',@WestCamp,@F3,1,9500, 'Occupied',  '',           GETUTCDATE(),GETUTCDATE()),
    ('R-W303',@WestCamp,@F3,0,10000,'Vacant',    '',           GETUTCDATE(),GETUTCDATE());

    -- Update camp room counts
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=Camps.Id),
                     Floors=(SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=Camps.Id);
END
GO

PRINT '>>> Inserting Tenants...';
IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Rahul Sharma')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES
('Individual','Rahul Sharma',   'P1234567','Indian',  '784-1990-1234567-1','9876543201','9876543201','rahul@example.com',   '12, MG Road, Mumbai',      'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Priya Patel',    'P2345678','Indian',  '784-1991-2345678-2','9876543202','9876543202','priya@example.com',   '45, Civil Lines, Delhi',   'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Amit Kumar',     'P3456789','Indian',  '784-1988-3456789-3','9876543203','9876543203','amit@example.com',    'Near Bus Stand, Jaipur',   'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Neha Singh',     'P4567890','Indian',  '784-1995-4567890-4','9876543204','9876543204','neha@example.com',    'Sector 15, Noida',         'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Suresh Verma',   'P5678901','Indian',  '784-1985-5678901-5','9876543205','9876543205','suresh@example.com',  'Residency Road, Bangalore','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Kavita Mishra',  'P6789012','Indian',  '784-1992-6789012-6','9876543206','9876543206','kavita@example.com',  'Ashok Nagar, Bhopal',      'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Mohan Lal',      'P7890123','Indian',  '784-1987-7890123-7','9876543207','9876543207','mohan@example.com',   'Gandhi Nagar, Patna',      'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Anita Gupta',    'P8901234','Indian',  '784-1993-8901234-8','9876543208','9876543208','anita@example.com',   'Model Town, Amritsar',     'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Ravi Shankar',   'P9012345','Indian',  '784-1989-9012345-9','9876543209','9876543209','ravi@example.com',    'Lal Darwaza, Hyderabad',   'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Individual','Sunita Rao',     'PA123456','Indian',  '784-1994-1230001-0','9876543210','9876543210','sunita@example.com',  'JP Nagar, Bangalore',      'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE()),
('Company',   'Al-Noor Trading LLC','','Pakistani','784-1980-1111111-1','0551112233','0551112233','alnoor@trading.ae','Al Quoz, Dubai',           'Active','TL-2023-001','DED','3','','','','','Sheikh Ali','784-1960-9999999-1','','','sheikh@alnoor.ae','0551119999',GETUTCDATE(),GETUTCDATE()),
('Individual','Deepak Joshi',   'PB234567','Nepali',  '784-1991-2222222-2','9876543212','9876543212','deepak@example.com',  'Andheri West, Mumbai',     'Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

PRINT '>>> Inserting Contracts + Installments (Monthly Due data)...';
IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId='CNT-000001')
BEGIN
    DECLARE @T1 INT=(SELECT Id FROM Tenants WHERE Name='Rahul Sharma');
    DECLARE @T2 INT=(SELECT Id FROM Tenants WHERE Name='Priya Patel');
    DECLARE @T3 INT=(SELECT Id FROM Tenants WHERE Name='Amit Kumar');
    DECLARE @T4 INT=(SELECT Id FROM Tenants WHERE Name='Neha Singh');
    DECLARE @T5 INT=(SELECT Id FROM Tenants WHERE Name='Suresh Verma');
    DECLARE @T6 INT=(SELECT Id FROM Tenants WHERE Name='Kavita Mishra');
    DECLARE @T7 INT=(SELECT Id FROM Tenants WHERE Name='Mohan Lal');
    DECLARE @T8 INT=(SELECT Id FROM Tenants WHERE Name='Anita Gupta');
    DECLARE @T9 INT=(SELECT Id FROM Tenants WHERE Name='Ravi Shankar');
    DECLARE @T10 INT=(SELECT Id FROM Tenants WHERE Name='Sunita Rao');

    DECLARE @C1 INT=(SELECT Id FROM Camps WHERE Code='CMP-000001');
    DECLARE @C2 INT=(SELECT Id FROM Camps WHERE Code='CMP-000002');
    DECLARE @C3 INT=(SELECT Id FROM Camps WHERE Code='CMP-000003');

    DECLARE @R101 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-101');
    DECLARE @R102 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-102');
    DECLARE @R103 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-103');
    DECLARE @R104 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-104');
    DECLARE @R105 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-105');
    DECLARE @R201 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-201');
    DECLARE @R202 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-202');
    DECLARE @R203 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-203');
    DECLARE @RE101 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-E101');
    DECLARE @RW301 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-W301');
    DECLARE @RW302 INT=(SELECT Id FROM Rooms WHERE RoomNo='R-W302');

    -- Insert Contracts (12 months each, starting Jan 2026)
    INSERT INTO Contracts(ContractId,TenantId,CampId,StartDate,Months,EndDate,MonthlyTotal,ContractTotal,Status,CreatedAt,UpdatedAt) VALUES
    ('CNT-000001',@T1, @C1,'2026-01-01',12,'2026-12-31',8500, 102000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000002',@T2, @C1,'2026-01-01',12,'2026-12-31',7200,  86400,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000003',@T3, @C2,'2026-01-01',12,'2026-12-31',9000, 108000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000004',@T4, @C1,'2026-01-01',12,'2026-12-31',6500,  78000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000005',@T5, @C3,'2026-01-01',12,'2026-12-31',11000,132000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000006',@T6, @C2,'2026-01-01',12,'2026-12-31',7800,  93600,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000007',@T7, @C3,'2026-01-01',12,'2026-12-31',9500, 114000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000008',@T8, @C1,'2026-01-01',12,'2026-12-31',6000,  72000,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000009',@T9, @C2,'2026-01-01',12,'2026-12-31',8200,  98400,'Active',GETUTCDATE(),GETUTCDATE()),
    ('CNT-000010',@T10,@C1,'2026-01-01',12,'2026-12-31',7500,  90000,'Active',GETUTCDATE(),GETUTCDATE());

    -- Link rooms to contracts
    INSERT INTO ContractRooms(ContractId,RoomId) VALUES
    ('CNT-000001',@R101),('CNT-000002',@R102),('CNT-000003',@R201),
    ('CNT-000004',@R103),('CNT-000005',@RW301),('CNT-000006',@R202),
    ('CNT-000007',@RW302),('CNT-000008',@R104),('CNT-000009',@R203),
    ('CNT-000010',@R105);

    -- Generate 12 installments per contract
    DECLARE @i INT=1;
    WHILE @i<=12
    BEGIN
        INSERT INTO Payments(ContractId,InstallmentNo,Amount,DueDate,PaidAmount,Status,PaymentMode,PaymentModeId,CreatedAt,UpdatedAt) VALUES
        ('CNT-000001',@i,8500, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000002',@i,7200, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000003',@i,9000, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000004',@i,6500, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000005',@i,11000,DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000006',@i,7800, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000007',@i,9500, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000008',@i,6000, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000009',@i,8200, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE()),
        ('CNT-000010',@i,7500, DATEADD(MONTH,@i-1,'2026-01-01'),0,'Pending','',NULL,GETUTCDATE(),GETUTCDATE());
        SET @i+=1;
    END
END
GO

PRINT '>>> Updating Payments - Monthly Due data from UI (paid/partial/overdue)...';
-- Match exact MonthlyDue.jsx data: CNT-001=paid, CNT-002=unpaid, CNT-003=paid, CNT-004=partial, CNT-005=overdue etc.

-- CNT-000001 - Rahul Sharma - June installment (6) - PAID
UPDATE Payments SET PaidAmount=8500,PaidDate='2026-06-04',Status='Paid',
    PaymentMode='Cash',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cash')
WHERE ContractId='CNT-000001' AND InstallmentNo=6;

-- Jan-May also paid
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,3,DueDate),Status='Paid',
    PaymentMode='Cash',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cash')
WHERE ContractId='CNT-000001' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000002 - Priya Patel - June - UNPAID (all 6 months unpaid)
-- already Pending by default

-- CNT-000003 - Amit Kumar - June - PAID
UPDATE Payments SET PaidAmount=9000,PaidDate='2026-06-10',Status='Paid',
    PaymentMode='Cheque',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cheque')
WHERE ContractId='CNT-000003' AND InstallmentNo=6;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,4,DueDate),Status='Paid',
    PaymentMode='Cheque',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cheque')
WHERE ContractId='CNT-000003' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000004 - Neha Singh - June - PARTIAL
UPDATE Payments SET PaidAmount=3000,Status='Partial',
    PaymentMode='Online Payment',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Online Payment')
WHERE ContractId='CNT-000004' AND InstallmentNo=6;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,2,DueDate),Status='Paid',
    PaymentMode='Online Payment',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Online Payment')
WHERE ContractId='CNT-000004' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000005 - Suresh Verma - June - OVERDUE
UPDATE Payments SET Status='Overdue'
WHERE ContractId='CNT-000005' AND InstallmentNo=6;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,5,DueDate),Status='Paid',
    PaymentMode='Cash',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cash')
WHERE ContractId='CNT-000005' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000006 - Kavita Mishra - June - PAID
UPDATE Payments SET PaidAmount=7800,PaidDate='2026-06-03',Status='Paid',
    PaymentMode='Debit Card',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Debit Card')
WHERE ContractId='CNT-000006' AND InstallmentNo=6;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,3,DueDate),Status='Paid',
    PaymentMode='Debit Card',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Debit Card')
WHERE ContractId='CNT-000006' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000007 - Mohan Lal - June - UNPAID
-- already Pending

-- CNT-000008 - Anita Gupta - June - PAID
UPDATE Payments SET PaidAmount=6000,PaidDate='2026-06-06',Status='Paid',
    PaymentMode='Cash',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cash')
WHERE ContractId='CNT-000008' AND InstallmentNo=6;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,3,DueDate),Status='Paid',
    PaymentMode='Cash',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cash')
WHERE ContractId='CNT-000008' AND InstallmentNo BETWEEN 1 AND 5;

-- CNT-000009 - Ravi Shankar - May (5) - OVERDUE
UPDATE Payments SET Status='Overdue'
WHERE ContractId='CNT-000009' AND InstallmentNo=5;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,4,DueDate),Status='Paid',
    PaymentMode='Cheque',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Cheque')
WHERE ContractId='CNT-000009' AND InstallmentNo BETWEEN 1 AND 4;

-- CNT-000010 - Sunita Rao - May (5) - PAID
UPDATE Payments SET PaidAmount=7500,PaidDate='2026-05-07',Status='Paid',
    PaymentMode='Online Payment',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Online Payment')
WHERE ContractId='CNT-000010' AND InstallmentNo=5;
UPDATE Payments SET PaidAmount=Amount,PaidDate=DATEADD(DAY,2,DueDate),Status='Paid',
    PaymentMode='Online Payment',PaymentModeId=(SELECT TOP 1 Id FROM PaymentModes WHERE Name='Online Payment')
WHERE ContractId='CNT-000010' AND InstallmentNo BETWEEN 1 AND 4;

-- Update FundPool balance from payments
UPDATE FundPools SET Balance=Balance+(
    SELECT ISNULL(SUM(PaidAmount),0) FROM Payments WHERE Status='Paid' AND FundPoolId IS NULL
)/4 WHERE Code='FP-000001';
GO

PRINT '>>> Inserting Sample Waivers...';
IF NOT EXISTS (SELECT 1 FROM Waivers WHERE ContractId='CNT-000004')
BEGIN
    DECLARE @W_TenantId INT=(SELECT Id FROM Tenants WHERE Name='Neha Singh');
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,BalanceAmount,Remark,WaiverDate) VALUES
    (@W_TenantId,'CNT-000004',3,6500,1000,5500,'Hardship waiver approved by manager','2026-03-20'),
    (@W_TenantId,'CNT-000004',4,6500,500, 6000,'Partial discount - advance payment','2026-04-15');

    -- Also one for Ravi Shankar
    DECLARE @W_T9 INT=(SELECT Id FROM Tenants WHERE Name='Ravi Shankar');
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,BalanceAmount,Remark,WaiverDate) VALUES
    (@W_T9,'CNT-000009',2,8200,200,8000,'Early payment discount','2026-02-10');
END
GO

PRINT '============================================';
PRINT 'ALL DUMMY DATA INSERTED SUCCESSFULLY!';
PRINT 'Summary:';
PRINT '  Partners     : 6';
PRINT '  Owners       : 5';
PRINT '  Floors       : 5';
PRINT '  Designations : 7';
PRINT '  Accounts Heads: 10';
PRINT '  Fund Pools   : 4';
PRINT '  Roles        : 5';
PRINT '  Other Persons: 5';
PRINT '  Camps        : 5';
PRINT '  Rooms        : 18';
PRINT '  Tenants      : 12';
PRINT '  Contracts    : 10';
PRINT '  Payments     : 120 installments';
PRINT '  Waivers      : 3';
PRINT '============================================';
GO
