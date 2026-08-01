-- ============================================================
-- 133: Alter optional columns to NULL in all tables
--      Taaki edit ke time null bhej sako aur NULL save ho
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- Staff table — optional fields NULL allow karo
-- ══════════════════════════════════════════════════════════════
ALTER TABLE Staff ALTER COLUMN Designation NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN Contact     NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN Email       NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN Address     NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN Remarks     NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN EmiratesId  NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN PassportNo  NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN Nationality NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN JobTitle    NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN LabourCardNo  NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN IloeNo        NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN InsuranceNo   NVARCHAR(MAX) NULL;
-- Document URLs (already nullable likely, but just in case)
ALTER TABLE Staff ALTER COLUMN EmiratesIdDocument NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN PassportDocument   NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN LabourCardDocument NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN IloeDocument       NVARCHAR(MAX) NULL;
ALTER TABLE Staff ALTER COLUMN InsuranceDocument  NVARCHAR(MAX) NULL;
GO
PRINT '✅ Staff columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- Tenants table — optional fields NULL allow karo
-- ══════════════════════════════════════════════════════════════
ALTER TABLE Tenants ALTER COLUMN Passport            NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Nationality         NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN EmiratesId          NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Contact             NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Whatsapp            NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Email               NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Address             NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN Company             NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN TradeLicense        NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LicensingAuthority  NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN NumberOfCoOccupants NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN PlotNo              NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN MakaniNo            NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN PropertyArea        NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN PremisesNo          NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorName          NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorEid           NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorLicense       NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorLicAuthority  NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorEmail         NVARCHAR(MAX) NULL;
ALTER TABLE Tenants ALTER COLUMN LessorPhone         NVARCHAR(MAX) NULL;
GO
PRINT '✅ Tenants columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- Owners table
-- ══════════════════════════════════════════════════════════════
ALTER TABLE Owners ALTER COLUMN Contact NVARCHAR(MAX) NULL;
ALTER TABLE Owners ALTER COLUMN Email   NVARCHAR(MAX) NULL;
GO
PRINT '✅ Owners columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- Partners table
-- ══════════════════════════════════════════════════════════════
ALTER TABLE Partners ALTER COLUMN Contact NVARCHAR(MAX) NULL;
ALTER TABLE Partners ALTER COLUMN Mobile  NVARCHAR(MAX) NULL;
ALTER TABLE Partners ALTER COLUMN Email   NVARCHAR(MAX) NULL;
GO
PRINT '✅ Partners columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- OtherPersons table
-- ══════════════════════════════════════════════════════════════
ALTER TABLE OtherPersons ALTER COLUMN Mobile  NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN Email   NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN Address NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN City    NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN State   NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN Pincode NVARCHAR(MAX) NULL;
ALTER TABLE OtherPersons ALTER COLUMN Remarks NVARCHAR(MAX) NULL;
GO
PRINT '✅ OtherPersons columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- AppUsers table
-- ══════════════════════════════════════════════════════════════
ALTER TABLE AppUsers ALTER COLUMN Role    NVARCHAR(MAX) NULL;
ALTER TABLE AppUsers ALTER COLUMN Source  NVARCHAR(MAX) NULL;
ALTER TABLE AppUsers ALTER COLUMN Contact NVARCHAR(MAX) NULL;
ALTER TABLE AppUsers ALTER COLUMN Email   NVARCHAR(MAX) NULL;
GO
PRINT '✅ AppUsers columns altered to NULL';
GO

-- ══════════════════════════════════════════════════════════════
-- Rooms table
-- ══════════════════════════════════════════════════════════════
ALTER TABLE Rooms ALTER COLUMN OtherDetails NVARCHAR(MAX) NULL;
GO
PRINT '✅ Rooms columns altered to NULL';
GO

PRINT '';
PRINT '✅✅ 133 - All optional columns are now nullable. Null save hoga jab null bhejoge.';
GO
