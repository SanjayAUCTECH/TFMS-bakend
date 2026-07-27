USE TFMS_TestSoftwareDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId            NVARCHAR(MAX),
    @TenantId              INT=NULL,
    @StartDate             DATE=NULL,
    @Months                INT=NULL,
    @CampIdsJson           NVARCHAR(MAX)=NULL,
    @ContractType          NVARCHAR(MAX)=NULL,
    @RoomIdsJson           NVARCHAR(MAX)=NULL,
    @SecurityDeposit       DECIMAL(18,2)=NULL,
    @LessorAmount          DECIMAL(18,2)=NULL,
    @Notes                 NVARCHAR(MAX)=NULL,
    @MonthlyTotal          DECIMAL(18,2)=NULL,
    @ContractTotal         DECIMAL(18,2)=NULL,
    @ContractPropertyUsage NVARCHAR(MAX)=NULL,
    @ContractBuildingName  NVARCHAR(MAX)=NULL,
    @ContractPropertyType  NVARCHAR(MAX)=NULL,
    @ContractLocation      NVARCHAR(MAX)=NULL,
    @ContractPropertyNo    NVARCHAR(MAX)=NULL,
    @ContractPropertyArea  NVARCHAR(MAX)=NULL,
    @ContractPremisesNo    NVARCHAR(MAX)=NULL,
    @ContractPaymentMode   NVARCHAR(MAX)=NULL,
    @ContractPlotNo        NVARCHAR(MAX)=NULL,
    @ContractMakaniNo      NVARCHAR(MAX)=NULL,
    @UpdatedBy             INT=NULL
AS BEGIN
    SET NOCOUNT ON;

    UPDATE Contracts SET
        TenantId              = ISNULL(@TenantId, TenantId),
        StartDate             = ISNULL(@StartDate, StartDate),
        Months                = ISNULL(@Months, Months),
        EndDate               = CASE WHEN @StartDate IS NOT NULL AND @Months IS NOT NULL
                                     THEN DATEADD(MONTH, @Months, @StartDate)
                                     ELSE EndDate END,
        ContractType          = ISNULL(@ContractType, ContractType),
        SecurityDeposit       = ISNULL(@SecurityDeposit, SecurityDeposit),
        LessorAmount          = ISNULL(@LessorAmount, LessorAmount),
        Notes                 = ISNULL(@Notes, Notes),
        MonthlyTotal          = CASE WHEN @MonthlyTotal > 0 THEN @MonthlyTotal ELSE MonthlyTotal END,
        ContractTotal         = CASE WHEN @ContractTotal > 0 THEN @ContractTotal ELSE ContractTotal END,
        ContractPropertyUsage = ISNULL(@ContractPropertyUsage, ContractPropertyUsage),
        ContractBuildingName  = ISNULL(@ContractBuildingName, ContractBuildingName),
        ContractPropertyType  = ISNULL(@ContractPropertyType, ContractPropertyType),
        ContractLocation      = ISNULL(@ContractLocation, ContractLocation),
        ContractPropertyNo    = ISNULL(@ContractPropertyNo, ContractPropertyNo),
        ContractPropertyArea  = ISNULL(@ContractPropertyArea, ContractPropertyArea),
        ContractPremisesNo    = ISNULL(@ContractPremisesNo, ContractPremisesNo),
        ContractPaymentMode   = ISNULL(@ContractPaymentMode, ContractPaymentMode),
        ContractPlotNo        = ISNULL(@ContractPlotNo, ContractPlotNo),
        ContractMakaniNo      = ISNULL(@ContractMakaniNo, ContractMakaniNo),
        UpdatedAt             = GETUTCDATE()
    WHERE ContractId = @ContractId AND IsDeleted = 0;

    -- Update ContractCamps if CampIdsJson provided
    IF @CampIdsJson IS NOT NULL AND @CampIdsJson <> '[]' AND @CampIdsJson <> 'null'
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId = @ContractId;
        INSERT INTO ContractCamps(ContractId, CampId)
        SELECT @ContractId, CAST([value] AS INT)
        FROM OPENJSON(@CampIdsJson)
        WHERE NOT EXISTS (
            SELECT 1 FROM ContractCamps cc
            WHERE cc.ContractId = @ContractId AND cc.CampId = CAST([value] AS INT)
        );
    END

    -- Update ContractRooms if RoomIdsJson provided (rich format with amounts)
    IF @RoomIdsJson IS NOT NULL AND @RoomIdsJson <> '[]' AND @RoomIdsJson <> 'null'
    BEGIN
        -- Handle rich format with roomId, monthlyAmount, campId
        IF LOWER(@RoomIdsJson) LIKE '%"roomid"%' OR LOWER(@RoomIdsJson) LIKE '%"roomId"%'
        BEGIN
            -- Add new rooms not already in ContractRooms
            INSERT INTO ContractRooms(ContractId, RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance)
            SELECT @ContractId, j.roomId,
                ISNULL(j.campId, r.CampId),
                ISNULL(j.monthlyAmount, r.MonthlyPrice),
                ISNULL(j.monthlyAmount, r.MonthlyPrice) * ISNULL(@Months, 12),
                0,
                ISNULL(j.monthlyAmount, r.MonthlyPrice) * ISNULL(@Months, 12)
            FROM OPENJSON(@RoomIdsJson) WITH(
                roomId INT '$.roomId', campId INT '$.campId',
                monthlyAmount DECIMAL(18,2) '$.monthlyAmount') j
            JOIN Rooms r ON r.Id = j.roomId
            WHERE NOT EXISTS(SELECT 1 FROM ContractRooms cr WHERE cr.ContractId=@ContractId AND cr.RoomId=j.roomId);
        END
    END
END
GO
PRINT 'sp_UpdateContract FIXED - all params match repository';
GO
