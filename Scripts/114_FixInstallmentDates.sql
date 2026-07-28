-- ============================================================
-- 114: Fix ContractInstallments DueDates
-- Problem: Last installment gets wrong date (EndDate based)
-- Fix: All DueDates = DATEADD(MONTH, InstallmentNo-1, StartDate)
-- Also fix ContractRoomInstallments same way
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Fix existing wrong ContractInstallments dates ─────────────
-- For any contract where last installment date != expected
UPDATE ci
SET ci.DueDate = DATEADD(MONTH, ci.InstallmentNo - 1, c.StartDate)
FROM ContractInstallments ci
JOIN Contracts c ON c.ContractId = ci.ContractId AND c.IsDeleted = 0
WHERE ISNULL(ci.IsDeleted, 0) = 0
  AND ci.DueDate <> DATEADD(MONTH, ci.InstallmentNo - 1, c.StartDate);

SELECT 'ContractInstallments fixed: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows' AS Result;
GO

-- ── Fix existing wrong ContractRoomInstallments dates ─────────
UPDATE cri
SET cri.DueDate = DATEADD(MONTH, cri.InstallmentNo - 1, c.StartDate)
FROM ContractRoomInstallments cri
JOIN Contracts c ON c.ContractId = cri.ContractId AND c.IsDeleted = 0
WHERE ISNULL(cri.IsDeleted, 0) = 0
  AND cri.DueDate <> DATEADD(MONTH, cri.InstallmentNo - 1, c.StartDate);

SELECT 'ContractRoomInstallments fixed: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows' AS Result;
GO

-- ── Verify CNT-000091 ──────────────────────────────────────────
SELECT InstallmentNo, DueDate,
    DATEADD(MONTH, InstallmentNo-1, '2026-07-28') AS ExpectedDate,
    CASE WHEN DueDate = DATEADD(MONTH, InstallmentNo-1, '2026-07-28') THEN 'OK' ELSE 'WRONG' END AS Check
FROM ContractInstallments WHERE ContractId='CNT-000091' ORDER BY InstallmentNo;
GO

PRINT '✅ All installment dates fixed - now based on StartDate + (InstallmentNo-1) months';
GO
