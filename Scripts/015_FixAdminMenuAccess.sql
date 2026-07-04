USE TFMS_softwareDB;
GO

-- Fix Admin users: give full access to all menu pages
DECLARE @fullAccess NVARCHAR(MAX) = '{"dashboard":true,"partners":true,"owners":true,"floors":true,"roomstatus":true,"paymentmode":true,"fundpool":true,"role-master":true,"accounts-head":true,"designation":true,"other-person":true,"camps":true,"rooms":true,"tenants":true,"newcontract":true,"updatecontract":true,"viewcontract":true,"contractlist":true,"recordpayment":true,"makepayment":true,"waiver":true,"income":true,"expense":true,"mis-dashboard":true,"report-inventory":true,"report-tenant":true,"report-partner":true,"report-camp":true,"report-transaction":true,"report-ledger":true,"report-due":true,"report-waiver":true,"user-list":true,"user-access":true,"user-menu-access":true,"staff-master":true}';

UPDATE AppUsers SET MenuAccess = @fullAccess WHERE Role = 'Admin' OR IsAdmin = 1;

SELECT 'Updated ' + CAST(@@ROWCOUNT as varchar) + ' Admin users with full menu access' as Result;
GO
