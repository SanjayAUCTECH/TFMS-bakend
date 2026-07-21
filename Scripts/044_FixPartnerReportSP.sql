-- ============================================================
-- 044: Fix sp_GetPartnerReport
--      - Replace STRING_AGG with STUFF+FOR XML (SQL Express compat)
--      - TotalPaid from Expenses WHERE RecipientRole='Partner' AND RecipientId=p.Id
--      - ShareDue = TotalCollected - TotalPaid
--      - Proper pagination via SP
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count
    SELECT @TotalRecords = COUNT(*)
    FROM Partners p
    WHERE (@Status     IS NULL OR p.Status = @Status)
      AND (@SearchText IS NULL
           OR p.Name LIKE '%' + @SearchText + '%'
           OR p.Code LIKE '%' + @SearchText + '%');

    -- Main
    SELECT
        p.Id                                    PartnerId,
        p.Code                                  PartnerCode,
        p.Name                                  PartnerName,
        ISNULL(p.Contact, '')                   Contact,
        ISNULL(p.Mobile,  '')                   Mobile,
        ISNULL(p.Email,   '')                   Email,
        p.Status,

        -- Total camps assigned
        COUNT(DISTINCT cp.CampId)               TotalCamps,

        -- Camp names (STUFF + FOR XML for SQL Express)
        ISNULL(STUFF((
            SELECT DISTINCT ', ' + c2.Name
            FROM CampPartners cp2
            JOIN Camps c2 ON c2.Id = cp2.CampId
            WHERE cp2.PartnerId = p.Id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, ''), '') CampNames,

        -- Share value & type (from CampPartners)
        ISNULL(AVG(CAST(cp.ShareValue AS DECIMAL(18,4))), 0) ShareValue,
        ISNULL(MAX(cp.ShareType), '')           ShareType,

        -- Total rent collected from tenants for this partner's camps
        ISNULL((
            SELECT SUM(ci.PaidAmount)
            FROM ContractInstallments ci
            JOIN ContractCamps cc ON cc.ContractId = ci.ContractId
            JOIN CampPartners cp3 ON cp3.CampId = cc.CampId AND cp3.PartnerId = p.Id
            WHERE ci.Status = 'Paid'
        ), 0)                                   TotalCollected,

        -- Total amount paid TO this partner via Expenses
        -- Join: RecipientRole='Partner' AND RecipientId = p.Id
        ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE e.RecipientRole = 'Partner'
              AND e.RecipientId   = p.Id
        ), 0)                                   TotalPaid,

        -- ShareDue = TotalCollected - TotalPaid
        ISNULL((
            SELECT SUM(ci.PaidAmount)
            FROM ContractInstallments ci
            JOIN ContractCamps cc ON cc.ContractId = ci.ContractId
            JOIN CampPartners cp4 ON cp4.CampId = cc.CampId AND cp4.PartnerId = p.Id
            WHERE ci.Status = 'Paid'
        ), 0)
        - ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE e.RecipientRole = 'Partner'
              AND e.RecipientId   = p.Id
        ), 0)                                   ShareDue

    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId = p.Id
    LEFT JOIN Camps c ON c.Id = cp.CampId
    WHERE (@Status     IS NULL OR p.Status = @Status)
      AND (@SearchText IS NULL
           OR p.Name LIKE '%' + @SearchText + '%'
           OR p.Code LIKE '%' + @SearchText + '%')
    GROUP BY p.Id, p.Code, p.Name, p.Contact, p.Mobile, p.Email, p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '044 - sp_GetPartnerReport fixed: STUFF+FOR XML, RecipientId join, ShareDue calculated';
GO
