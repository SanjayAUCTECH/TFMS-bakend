-- ============================================================
-- 051: Fix sp_CreateContract — ContractRooms INSERT
--      Add: CampId, TotalAmount (monthlyAmount × months), Balance
-- Date: July 21, 2026
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

    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate DATE = DATEADD(MONTH, @Months, @StartDate);

    -- ── Parse RoomIds — support BOTH formats ─────────────────────────────────
    CREATE TABLE #ParsedRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL, CampId INT NULL);

    IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
    BEGIN
        -- Rich format: [{"roomId":442,"monthlyAmount":1200,"campId":62},...]
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT j.roomId, j.monthlyAmount, j.campId
        FROM OPENJSON(@RoomIdsJson)
        WITH (
            roomId        INT            '$.roomId',
            monthlyAmount DECIMAL(18,2)  '$.monthlyAmount',
            campId        INT            '$.campId'
        ) j;
    END
    ELSE
    BEGIN
        -- Simple format: [442, 443, ...]
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT CAST([value] AS INT), NULL, NULL
        FROM OPENJSON(@RoomIdsJson);
    END

    -- ── Resolve CampId for rooms that don't have it in JSON ──────────────────
    -- Use room's own CampId from Rooms table as fallback
    UPDATE pr SET pr.CampId = r.CampId
    FROM #ParsedRooms pr
    JOIN Rooms r ON r.Id = pr.RoomId
    WHERE pr.CampId IS NULL;

    -- ── Calculate monthly total ───────────────────────────────────────────────
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;

    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
    BEGIN
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

    -- ── Link rooms — with CampId, TotalAmount, Balance ───────────────────────
    INSERT INTO ContractRooms (ContractId, RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance)
    SELECT
        @NewContractId,
        pr.RoomId,
        -- CampId: from JSON or from Rooms table
        ISNULL(pr.CampId, r.CampId),
        -- MonthlyAmount: from JSON or from Rooms.MonthlyPrice
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
             THEN pr.MonthlyAmount
             ELSE r.MonthlyPrice
        END,
        -- TotalAmount = monthlyAmount × months
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
             THEN pr.MonthlyAmount * @Months
             ELSE r.MonthlyPrice * @Months
        END,
        -- PaidAmount = 0 (nothing paid yet)
        0,
        -- Balance = TotalAmount (unpaid)
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
             THEN pr.MonthlyAmount * @Months
             ELSE r.MonthlyPrice * @Months
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
    ELSE
    BEGIN
        -- Auto-link camps from rooms if CampIdsJson not provided
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT DISTINCT @NewContractId, ISNULL(pr.CampId, r.CampId)
        FROM #ParsedRooms pr
        JOIN Rooms r ON r.Id = pr.RoomId
        WHERE ISNULL(pr.CampId, r.CampId) > 0
          AND NOT EXISTS (
            SELECT 1 FROM ContractCamps cc
            WHERE cc.ContractId = @NewContractId
              AND cc.CampId = ISNULL(pr.CampId, r.CampId)
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

PRINT '051 - sp_CreateContract fixed: ContractRooms now saves CampId, TotalAmount, Balance correctly';
GO
