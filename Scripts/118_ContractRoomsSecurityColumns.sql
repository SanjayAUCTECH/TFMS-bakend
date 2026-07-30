-- ============================================================
-- 118: Update sp_CreateContract
-- Changes:
--   1. ContractRooms: add SecurityAmount (evenly distributed)
--   2. ContractRooms: SecurityDueAmount = SecurityAmount
--   3. ContractRooms: SecurityPaidAmount = 0, SecurityPaidDate = NULL
--   4. ContractRooms: AddedBy = @AddedBy
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Helper: Get room count for even distribution
-- SecurityAmount per room = ROUND(TotalSecurity / RoomCount, 2)
-- Last room gets remainder to avoid rounding issues

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
    @AddedBy INT = NULL, @NewContractId NVARCHAR(450) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @EndDate DATE = DATEADD(MONTH, @Months, @StartDate);

    -- Parse RoomIds
    CREATE TABLE #ParsedRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL, CampId INT NULL);

    IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
    BEGIN
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT j.roomId, j.monthlyAmount, j.campId
        FROM OPENJSON(@RoomIdsJson) WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount', campId INT '$.campId') j;
    END
    ELSE
    BEGIN
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT CAST([value] AS INT), NULL, NULL FROM OPENJSON(@RoomIdsJson);
    END

    -- Resolve CampId
    UPDATE pr SET pr.CampId = r.CampId FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId WHERE pr.CampId IS NULL;

    -- Calculate monthly total
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
    BEGIN
        SELECT @CalcMonthly = ISNULL(SUM(CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0 THEN pr.MonthlyAmount ELSE r.MonthlyPrice END), 0)
        FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId;
    END
    ELSE SET @CalcMonthly = @MonthlyTotal;

    DECLARE @TotalContractAmt DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    -- Insert Contract
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
        @ContractType, @SecurityDeposit, 'Pending',
        @InstallmentType, @IssuedBy, @Notes, @LessorAmount,
        @CalcMonthly, @TotalContractAmt,
        @ContractPropertyUsage, @ContractBuildingName, @ContractPropertyType,
        @ContractLocation, @ContractPropertyNo, @ContractPropertyArea,
        @ContractPremisesNo, @ContractPaymentMode, @ContractPlotNo, @ContractMakaniNo,
        'Active', 0, @AddedBy, GETUTCDATE(), GETUTCDATE()
    );

    -- ── Security per room calculation ──────────────────────────
    DECLARE @RoomCount     INT           = (SELECT COUNT(*) FROM #ParsedRooms);
    DECLARE @PerRoomSec    DECIMAL(18,2) = CASE WHEN @RoomCount > 0 THEN ROUND(@SecurityDeposit / @RoomCount, 2) ELSE 0 END;
    DECLARE @LastRoomSec   DECIMAL(18,2) = @SecurityDeposit - (@PerRoomSec * (@RoomCount - 1));  -- remainder goes to last room

    -- Insert ContractRooms with security columns + AddedBy
    ;WITH RoomRanked AS (
        SELECT
            pr.RoomId,
            ISNULL(pr.CampId, r.CampId)  AS CampId,
            CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0 THEN pr.MonthlyAmount ELSE r.MonthlyPrice END AS MonthlyAmt,
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
        rr.MonthlyAmt,
        rr.MonthlyAmt * @Months,
        0,
        rr.MonthlyAmt * @Months,
        -- SecurityAmount: last room gets remainder
        CASE WHEN rr.RowNum = @RoomCount THEN @LastRoomSec ELSE @PerRoomSec END,
        0,   -- SecurityPaidAmount
        -- SecurityDueAmount = SecurityAmount
        CASE WHEN rr.RowNum = @RoomCount THEN @LastRoomSec ELSE @PerRoomSec END,
        NULL, -- SecurityPaidDate
        @AddedBy,
        0
    FROM RoomRanked rr;

    -- Mark rooms occupied
    UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE()
    WHERE Id IN (SELECT RoomId FROM #ParsedRooms);

    -- Link camps
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
    BEGIN
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @NewContractId, CAST([value] AS INT) FROM OPENJSON(@CampIdsJson)
        WHERE NOT EXISTS (SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=@NewContractId AND cc.CampId=CAST([value] AS INT));
    END
    ELSE
    BEGIN
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT DISTINCT @NewContractId, ISNULL(pr.CampId, r.CampId)
        FROM #ParsedRooms pr JOIN Rooms r ON r.Id=pr.RoomId
        WHERE ISNULL(pr.CampId, r.CampId) > 0
          AND NOT EXISTS (SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=@NewContractId AND cc.CampId=ISNULL(pr.CampId,r.CampId));
    END

    -- Generate monthly installments
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i-1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END

    -- Generate room-wise installments
    EXEC sp_GenerateContractRoomInstallments @NewContractId;

    DROP TABLE #ParsedRooms;
END
GO

PRINT '✅ sp_CreateContract updated: SecurityAmount distributed, AddedBy set in ContractRooms';
GO
