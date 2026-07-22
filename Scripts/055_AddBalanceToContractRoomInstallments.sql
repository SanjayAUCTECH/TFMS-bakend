-- ============================================================
-- 055: Add Balance column to ContractRoomInstallments
--      Balance = InstallAmount - PaidAmount
--      Update SPs: Generate, GetAll, UpdatePayment
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. sp_GenerateContractRoomInstallments — insert Balance ──
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

    DECLARE @RoomId     INT;
    DECLARE @RoomNo     NVARCHAR(MAX);
    DECLARE @MonthlyAmt DECIMAL(18,2);
    DECLARE @CampId     INT;
    DECLARE @CampName   NVARCHAR(MAX);

    DECLARE room_cursor CURSOR FOR
        SELECT
            cr.RoomId,
            r.RoomNo,
            ISNULL(cr.MonthlyAmount, r.MonthlyPrice)  MonthlyAmount,
            ISNULL(cr.CampId, r.CampId)               CampId,
            ISNULL(ca.Name, '')                        CampName
        FROM ContractRooms cr
        JOIN Rooms r  ON r.Id  = cr.RoomId
        LEFT JOIN Camps ca ON ca.Id = ISNULL(cr.CampId, r.CampId)
        WHERE cr.ContractId = @ContractId;

    OPEN room_cursor;
    FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmt, @CampId, @CampName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @i INT = 1;
        WHILE @i <= @Months
        BEGIN
            DECLARE @DueDate DATE = DATEADD(MONTH, @i - 1, @StartDate);
            DECLARE @MonthName NVARCHAR(10) =
                CASE MONTH(@DueDate)
                    WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                    WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                    WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                    WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
                END + RIGHT(CAST(YEAR(@DueDate) AS NVARCHAR), 2);

            INSERT INTO ContractRoomInstallments (
                ContractId, CampId, CampName, RoomId, RoomNo,
                InstallmentNo, InstallAmount, DueDate, Month,
                PaymentMode, ReferenceNo, ClearanceDate,
                Status, PaidAmount, Balance, PaidDate,
                CreatedAt, UpdatedAt
            )
            VALUES (
                @ContractId, @CampId, @CampName, @RoomId, @RoomNo,
                @i, @MonthlyAmt, @DueDate, @MonthName,
                '', '', NULL,
                'Pending', 0, @MonthlyAmt, NULL,
                GETDATE(), GETDATE()
            );

            SET @i += 1;
        END
        FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmt, @CampId, @CampName;
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

-- ── 2. sp_GetContractRoomInstallments — return Balance ────────
CREATE OR ALTER PROCEDURE sp_GetContractRoomInstallments
    @ContractId   NVARCHAR(MAX),
    @CampId       INT           = NULL,
    @RoomId       INT           = NULL,
    @Month        NVARCHAR(10)  = NULL,
    @Status       NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cri.Id,
        cri.ContractId,
        cri.CampId,
        cri.CampName,
        cri.RoomId,
        cri.RoomNo,
        cri.InstallmentNo,
        cri.InstallAmount,
        cri.DueDate,
        cri.Month,
        cri.PaymentMode,
        cri.ReferenceNo,
        cri.ClearanceDate,
        cri.Status,
        cri.PaidAmount,
        cri.Balance,
        cri.PaidDate,
        cri.CreatedAt,
        cri.UpdatedAt
    FROM ContractRoomInstallments cri
    WHERE cri.ContractId = @ContractId
      AND (@CampId IS NULL OR cri.CampId = @CampId)
      AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
      AND (@Month  IS NULL OR cri.Month  = @Month)
      AND (@Status IS NULL OR cri.Status = @Status)
    ORDER BY cri.InstallmentNo, cri.CampName, cri.RoomNo;
END
GO

-- ── 3. sp_UpdateContractRoomInstallment — recalculate Balance ─
CREATE OR ALTER PROCEDURE sp_UpdateContractRoomInstallment
    @Id           INT,
    @PaymentMode  NVARCHAR(MAX)  = NULL,
    @ReferenceNo  NVARCHAR(MAX)  = NULL,
    @ClearanceDate DATE          = NULL,
    @PaidAmount   DECIMAL(18,2)  = NULL,
    @PaidDate     DATE           = NULL,
    @Status       NVARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ContractRoomInstallments
    SET
        PaymentMode   = ISNULL(@PaymentMode,   PaymentMode),
        ReferenceNo   = ISNULL(@ReferenceNo,   ReferenceNo),
        ClearanceDate = ISNULL(@ClearanceDate, ClearanceDate),
        PaidAmount    = ISNULL(@PaidAmount,    PaidAmount),
        -- Recalculate Balance
        Balance       = InstallAmount - ISNULL(@PaidAmount, PaidAmount),
        PaidDate      = ISNULL(@PaidDate,      PaidDate),
        Status        = ISNULL(@Status,        Status),
        UpdatedAt     = GETDATE()
    WHERE Id = @Id;
END
GO

PRINT '055 - Balance column added to ContractRoomInstallments, SPs updated';
GO
