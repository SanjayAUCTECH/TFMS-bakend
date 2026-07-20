-- ============================================================
-- 041: Fix sp_GetTenantReport — 1 row per tenant
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
    @Status       NVARCHAR(MAX) = NULL,
    @CampId       INT           = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count distinct tenants
    SELECT @TotalRecords = COUNT(DISTINCT t.Id)
    FROM Tenants t
    LEFT JOIN Contracts c   ON c.TenantId = t.Id AND c.Status = 'Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId = c.ContractId
    WHERE (@Status     IS NULL OR t.Status   = @Status)
      AND (@CampId     IS NULL OR cc.CampId  = @CampId)
      AND (@SearchText IS NULL
           OR t.Name    LIKE '%' + @SearchText + '%'
           OR t.Contact LIKE '%' + @SearchText + '%');

    -- Main query: 1 row per tenant
    SELECT
        t.Id                                                            TenantId,
        t.Name                                                          TenantName,
        ISNULL(t.Contact, '')                                           Contact,
        ISNULL(t.Email, '')                                             Email,
        ISNULL(t.EmiratesId, '')                                        EmiratesId,
        ISNULL(t.Nationality, '')                                       Nationality,
        t.Status,
        ISNULL(t.Type, 'Individual')                                    [Type],

        -- Latest active contract info
        ISNULL((SELECT TOP 1 c1.ContractId
                FROM Contracts c1
                WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
                ORDER BY c1.StartDate DESC, c1.Id DESC), '')            ContractId,

        (SELECT TOP 1 c1.StartDate
         FROM Contracts c1
         WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
         ORDER BY c1.StartDate DESC, c1.Id DESC)                        ContractStart,

        (SELECT TOP 1 c1.EndDate
         FROM Contracts c1
         WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
         ORDER BY c1.StartDate DESC, c1.Id DESC)                        ContractEnd,

        ISNULL((SELECT TOP 1 c1.Status
                FROM Contracts c1
                WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
                ORDER BY c1.StartDate DESC, c1.Id DESC), '')            ContractStatus,

        -- Security Deposit from latest active contract
        ISNULL((SELECT TOP 1 c1.SecurityDeposit
                FROM Contracts c1
                WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
                ORDER BY c1.StartDate DESC, c1.Id DESC), 0)             SecurityDeposit,

        ISNULL((SELECT TOP 1 ISNULL(c1.SecurityDepositStatus, 'Pending')
                FROM Contracts c1
                WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
                ORDER BY c1.StartDate DESC, c1.Id DESC), 'Pending')     SecurityDepositStatus,

        ISNULL((SELECT TOP 1 ISNULL(c1.SecurityDepositPaid, 0)
                FROM Contracts c1
                WHERE c1.TenantId = t.Id AND c1.Status = 'Active'
                ORDER BY c1.StartDate DESC, c1.Id DESC), 0)             SecurityDepositPaid,

        -- Camp names (all active contracts) — STUFF+FOR XML
        ISNULL(STUFF((
            SELECT DISTINCT ', ' + ca2.Name
            FROM Contracts c2
            JOIN ContractCamps cc2 ON cc2.ContractId = c2.ContractId
            JOIN Camps ca2         ON ca2.Id          = cc2.CampId
            WHERE c2.TenantId = t.Id AND c2.Status = 'Active'
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''), '') CampName,

        -- Camps count
        ISNULL((SELECT COUNT(DISTINCT cc3.CampId)
                FROM Contracts c3
                JOIN ContractCamps cc3 ON cc3.ContractId = c3.ContractId
                WHERE c3.TenantId = t.Id AND c3.Status = 'Active'), 0) CampsCount,

        -- Room numbers (all active contracts) — STUFF+FOR XML
        ISNULL(STUFF((
            SELECT ', ' + r2.RoomNo
            FROM Contracts c4
            JOIN ContractRooms cr2 ON cr2.ContractId = c4.ContractId
            JOIN Rooms r2          ON r2.Id           = cr2.RoomId
            WHERE c4.TenantId = t.Id AND c4.Status = 'Active'
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''), '') RoomNo,

        -- Rooms booked count
        ISNULL((SELECT COUNT(*)
                FROM Contracts c5
                JOIN ContractRooms cr3 ON cr3.ContractId = c5.ContractId
                WHERE c5.TenantId = t.Id AND c5.Status = 'Active'), 0) RoomsBooked,

        -- Monthly rent (sum of all active)
        ISNULL((SELECT SUM(c6.MonthlyTotal)
                FROM Contracts c6
                WHERE c6.TenantId = t.Id AND c6.Status = 'Active'), 0) MonthlyRent,

        -- Contract rent total (sum of all active)
        ISNULL((SELECT SUM(c7.ContractTotal)
                FROM Contracts c7
                WHERE c7.TenantId = t.Id AND c7.Status = 'Active'), 0) ContractRentTotal,

        -- Total amount = rent + security deposit (all active)
        ISNULL((SELECT SUM(c8.ContractTotal) + SUM(ISNULL(c8.SecurityDeposit, 0))
                FROM Contracts c8
                WHERE c8.TenantId = t.Id AND c8.Status = 'Active'), 0) TotalAmount,

        -- Rent paid (TxnType=CR, all contracts)
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                JOIN Contracts cx ON cx.ContractId = tr.ContractId
                WHERE cx.TenantId = t.Id AND tr.TxnType = 'CR'), 0)    RentPaid,

        -- SD paid (TxnType=SD-CR, all contracts)
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                JOIN Contracts cx ON cx.ContractId = tr.ContractId
                WHERE cx.TenantId = t.Id AND tr.TxnType = 'SD-CR'), 0) SecurityDepositPaidAmount,

        -- Total paid = CR + SD-CR
        ISNULL((SELECT SUM(tr.Amount)
                FROM TxnRecords tr
                JOIN Contracts cx ON cx.ContractId = tr.ContractId
                WHERE cx.TenantId = t.Id AND tr.TxnType IN ('CR','SD-CR')), 0) TotalPaid,

        -- Total due = TotalAmount - TotalPaid
        ISNULL((SELECT SUM(c9.ContractTotal) + SUM(ISNULL(c9.SecurityDeposit, 0))
                FROM Contracts c9
                WHERE c9.TenantId = t.Id AND c9.Status = 'Active'), 0)
        - ISNULL((SELECT SUM(tr2.Amount)
                  FROM TxnRecords tr2
                  JOIN Contracts cx2 ON cx2.ContractId = tr2.ContractId
                  WHERE cx2.TenantId = t.Id AND tr2.TxnType IN ('CR','SD-CR')), 0) TotalDue,

        -- Balance = same as TotalDue
        ISNULL((SELECT SUM(c10.ContractTotal) + SUM(ISNULL(c10.SecurityDeposit, 0))
                FROM Contracts c10
                WHERE c10.TenantId = t.Id AND c10.Status = 'Active'), 0)
        - ISNULL((SELECT SUM(tr3.Amount)
                  FROM TxnRecords tr3
                  JOIN Contracts cx3 ON cx3.ContractId = tr3.ContractId
                  WHERE cx3.TenantId = t.Id AND tr3.TxnType IN ('CR','SD-CR')), 0) Balance,

        -- Waiver (all contracts)
        ISNULL((SELECT SUM(w.WaiverAmount)
                FROM Waivers w
                JOIN Contracts cw ON cw.ContractId = w.ContractId
                WHERE cw.TenantId = t.Id), 0)                           WaiverAmount

    FROM Tenants t
    LEFT JOIN Contracts cf   ON cf.TenantId   = t.Id AND cf.Status = 'Active'
    LEFT JOIN ContractCamps ccf ON ccf.ContractId = cf.ContractId
    WHERE (@Status     IS NULL OR t.Status    = @Status)
      AND (@CampId     IS NULL OR ccf.CampId  = @CampId)
      AND (@SearchText IS NULL
           OR t.Name    LIKE '%' + @SearchText + '%'
           OR t.Contact LIKE '%' + @SearchText + '%')
    GROUP BY t.Id, t.Name, t.Contact, t.Email, t.EmiratesId,
             t.Nationality, t.Status, t.Type
    ORDER BY t.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '041 - sp_GetTenantReport fixed: 1 row per tenant';
GO
