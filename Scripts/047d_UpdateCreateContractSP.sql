-- ============================================================
-- 047d: Update sp_CreateContract & sp_UpdateContract
--       Add call to sp_GenerateContractRoomInstallments
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

    -- Link camps
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

    -- Generate monthly installments (ContractInstallments)
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i - 1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END

    -- ✅ Auto-generate room-wise installments (ContractRoomInstallments)
    EXEC sp_GenerateContractRoomInstallments @NewContractId;
END
GO

PRINT '047d - sp_CreateContract updated with room installment generation.';
GO
