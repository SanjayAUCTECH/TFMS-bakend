-- ================================================================
-- FILE   : sp_GetTenantLedger_Update.sql
-- PURPOSE: Add Result Set 3 — Installments array to tenant ledger
--          (ContractInstallments with paid/pending/balance)
-- Run this in SSMS to update the existing SP
-- ================================================================

CREATE OR ALTER PROCEDURE sp_GetTenantLedger
    @TenantId   INT,
    @ContractId NVARCHAR(50) = NULL,
    @DateFrom   NVARCHAR(20) = NULL,
    @DateTo     NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ── RESULT SET 1: Summary header ──────────────────────────────
    SELECT
        ISNULL(t.Name,    '') AS TenantName,
        ISNULL(t.Contact, '') AS Contact,
        ISNULL(SUM(CASE WHEN ci.Amount > 0 THEN ci.Amount ELSE 0 END), 0)         AS TotalDebit,
        ISNULL(SUM(CASE WHEN ci.PaidAmount > 0 THEN ci.PaidAmount ELSE 0 END), 0) AS TotalCredit,
        ISNULL(SUM(ci.Amount), 0) - ISNULL(SUM(ci.PaidAmount), 0)                 AS NetBalance
    FROM Tenants t
    LEFT JOIN Contracts ct   ON ct.TenantId = t.Id AND ISNULL(ct.IsDeleted,0) = 0
    LEFT JOIN ContractInstallments ci
           ON ci.ContractId = ct.ContractId
          AND ISNULL(ci.IsDeleted, 0) = 0
          AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
          AND (@DateFrom   IS NULL OR ci.DueDate   >= @DateFrom)
          AND (@DateTo     IS NULL OR ci.DueDate   <= @DateTo)
    WHERE t.Id = @TenantId AND ISNULL(t.IsDeleted, 0) = 0
    GROUP BY t.Name, t.Contact;


    -- ── RESULT SET 2: Ledger rows (DR = due, CR = payment, Waiver) ─
    SELECT
        ci.DueDate                                              AS [Date],
        'Installment #' + CAST(ci.InstallmentNo AS NVARCHAR)
            + ' Due'                                            AS [Description],
        'Debit'                                                 AS [Type],
        ci.Amount                                               AS Debit,
        0                                                       AS Credit,
        ci.Amount - ISNULL(ci.PaidAmount, 0)                    AS Balance,
        ci.ContractId,
        ci.InstallmentNo,
        ISNULL(ci.PaymentMode, '')                              AS PaymentMode,
        ''                                                      AS Reference
    FROM Contracts ct
    JOIN ContractInstallments ci
         ON ci.ContractId = ct.ContractId
        AND ISNULL(ci.IsDeleted, 0) = 0
    WHERE
        ct.TenantId = @TenantId
        AND ISNULL(ct.IsDeleted, 0) = 0
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        AND (@DateFrom   IS NULL OR ci.DueDate   >= @DateFrom)
        AND (@DateTo     IS NULL OR ci.DueDate   <= @DateTo)

    UNION ALL

    SELECT
        ISNULL(ci.PaidDate, ci.DueDate)                        AS [Date],
        'Payment Received - Inst #' + CAST(ci.InstallmentNo AS NVARCHAR) AS [Description],
        'Credit'                                                AS [Type],
        0                                                       AS Debit,
        ISNULL(ci.PaidAmount, 0)                                AS Credit,
        ci.Amount - ISNULL(ci.PaidAmount, 0)                    AS Balance,
        ci.ContractId,
        ci.InstallmentNo,
        ISNULL(ci.PaymentMode, '')                              AS PaymentMode,
        ISNULL(ci.ChequeNumber, '')                             AS Reference
    FROM Contracts ct
    JOIN ContractInstallments ci
         ON ci.ContractId = ct.ContractId
        AND ISNULL(ci.IsDeleted, 0) = 0
        AND ISNULL(ci.PaidAmount, 0) > 0
    WHERE
        ct.TenantId = @TenantId
        AND ISNULL(ct.IsDeleted, 0) = 0
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        AND (@DateFrom   IS NULL OR ci.DueDate   >= @DateFrom)
        AND (@DateTo     IS NULL OR ci.DueDate   <= @DateTo)

    ORDER BY [Date], ContractId, InstallmentNo, [Type];


    -- ── RESULT SET 3: Installments detail (new) ───────────────────
    SELECT
        ci.Id,
        ci.ContractId,
        ci.InstallmentNo,
        ci.Amount,
        ISNULL(ci.PaidAmount, 0)                                AS PaidAmount,
        ci.Amount - ISNULL(ci.PaidAmount, 0)                    AS Balance,
        CONVERT(NVARCHAR(10), ci.DueDate, 120)                  AS DueDate,
        CASE WHEN ci.PaidDate IS NOT NULL
             THEN CONVERT(NVARCHAR(10), ci.PaidDate, 120)
             ELSE NULL END                                      AS PaidDate,
        ISNULL(ci.Status, 'Pending')                            AS [Status],
        ISNULL(ci.PaymentMode, '')                              AS PaymentMode,

        -- Camp name (from ContractCamps → Camps)
        ISNULL(
            (SELECT TOP 1 ca.Name
             FROM ContractCamps cc
             JOIN Camps ca ON ca.Id = cc.CampId
             WHERE cc.ContractId = ci.ContractId
             ORDER BY cc.Id),
        '')                                                     AS CampName,

        -- Room numbers for this installment
        ISNULL(
            (SELECT STRING_AGG(r.RoomNo, ', ')
             FROM ContractRooms cr
             JOIN Rooms r ON r.Id = cr.RoomId
             WHERE cr.ContractId = ci.ContractId),
        '')                                                     AS RoomNos

    FROM Contracts ct
    JOIN ContractInstallments ci
         ON ci.ContractId = ct.ContractId
        AND ISNULL(ci.IsDeleted, 0) = 0
    WHERE
        ct.TenantId = @TenantId
        AND ISNULL(ct.IsDeleted, 0) = 0
        AND (@ContractId IS NULL OR ci.ContractId = @ContractId)
        AND (@DateFrom   IS NULL OR ci.DueDate   >= @DateFrom)
        AND (@DateTo     IS NULL OR ci.DueDate   <= @DateTo)

    ORDER BY ci.ContractId, ci.InstallmentNo;

END
GO

PRINT 'sp_GetTenantLedger updated with Installments result set.';
GO
