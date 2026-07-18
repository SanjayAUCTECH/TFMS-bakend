-- ============================================================================
-- 035: Room-Wise Payment Tracking
-- ContractRoomsTrns table for tracking payments per room
-- Updated sp_RecordPayment to accept room-wise payment array
-- ============================================================================

-- ── 1. Create ContractRoomsTrns table ────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ContractRoomsTrns')
BEGIN
    CREATE TABLE ContractRoomsTrns (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        ContractId      NVARCHAR(MAX) NOT NULL,
        RoomId          INT NOT NULL,
        CampId          INT NULL,
        TxnRecordId     INT NULL,           -- Links to TxnRecords.Id
        Amount          DECIMAL(18,2) NOT NULL DEFAULT 0,
        PaidDate        DATE NULL,
        PaymentMode     NVARCHAR(MAX) NULL,
        Description     NVARCHAR(MAX) NULL,
        CreatedAt       DATETIME2 DEFAULT GETDATE(),
        UpdatedAt       DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'ContractRoomsTrns table created.';
END
GO

-- ── 2. Ensure ContractRooms has required columns ─────────────────────────────
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='CampId')
    ALTER TABLE ContractRooms ADD CampId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='MonthlyAmount')
    ALTER TABLE ContractRooms ADD MonthlyAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='TotalAmount')
    ALTER TABLE ContractRooms ADD TotalAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='PaidAmount')
    ALTER TABLE ContractRooms ADD PaidAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='Balance')
    ALTER TABLE ContractRooms ADD Balance DECIMAL(18,2) NULL DEFAULT 0;
GO

-- ── 3. sp_RecordPaymentWithRooms ─────────────────────────────────────────────
-- New SP that accepts room-wise payment JSON array
-- Distributes payment to ContractRooms + logs in ContractRoomsTrns
-- Also updates ContractInstallments (existing flow)
-- ============================================================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_RecordPaymentWithRooms')
    DROP PROCEDURE sp_RecordPaymentWithRooms;
GO

CREATE PROCEDURE sp_RecordPaymentWithRooms
    @ContractId      NVARCHAR(MAX),
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATE,
    @RoomPaymentsJson NVARCHAR(MAX) = '[]',  -- [{roomId, campId, amount}]
    @InstallmentNo   INT           = 0,
    @PaymentModeId   INT           = NULL,
    @PaymentMode     NVARCHAR(MAX) = '',
    @ChequeNumber    NVARCHAR(MAX) = '',
    @ClearanceDate   NVARCHAR(MAX) = '',
    @Description     NVARCHAR(MAX) = '',
    @ReceivedBy      NVARCHAR(MAX) = '',
    @ReceivedContact NVARCHAR(MAX) = '',
    @FundPoolId      INT           = NULL,
    @FundPoolName    NVARCHAR(MAX) = '',
    @IssuedBy        NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── Validate contract exists ─────────────────────────────────
        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId = @ContractId)
        BEGIN
            RAISERROR('Contract %s not found.', 16, 1, @ContractId);
            RETURN;
        END

        -- ── Get TenantId, CampId ─────────────────────────────────────
        DECLARE @TenantId INT, @CampId INT;
        SELECT @TenantId = TenantId, @CampId = ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId), 0)
        FROM Contracts WHERE ContractId = @ContractId;

        -- ── Distribute payment across pending installments ───────────
        DECLARE @Remaining       DECIMAL(18,2) = @PaidAmount;
        DECLARE @AppliedList     NVARCHAR(MAX) = '';
        DECLARE @CurrentInstNo   INT;
        DECLARE @CurrentAmount   DECIMAL(18,2);
        DECLARE @CurrentPaid     DECIMAL(18,2);
        DECLARE @CurrentDue      DECIMAL(18,2);
        DECLARE @ToApply         DECIMAL(18,2);
        DECLARE @NewPaid         DECIMAL(18,2);
        DECLARE @NewStatus       NVARCHAR(MAX);

        DECLARE inst_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Amount - PaidAmount AS Due
            FROM ContractInstallments
            WHERE ContractId = @ContractId
              AND Status IN ('Pending', 'Partial', 'Overdue')
              AND (Amount - PaidAmount) > 0
              AND (@InstallmentNo = 0 OR InstallmentNo >= @InstallmentNo)
            ORDER BY InstallmentNo;

        OPEN inst_cursor;
        FETCH NEXT FROM inst_cursor INTO @CurrentInstNo, @CurrentAmount, @CurrentPaid, @CurrentDue;

        WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
        BEGIN
            SET @ToApply  = CASE WHEN @Remaining >= @CurrentDue THEN @CurrentDue ELSE @Remaining END;
            SET @NewPaid  = @CurrentPaid + @ToApply;
            SET @NewStatus = CASE
                WHEN @NewPaid >= @CurrentAmount THEN 'Paid'
                WHEN @NewPaid  > 0              THEN 'Partial'
                ELSE 'Pending'
            END;

            UPDATE ContractInstallments
            SET PaidAmount      = @NewPaid,
                PaidDate        = @PaidDate,
                Status          = @NewStatus,
                PaymentModeId   = @PaymentModeId,
                PaymentMode     = @PaymentMode,
                ChequeNumber    = @ChequeNumber,
                ClearanceDate   = @ClearanceDate,
                Description     = @Description,
                ReceivedBy      = @ReceivedBy,
                ReceivedContact = @ReceivedContact,
                FundPoolId      = @FundPoolId,
                FundPoolName    = @FundPoolName,
                IssuedBy        = @IssuedBy
            WHERE ContractId = @ContractId AND InstallmentNo = @CurrentInstNo;

            SET @AppliedList = CASE
                WHEN @AppliedList = '' THEN CAST(@CurrentInstNo AS NVARCHAR)
                ELSE @AppliedList + ',' + CAST(@CurrentInstNo AS NVARCHAR)
            END;

            SET @Remaining = @Remaining - @ToApply;
            FETCH NEXT FROM inst_cursor INTO @CurrentInstNo, @CurrentAmount, @CurrentPaid, @CurrentDue;
        END;

        CLOSE inst_cursor;
        DEALLOCATE inst_cursor;

        -- ── Update FundPool balance ───────────────────────────────────
        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools
            SET Balance   = Balance + @PaidAmount,
                UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- ── Create TxnRecord ──────────────────────────────────────────
        DECLARE @TxnId NVARCHAR(MAX) =
            'TXN-' + CONVERT(NVARCHAR(MAX), @PaidDate, 112) + '-' +
            RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM TxnRecords) AS NVARCHAR), 6);

        DECLARE @Unallocated DECIMAL(18,2) = CASE WHEN @Remaining > 0 THEN @Remaining ELSE 0 END;

        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId,
            TotalAmount, Amount,
            PaidDate,
            PaymentMode, PaymentModeId,
            ChequeNumber, Description,
            IssuedBy, ReceivedBy, ReceivedContact,
            FundPoolId, FundPoolName,
            AppliedInstallments, Unallocated,
            InstallmentNo,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @TxnId, 'CR', @ContractId, @ContractId,
            @TenantId, @CampId,
            @PaidAmount, @PaidAmount,
            @PaidDate,
            @PaymentMode, @PaymentModeId,
            @ChequeNumber, @Description,
            @IssuedBy, @ReceivedBy, @ReceivedContact,
            @FundPoolId, @FundPoolName,
            @AppliedList, @Unallocated,
            CASE WHEN @AppliedList <> '' AND CHARINDEX(',', @AppliedList) = 0
                 THEN CAST(@AppliedList AS INT) ELSE NULL END,
            GETUTCDATE(), GETUTCDATE()
        );

        DECLARE @TxnRecordId INT = SCOPE_IDENTITY();

        -- ── Process Room-Wise Payments ────────────────────────────────
        IF @RoomPaymentsJson IS NOT NULL AND @RoomPaymentsJson <> '[]' AND @RoomPaymentsJson <> ''
        BEGIN
            -- Insert into ContractRoomsTrns
            INSERT INTO ContractRoomsTrns (ContractId, RoomId, CampId, TxnRecordId, Amount, PaidDate, PaymentMode, Description, CreatedAt, UpdatedAt)
            SELECT
                @ContractId,
                JSON_VALUE(value, '$.roomId'),
                JSON_VALUE(value, '$.campId'),
                @TxnRecordId,
                JSON_VALUE(value, '$.amount'),
                @PaidDate,
                @PaymentMode,
                @Description,
                GETDATE(),
                GETDATE()
            FROM OPENJSON(@RoomPaymentsJson);

            -- Update ContractRooms PaidAmount and Balance
            UPDATE cr
            SET cr.PaidAmount = ISNULL(cr.PaidAmount, 0) + rp.Amount,
                cr.Balance    = ISNULL(cr.TotalAmount, 0) - (ISNULL(cr.PaidAmount, 0) + rp.Amount)
            FROM ContractRooms cr
            INNER JOIN (
                SELECT
                    CAST(JSON_VALUE(value, '$.roomId') AS INT) AS RoomId,
                    CAST(JSON_VALUE(value, '$.amount') AS DECIMAL(18,2)) AS Amount
                FROM OPENJSON(@RoomPaymentsJson)
            ) rp ON rp.RoomId = cr.RoomId AND cr.ContractId = @ContractId;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 4. sp_GetContractRoomsForPayment ─────────────────────────────────────────
-- Returns rooms with balances for a contract (used in Receive Payment UI)
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetContractRoomsForPayment')
    DROP PROCEDURE sp_GetContractRoomsForPayment;
GO

CREATE PROCEDURE sp_GetContractRoomsForPayment
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cr.Id,
        cr.ContractId,
        cr.RoomId,
        ISNULL(cr.CampId, 0) AS CampId,
        ISNULL(r.RoomNo, '') AS RoomNo,
        ISNULL(ca.Name, '') AS CampName,
        ISNULL(cr.MonthlyAmount, r.MonthlyPrice) AS MonthlyAmount,
        ISNULL(cr.TotalAmount, 0) AS TotalAmount,
        ISNULL(cr.PaidAmount, 0) AS PaidAmount,
        ISNULL(cr.Balance, ISNULL(cr.TotalAmount, 0) - ISNULL(cr.PaidAmount, 0)) AS Balance
    FROM ContractRooms cr
    JOIN Rooms r ON r.Id = cr.RoomId
    LEFT JOIN Camps ca ON ca.Id = cr.CampId
    WHERE cr.ContractId = @ContractId
    ORDER BY ca.Name, r.RoomNo;
END
GO

-- ── 5. sp_CancelContract (Create/Update) ─────────────────────────────────────
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_CancelContract')
    DROP PROCEDURE sp_CancelContract;
GO

CREATE PROCEDURE sp_CancelContract
    @ContractId         NVARCHAR(MAX),
    @CancellationDate   DATE = NULL,
    @CancellationReason NVARCHAR(MAX) = NULL,
    @RefundAmount       DECIMAL(18,2) = 0,
    @PenaltyAmount      DECIMAL(18,2) = 0,
    @SettlementAmount   DECIMAL(18,2) = 0,
    @CancelledBy        NVARCHAR(MAX) = NULL,
    @Notes              NVARCHAR(MAX) = NULL,
    @NewId              INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate contract
        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId = @ContractId AND Status = 'Active')
        BEGIN
            RAISERROR('Active contract %s not found.', 16, 1, @ContractId);
            RETURN;
        END

        DECLARE @TenantId INT;
        SELECT @TenantId = TenantId FROM Contracts WHERE ContractId = @ContractId;

        -- 1. Mark contract as Cancelled
        UPDATE Contracts
        SET Status = 'Cancelled', UpdatedAt = GETDATE()
        WHERE ContractId = @ContractId;

        -- 2. Cancel all pending installments
        UPDATE ContractInstallments
        SET Status = 'Cancelled'
        WHERE ContractId = @ContractId AND Status IN ('Pending', 'Partial', 'Overdue');

        -- 3. Mark rooms as Vacant
        UPDATE Rooms
        SET Occupied = 0, Status = 'Vacant', UpdatedAt = GETDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);

        -- 4. Log cancellation
        IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ContractCancellations')
        BEGIN
            CREATE TABLE ContractCancellations (
                Id                 INT IDENTITY(1,1) PRIMARY KEY,
                ContractId         NVARCHAR(MAX) NOT NULL,
                TenantId           INT NULL,
                CancellationDate   DATE NULL,
                CancellationReason NVARCHAR(MAX) NULL,
                RefundAmount       DECIMAL(18,2) DEFAULT 0,
                PenaltyAmount      DECIMAL(18,2) DEFAULT 0,
                SettlementAmount   DECIMAL(18,2) DEFAULT 0,
                CancelledBy        NVARCHAR(MAX) NULL,
                Notes              NVARCHAR(MAX) NULL,
                Status             NVARCHAR(MAX) DEFAULT 'Cancelled',
                CreatedAt          DATETIME2 DEFAULT GETDATE(),
                UpdatedAt          DATETIME2 DEFAULT GETDATE()
            );
        END

        INSERT INTO ContractCancellations (
            ContractId, TenantId, CancellationDate, CancellationReason,
            RefundAmount, PenaltyAmount, SettlementAmount,
            CancelledBy, Notes, Status
        )
        VALUES (
            @ContractId, @TenantId,
            ISNULL(@CancellationDate, GETDATE()),
            @CancellationReason,
            @RefundAmount, @PenaltyAmount, @SettlementAmount,
            @CancelledBy, @Notes, 'Cancelled'
        );
        SET @NewId = SCOPE_IDENTITY();

        -- 5. Create penalty DR TxnRecord if penalty > 0
        IF @PenaltyAmount > 0
        BEGIN
            DECLARE @CampId INT = ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId), 0);
            INSERT INTO TxnRecords (
                TxnId, TxnType, ContractId, ContractCode,
                TenantId, CampId, TotalAmount, Amount,
                PaidDate, Description, IssuedBy, ReceivedBy,
                CreatedAt, UpdatedAt
            )
            VALUES (
                'TXN-' + CONVERT(NVARCHAR(MAX), GETDATE(), 112) + '-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6),
                'DR', @ContractId, @ContractId,
                @TenantId, @CampId, @PenaltyAmount, @PenaltyAmount,
                ISNULL(@CancellationDate, GETDATE()),
                'Cancellation penalty - ' + @ContractId,
                @CancelledBy, @CancelledBy,
                GETDATE(), GETDATE()
            );
        END

        -- 6. Create refund CR TxnRecord if refund > 0
        IF @RefundAmount > 0
        BEGIN
            DECLARE @CampId2 INT = ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId), 0);
            INSERT INTO TxnRecords (
                TxnId, TxnType, ContractId, ContractCode,
                TenantId, CampId, TotalAmount, Amount,
                PaidDate, Description, IssuedBy, ReceivedBy,
                CreatedAt, UpdatedAt
            )
            VALUES (
                'TXN-' + CONVERT(NVARCHAR(MAX), GETDATE(), 112) + '-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6),
                'CR', @ContractId, @ContractId,
                @TenantId, @CampId2, @RefundAmount, @RefundAmount,
                ISNULL(@CancellationDate, GETDATE()),
                'Cancellation refund - ' + @ContractId,
                @CancelledBy, @CancelledBy,
                GETDATE(), GETDATE()
            );
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 6. sp_GetContractCancellations ───────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetContractCancellations')
    DROP PROCEDURE sp_GetContractCancellations;
GO

CREATE PROCEDURE sp_GetContractCancellations
    @ContractId NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        cc.Id, cc.ContractId, cc.TenantId,
        t.Name AS TenantName,
        cc.CancellationDate, cc.CancellationReason,
        cc.RefundAmount, cc.PenaltyAmount, cc.SettlementAmount,
        cc.CancelledBy, cc.Notes, cc.Status,
        cc.CreatedAt, cc.UpdatedAt
    FROM ContractCancellations cc
    LEFT JOIN Tenants t ON t.Id = cc.TenantId
    WHERE (@ContractId IS NULL OR cc.ContractId = @ContractId)
    ORDER BY cc.CreatedAt DESC;
END
GO

PRINT '035 — Room-Wise Payments + Contract Cancellation applied successfully!';
GO
