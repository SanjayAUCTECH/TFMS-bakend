-- ============================================================
-- Script 027: Remove CampId from Contracts + Add ContractType
-- ContractType: 'Monthly' | 'Scheduled'
--   Monthly   = monthly installments (equal payments each month)
--   Scheduled = custom payment schedule (flexible amounts/dates)
-- ============================================================

-- ── Step 1: Drop FK on Contracts.CampId ─────────────────────
IF EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK__Contracts__CampI__59904A2C'
      AND OBJECT_NAME(parent_object_id) = 'Contracts'
)
BEGIN
    ALTER TABLE Contracts DROP CONSTRAINT FK__Contracts__CampI__59904A2C;
    PRINT 'FK on CampId dropped.';
END
ELSE
BEGIN
    -- Try generic drop by searching
    DECLARE @fkName NVARCHAR(MAX);
    SELECT @fkName = fk.name
    FROM sys.foreign_keys fk
    JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
    JOIN sys.columns col ON col.object_id = fkc.parent_object_id AND col.column_id = fkc.parent_column_id
    WHERE OBJECT_NAME(fk.parent_object_id) = 'Contracts' AND col.name = 'CampId';

    IF @fkName IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE Contracts DROP CONSTRAINT ' + @fkName);
        PRINT 'FK on CampId dropped (dynamic).';
    END
    ELSE
        PRINT 'No FK on CampId found - skipping.';
END
GO

-- ── Step 2: Drop CampId column from Contracts ───────────────
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Contracts' AND COLUMN_NAME = 'CampId'
)
BEGIN
    ALTER TABLE Contracts DROP COLUMN CampId;
    PRINT 'CampId column removed from Contracts.';
END
ELSE
    PRINT 'CampId column already removed.';
GO

-- ── Step 3: Add ContractType column ─────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Contracts' AND COLUMN_NAME = 'ContractType'
)
BEGIN
    ALTER TABLE Contracts
    ADD ContractType NVARCHAR(MAX) NOT NULL DEFAULT 'Monthly';
    PRINT 'ContractType column added (default: Monthly).';
END
ELSE
    PRINT 'ContractType column already exists.';
GO

-- ── Step 4: Update sp_GetContracts — remove CampId ref ──────
-- (This SP uses CampId from Contracts for filtering — now use ContractCamps join)
CREATE OR ALTER PROCEDURE sp_GetContracts
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX)  = NULL,
    @SortDirection NVARCHAR(MAX)   = 'ASC',
    @Status        NVARCHAR(MAX)  = NULL,
    @TenantId      INT           = NULL,
    @CampId        INT           = NULL,
    @DateFrom      NVARCHAR(MAX)  = NULL,
    @DateTo        NVARCHAR(MAX)  = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(DISTINCT c.Id)
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId = c.ContractId
    WHERE (@Status    IS NULL OR c.Status    = @Status)
      AND (@TenantId  IS NULL OR c.TenantId  = @TenantId)
      AND (@CampId    IS NULL OR cc.CampId   = @CampId)
      AND (@DateFrom  IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo    IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL
           OR t.Name        LIKE '%' + @SearchText + '%'
           OR c.ContractId  LIKE '%' + @SearchText + '%');

    SELECT DISTINCT
        c.Id, c.ContractId, c.TenantId,
        t.Name                                       TenantName,
        -- Primary camp from ContractCamps
        ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = c.ContractId ORDER BY Id), 0)         CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id = cc2.CampId WHERE cc2.ContractId = c.ContractId ORDER BY cc2.Id), '')  CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)  SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.ContractType, 'Monthly')    ContractType,
        ISNULL(c.IssuedBy, '')        IssuedBy,
        ISNULL(c.Notes, '')           Notes,
        ISNULL(c.LessorAmount, 0)     LessorAmount,
        c.Status,
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0)  TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount  FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId = c.ContractId
    WHERE (@Status    IS NULL OR c.Status    = @Status)
      AND (@TenantId  IS NULL OR c.TenantId  = @TenantId)
      AND (@CampId    IS NULL OR cc.CampId   = @CampId)
      AND (@DateFrom  IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo    IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL
           OR t.Name        LIKE '%' + @SearchText + '%'
           OR c.ContractId  LIKE '%' + @SearchText + '%')
    ORDER BY c.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Step 5: Update sp_GetContractById ───────────────────────
CREATE OR ALTER PROCEDURE sp_GetContractById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.Id, c.ContractId, c.TenantId,
        t.Name TenantName,
        ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = c.ContractId ORDER BY Id), 0)        CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id = cc2.CampId WHERE cc2.ContractId = c.ContractId ORDER BY cc2.Id), '') CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)  SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.ContractType, 'Monthly')    ContractType,
        ISNULL(c.IssuedBy, '')   IssuedBy,
        ISNULL(c.Notes,   '')    Notes,
        ISNULL(c.LessorAmount, 0) LessorAmount,
        c.Status,
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0)  TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount   FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt,
        -- Room columns (joined per row)
        cr.RoomId,
        -- Payment columns
        ci.Id PayId, ci.InstallmentNo, ci.Amount PayAmount,
        ci.DueDate, ci.PaidAmount, ci.PaidDate, ci.Status PayStatus,
        ISNULL(ci.PaymentMode,    '') PaymentMode,
        ISNULL(ci.ChequeNumber,   '') ChequeNumber,
        ISNULL(ci.ClearanceDate,  '') ClearanceDate
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId = c.ContractId
    LEFT JOIN ContractInstallments ci ON ci.ContractId = c.ContractId
    WHERE c.Id = @Id
    ORDER BY ci.InstallmentNo;
END
GO

-- ── Step 6: Update sp_GetContractByContractId ────────────────
CREATE OR ALTER PROCEDURE sp_GetContractByContractId
    @ContractId NVARCHAR(450)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.Id, c.ContractId, c.TenantId,
        t.Name TenantName,
        ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = c.ContractId ORDER BY Id), 0)        CampId,
        ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id = cc2.CampId WHERE cc2.ContractId = c.ContractId ORDER BY cc2.Id), '') CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)  SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.ContractType, 'Monthly')    ContractType,
        ISNULL(c.IssuedBy, '')   IssuedBy,
        ISNULL(c.Notes,   '')    Notes,
        ISNULL(c.LessorAmount, 0) LessorAmount,
        c.Status,
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0)  TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount   FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt,
        cr.RoomId,
        ci.Id PayId, ci.InstallmentNo, ci.Amount PayAmount,
        ci.DueDate, ci.PaidAmount, ci.PaidDate, ci.Status PayStatus,
        ISNULL(ci.PaymentMode,    '') PaymentMode,
        ISNULL(ci.ChequeNumber,   '') ChequeNumber,
        ISNULL(ci.ClearanceDate,  '') ClearanceDate
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId = c.ContractId
    LEFT JOIN ContractInstallments ci ON ci.ContractId = c.ContractId
    WHERE c.ContractId = @ContractId
    ORDER BY ci.InstallmentNo;
END
GO

-- ── Step 7: Update sp_CreateContract — remove CampId, add ContractType ──
CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId              INT,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @StartDate             DATE,
    @Months                INT,
    @RoomIdsJson           NVARCHAR(MAX),
    @ContractType          NVARCHAR(MAX)  = 'Monthly',
    @SecurityDeposit       DECIMAL(18,2) = 0,
    @InstallmentType       NVARCHAR(MAX)  = 'monthly',
    @IssuedBy              NVARCHAR(MAX) = '',
    @Notes                 NVARCHAR(MAX) = '',
    @LessorAmount          DECIMAL(18,2) = 0,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(MAX) = '',
    @ContractBuildingName  NVARCHAR(MAX) = '',
    @ContractPropertyType  NVARCHAR(MAX) = '',
    @ContractLocation      NVARCHAR(MAX) = '',
    @ContractPropertyNo    NVARCHAR(MAX) = '',
    @ContractPropertyArea  NVARCHAR(MAX) = '',
    @ContractPremisesNo    NVARCHAR(MAX) = '',
    @ContractPaymentMode   NVARCHAR(MAX) = '',
    @ContractPlotNo        NVARCHAR(MAX) = '',
    @ContractMakaniNo      NVARCHAR(MAX) = '',
    @NewContractId         NVARCHAR(450) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate     DATE          = DATEADD(MONTH, @Months, @StartDate);
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;

    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
        SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
        FROM Rooms r
        JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    ELSE
        SET @CalcMonthly = @MonthlyTotal;

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    INSERT INTO Contracts (
        ContractId, TenantId, StartDate, Months, EndDate,
        MonthlyTotal, ContractTotal, SecurityDeposit,
        ContractType, InstallmentType,
        IssuedBy, Notes, LessorAmount,
        ContractPropertyUsage, ContractBuildingName, ContractPropertyType,
        ContractLocation, ContractPropertyNo, ContractPropertyArea,
        ContractPremisesNo, ContractPaymentMode, ContractPlotNo, ContractMakaniNo,
        Status, CreatedAt, UpdatedAt
    )
    VALUES (
        @NewContractId, @TenantId, @StartDate, @Months, @EndDate,
        @CalcMonthly, @FinalTotal, @SecurityDeposit,
        @ContractType, @InstallmentType,
        @IssuedBy, @Notes, @LessorAmount,
        @ContractPropertyUsage, @ContractBuildingName, @ContractPropertyType,
        @ContractLocation, @ContractPropertyNo, @ContractPropertyArea,
        @ContractPremisesNo, @ContractPaymentMode, @ContractPlotNo, @ContractMakaniNo,
        'Active', GETUTCDATE(), GETUTCDATE()
    );

    -- Link rooms
    INSERT INTO ContractRooms (ContractId, RoomId)
    SELECT @NewContractId, RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$');

    -- Mark rooms occupied
    UPDATE Rooms SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
    WHERE Id IN (SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$'));

    -- Link camps from CampIdsJson
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @NewContractId, CampId
        FROM OPENJSON(@CampIdsJson) WITH (CampId INT '$')
        WHERE NOT EXISTS (
            SELECT 1 FROM ContractCamps cc
            WHERE cc.ContractId = @NewContractId AND cc.CampId = CampId
        );
    END

    -- Generate monthly installments
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i - 1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END
END
GO

-- ── Step 8: Update sp_UpdateContract — remove CampId, add ContractType ──
CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId            NVARCHAR(450),
    @TenantId              INT           = NULL,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @StartDate             DATE          = NULL,
    @Months                INT           = NULL,
    @RoomIdsJson           NVARCHAR(MAX) = NULL,
    @ContractType          NVARCHAR(MAX)  = NULL,
    @SecurityDeposit       DECIMAL(18,2) = NULL,
    @LessorAmount          DECIMAL(18,2) = NULL,
    @Notes                 NVARCHAR(MAX) = NULL,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(MAX) = NULL,
    @ContractBuildingName  NVARCHAR(MAX) = NULL,
    @ContractPropertyType  NVARCHAR(MAX) = NULL,
    @ContractLocation      NVARCHAR(MAX) = NULL,
    @ContractPropertyNo    NVARCHAR(MAX) = NULL,
    @ContractPropertyArea  NVARCHAR(MAX) = NULL,
    @ContractPremisesNo    NVARCHAR(MAX) = NULL,
    @ContractPaymentMode   NVARCHAR(MAX) = NULL,
    @ContractPlotNo        NVARCHAR(MAX) = NULL,
    @ContractMakaniNo      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExTenantId        INT;
    DECLARE @ExStartDate       DATE;
    DECLARE @ExMonths          INT;
    DECLARE @ExLessor          DECIMAL(18,2);
    DECLARE @ExSecurityDeposit DECIMAL(18,2);
    DECLARE @ExContractType    NVARCHAR(MAX);

    SELECT
        @ExTenantId        = TenantId,
        @ExStartDate       = StartDate,
        @ExMonths          = Months,
        @ExLessor          = LessorAmount,
        @ExSecurityDeposit = SecurityDeposit,
        @ExContractType    = ContractType
    FROM Contracts WHERE ContractId = @ContractId;

    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
        SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
        FROM Rooms r
        JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;

    DECLARE @FinalMonths   INT           = ISNULL(@Months,       @ExMonths);
    DECLARE @FinalStart    DATE          = ISNULL(@StartDate,    @ExStartDate);
    DECLARE @FinalMonthly  DECIMAL(18,2) = ISNULL(@MonthlyTotal, @CalcMonthly);
    DECLARE @FinalTotal    DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @FinalMonths);
    DECLARE @FinalEnd      DATE          = DATEADD(MONTH, @FinalMonths, @FinalStart);
    DECLARE @FinalSecurity DECIMAL(18,2) = CASE WHEN @SecurityDeposit IS NOT NULL THEN @SecurityDeposit ELSE @ExSecurityDeposit END;
    DECLARE @FinalContractType NVARCHAR(MAX) = ISNULL(@ContractType, @ExContractType);

    UPDATE Contracts SET
        TenantId               = ISNULL(@TenantId,              TenantId),
        StartDate              = @FinalStart,
        Months                 = @FinalMonths,
        EndDate                = @FinalEnd,
        MonthlyTotal           = @FinalMonthly,
        ContractTotal          = @FinalTotal,
        SecurityDeposit        = @FinalSecurity,
        ContractType           = @FinalContractType,
        LessorAmount           = ISNULL(@LessorAmount,          LessorAmount),
        Notes                  = ISNULL(@Notes,                 Notes),
        ContractPropertyUsage  = ISNULL(@ContractPropertyUsage, ContractPropertyUsage),
        ContractBuildingName   = ISNULL(@ContractBuildingName,  ContractBuildingName),
        ContractPropertyType   = ISNULL(@ContractPropertyType,  ContractPropertyType),
        ContractLocation       = ISNULL(@ContractLocation,      ContractLocation),
        ContractPropertyNo     = ISNULL(@ContractPropertyNo,    ContractPropertyNo),
        ContractPropertyArea   = ISNULL(@ContractPropertyArea,  ContractPropertyArea),
        ContractPremisesNo     = ISNULL(@ContractPremisesNo,    ContractPremisesNo),
        ContractPaymentMode    = ISNULL(@ContractPaymentMode,   ContractPaymentMode),
        ContractPlotNo         = ISNULL(@ContractPlotNo,        ContractPlotNo),
        ContractMakaniNo       = ISNULL(@ContractMakaniNo,      ContractMakaniNo),
        UpdatedAt              = GETUTCDATE()
    WHERE ContractId = @ContractId;

    -- Update rooms
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        UPDATE Rooms SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);
        DELETE FROM ContractRooms WHERE ContractId = @ContractId;
        INSERT INTO ContractRooms (ContractId, RoomId)
        SELECT @ContractId, RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$');
        UPDATE Rooms SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$'));
    END

    -- Update camps
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId = @ContractId;
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @ContractId, CampId FROM OPENJSON(@CampIdsJson) WITH (CampId INT '$');
    END
END
GO

PRINT '=== Script 027 completed: CampId removed, ContractType added, SPs updated ===';
