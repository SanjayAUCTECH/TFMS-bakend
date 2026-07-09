-- ============================================================
-- TFMS — Script 018: Smart sp_RecordPayment
-- Auto-distributes payment across pending installments in order.
-- InstallmentNo = 0  → auto-distribute
-- InstallmentNo > 0  → start from that specific installment
-- One TxnRecord per payment call, AppliedInstallments lists all.
-- ============================================================
USE TFMS_softwareDB;
GO

CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId      NVARCHAR(20),
    @InstallmentNo   INT           = 0,      -- 0 = auto (start from first pending)
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATE,
    @PaymentModeId   INT           = NULL,
    @PaymentMode     NVARCHAR(50)  = '',
    @ChequeNumber    NVARCHAR(50)  = '',
    @ClearanceDate   NVARCHAR(50)  = '',
    @Description     NVARCHAR(500) = '',
    @ReceivedBy      NVARCHAR(200) = '',
    @ReceivedContact NVARCHAR(20)  = '',
    @FundPoolId      INT           = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @IssuedBy        NVARCHAR(100) = ''
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
        SELECT @TenantId = TenantId, @CampId = CampId
        FROM Contracts WHERE ContractId = @ContractId;

        -- ── Load pending/partial installments into temp table ────────
        -- Order by InstallmentNo; start from @InstallmentNo if specified
        CREATE TABLE #Pending (
            InstallmentNo INT,
            Amount        DECIMAL(18,2),
            PaidAmount    DECIMAL(18,2),
            Due           DECIMAL(18,2)   -- Amount - PaidAmount
        );

        INSERT INTO #Pending (InstallmentNo, Amount, PaidAmount, Due)
        SELECT InstallmentNo, Amount, PaidAmount, Amount - PaidAmount
        FROM ContractInstallments
        WHERE ContractId   = @ContractId
          AND Status       IN ('Pending', 'Partial', 'Overdue')
          AND (Amount - PaidAmount) > 0
          AND (@InstallmentNo = 0 OR InstallmentNo >= @InstallmentNo)
        ORDER BY InstallmentNo;

        IF NOT EXISTS (SELECT 1 FROM #Pending)
        BEGIN
            DROP TABLE #Pending;
            RAISERROR('No pending installments found for contract %s.', 16, 1, @ContractId);
            RETURN;
        END

        -- ── Distribute payment across installments ───────────────────
        DECLARE @Remaining       DECIMAL(18,2) = @PaidAmount;
        DECLARE @AppliedList     NVARCHAR(200) = '';
        DECLARE @CurrentInstNo   INT;
        DECLARE @CurrentAmount   DECIMAL(18,2);
        DECLARE @CurrentPaid     DECIMAL(18,2);
        DECLARE @CurrentDue      DECIMAL(18,2);
        DECLARE @ToApply         DECIMAL(18,2);
        DECLARE @NewPaid         DECIMAL(18,2);
        DECLARE @NewStatus       NVARCHAR(20);

        DECLARE inst_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Due
            FROM #Pending
            ORDER BY InstallmentNo;

        OPEN inst_cursor;
        FETCH NEXT FROM inst_cursor INTO @CurrentInstNo, @CurrentAmount, @CurrentPaid, @CurrentDue;

        WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
        BEGIN
            -- How much to apply to this installment
            SET @ToApply  = CASE WHEN @Remaining >= @CurrentDue THEN @CurrentDue ELSE @Remaining END;
            SET @NewPaid  = @CurrentPaid + @ToApply;
            SET @NewStatus = CASE
                WHEN @NewPaid >= @CurrentAmount THEN 'Paid'
                WHEN @NewPaid  > 0              THEN 'Partial'
                ELSE 'Pending'
            END;

            -- Update this installment
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

            -- Track applied installments
            SET @AppliedList = CASE
                WHEN @AppliedList = '' THEN CAST(@CurrentInstNo AS NVARCHAR)
                ELSE @AppliedList + ',' + CAST(@CurrentInstNo AS NVARCHAR)
            END;

            SET @Remaining = @Remaining - @ToApply;

            FETCH NEXT FROM inst_cursor INTO @CurrentInstNo, @CurrentAmount, @CurrentPaid, @CurrentDue;
        END;

        CLOSE inst_cursor;
        DEALLOCATE inst_cursor;
        DROP TABLE #Pending;

        -- ── Update FundPool balance ───────────────────────────────────
        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools
            SET Balance   = Balance + @PaidAmount,
                UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- ── Create ONE TxnRecord for entire payment ───────────────────
        DECLARE @TxnId NVARCHAR(20) =
            'TXN-' + CONVERT(NVARCHAR(8), @PaidDate, 112) + '-' +
            RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM TxnRecords) AS NVARCHAR), 6);

        -- Unallocated = excess payment beyond all installments
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
            -- InstallmentNo = first applied installment
            CASE WHEN CHARINDEX(',', @AppliedList) > 0
                 THEN CAST(LEFT(@AppliedList, CHARINDEX(',', @AppliedList) - 1) AS INT)
                 WHEN @AppliedList <> ''
                 THEN CAST(@AppliedList AS INT)
                 ELSE NULL END,
            GETUTCDATE(), GETUTCDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

PRINT 'Script 018 — Smart sp_RecordPayment applied!';
GO
