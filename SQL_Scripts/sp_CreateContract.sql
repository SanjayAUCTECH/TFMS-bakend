SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId              INT,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @StartDate             DATE,
    @Months                INT,
    @RoomIdsJson           NVARCHAR(MAX),
    @ContractType          NVARCHAR(MAX)  = 'Monthly',
    @SecurityDeposit       DECIMAL(18,2) = 0,   -- ✅ NOW USED — from API payload
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
    @AddedBy               INT           = NULL,
    @NewContractId         NVARCHAR(450) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Generate new ContractId ────────────────────────────────────────────
    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST(
        (SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate DATE = DATEADD(MONTH, @Months, @StartDate);

    -- ── Parse RoomIds JSON → temp table ───────────────────────────────────
    CREATE TABLE #ParsedRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL, CampId INT NULL);

    IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
    BEGIN
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT j.roomId, j.monthlyAmount, j.campId
        FROM OPENJSON(@RoomIdsJson) WITH (
            roomId        INT            '$.roomId',
            monthlyAmount DECIMAL(18,2)  '$.monthlyAmount',
            campId        INT            '$.campId'
        ) j;
    END
    ELSE
    BEGIN
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT CAST([value] AS INT), NULL, NULL FROM OPENJSON(@RoomIdsJson);
    END

    -- Fill missing CampId from Rooms table
    UPDATE pr
    SET pr.CampId = r.CampId
    FROM #ParsedRooms pr
    JOIN Rooms r ON r.Id = pr.RoomId
    WHERE pr.CampId IS NULL;

    -- ── Calculate MonthlyTotal ─────────────────────────────────────────────
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
    BEGIN
        SELECT @CalcMonthly = ISNULL(SUM(
            CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
                 THEN pr.MonthlyAmount
                 ELSE r.MonthlyPrice
            END), 0)
        FROM #ParsedRooms pr
        JOIN Rooms r ON r.Id = pr.RoomId;
    END
    ELSE
        SET @CalcMonthly = @MonthlyTotal;

    DECLARE @TotalContractAmt DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    -- ══════════════════════════════════════════════════════════════════════
    -- SECURITY DEPOSIT — from API payload (@SecurityDeposit)
    -- Contract me @SecurityDeposit as-is save hoga.
    -- ContractRooms me equally distribute hoga (SD / total rooms).
    -- ══════════════════════════════════════════════════════════════════════
    DECLARE @RoomCount INT = (SELECT COUNT(*) FROM #ParsedRooms);
    IF @RoomCount = 0 SET @RoomCount = 1;   -- divide-by-zero guard

    -- Per-room SD (equal split, rounded to 2 decimals)
    DECLARE @PerRoomSD DECIMAL(18,2) = ROUND(@SecurityDeposit / @RoomCount, 2);

    -- ── INSERT Contracts ───────────────────────────────────────────────────
    INSERT INTO Contracts (
        ContractId, TenantId, StartDate, EndDate, Months,
        ContractType, SecurityDeposit, SecurityDepositStatus,
        InstallmentType, IssuedBy, Notes, LessorAmount,
        MonthlyTotal, ContractTotal,
        ContractPropertyUsage, ContractBuildingName, ContractPropertyType,
        ContractLocation, ContractPropertyNo, ContractPropertyArea,
        ContractPremisesNo, ContractPaymentMode, ContractPlotNo, ContractMakaniNo,
        Status, IsDeleted, AddedBy, CreatedAt, UpdatedAt
    )
    VALUES (
        @NewContractId, @TenantId, @StartDate, @EndDate, @Months,
        @ContractType,
        @SecurityDeposit,       -- ✅ API payload se as-is
        'Pending',
        @InstallmentType, @IssuedBy, @Notes, @LessorAmount,
        @CalcMonthly, @TotalContractAmt,
        @ContractPropertyUsage, @ContractBuildingName, @ContractPropertyType,
        @ContractLocation, @ContractPropertyNo, @ContractPropertyArea,
        @ContractPremisesNo, @ContractPaymentMode, @ContractPlotNo, @ContractMakaniNo,
        'Active', 0, @AddedBy, GETUTCDATE(), GETUTCDATE()
    );

    -- ── INSERT ContractRooms (SecurityAmount = equal split of @SecurityDeposit) ──
    ;WITH RoomRanked AS (
        SELECT
            pr.RoomId,
            ISNULL(pr.CampId, r.CampId) AS CampId,
            CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
                 THEN pr.MonthlyAmount
                 ELSE r.MonthlyPrice
            END AS MonthlyAmt,
            ROW_NUMBER() OVER (ORDER BY pr.RoomId) AS RowNum
        FROM #ParsedRooms pr
        JOIN Rooms r ON r.Id = pr.RoomId
    )
    INSERT INTO ContractRooms (
        ContractId, RoomId, CampId,
        MonthlyAmount, TotalAmount, PaidAmount, Balance,
        SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate,
        AddedBy, IsDeleted
    )
    SELECT
        @NewContractId,
        rr.RoomId,
        rr.CampId,
        rr.MonthlyAmt,                              -- monthly rent
        rr.MonthlyAmt * @Months,                    -- TotalAmount
        0,                                          -- PaidAmount
        rr.MonthlyAmt * @Months,                    -- Balance = TotalAmount
        -- SecurityAmount: equal split; last room gets remainder to match total exactly
        CASE WHEN rr.RowNum = @RoomCount
             THEN @SecurityDeposit - (@PerRoomSD * (@RoomCount - 1))
             ELSE @PerRoomSD
        END,
        0,                                          -- SecurityPaidAmount
        -- SecurityDueAmount = SecurityAmount
        CASE WHEN rr.RowNum = @RoomCount
             THEN @SecurityDeposit - (@PerRoomSD * (@RoomCount - 1))
             ELSE @PerRoomSD
        END,
        NULL,                                       -- SecurityPaidDate
        @AddedBy,
        0
    FROM RoomRanked rr;

    -- ── Mark selected rooms as Occupied ───────────────────────────────────
    UPDATE Rooms
    SET Occupied  = 1,
        Status    = 'Occupied',
        UpdatedAt = GETUTCDATE()
    WHERE Id IN (SELECT RoomId FROM #ParsedRooms);

    -- ── INSERT ContractCamps ───────────────────────────────────────────────
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

    -- ── INSERT ContractInstallments (one row per month) ───────────────────
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i - 1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END

    -- ── Generate room-wise installments ───────────────────────────────────
    EXEC sp_GenerateContractRoomInstallments @NewContractId;

    DROP TABLE #ParsedRooms;
END;
GO

PRINT 'sp_CreateContract updated: SecurityDeposit from payload + equal split per room.';
GO
