-- ============================================================
-- Script 026: Multi-Camp Support + SecurityDeposit Fix
-- - Create ContractCamps table for storing all selected camps
-- - Update sp_CreateContract to handle CampIdsJson + all params
-- - Update sp_UpdateContract to handle CampIdsJson + SecurityDeposit
-- - Backfill ContractCamps from existing Contracts.CampId
-- ============================================================

-- â”€â”€ Step 1: Create ContractCamps table (if not exists) â”€â”€â”€â”€â”€â”€â”€
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ContractCamps')
BEGIN
    CREATE TABLE ContractCamps (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        ContractId  NVARCHAR(450) NOT NULL,
        CampId      INT           NOT NULL,
        CreatedAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT FK_ContractCamps_Contract FOREIGN KEY (ContractId) REFERENCES Contracts(ContractId),
        CONSTRAINT FK_ContractCamps_Camp     FOREIGN KEY (CampId)     REFERENCES Camps(Id),
        CONSTRAINT UQ_ContractCamps          UNIQUE (ContractId, CampId)
    );
    PRINT 'ContractCamps table created.';
END
ELSE
    PRINT 'ContractCamps table already exists.';
GO

-- â”€â”€ Step 2: Backfill ContractCamps from existing Contracts â”€â”€â”€
INSERT INTO ContractCamps (ContractId, CampId)
SELECT c.ContractId, c.CampId
FROM Contracts c
WHERE c.CampId IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM ContractCamps cc
      WHERE cc.ContractId = c.ContractId AND cc.CampId = c.CampId
  );
PRINT 'ContractCamps backfilled from existing contracts.';
GO

-- â”€â”€ Step 3: Recreate sp_CreateContract with all params â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId              INT,
    @CampId                INT,
    @CampIdsJson           NVARCHAR(MAX) = NULL,   -- all selected camp IDs as JSON array
    @StartDate             DATE,
    @Months                INT,
    @RoomIdsJson           NVARCHAR(MAX),
    @SecurityDeposit       DECIMAL(18,2) = 0,
    @InstallmentType       NVARCHAR(MAX)  = 'monthly',
    @IssuedBy              NVARCHAR(MAX) = '',
    @Notes                 NVARCHAR(MAX) = '',
    @LessorAmount          DECIMAL(18,2) = 0,
    @MonthlyTotal          DECIMAL(18,2) = NULL,   -- override; NULL = calculate from rooms
    @ContractTotal         DECIMAL(18,2) = NULL,   -- override; NULL = monthly * months
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
    @NewContractId         NVARCHAR(MAX)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Generate ContractId
    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate      DATE          = DATEADD(MONTH, @Months, @StartDate);
    DECLARE @CalcMonthly  DECIMAL(18,2) = 0;

    -- Calculate monthly total from rooms if not overridden
    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
        SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
        FROM Rooms r
        JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    ELSE
        SET @CalcMonthly = @MonthlyTotal;

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    -- Insert contract
    INSERT INTO Contracts (
        ContractId, TenantId, CampId, StartDate, Months, EndDate,
        MonthlyTotal, ContractTotal, SecurityDeposit, InstallmentType,
        IssuedBy, Notes, LessorAmount,
        ContractPropertyUsage, ContractBuildingName, ContractPropertyType,
        ContractLocation, ContractPropertyNo, ContractPropertyArea,
        ContractPremisesNo, ContractPaymentMode, ContractPlotNo, ContractMakaniNo,
        Status, CreatedAt, UpdatedAt
    )
    VALUES (
        @NewContractId, @TenantId, @CampId, @StartDate, @Months, @EndDate,
        @CalcMonthly, @FinalTotal, @SecurityDeposit, @InstallmentType,
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

    -- Link all selected camps
    DECLARE @CampsToInsert NVARCHAR(MAX) = ISNULL(@CampIdsJson, '[' + CAST(@CampId AS NVARCHAR) + ']');
    INSERT INTO ContractCamps (ContractId, CampId)
    SELECT @NewContractId, CampId
    FROM OPENJSON(@CampsToInsert) WITH (CampId INT '$')
    WHERE NOT EXISTS (
        SELECT 1 FROM ContractCamps cc
        WHERE cc.ContractId = @NewContractId AND cc.CampId = CampId
    );

    -- Generate installments (one per month by default)
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i - 1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END
END
GO

-- â”€â”€ Step 4: Recreate sp_UpdateContract with SecurityDeposit + CampIds â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId NVARCHAR(450),
    @TenantId              INT           = NULL,
    @CampId                INT           = NULL,
    @CampIdsJson           NVARCHAR(MAX) = NULL,   -- all selected camp IDs as JSON array
    @StartDate             DATE          = NULL,
    @Months                INT           = NULL,
    @RoomIdsJson           NVARCHAR(MAX) = NULL,
    @SecurityDeposit       DECIMAL(18,2) = NULL,   -- â† was missing, caused 0 on update
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

    -- Load existing values
    DECLARE @ExTenantId       INT;
    DECLARE @ExCampId         INT;
    DECLARE @ExStartDate      DATE;
    DECLARE @ExMonths         INT;
    DECLARE @ExLessor         DECIMAL(18,2);
    DECLARE @ExSecurityDeposit DECIMAL(18,2);

    SELECT
        @ExTenantId        = TenantId,
        @ExCampId          = CampId,
        @ExStartDate       = StartDate,
        @ExMonths          = Months,
        @ExLessor          = LessorAmount,
        @ExSecurityDeposit = SecurityDeposit
    FROM Contracts WHERE ContractId = @ContractId;

    -- Recalculate monthly total if rooms changed
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
    DECLARE @FinalCampId   INT           = ISNULL(@CampId, @ExCampId);
    -- SecurityDeposit: use new value if explicitly provided, else keep existing
    DECLARE @FinalSecurity DECIMAL(18,2) = CASE WHEN @SecurityDeposit IS NOT NULL THEN @SecurityDeposit ELSE @ExSecurityDeposit END;

    -- Update contract row
    UPDATE Contracts SET
        TenantId               = ISNULL(@TenantId,              TenantId),
        CampId                 = @FinalCampId,
        StartDate              = @FinalStart,
        Months                 = @FinalMonths,
        EndDate                = @FinalEnd,
        MonthlyTotal           = @FinalMonthly,
        ContractTotal          = @FinalTotal,
        SecurityDeposit        = @FinalSecurity,
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

    -- Update rooms if new room list provided
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        -- Free old rooms
        UPDATE Rooms SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);

        DELETE FROM ContractRooms WHERE ContractId = @ContractId;

        -- Assign new rooms
        INSERT INTO ContractRooms (ContractId, RoomId)
        SELECT @ContractId, RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$');

        -- Mark new rooms occupied
        UPDATE Rooms SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$'));
    END

    -- Update ContractCamps if new camp list provided
    DECLARE @CampsJson NVARCHAR(MAX) = NULL;
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
        SET @CampsJson = @CampIdsJson;
    ELSE IF @CampId IS NOT NULL
        SET @CampsJson = '[' + CAST(@CampId AS NVARCHAR) + ']';

    IF @CampsJson IS NOT NULL
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId = @ContractId;
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @ContractId, CampId FROM OPENJSON(@CampsJson) WITH (CampId INT '$');
    END
END
GO

PRINT '=== Script 026 completed: ContractCamps table + SecurityDeposit + Multi-Camp SPs updated ===';

