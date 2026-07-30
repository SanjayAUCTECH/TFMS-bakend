-- ============================================================
-- 119: sp_UpdateContract — Safe Update Pattern
-- Rule: If any payment exists → skip rooms/installments
--       If no payment → delete + fresh insert
-- Output: @PaymentStarted = 1 (locked) / 0 (updated)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId            NVARCHAR(MAX),
    @TenantId              INT           = NULL,
    @StartDate             DATE          = NULL,
    @Months                INT           = NULL,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @ContractType          NVARCHAR(MAX) = NULL,
    @RoomIdsJson           NVARCHAR(MAX) = NULL,
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
    @ContractMakaniNo      NVARCHAR(MAX) = NULL,
    @UpdatedBy             INT           = NULL,
    @PaymentStarted        BIT           = 0 OUTPUT  -- 1=locked, 0=updated
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Check if any payment has been received ────────────────
    SET @PaymentStarted = 0;

    IF EXISTS (
        SELECT 1 FROM TxnRecords
        WHERE ContractId=@ContractId AND TxnType='CR' AND ISNULL(IsDeleted,0)=0
    )
    OR EXISTS (
        SELECT 1 FROM ContractInstallments
        WHERE ContractId=@ContractId AND PaidAmount>0 AND ISNULL(IsDeleted,0)=0
    )
    OR EXISTS (
        SELECT 1 FROM ContractRooms
        WHERE ContractId=@ContractId AND PaidAmount>0 AND ISNULL(IsDeleted,0)=0
    )
    OR EXISTS (
        SELECT 1 FROM ContractRoomsTrns
        WHERE ContractId=@ContractId AND TxnType='CR'
    )
        SET @PaymentStarted = 1;

    -- ── 1. Contracts — always update (basic fields) ───────────
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
        UpdatedBy             = @UpdatedBy,
        UpdatedAt             = GETUTCDATE()
    WHERE ContractId=@ContractId AND IsDeleted=0;

    -- ── 2. ContractCamps — always update ─────────────────────
    IF @CampIdsJson IS NOT NULL AND @CampIdsJson<>'[]' AND @CampIdsJson<>'null'
    BEGIN
        DELETE FROM ContractCamps WHERE ContractId=@ContractId;
        INSERT INTO ContractCamps(ContractId, CampId)
        SELECT @ContractId, CAST([value] AS INT) FROM OPENJSON(@CampIdsJson);
    END

    -- ── 3. Rooms/Installments — only if NO payment ───────────
    IF @PaymentStarted = 0
    AND @RoomIdsJson IS NOT NULL AND @RoomIdsJson<>'[]' AND @RoomIdsJson<>'null'
    AND LOWER(@RoomIdsJson) LIKE '%"roomid"%'
    BEGIN
        -- Get effective months
        DECLARE @EffMonths INT = ISNULL(@Months, (SELECT Months FROM Contracts WHERE ContractId=@ContractId));
        DECLARE @EffStart  DATE = ISNULL(@StartDate, (SELECT StartDate FROM Contracts WHERE ContractId=@ContractId));
        DECLARE @EffSD     DECIMAL(18,2) = ISNULL(@SecurityDeposit, (SELECT SecurityDeposit FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0));
        DECLARE @EffMT     DECIMAL(18,2) = ISNULL(NULLIF(@MonthlyTotal,0), (SELECT MonthlyTotal FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0));

        -- Parse new rooms
        CREATE TABLE #NewRooms (RoomId INT, MonthlyAmount DECIMAL(18,2), CampId INT);
        INSERT INTO #NewRooms
        SELECT j.roomId,
               ISNULL(j.monthlyAmount, r.MonthlyPrice),
               ISNULL(j.campId, r.CampId)
        FROM OPENJSON(@RoomIdsJson) WITH(roomId INT '$.roomId', campId INT '$.campId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount') j
        JOIN Rooms r ON r.Id=j.roomId;

        -- Mark OLD rooms vacant (rooms not in new list)
        UPDATE Rooms SET Occupied=0, Status='Vacant', UpdatedAt=GETUTCDATE()
        WHERE Id IN (
            SELECT cr.RoomId FROM ContractRooms cr
            WHERE cr.ContractId=@ContractId AND ISNULL(cr.IsDeleted,0)=0
              AND cr.RoomId NOT IN (SELECT RoomId FROM #NewRooms)
        ) AND IsDeleted=0;

        -- Mark NEW rooms occupied
        UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM #NewRooms) AND IsDeleted=0;

        -- Delete old ContractRooms, ContractInstallments, ContractRoomInstallments
        DELETE FROM ContractRoomInstallments WHERE ContractId=@ContractId;
        DELETE FROM ContractRooms WHERE ContractId=@ContractId;
        DELETE FROM ContractInstallments WHERE ContractId=@ContractId;

        -- Security per room
        DECLARE @RoomCnt   INT           = (SELECT COUNT(*) FROM #NewRooms);
        DECLARE @PerRoomSD DECIMAL(18,2) = CASE WHEN @RoomCnt>0 THEN ROUND(@EffSD/@RoomCnt,2) ELSE 0 END;
        DECLARE @LastRoomSD DECIMAL(18,2)= @EffSD - (@PerRoomSD * (@RoomCnt-1));

        -- Insert new ContractRooms with security
        ;WITH RR AS (SELECT RoomId, MonthlyAmount, CampId, ROW_NUMBER() OVER(ORDER BY RoomId) AS RowNum FROM #NewRooms)
        INSERT INTO ContractRooms(ContractId, RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance,
            SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate, AddedBy, IsDeleted)
        SELECT @ContractId, RoomId, CampId, MonthlyAmount, MonthlyAmount*@EffMonths, 0, MonthlyAmount*@EffMonths,
            CASE WHEN RowNum=@RoomCnt THEN @LastRoomSD ELSE @PerRoomSD END,
            0,
            CASE WHEN RowNum=@RoomCnt THEN @LastRoomSD ELSE @PerRoomSD END,
            NULL, @UpdatedBy, 0
        FROM RR;

        -- Insert new ContractInstallments
        DECLARE @ci INT=1;
        WHILE @ci<=@EffMonths
        BEGIN
            INSERT INTO ContractInstallments(ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
            VALUES(@ContractId, @ci, @EffMT, DATEADD(MONTH,@ci-1,@EffStart), 0, 'Pending');
            SET @ci+=1;
        END

        -- Regenerate ContractRoomInstallments
        EXEC sp_GenerateContractRoomInstallments @ContractId;

        DROP TABLE #NewRooms;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#NewRooms') IS NOT NULL DROP TABLE #NewRooms;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_UpdateContract - Safe update pattern with payment lock';
GO
