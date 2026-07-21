-- ============================================================
-- 047: ContractRoomInstallments Table
--      Room-wise installment breakdown per contract
--      Auto-populated when contract is created/updated
-- Date: July 21, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. Create Table ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ContractRoomInstallments')
CREATE TABLE ContractRoomInstallments (
    Id             INT IDENTITY(1,1) PRIMARY KEY,
    ContractId     NVARCHAR(MAX)  NOT NULL,
    CampId         INT            NOT NULL DEFAULT 0,
    CampName       NVARCHAR(MAX)  NOT NULL DEFAULT '',
    RoomId         INT            NOT NULL,
    RoomNo         NVARCHAR(MAX)  NOT NULL DEFAULT '',
    InstallmentNo  INT            NOT NULL,           -- 1,2,3...
    InstallAmount  DECIMAL(18,2)  NOT NULL DEFAULT 0, -- Room's share of monthly rent
    DueDate        DATE           NOT NULL,
    Month          NVARCHAR(10)   NOT NULL DEFAULT '', -- Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
    PaymentMode    NVARCHAR(MAX)  NOT NULL DEFAULT '',
    ReferenceNo    NVARCHAR(MAX)  NOT NULL DEFAULT '', -- Cheque no / ref no
    ClearanceDate  DATE           NULL,
    Status         NVARCHAR(20)   NOT NULL DEFAULT 'Pending', -- Pending, Paid, Partial, Cancelled
    PaidAmount     DECIMAL(18,2)  NOT NULL DEFAULT 0,
    PaidDate       DATE           NULL,
    CreatedAt      DATETIME2      NOT NULL DEFAULT GETDATE(),
    UpdatedAt      DATETIME2      NOT NULL DEFAULT GETDATE()
);
GO

-- Indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_ContractId' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_ContractId ON ContractRoomInstallments (ContractId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_RoomId' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_RoomId ON ContractRoomInstallments (RoomId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CRI_DueDate' AND object_id=OBJECT_ID('ContractRoomInstallments'))
    CREATE INDEX IX_CRI_DueDate ON ContractRoomInstallments (DueDate);
GO

PRINT 'ContractRoomInstallments table created.';
GO

-- ── 2. sp_GenerateContractRoomInstallments ────────────────────
-- Called after contract create/update — generates room-wise rows
CREATE OR ALTER PROCEDURE sp_GenerateContractRoomInstallments
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Delete existing rows for this contract (re-generate fresh)
    DELETE FROM ContractRoomInstallments WHERE ContractId = @ContractId;

    -- Get contract info
    DECLARE @StartDate DATE, @Months INT;
    SELECT @StartDate = StartDate, @Months = Months
    FROM Contracts WHERE ContractId = @ContractId;

    IF @StartDate IS NULL OR @Months IS NULL OR @Months <= 0
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Loop through each room of the contract
    DECLARE @RoomId INT, @RoomNo NVARCHAR(MAX), @MonthlyAmount DECIMAL(18,2);
    DECLARE @CampId INT, @CampName NVARCHAR(MAX);

    -- Cursor over rooms
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
            DECLARE @MonthName NVARCHAR(10) =
                CASE MONTH(@DueDate)
                    WHEN 1  THEN 'Jan'
                    WHEN 2  THEN 'Feb'
                    WHEN 3  THEN 'Mar'
                    WHEN 4  THEN 'Apr'
                    WHEN 5  THEN 'May'
                    WHEN 6  THEN 'Jun'
                    WHEN 7  THEN 'Jul'
                    WHEN 8  THEN 'Aug'
                    WHEN 9  THEN 'Sep'
                    WHEN 10 THEN 'Oct'
                    WHEN 11 THEN 'Nov'
                    WHEN 12 THEN 'Dec'
                END;

            INSERT INTO ContractRoomInstallments (
                ContractId, CampId, CampName, RoomId, RoomNo,
                InstallmentNo, InstallAmount, DueDate, Month,
                PaymentMode, ReferenceNo, ClearanceDate,
                Status, PaidAmount, PaidDate,
                CreatedAt, UpdatedAt
            )
            VALUES (
                @ContractId, @CampId, @CampName, @RoomId, @RoomNo,
                @i, @MonthlyAmount, @DueDate, @MonthName,
                '', '', NULL,
                'Pending', 0, NULL,
                GETDATE(), GETDATE()
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

-- ── 3. sp_GetContractRoomInstallments ─────────────────────────
CREATE OR ALTER PROCEDURE sp_GetContractRoomInstallments
    @ContractId   NVARCHAR(MAX),
    @RoomId       INT           = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @Month        NVARCHAR(10)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cri.Id, cri.ContractId,
        cri.CampId, cri.CampName,
        cri.RoomId, cri.RoomNo,
        cri.InstallmentNo, cri.InstallAmount,
        cri.DueDate, cri.Month,
        cri.PaymentMode, cri.ReferenceNo, cri.ClearanceDate,
        cri.Status, cri.PaidAmount, cri.PaidDate,
        cri.CreatedAt, cri.UpdatedAt
    FROM ContractRoomInstallments cri
    WHERE cri.ContractId = @ContractId
      AND (@RoomId IS NULL OR cri.RoomId = @RoomId)
      AND (@Status IS NULL OR cri.Status = @Status)
      AND (@Month  IS NULL OR cri.Month  = @Month)
    ORDER BY cri.InstallmentNo, cri.CampName, cri.RoomNo;
END
GO

-- ── 4. sp_UpdateContractRoomInstallment ───────────────────────
-- Update payment info on a single room installment
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
        PaidDate      = ISNULL(@PaidDate,      PaidDate),
        Status        = ISNULL(@Status,        Status),
        UpdatedAt     = GETDATE()
    WHERE Id = @Id;
END
GO

-- ── 5. Update sp_CreateContract — auto-generate room installments ──
-- Re-create sp_CreateContract to call sp_GenerateContractRoomInstallments at end
PRINT 'Updating sp_CreateContract to auto-generate ContractRoomInstallments...';
GO
