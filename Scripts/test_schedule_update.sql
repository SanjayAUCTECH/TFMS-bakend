USE TFMS_TestSoftwareDB;
-- Test: Update schedule for CNT-000177 with bi-monthly (2 month steps)
-- Contract: 3 months, 1 room (SL1, 100/month) = total 300
-- Bi-monthly = installments on month 1 and month 3 = 2 installments
DECLARE @schedule NVARCHAR(MAX) = '[
  {"no":1,"amount":200,"dueDate":"2026-10-01","mode":"Cash","cheque":"","clearance":""},
  {"no":2,"amount":100,"dueDate":"2026-12-01","mode":"Cash","cheque":"","clearance":""}
]';
EXEC sp_UpdatePaymentSchedule @ContractId='CNT-000177', @ScheduleJson=@schedule;

SELECT 'ContractInstallments' AS Tbl, InstallmentNo, Amount, DueDate, Status FROM ContractInstallments WHERE ContractId='CNT-000177' ORDER BY InstallmentNo;
SELECT 'RoomInstallments' AS Tbl, RoomNo, InstallmentNo, InstallAmount, DueDate, Month, Status FROM ContractRoomInstallments WHERE ContractId='CNT-000177' ORDER BY InstallmentNo;
