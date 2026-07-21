-- ============================================================
-- 049: Fix sp_UpdatePaymentSchedule
--      1. Keep existing behavior (ContractInstallments update)
--      2. ADD: Regenerate ContractRoomInstallments based on new schedule
--         - Each installment splits proportionally across rooms
--         - Month name derived from DueDate
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdatePaymentSchedule
    @ContractId   NVARCHAR(MAX),
    @ScheduleJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── 1. Delete & recreate ContractInstallments ─────────────────────────
    DELETE FROM ContractInstallments WHERE ContractId = @ContractId;

    INSERT INTO ContractInstallments (
        ContractId, InstallmentNo, Amount, DueDate,
        PaidAmount, Status, PaymentMode, ChequeNumber, ClearanceDate
    )
    SELECT
        @ContractId,
        s.InstallmentNo,
        s.Amount,
        s.DueDate,
        0,
        'Pending',
        ISNULL(NULLIF(s.PaymentMode,   ''), 'Cash'),
        ISNULL(NULLIF(s.ChequeNumber,  ''), ''),
        ISNULL(NULLIF(s.ClearanceDate, ''), '')
    FROM OPENJSON(@ScheduleJson) WITH (
        InstallmentNo  INT            '$.no',
        Amount         DECIMAL(18,2)  '$.amount',
        DueDate        DATE           '$.dueDate',
        PaymentMode    NVARCHAR(50)   '$.mode',
        ChequeNumber   NVARCHAR(50)   '$.cheque',
        ClearanceDate  NVARCHAR(50)   '$.clearance'
    ) s;

    -- ── 2. Regenerate ContractRoomInstallments ─────────────────────────────
    -- Delete existing room installments for this contract
    DELETE FROM ContractRoomInstallments WHERE ContractId = @ContractId;

    -- Get contract info
    DECLARE @StartDate DATE, @Months INT;
    SELECT @StartDate = StartDate, @Months = Months
    FROM Contracts WHERE ContractId = @ContractId;

    -- Get total monthly amount from rooms
    DECLARE @TotalMonthly DECIMAL(18,2) = 0;
    SELECT @TotalMonthly = ISNULL(SUM(ISNULL(cr.MonthlyAmount, r.MonthlyPrice)), 0)
    FROM ContractRooms cr
    JOIN Rooms r ON r.Id = cr.RoomId
    WHERE cr.ContractId = @ContractId;

    IF @TotalMonthly = 0
        SELECT @TotalMonthly = ISNULL(MonthlyTotal, 0) FROM Contracts WHERE ContractId = @ContractId;

    -- For each installment in the new schedule, create room-wise rows
    -- Room's share = (room monthly amount / total monthly) * installment amount
    DECLARE @InstNo     INT;
    DECLARE @InstAmt    DECIMAL(18,2);
    DECLARE @DueDate    DATE;
    DECLARE @PayMode    NVARCHAR(50);
    DECLARE @ChequeNo   NVARCHAR(50);
    DECLARE @ClearDate  NVARCHAR(50);

    DECLARE inst_cursor CURSOR FOR
        SELECT
            s.InstallmentNo,
            s.Amount,
            s.DueDate,
            ISNULL(NULLIF(s.PaymentMode,  ''), 'Cash'),
            ISNULL(NULLIF(s.ChequeNumber, ''), ''),
            ISNULL(NULLIF(s.ClearanceDate,''), '')
        FROM OPENJSON(@ScheduleJson) WITH (
            InstallmentNo  INT            '$.no',
            Amount         DECIMAL(18,2)  '$.amount',
            DueDate        DATE           '$.dueDate',
            PaymentMode    NVARCHAR(50)   '$.mode',
            ChequeNumber   NVARCHAR(50)   '$.cheque',
            ClearanceDate  NVARCHAR(50)   '$.clearance'
        ) s;

    OPEN inst_cursor;
    FETCH NEXT FROM inst_cursor INTO @InstNo, @InstAmt, @DueDate, @PayMode, @ChequeNo, @ClearDate;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Month name from DueDate
        DECLARE @MonthName NVARCHAR(10) =
            CASE MONTH(@DueDate)
                WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
            END;

        -- Insert room-wise rows for this installment
        INSERT INTO ContractRoomInstallments (
            ContractId, CampId, CampName, RoomId, RoomNo,
            InstallmentNo, InstallAmount, DueDate, Month,
            PaymentMode, ReferenceNo, ClearanceDate,
            Status, PaidAmount, PaidDate,
            CreatedAt, UpdatedAt
        )
        SELECT
            @ContractId,
            ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId = cr.ContractId ORDER BY cc.Id), 0),
            ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc2 JOIN Camps ca ON ca.Id = cc2.CampId WHERE cc2.ContractId = cr.ContractId ORDER BY cc2.Id), ''),
            cr.RoomId,
            r.RoomNo,
            @InstNo,
            -- Room's proportional share of this installment amount
            CASE
                WHEN @TotalMonthly > 0
                THEN ROUND(ISNULL(cr.MonthlyAmount, r.MonthlyPrice) / @TotalMonthly * @InstAmt, 2)
                ELSE ROUND(@InstAmt / NULLIF((SELECT COUNT(*) FROM ContractRooms WHERE ContractId = @ContractId), 0), 2)
            END,
            @DueDate,
            @MonthName,
            @PayMode,
            @ChequeNo,
            CASE WHEN @ClearDate = '' THEN NULL ELSE TRY_CAST(@ClearDate AS DATE) END,
            'Pending',
            0,
            NULL,
            GETDATE(),
            GETDATE()
        FROM ContractRooms cr
        JOIN Rooms r ON r.Id = cr.RoomId
        WHERE cr.ContractId = @ContractId;

        FETCH NEXT FROM inst_cursor INTO @InstNo, @InstAmt, @DueDate, @PayMode, @ChequeNo, @ClearDate;
    END

    CLOSE inst_cursor;
    DEALLOCATE inst_cursor;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '049 - sp_UpdatePaymentSchedule fixed: ContractRoomInstallments updated with proportional room amounts';
GO
