-- ============================================================
-- 121: Update sp_UpdateContract
-- Change: SecurityAmount per room = 5% of room TotalAmount
--         SecurityDeposit on Contracts = SUM of room SecurityAmounts
--         (same logic as sp_CreateContract script 120)
--
-- Rule:
--   Per room:
--     TotalAmount       = MonthlyAmount × Months
--     SecurityAmount    = ROUND(TotalAmount × 5%, 2)
--     SecurityDueAmount = SecurityAmount
--
--   Contracts:
--     SecurityDeposit   = SUM of all room SecurityAmounts (auto)
--
-- Note: @SecurityDeposit param kept for backward compatibility but ignored
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId            NVARCHAR(450),
    @TenantId              INT           = NULL,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @StartDate             DATE          = NULL,
    @Months                INT           = NULL,
    @RoomIdsJson           NVARCHAR(MAX) = NULL,
    @ContractType          NVARCHAR(50)  = NULL,
    @SecurityDeposit       DECIMAL(18,2) = NULL,   -- kept for compat, ignored
    @LessorAmount          DECIMAL(18,2) = NULL,
    @Notes                 NVARCHAR(MAX) = NULL,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(200) = NULL,
    @ContractBuildingName  NVARCHAR(200) = NULL,
    @ContractPropertyType  NVARCHAR(100) = NULL,
    @ContractLocation      NVARCHAR(200) = NULL,
    @ContractPropertyNo    NVARCHAR(100) = NULL,
    @ContractPropertyArea  NVARCHAR(100) = NULL,
    @ContractPremisesNo    NVARCHAR(100) = NULL,
    @ContractPaymentMode   NVARCHAR(100) = NULL,
    @ContractPlotNo        NVARCHAR(100) = NULL,
    @ContractMakaniNo      NVARCHAR(100) = NULL,
    @UpdatedBy             INT           = NULL,
    @PaymentStarted        BIT           = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Read existing contract values ──────────────────────────────────────
    DECLARE @ExTenantId        INT;
    DECLARE @ExStartDate       DATE;
    DECLARE @ExMonths          INT;
    DECLARE @ExLessor          DECIMAL(18,2);
    DECLARE @ExSecurityDeposit DECIMAL(18,2);
    DECLARE @ExContractType    NVARCHAR(50);

    SELECT
        @ExTenantId        = TenantId,
        @ExStartDate       = StartDate,
        @ExMonths          = Months,
        @ExLessor          = LessorAmount,
        @ExSecurityDeposit = SecurityDeposit,
        @ExContractType    = ContractType
    FROM Contracts WHERE ContractId = @ContractId;

    -- ── Resolve final values ───────────────────────────────────────────────
    DECLARE @FinalMonths       INT           = ISNULL(@Months,      @ExMonths);
    DECLARE @FinalStart        DATE          = ISNULL(@StartDate,   @ExStartDate);
    DECLARE @FinalEnd          DATE          = DATEADD(MONTH, @FinalMonths, @FinalStart);
    DECLARE @FinalContractType NVARCHAR(50)  = ISNULL(@ContractType, @ExContractType);

    -- ── Parse rooms if provided ────────────────────────────────────────────
    DECLARE @RoomsProvided BIT = 0;
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
        SET @RoomsProvided = 1;

    -- ── Calculate monthly total ────────────────────────────────────────────
    DECLARE @FinalMonthly DECIMAL(18,2);

    IF @RoomsProvided = 1
    BEGIN
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            -- Rich JSON: use monthlyAmount from payload
            SELECT @FinalMonthly = ISNULL(SUM(
                CASE WHEN j.monthlyAmount > 0 THEN j.monthlyAmount ELSE r.MonthlyPrice END
            ), 0)
            FROM OPENJSON(@RoomIdsJson) WITH (
                roomId        INT           '$.roomId',
                monthlyAmount DECIMAL(18,2) '$.monthlyAmount'
            ) j
            JOIN Rooms r ON r.Id = j.roomId;
        ELSE
            -- Simple JSON [id, id, ...]
            SELECT @FinalMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
            FROM Rooms r
            JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    END
    ELSE
        SET @FinalMonthly = ISNULL(@MonthlyTotal, 0);

    IF @FinalMonthly = 0
        SET @FinalMonthly = ISNULL(@MonthlyTotal, 0);

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @FinalMonths);

    -- ── Calculate SecurityDeposit = SUM of 5% of each room TotalAmount ────
    DECLARE @CalcSecurityDeposit DECIMAL(18,2) = 0;

    IF @RoomsProvided = 1
    BEGIN
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            SELECT @CalcSecurityDeposit = ISNULL(SUM(
                ROUND(
                    CASE WHEN j.monthlyAmount > 0 THEN j.monthlyAmount ELSE r.MonthlyPrice END
                    * @FinalMonths * 0.05
                , 2)
            ), 0)
            FROM OPENJSON(@RoomIdsJson) WITH (
                roomId        INT           '$.roomId',
                monthlyAmount DECIMAL(18,2) '$.monthlyAmount'
            ) j
            JOIN Rooms r ON r.Id = j.roomId;
        ELSE
            SELECT @CalcSecurityDeposit = ISNULL(SUM(
                ROUND(r.MonthlyPrice * @FinalMonths * 0.05, 2)
            ), 0)
            FROM Rooms r
            JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    END
    ELSE
        -- Rooms not changed — keep existing SecurityDeposit
        SET @CalcSecurityDeposit = @ExSecurityDeposit;

    -- ── UPDATE Contracts ───────────────────────────────────────────────────
    UPDATE Contracts SET
        TenantId               = ISNULL(@TenantId,              TenantId),
        StartDate              = @FinalStart,
        Months                 = @FinalMonths,
        EndDate                = @FinalEnd,
        MonthlyTotal           = @FinalMonthly,
        ContractTotal          = @FinalTotal,
        SecurityDeposit        = @CalcSecurityDeposit,   -- ← 5% auto-calc
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

    -- ── Update Rooms & ContractRooms if rooms changed ──────────────────────
    IF @RoomsProvided = 1
    BEGIN
        -- Mark old rooms vacant
        UPDATE Rooms SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);

        -- Remove old room links
        DELETE FROM ContractRooms WHERE ContractId = @ContractId;

        -- Insert new ContractRooms WITH SecurityAmount = 5% of TotalAmount
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
        BEGIN
            ;WITH RoomRanked AS (
                SELECT
                    j.roomId AS RoomId,
                    ISNULL(j.campId, r.CampId) AS CampId,
                    CASE WHEN j.monthlyAmount > 0
                         THEN j.monthlyAmount
                         ELSE r.MonthlyPrice
                    END AS MonthlyAmt
                FROM OPENJSON(@RoomIdsJson) WITH (
                    roomId        INT           '$.roomId',
                    monthlyAmount DECIMAL(18,2) '$.monthlyAmount',
                    campId        INT           '$.campId'
                ) j
                JOIN Rooms r ON r.Id = j.roomId
            )
            INSERT INTO ContractRooms (
                ContractId, RoomId, CampId,
                MonthlyAmount, TotalAmount, PaidAmount, Balance,
                SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate,
                IsDeleted
            )
            SELECT
                @ContractId,
                rr.RoomId,
                rr.CampId,
                rr.MonthlyAmt,
                rr.MonthlyAmt * @FinalMonths,                    -- TotalAmount
                0,                                               -- PaidAmount
                rr.MonthlyAmt * @FinalMonths,                    -- Balance
                ROUND(rr.MonthlyAmt * @FinalMonths * 0.05, 2),  -- SecurityAmount = 5%
                0,                                               -- SecurityPaidAmount
                ROUND(rr.MonthlyAmt * @FinalMonths * 0.05, 2),  -- SecurityDueAmount = 5%
                NULL,                                            -- SecurityPaidDate
                0
            FROM RoomRanked rr;
        END
        ELSE
        BEGIN
            -- Simple JSON [id, id] — use Rooms.MonthlyPrice
            INSERT INTO ContractRooms (
                ContractId, RoomId, CampId,
                MonthlyAmount, TotalAmount, PaidAmount, Balance,
                SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate,
                IsDeleted
            )
            SELECT
                @ContractId,
                r.Id,
                r.CampId,
                r.MonthlyPrice,
                r.MonthlyPrice * @FinalMonths,
                0,
                r.MonthlyPrice * @FinalMonths,
                ROUND(r.MonthlyPrice * @FinalMonths * 0.05, 2),
                0,
                ROUND(r.MonthlyPrice * @FinalMonths * 0.05, 2),
                NULL,
                0
            FROM Rooms r
            JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
        END

        -- Mark new rooms occupied
        UPDATE Rooms SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
        WHERE Id IN (
            SELECT CAST([value] AS INT) FROM OPENJSON(@RoomIdsJson)
            WHERE ISJSON(@RoomIdsJson) = 1
              AND LOWER(@RoomIdsJson) NOT LIKE '%"roomid"%'
            UNION ALL
            SELECT j.roomId FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId') j
            WHERE LOWER(@RoomIdsJson) LIKE '%"roomid"%'
        );
    END

    -- ── Update ContractCamps if camps changed ──────────────────────────────
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId = @ContractId;
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @ContractId, CampId FROM OPENJSON(@CampIdsJson) WITH (CampId INT '$');
    END

    -- ── Regenerate ContractInstallments (only if no payment received yet) ──
    -- Check if any installment has been paid
    DECLARE @HasPayments BIT = 0;
    IF EXISTS (SELECT 1 FROM ContractInstallments WHERE ContractId=@ContractId AND PaidAmount>0 AND ISNULL(IsDeleted,0)=0)
        SET @HasPayments = 1;

    IF @HasPayments = 0
    BEGIN
        -- Safe to regenerate — no payments made yet
        DELETE FROM ContractInstallments WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0;

        DECLARE @ci INT = 1;
        WHILE @ci <= @FinalMonths
        BEGIN
            INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status, IsDeleted)
            VALUES (@ContractId, @ci, @FinalMonthly, DATEADD(MONTH, @ci - 1, @FinalStart), 0, 'Pending', 0);
            SET @ci += 1;
        END
    END
    ELSE
        SET @PaymentStarted = 1;

    -- ── Regenerate room-wise installments ─────────────────────────────────
    EXEC sp_GenerateContractRoomInstallments @ContractId;

    SET @PaymentStarted = ISNULL(@PaymentStarted, 0);
END
GO

PRINT '✅ 121 - sp_UpdateContract: SecurityAmount = 5% of room TotalAmount (auto-calculated)';
GO
