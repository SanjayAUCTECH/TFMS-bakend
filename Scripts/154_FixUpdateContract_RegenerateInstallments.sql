-- ============================================================
-- 154: Fix sp_UpdateContract — Regenerate ContractInstallments
-- 
-- BUG: Contract edit karne pe ContractRoomInstallments regenerate
--      hoti thi but ContractInstallments (main monthly) NAHI hoti thi.
--      Agar StartDate ya Months change karo toh purani dates rehti thi.
--
-- FIX: Agar koi payment nahi hui (PaidAmount=0 on all), toh:
--      1. DELETE old ContractInstallments
--      2. Re-INSERT with correct dates from new StartDate
--
--      Agar payment ho chuki hai: installments change NAHI hongi
--      (safety — paid data lose nahi hoga)
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
    @SecurityDeposit       DECIMAL(18,2) = NULL,
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
    DECLARE @ExTenantId INT, @ExStartDate DATE, @ExMonths INT,
            @ExLessor DECIMAL(18,2), @ExSecurityDeposit DECIMAL(18,2), @ExContractType NVARCHAR(50);

    SELECT @ExTenantId=TenantId, @ExStartDate=StartDate, @ExMonths=Months,
           @ExLessor=LessorAmount, @ExSecurityDeposit=SecurityDeposit, @ExContractType=ContractType
    FROM Contracts WHERE ContractId=@ContractId;

    -- ── Resolve final values ───────────────────────────────────────────────
    DECLARE @FinalMonths INT = ISNULL(@Months, @ExMonths);
    DECLARE @FinalStart DATE = ISNULL(@StartDate, @ExStartDate);
    DECLARE @FinalEnd DATE = DATEADD(MONTH, @FinalMonths, @FinalStart);
    DECLARE @FinalContractType NVARCHAR(50) = ISNULL(@ContractType, @ExContractType);

    -- ── Parse rooms ────────────────────────────────────────────────────────
    DECLARE @RoomsProvided BIT = 0;
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
        SET @RoomsProvided = 1;

    -- ── Calculate monthly total ────────────────────────────────────────────
    DECLARE @FinalMonthly DECIMAL(18,2) = 0;

    IF @RoomsProvided = 1
    BEGIN
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            SELECT @FinalMonthly = ISNULL(SUM(
                CASE WHEN j.monthlyAmount > 0 THEN j.monthlyAmount ELSE r.MonthlyPrice END
            ), 0)
            FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount') j
            JOIN Rooms r ON r.Id = j.roomId;
        ELSE
            SELECT @FinalMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
            FROM Rooms r JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    END
    ELSE
        SET @FinalMonthly = ISNULL(@MonthlyTotal, 0);

    IF @FinalMonthly = 0
        SET @FinalMonthly = ISNULL(@MonthlyTotal, 0);

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @FinalMonths);

    -- ── Calculate SecurityDeposit = 5% per room ────────────────────────────
    DECLARE @CalcSecurityDeposit DECIMAL(18,2) = 0;
    IF @RoomsProvided = 1
    BEGIN
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
            SELECT @CalcSecurityDeposit = ISNULL(SUM(ROUND(
                CASE WHEN j.monthlyAmount > 0 THEN j.monthlyAmount ELSE r.MonthlyPrice END * @FinalMonths * 0.05, 2)), 0)
            FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount') j
            JOIN Rooms r ON r.Id = j.roomId;
        ELSE
            SELECT @CalcSecurityDeposit = ISNULL(SUM(ROUND(r.MonthlyPrice * @FinalMonths * 0.05, 2)), 0)
            FROM Rooms r JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
    END
    ELSE
        SET @CalcSecurityDeposit = @ExSecurityDeposit;

    -- ── UPDATE Contracts ───────────────────────────────────────────────────
    UPDATE Contracts SET
        TenantId=ISNULL(@TenantId, TenantId), StartDate=@FinalStart,
        Months=@FinalMonths, EndDate=@FinalEnd,
        MonthlyTotal=@FinalMonthly, ContractTotal=@FinalTotal,
        SecurityDeposit=@CalcSecurityDeposit, ContractType=@FinalContractType,
        LessorAmount=ISNULL(@LessorAmount, LessorAmount),
        Notes=ISNULL(@Notes, Notes),
        ContractPropertyUsage=ISNULL(@ContractPropertyUsage, ContractPropertyUsage),
        ContractBuildingName=ISNULL(@ContractBuildingName, ContractBuildingName),
        ContractPropertyType=ISNULL(@ContractPropertyType, ContractPropertyType),
        ContractLocation=ISNULL(@ContractLocation, ContractLocation),
        ContractPropertyNo=ISNULL(@ContractPropertyNo, ContractPropertyNo),
        ContractPropertyArea=ISNULL(@ContractPropertyArea, ContractPropertyArea),
        ContractPremisesNo=ISNULL(@ContractPremisesNo, ContractPremisesNo),
        ContractPaymentMode=ISNULL(@ContractPaymentMode, ContractPaymentMode),
        ContractPlotNo=ISNULL(@ContractPlotNo, ContractPlotNo),
        ContractMakaniNo=ISNULL(@ContractMakaniNo, ContractMakaniNo),
        UpdatedAt=GETUTCDATE()
    WHERE ContractId=@ContractId;

    -- ── Update Rooms & ContractRooms if rooms changed ──────────────────────
    IF @RoomsProvided = 1
    BEGIN
        UPDATE Rooms SET Occupied=0, Status='Vacant', UpdatedAt=GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId=@ContractId);

        DELETE FROM ContractRooms WHERE ContractId=@ContractId;

        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
        BEGIN
            INSERT INTO ContractRooms(ContractId,RoomId,CampId,MonthlyAmount,TotalAmount,PaidAmount,Balance,
                SecurityAmount,SecurityPaidAmount,SecurityDueAmount,SecurityPaidDate,IsDeleted)
            SELECT @ContractId, j.roomId, ISNULL(j.campId, r.CampId),
                CASE WHEN j.monthlyAmount>0 THEN j.monthlyAmount ELSE r.MonthlyPrice END,
                CASE WHEN j.monthlyAmount>0 THEN j.monthlyAmount ELSE r.MonthlyPrice END * @FinalMonths,
                0, CASE WHEN j.monthlyAmount>0 THEN j.monthlyAmount ELSE r.MonthlyPrice END * @FinalMonths,
                ROUND((CASE WHEN j.monthlyAmount>0 THEN j.monthlyAmount ELSE r.MonthlyPrice END * @FinalMonths) * 0.05, 2),
                0, ROUND((CASE WHEN j.monthlyAmount>0 THEN j.monthlyAmount ELSE r.MonthlyPrice END * @FinalMonths) * 0.05, 2),
                NULL, 0
            FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount', campId INT '$.campId') j
            JOIN Rooms r ON r.Id = j.roomId;
        END
        ELSE
        BEGIN
            INSERT INTO ContractRooms(ContractId,RoomId,CampId,MonthlyAmount,TotalAmount,PaidAmount,Balance,
                SecurityAmount,SecurityPaidAmount,SecurityDueAmount,SecurityPaidDate,IsDeleted)
            SELECT @ContractId, r.Id, r.CampId, r.MonthlyPrice, r.MonthlyPrice*@FinalMonths,
                0, r.MonthlyPrice*@FinalMonths,
                ROUND(r.MonthlyPrice*@FinalMonths*0.05, 2), 0, ROUND(r.MonthlyPrice*@FinalMonths*0.05, 2), NULL, 0
            FROM Rooms r JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;
        END

        UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE()
        WHERE Id IN (
            SELECT CAST([value] AS INT) FROM OPENJSON(@RoomIdsJson)
            WHERE ISJSON(@RoomIdsJson)=1 AND LOWER(@RoomIdsJson) NOT LIKE '%"roomid"%'
            UNION ALL
            SELECT j.roomId FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId') j
            WHERE LOWER(@RoomIdsJson) LIKE '%"roomid"%'
        );
    END

    -- ── Update ContractCamps ───────────────────────────────────────────────
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId=@ContractId;
        INSERT INTO ContractCamps(ContractId, CampId)
        SELECT @ContractId, CampId FROM OPENJSON(@CampIdsJson) WITH (CampId INT '$');
    END

    -- ══════════════════════════════════════════════════════════════
    -- ★★★ FIX: Regenerate ContractInstallments (main monthly) ★★★
    -- Only if NO payment has been made yet
    -- ══════════════════════════════════════════════════════════════
    DECLARE @HasPayments BIT = 0;
    IF EXISTS (SELECT 1 FROM ContractInstallments
               WHERE ContractId=@ContractId AND PaidAmount>0 AND ISNULL(IsDeleted,0)=0)
        SET @HasPayments = 1;

    IF @HasPayments = 0
    BEGIN
        -- Safe to regenerate — no payments made yet
        DELETE FROM ContractInstallments WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0;

        DECLARE @ci INT = 1;
        WHILE @ci <= @FinalMonths
        BEGIN
            INSERT INTO ContractInstallments(ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status, IsDeleted)
            VALUES(@ContractId, @ci, @FinalMonthly, DATEADD(MONTH, @ci-1, @FinalStart), 0, 'Pending', 0);
            SET @ci += 1;
        END
    END
    ELSE
        SET @HasPayments = 1;

    -- ── Regenerate room-wise installments ─────────────────────────────────
    IF @HasPayments = 0
        EXEC sp_GenerateContractRoomInstallments @ContractId;

    SET @PaymentStarted = @HasPayments;
END
GO

PRINT '✅ 154 - sp_UpdateContract FIXED!';
PRINT '   ContractInstallments now regenerate on edit (if no payment made).';
PRINT '   DueDate = DATEADD(MONTH, InstallmentNo-1, StartDate)';
PRINT '   First installment = StartDate month (May = May, not June)';
GO
