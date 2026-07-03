USE TFMS_softwareDB;
GO

-- ── Fix Tenants ─────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Rahul Sharma')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Rahul Sharma','P1234567','Indian','784-1990-1234567-1','9876543201','9876543201',
    'rahul@example.com','12 MG Road Mumbai','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Priya Patel')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Priya Patel','P2345678','Indian','784-1991-2345678-2','9876543202','9876543202',
    'priya@example.com','45 Civil Lines Delhi','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Amit Kumar')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Amit Kumar','P3456789','Indian','784-1988-3456789-3','9876543203','9876543203',
    'amit@example.com','Near Bus Stand Jaipur','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Neha Singh')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Neha Singh','P4567890','Indian','784-1995-4567890-4','9876543204','9876543204',
    'neha@example.com','Sector 15 Noida','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Suresh Verma')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Suresh Verma','P5678901','Indian','784-1985-5678901-5','9876543205','9876543205',
    'suresh@example.com','Residency Road Bangalore','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Kavita Mishra')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Kavita Mishra','P6789012','Indian','784-1992-6789012-6','9876543206','9876543206',
    'kavita@example.com','Ashok Nagar Bhopal','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Mohan Lal')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Mohan Lal','P7890123','Indian','784-1987-7890123-7','9876543207','9876543207',
    'mohan@example.com','Gandhi Nagar Patna','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Anita Gupta')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Anita Gupta','P8901234','Indian','784-1993-8901234-8','9876543208','9876543208',
    'anita@example.com','Model Town Amritsar','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Ravi Shankar')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Ravi Shankar','P9012345','Indian','784-1989-9012345-9','9876543209','9876543209',
    'ravi@example.com','Lal Darwaza Hyderabad','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Sunita Rao')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Sunita Rao','PA123456','Indian','784-1994-1230001-0','9876543210','9876543210',
    'sunita@example.com','JP Nagar Bangalore','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Deepak Joshi')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Individual','Deepak Joshi','PB234567','Nepali','784-1991-2222222-2','9876543212','9876543212',
    'deepak@example.com','Andheri West Mumbai','Active','','','','','','','','','','','','','','',GETUTCDATE(),GETUTCDATE());
GO

IF NOT EXISTS (SELECT 1 FROM Tenants WHERE Name='Al-Noor Trading LLC')
INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,Address,Status,
    Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,PlotNo,MakaniNo,PropertyArea,PremisesNo,
    LessorName,LessorEid,LessorLicense,LessorLicAuthority,LessorEmail,LessorPhone,CreatedAt,UpdatedAt)
VALUES('Company','Al-Noor Trading LLC','','Pakistani','784-1980-1111111-1','0551112233','0551112233',
    'alnoor@trading.ae','Al Quoz Dubai','Active','Al-Noor Trading LLC','TL-2023-001','DED','3','','','','',
    'Sheikh Ali','784-1960-9999999-1','','','sheikh@alnoor.ae','0551119999',GETUTCDATE(),GETUTCDATE());
GO

PRINT 'Tenants fixed. Total:';
SELECT COUNT(*) AS TotalTenants FROM Tenants;
GO
