-- ============================================================
-- 057: Fix sp_GetCampReport
--      TotalCollected  → SUM(ContractRooms.PaidAmount) per camp
--      TotalDue        → SUM(ContractRooms.Balance)    per camp
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetCampReport
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM Camps ca
    WHERE (@Status     IS NULL OR ca.Status = @Status)
      AND (@SearchText IS NULL
           OR ca.Name LIKE '%' + @SearchText + '%'
           OR ca.Code LIKE '%' + @SearchText + '%');

    SELECT
        ca.Id                                                               CampId,
        ca.Code                                                             CampCode,
        ca.Name                                                             CampName,
        ca.Status,

        -- Total rooms in camp
        COUNT(DISTINCT r.Id)                                                TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Status = 'Occupied' THEN r.Id END)      OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Status = 'Vacant'   THEN r.Id END)      VacantRooms,

        -- Active contracts linked to this camp
        COUNT(DISTINCT CASE WHEN c.Status = 'Active'   THEN c.Id END)      ActiveContracts,

        -- Monthly rent (occupied rooms)
        ISNULL(SUM(CASE WHEN r.Status = 'Occupied' THEN r.MonthlyPrice ELSE 0 END), 0) TotalMonthlyRent,

        -- ✅ Total Collected = SUM(ContractRooms.PaidAmount) for rooms in this camp
        ISNULL((
            SELECT SUM(cr.PaidAmount)
            FROM ContractRooms cr
            WHERE cr.CampId = ca.Id
        ), 0)                                                               TotalCollected,

        -- ✅ Total Due = SUM(ContractRooms.Balance) for rooms in this camp
        ISNULL((
            SELECT SUM(cr.Balance)
            FROM ContractRooms cr
            WHERE cr.CampId = ca.Id
              AND cr.Balance > 0
        ), 0)                                                               TotalDue,

        -- Expenses for this camp
        ISNULL((
            SELECT SUM(e.Amount)
            FROM Expenses e
            WHERE e.Nature = 'Camp' AND e.CampId = ca.Id
        ), 0)                                                               CampExpense,

        -- HO allocated (10% of HO expenses)
        ISNULL((
            SELECT SUM(e2.Amount) * 0.1
            FROM Expenses e2
            WHERE e2.Nature = 'HO'
        ), 0)                                                               HOAllocated,

        -- Profit = TotalCollected - CampExpense
        ISNULL((
            SELECT SUM(cr2.PaidAmount)
            FROM ContractRooms cr2
            WHERE cr2.CampId = ca.Id
        ), 0)
        - ISNULL((
            SELECT SUM(e3.Amount)
            FROM Expenses e3
            WHERE e3.Nature = 'Camp' AND e3.CampId = ca.Id
        ), 0)                                                               Profit,

        -- Total Expense (Camp + HO)
        ISNULL((
            SELECT SUM(e4.Amount)
            FROM Expenses e4
            WHERE e4.CampId = ca.Id OR e4.Nature = 'HO'
        ), 0)                                                               TotalExpense

    FROM Camps ca
    LEFT JOIN Rooms r           ON r.CampId  = ca.Id
    LEFT JOIN ContractCamps cc  ON cc.CampId = ca.Id
    LEFT JOIN Contracts c       ON c.ContractId = cc.ContractId
    WHERE (@Status     IS NULL OR ca.Status = @Status)
      AND (@SearchText IS NULL
           OR ca.Name LIKE '%' + @SearchText + '%'
           OR ca.Code LIKE '%' + @SearchText + '%')
    GROUP BY ca.Id, ca.Code, ca.Name, ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '057 - sp_GetCampReport fixed: TotalCollected/TotalDue from ContractRooms.PaidAmount/Balance';
GO
