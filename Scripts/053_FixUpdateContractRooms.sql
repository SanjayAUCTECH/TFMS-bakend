-- ============================================================
-- 053: Fix sp_UpdateContract — ContractRooms INSERT
--      Support both JSON formats, save CampId/TotalAmount/Balance
-- Date: July 21, 2026
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
    @ContractType          NVARCHAR(MAX) = NULL,
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

    -- Calculate monthly from new rooms if provided
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            SELECT @CalcMonthly = ISNULL(SUM(
                CASE WHEN j.monthlyAmount IS NOT NULL AND j.monthlyAmount > 0
                     THEN j.monthlyAmount ELSE r.MonthlyPrice END
            ), 0)
            FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount') j
            JOIN Rooms r ON r.Id = j.roomId;
        ELSE
            SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
            FROM Rooms r
            JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    END

    DECLARE @FinalMonths   INT           = ISNULL(@Months,       @ExMonths);
    DECLARE @FinalStart    DATE          = ISNULL(@StartDate,    @ExStartDate);
    DECLARE @FinalMonthly  DECIMAL(18,2) = ISNULL(@MonthlyTotal, @CalcMonthly);
    DECLARE @FinalTotal    DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @FinalMonths);
    DECLARE @FinalEnd      DATE          = DATEADD(MONTH, @FinalMonths, @FinalStart);
    DECLARE @FinalSecurity DECIMAL(18,2) = CASE WHEN @SecurityDeposit IS NOT NULL THEN @SecurityDeposit ELSE @ExSecurityDeposit END;
    DECLARE @FinalContractType NVARCHAR(MAX) = ISNULL(@ContractType, @ExContractType);

    -- Update contract main record
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

    -- Update rooms (if provided)
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        -- Free old rooms
        UPDATE Rooms SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);

        DELETE FROM ContractRooms WHERE ContractId = @ContractId;

        -- Parse both JSON formats into temp table
        CREATE TABLE #UpdRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL, CampId INT NULL);

        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            INSERT INTO #UpdRooms (RoomId, MonthlyAmount, CampId)
            SELECT j.roomId, j.monthlyAmount, j.campId
            FROM OPENJSON(@RoomIdsJson)
            WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount', campId INT '$.campId') j;
        ELSE
            INSERT INTO #UpdRooms (RoomId, MonthlyAmount, CampId)
            SELECT CAST([value] AS INT), NULL, NULL FROM OPENJSON(@RoomIdsJson);

        -- Resolve CampId from Rooms table where not provided
        UPDATE ur SET ur.CampId = r.CampId
        FROM #UpdRooms ur JOIN Rooms r ON r.Id = ur.RoomId
        WHERE ur.CampId IS NULL;

        -- Insert ContractRooms with all columns
        INSERT INTO ContractRooms (ContractId, RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance)
        SELECT
            @ContractId,
            ur.RoomId,
            ISNULL(ur.CampId, r.CampId),
            CASE WHEN ur.MonthlyAmount IS NOT NULL AND ur.MonthlyAmount > 0 THEN ur.MonthlyAmount ELSE r.MonthlyPrice END,
            CASE WHEN ur.MonthlyAmount IS NOT NULL AND ur.MonthlyAmount > 0 THEN ur.MonthlyAmount * @FinalMonths ELSE r.MonthlyPrice * @FinalMonths END,
            0,
            CASE WHEN ur.MonthlyAmount IS NOT NULL AND ur.MonthlyAmount > 0 THEN ur.MonthlyAmount * @FinalMonths ELSE r.MonthlyPrice * @FinalMonths END
        FROM #UpdRooms ur JOIN Rooms r ON r.Id = ur.RoomId;

        DROP TABLE #UpdRooms;

        -- Mark new rooms occupied
        UPDATE Rooms SET Occupied = 1, Status = 'Occupied', UpdatedAt = GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);
    END

    -- Update camps
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId = @ContractId;
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @ContractId, CAST([value] AS INT) FROM OPENJSON(@CampIdsJson);
    END

    -- Regenerate room-wise installments
    EXEC sp_GenerateContractRoomInstallments @ContractId;
END
GO

PRINT '053 - sp_UpdateContract fixed: ContractRooms with CampId/TotalAmount/Balance, both JSON formats supported';
GO
