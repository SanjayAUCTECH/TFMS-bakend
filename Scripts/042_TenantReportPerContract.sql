-- ============================================================
-- 042: sp_GetTenantReport — 1 row per CONTRACT
--      Tenant with 2 contracts = 2 rows
--      Tenant with no contract = 1 row (blank contract fields)
--      Security Deposit properly shown
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber   INT,
    @PageSize     INT,
    @SearchText   NVARCHAR(MAX) = NULL,
    @Status       NVARCHAR(MAX) = NULL,   -- Tenant status filter
    @CampId       INT           = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Count ─────────────────────────────────────────────────
    -- Count = distinct contracts (or 1 for tenants with no contract)
    SELECT @TotalRecords = COUNT(*)
    FROM (
        SELECT c.ContractId
        FROM Tenants t
        JOIN Contracts c ON c.TenantId = t.Id
        LEFT JOIN ContractCamps cc ON cc.ContractId = c.ContractId
        WHERE (@Status     IS NULL OR t.Status   = @Status)
          AND (@CampId     IS NULL OR cc.CampId  = @CampId)
          AND (@SearchText IS NULL
               OR t.Name    LIKE '%' + @SearchText + '%'
               OR t.Contact LIKE '%' + @SearchText + '%')
        UNION ALL
        -- Tenants with no contract at all
        SELECT NULL
        FROM Tenants t
        WHERE NOT EXISTS (SELECT 1 FROM Contracts c2 WHERE c2.TenantId = t.Id)
          AND (@Status     IS NULL OR t.Status = @Status)
          AND (@SearchText IS NULL
               OR t.Name    LIKE '%' + @SearchText + '%'
               OR t.Contact LIKE '%' + @SearchText + '%')
    ) x;

    -- ── Main: 1 row per contract ───────────────────────────────
    SELECT
        -- Tenant Info
        t.Id                                TenantId,
        t.Name                              TenantName,
        ISNULL(t.Contact,  '')              Contact,
        ISNULL(t.Email,    '')              Email,
        ISNULL(t.EmiratesId, '')            EmiratesId,
        ISNULL(t.Nationality, '')           Nationality,
        t.Status,
        ISNULL(t.Type, 'Individual')        [Type],

        -- Contract Info
        ISNULL(c.ContractId, '')            ContractId,
        c.StartDate                         ContractStart,
        c.EndDate                           ContractEnd,
        ISNULL(c.Status, '')                ContractStatus,

        -- Security Deposit (from this contract)
        ISNULL(c.SecurityDeposit, 0)                        SecurityDeposit,
        ISNULL(c.SecurityDepositStatus, 'Pending')          SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid, 0)                    SecurityDepositPaid,

        -- Camp info (this contract's camps)
        ISNULL(STUFF((
            SELECT DISTINCT ', ' + ca2.Name
            FROM ContractCamps cc2
            JOIN Camps ca2 ON ca2.Id = cc2.CampId
            WHERE cc2.ContractId = c.ContractId
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, ''), '')        CampName,

        ISNULL((SELECT COUNT(DISTINCT cc3.CampId)
                FROM ContractCamps cc3
                WHERE cc3.ContractId = c.ContractId), 0)    CampsCount,

        -- Room info (this contract's rooms)
        ISNULL(STUFF((
            SELECT ', ' + r2.RoomNo
            FROM ContractRooms cr2
            JOIN Rooms r2 ON r2.Id = cr2.RoomId
            WHERE cr2.ContractId = c.ContractId
            FOR XML PATH(''), TYPE
        ).value('.','NVARCHAR(MAX)'), 1, 2, ''), '')         RoomNo,

        ISNULL((SELECT COUNT(*)
                FROM ContractRooms cr3
                WHERE cr3.ContractId = c.ContractId), 0)    RoomsBooked,

        -- Rent amounts (this contract)
        ISNULL(c.MonthlyTotal,   0)         MonthlyRent,
        ISNULL(c.ContractTotal,  0)         ContractRentTotal,

        -- Total Amount = Rent + Security Deposit
        ISNULL(c.ContractTotal, 0) + ISNULL(c.SecurityDeposit, 0) TotalAmount,

        -- Rent Paid — TxnRecords CR type for this contract
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                WHERE tr.ContractId = c.ContractId
                  AND tr.TxnType = 'CR'), 0)                RentPaid,

        -- SD Paid — TxnRecords SD-CR type for this contract
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                WHERE tr.ContractId = c.ContractId
                  AND tr.TxnType = 'SD-CR'), 0)             SecurityDepositPaidAmount,

        -- Total Paid = RentPaid + SDPaidAmount
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                WHERE tr.ContractId = c.ContractId
                  AND tr.TxnType IN ('CR','SD-CR')), 0)     TotalPaid,

        -- Total Due = TotalAmount - TotalPaid
        (ISNULL(c.ContractTotal, 0) + ISNULL(c.SecurityDeposit, 0))
        - ISNULL((SELECT SUM(tr.Amount)
                  FROM TxnRecords tr
                  WHERE tr.ContractId = c.ContractId
                    AND tr.TxnType IN ('CR','SD-CR')), 0)   TotalDue,

        -- Balance = same as TotalDue
        (ISNULL(c.ContractTotal, 0) + ISNULL(c.SecurityDeposit, 0))
        - ISNULL((SELECT SUM(tr.Amount)
                  FROM TxnRecords tr
                  WHERE tr.ContractId = c.ContractId
                    AND tr.TxnType IN ('CR','SD-CR')), 0)   Balance,

        -- Waiver for this contract
        ISNULL((SELECT SUM(w.WaiverAmount)
                FROM Waivers w
                WHERE w.ContractId = c.ContractId), 0)      WaiverAmount

    FROM Tenants t
    -- LEFT JOIN so tenants with no contract still appear (1 row, blank contract)
    LEFT JOIN Contracts c ON c.TenantId = t.Id
    LEFT JOIN ContractCamps ccf ON ccf.ContractId = c.ContractId
    WHERE (@Status     IS NULL OR t.Status   = @Status)
      AND (@CampId     IS NULL OR ccf.CampId = @CampId OR c.ContractId IS NULL)
      AND (@SearchText IS NULL
           OR t.Name    LIKE '%' + @SearchText + '%'
           OR t.Contact LIKE '%' + @SearchText + '%')
    GROUP BY
        t.Id, t.Name, t.Contact, t.Email, t.EmiratesId, t.Nationality,
        t.Status, t.Type,
        c.ContractId, c.StartDate, c.EndDate, c.Status,
        c.SecurityDeposit, c.SecurityDepositStatus, c.SecurityDepositPaid,
        c.MonthlyTotal, c.ContractTotal
    ORDER BY t.Name, c.StartDate DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '042 - sp_GetTenantReport: 1 row per contract with SecurityDeposit';
GO
