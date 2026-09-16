SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetSalonUngeneratedData
    @SalonId  INT  = NULL,   -- optional filter
    @DateFrom DATE = NULL,   -- e.g. 2026-08-01
    @DateTo   DATE = NULL    -- e.g. 2026-08-31
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Default to current month if no dates provided ─────────────
    DECLARE @From DATE = ISNULL(@DateFrom, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1));
    DECLARE @To   DATE = ISNULL(@DateTo,   EOMONTH(DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)));

    -- ════════════════════════════════════════════════════════════
    -- UngeneratedCollection
    -- Source: SDCollection
    -- Filter: Date BETWEEN @From AND @To
    --         IsDeleted = 0
    --         SalonId filter if provided
    --         SUM(Amount) GROUP BY SalonId
    -- ════════════════════════════════════════════════════════════
    ;WITH CTE_Collection AS (
        SELECT
            sdc.SalonId,
            SUM(sdc.Amount) AS UngeneratedCollection
        FROM SDCollection sdc
        WHERE ISNULL(sdc.IsDeleted, 0) = 0
          AND sdc.Date >= @From
          AND sdc.Date <= @To
          AND (@SalonId IS NULL OR sdc.SalonId = @SalonId)
        GROUP BY sdc.SalonId
    ),

    -- ════════════════════════════════════════════════════════════
    -- UngeneratedCompanyExpense
    -- Source: CompanyExpensePosting
    -- Filter: Date BETWEEN @From AND @To
    --         IsDeleted = 0
    --         Head != 'SALARY' (case insensitive)
    --         SUM(Amount) GROUP BY SalonId
    -- ════════════════════════════════════════════════════════════
    CTE_CompanyExpense AS (
        SELECT
            cep.SalonId,
            SUM(cep.Amount) AS UngeneratedCompanyExpense
        FROM CompanyExpensePosting cep
        WHERE ISNULL(cep.IsDeleted, 0) = 0
          AND LOWER(ISNULL(cep.Head, '')) <> 'salary'
          AND cep.Date >= @From
          AND cep.Date <= @To
          AND (@SalonId IS NULL OR cep.SalonId = @SalonId)
        GROUP BY cep.SalonId
    ),

    -- ════════════════════════════════════════════════════════════
    -- UngeneratedStaffSalary
    -- Source: CompanyExpensePosting
    -- Filter: Date BETWEEN @From AND @To
    --         IsDeleted = 0
    --         Head = 'SALARY' (case insensitive)
    --         SUM(Amount) GROUP BY SalonId
    -- ════════════════════════════════════════════════════════════
    CTE_StaffSalary AS (
        SELECT
            cep.SalonId,
            SUM(cep.Amount) AS UngeneratedStaffSalary
        FROM CompanyExpensePosting cep
        WHERE ISNULL(cep.IsDeleted, 0) = 0
          AND LOWER(ISNULL(cep.Head, '')) = 'salary'
          AND cep.Date >= @From
          AND cep.Date <= @To
          AND (@SalonId IS NULL OR cep.SalonId = @SalonId)
        GROUP BY cep.SalonId
    )

    -- ════════════════════════════════════════════════════════════
    -- FINAL SELECT: Salon wise
    -- ════════════════════════════════════════════════════════════
    SELECT
        s.Id                                            AS SalonId,
        s.Name                                          AS SalonName,
        CONVERT(NVARCHAR(10), @From, 120)               AS DateFrom,
        CONVERT(NVARCHAR(10), @To,   120)               AS DateTo,

        -- UngeneratedCollection = SDCollection ka sum
        ISNULL(col.UngeneratedCollection,    0)         AS UngeneratedCollection,

        -- UngeneratedCompanyExpense = CompanyExpensePosting (Head != SALARY) ka sum
        ISNULL(exp.UngeneratedCompanyExpense, 0)        AS UngeneratedCompanyExpense,

        -- UngeneratedStaffSalary = CompanyExpensePosting (Head = SALARY) ka sum
        ISNULL(sal.UngeneratedStaffSalary,   0)         AS UngeneratedStaffSalary

    FROM (
        -- All distinct SalonIds from both tables within date range
        SELECT DISTINCT SalonId FROM SDCollection
        WHERE ISNULL(IsDeleted,0)=0
          AND Date >= @From AND Date <= @To
          AND (@SalonId IS NULL OR SalonId = @SalonId)
        UNION
        SELECT DISTINCT SalonId FROM CompanyExpensePosting
        WHERE ISNULL(IsDeleted,0)=0
          AND Date >= @From AND Date <= @To
          AND (@SalonId IS NULL OR SalonId = @SalonId)
    ) ids
    INNER JOIN SalonMaster s ON s.Id  = ids.SalonId AND ISNULL(s.IsDeleted,0) = 0
    LEFT JOIN CTE_Collection    col ON col.SalonId = ids.SalonId
    LEFT JOIN CTE_CompanyExpense exp ON exp.SalonId = ids.SalonId
    LEFT JOIN CTE_StaffSalary    sal ON sal.SalonId = ids.SalonId

    ORDER BY s.Name;

END
GO

PRINT 'sp_GetSalonUngeneratedData created successfully.';
GO
