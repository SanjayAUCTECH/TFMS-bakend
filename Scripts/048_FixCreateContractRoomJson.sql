-- ============================================================
-- 048: Fix sp_CreateContract — handle both RoomIds JSON formats
--      Format 1 (simple):  [442, 443]
--      Format 2 (rich):    [{"roomId":442,"monthlyAmount":1200},...]
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

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

    -- Generate contract ID
    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate DATE = DATEADD(MONTH, @Months, @StartDate);

    -- ── Parse RoomIds — support BOTH formats ─────────────────────────────────
    -- Create temp table to hold parsed rooms
    CREATE TABLE #ParsedRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL);

    -- Detect format: if JSON contains "roomId" key → rich format, else simple array
    IF LOWER(@RoomIdsJson) LIKE '%"roomid"%' OR LOWER(@RoomIdsJson) LIKE '%"roomId"%'
    BEGIN
        -- Rich format: [{"roomId":442,"monthlyAmount":1200},...]
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount)
        SELECT
            j.roomId,
            j.monthlyAmount
        FROM OPENJSON(@RoomIdsJson)
        WITH (
            roomId        INT            '$.roomId',
            monthlyAmount DECIMAL(18,2)  '$.monthlyAmount'
        ) j;
    END
    ELSE
    BEGIN
        -- Simple format: [442, 443, ...]
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount)
        SELECT CAST([value] AS INT), NULL
        FROM OPENJSON(@RoomIdsJson);
    END

    -- ── Calculate monthly total ───────────────────────────────────────────────
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;

    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
    BEGIN
        -- Use per-room monthly amounts if provided, else use Rooms.MonthlyPrice
        SELECT @CalcMonthly = ISNULL(SUM(
            CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
                 THEN pr.MonthlyAmount
                 ELSE r.MonthlyPrice
            END
        ), 0)
        FROM #ParsedRooms pr
        JOIN Rooms r ON r.Id = pr.RoomId;
    END
    ELSE
        SET @CalcMonthly = @MonthlyTotal;

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    -- ── Insert contract ───────────────────────────────────────────────────────
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

    -- ── Link rooms (with per-room monthly amount) ─────────────────────────────
    INSERT INTO ContractRooms (ContractId, RoomId, MonthlyAmount)
    SELECT
        @NewContractId,
        pr.RoomId,
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
             THEN pr.MonthlyAmount
             ELSE r.MonthlyPrice
        END
    FROM #ParsedRooms pr
    JOIN Rooms r ON r.Id = pr.RoomId;

    -- ── Mark rooms occupied ───────────────────────────────────────────────────
    UPDATE Rooms
    SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
    WHERE Id IN (SELECT RoomId FROM #ParsedRooms);

    -- ── Link camps ────────────────────────────────────────────────────────────
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @NewContractId, CAST([value] AS INT)
        FROM OPENJSON(@CampIdsJson)
        WHERE NOT EXISTS (
            SELECT 1 FROM ContractCamps cc
            WHERE cc.ContractId = @NewContractId
              AND cc.CampId = CAST([value] AS INT)
        );
    END

    -- ── Generate monthly installments ─────────────────────────────────────────
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i - 1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END

    -- ── Auto-generate room-wise installments ──────────────────────────────────
    EXEC sp_GenerateContractRoomInstallments @NewContractId;

    DROP TABLE #ParsedRooms;
END
GO

PRINT '048 - sp_CreateContract fixed: handles both simple [id] and rich [{roomId,monthlyAmount}] JSON formats';
GO
