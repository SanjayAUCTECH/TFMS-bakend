-- ============================================================
-- 050: Fix Month column format — Jun → Jun26, Feb27 etc.
--      sp_GenerateContractRoomInstallments
--      sp_UpdatePaymentSchedule
-- Date: July 21, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. Fix sp_GenerateContractRoomInstallments ────────────────
CREATE OR ALTER PROCEDURE sp_GenerateContractRoomInstallments
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM ContractRoomInstallments WHERE ContractId = @ContractId;

    DECLARE @StartDate DATE, @Months INT;
    SELECT @StartDate = StartDate, @Months = Months
    FROM Contracts WHERE ContractId = @ContractId;

    IF @StartDate IS NULL OR @Months IS NULL OR @Months <= 0
    BEGIN ROLLBACK TRANSACTION; RETURN; END

    DECLARE @RoomId INT, @RoomNo NVARCHAR(MAX), @MonthlyAmount DECIMAL(18,2);
    DECLARE @CampId INT, @CampName NVARCHAR(MAX);

    DECLARE room_cursor CURSOR FOR
        SELECT
            cr.RoomId,
            r.RoomNo,
            ISNULL(cr.MonthlyAmount, r.MonthlyPrice) MonthlyAmount,
            ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId=cr.ContractId ORDER BY cc.Id), 0) CampId,
            ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc JOIN Camps ca ON ca.Id=cc.CampId WHERE cc.ContractId=cr.ContractId ORDER BY cc.Id), '') CampName
        FROM ContractRooms cr
        JOIN Rooms r ON r.Id = cr.RoomId
        WHERE cr.ContractId = @ContractId;

    OPEN room_cursor;
    FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmount, @CampId, @CampName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @i INT = 1;
        WHILE @i <= @Months
        BEGIN
            DECLARE @DueDate DATE = DATEADD(MONTH, @i - 1, @StartDate);

            -- Month name + last 2 digits of year: Jun26, Feb27 etc.
            DECLARE @MonthName NVARCHAR(10) =
                CASE MONTH(@DueDate)
                    WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                    WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                    WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                    WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
                END
                + RIGHT(CAST(YEAR(@DueDate) AS NVARCHAR), 2);

            INSERT INTO ContractRoomInstallments (
                ContractId, CampId, CampName, RoomId, RoomNo,
                InstallmentNo, InstallAmount, DueDate, Month,
                PaymentMode, ReferenceNo, ClearanceDate,
                Status, PaidAmount, PaidDate, CreatedAt, UpdatedAt
            )
            VALUES (
                @ContractId, @CampId, @CampName, @RoomId, @RoomNo,
                @i, @MonthlyAmount, @DueDate, @MonthName,
                '', '', NULL,
                'Pending', 0, NULL, GETDATE(), GETDATE()
            );

            SET @i += 1;
        END

        FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmount, @CampId, @CampName;
    END

    CLOSE room_cursor;
    DEALLOCATE room_cursor;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 2. Fix sp_UpdatePaymentSchedule — also update Month in CRI ──
CREATE OR ALTER PROCEDURE sp_UpdatePaymentSchedule
    @ContractId   NVARCHAR(MAX),
    @ScheduleJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Update ContractInstallments
    DELETE FROM ContractInstallments WHERE ContractId = @ContractId;
    INSERT INTO ContractInstallments (
        ContractId, InstallmentNo, Amount, DueDate,
        PaidAmount, Status, PaymentMode, ChequeNumber, ClearanceDate
    )
    SELECT
        @ContractId, s.InstallmentNo, s.Amount, s.DueDate,
        0, 'Pending',
        ISNULL(NULLIF(s.PaymentMode,  ''), 'Cheque'),
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

    -- Update Month column in ContractRoomInstallments for matching installment numbers
    UPDATE cri
    SET
        cri.Month     = CASE MONTH(s.DueDate)
                            WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                            WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                            WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                            WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
                        END + RIGHT(CAST(YEAR(s.DueDate) AS NVARCHAR), 2),
        cri.DueDate   = s.DueDate,
        cri.UpdatedAt = GETDATE()
    FROM ContractRoomInstallments cri
    JOIN (
        SELECT InstallmentNo, DueDate
        FROM OPENJSON(@ScheduleJson) WITH (
            InstallmentNo INT  '$.no',
            DueDate       DATE '$.dueDate'
        )
    ) s ON s.InstallmentNo = cri.InstallmentNo
    WHERE cri.ContractId = @ContractId;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '050 - Month format fixed: Jun26, Feb27 etc. in ContractRoomInstallments';
GO
