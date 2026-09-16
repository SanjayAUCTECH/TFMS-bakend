SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ══════════════════════════════════════════════════════════════════════════
-- sp_ReceiveSecurityDeposit — Final Fix
-- @PaymentStatus parameter added
-- TxnId auto-generation added (TXN-XXXXXX format)
-- ══════════════════════════════════════════════════════════════════════════
ALTER PROCEDURE sp_ReceiveSecurityDeposit
    @ContractId    NVARCHAR(450),
    @Amount        DECIMAL(18,2),
    @PaidDate      DATE,
    @PaymentMode   NVARCHAR(100)  = 'Cash',
    @PaymentModeId INT            = NULL,
    @ChequeNumber  NVARCHAR(100)  = '',
    @FundPoolId    INT            = NULL,
    @FundPoolName  NVARCHAR(200)  = '',
    @ReceivedBy    NVARCHAR(200)  = 'Admin',
    @Notes         NVARCHAR(MAX)  = '',
    @PaymentStatus NVARCHAR(50)   = 'Paid',   -- ✅ 'Paid' | 'Advanced'
    @NewPaid       DECIMAL(18,2)  OUTPUT,
    @NewStatus     NVARCHAR(50)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Validate PaymentStatus ─────────────────────────────────────────────
    IF @PaymentStatus NOT IN ('Paid', 'Advanced')
        SET @PaymentStatus = 'Paid';

    -- ── Fetch Contract info ────────────────────────────────────────────────
    DECLARE @DepositAmount   DECIMAL(18,2),
            @CurrentPaid     DECIMAL(18,2),
            @TenantId        INT,
            @TenantName      NVARCHAR(200),
            @CampId          INT;

    SELECT
        @DepositAmount = ISNULL(SecurityDeposit, 0),
        @CurrentPaid   = ISNULL(SecurityDepositPaid, 0),
        @TenantId      = TenantId
    FROM Contracts
    WHERE ContractId = @ContractId
      AND ISNULL(IsDeleted, 0) = 0;

    IF @DepositAmount IS NULL
    BEGIN
        RAISERROR('Contract not found: %s', 16, 1, @ContractId);
        RETURN;
    END

    -- Get CampId from ContractRooms (first room's CampId)
    SELECT TOP 1 @CampId = CampId
    FROM ContractRooms
    WHERE ContractId = @ContractId
      AND ISNULL(IsDeleted, 0) = 0;

    SELECT @TenantName = ISNULL(Name, '') FROM Tenants WHERE Id = @TenantId;

    -- ── Calculate new paid & status ────────────────────────────────────────
    SET @NewPaid = @CurrentPaid + @Amount;

    SET @NewStatus = CASE
        WHEN @NewPaid <= 0                  THEN 'Pending'
        WHEN @NewPaid >= @DepositAmount     THEN 'Received'
        ELSE 'Partially Received'
    END;

    -- ── Step 1: Update Contracts ───────────────────────────────────────────
    UPDATE Contracts
    SET SecurityDepositPaid   = @NewPaid,
        SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    -- ── Step 2: Update FundPool balance ───────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools
        SET Balance   = Balance + @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

    -- ── Step 3: Generate TxnId ─────────────────────────────────────────────
    DECLARE @NewTxnId NVARCHAR(50);
    DECLARE @MaxId INT;
    
    -- Get max Id from TxnRecords to generate next TxnId
    SELECT @MaxId = ISNULL(MAX(Id), 0) + 1 FROM TxnRecords;
    
    -- Generate TxnId in format: TXN-00001, TXN-00002, etc.
    SET @NewTxnId = 'TXN-' + RIGHT('00000' + CAST(@MaxId AS NVARCHAR), 5);

    -- ── Step 4: Insert TxnRecord ───────────────────────────────────────────
    DECLARE @TxnRecordId INT;

    INSERT INTO TxnRecords (
        TxnId, ContractId, TxnType, Amount, TxnDate,
        PaymentMode, PaymentModeId, ChequeNumber,
        FundPoolId, FundPoolName, CampId, TenantId,
        Description, ReceivedBy,
        CreatedAt, UpdatedAt, IsDeleted
    )
    VALUES (
        @NewTxnId, @ContractId, 'SD-CR', @Amount, @PaidDate,
        @PaymentMode, @PaymentModeId, @ChequeNumber,
        @FundPoolId, @FundPoolName, @CampId, @TenantId,
        @Notes, @ReceivedBy,
        GETDATE(), GETDATE(), 0
    );

    SET @TxnRecordId = SCOPE_IDENTITY();

    -- ── Step 5: Insert Income ──────────────────────────────────────────────
    DECLARE @FundPoolCode NVARCHAR(50) = '';
    SELECT @FundPoolCode = ISNULL(Code, '') FROM FundPools WHERE Id = @FundPoolId;

    DECLARE @CampName NVARCHAR(200) = '';
    SELECT @CampName = ISNULL(Name, '') FROM Camps WHERE Id = @CampId;

    INSERT INTO Incomes (
        ContractId, Source, Head, Amount, [Date],
        Mode, FundPool, TxnRecordId,
        TenantName, CampName,
        Purpose, VoucherNo,
        CreatedAt, UpdatedAt, IsDeleted
    )
    VALUES (
        @ContractId, 'Tenant', 'SECURITY DEPOSIT', @Amount, @PaidDate,
        @PaymentMode, @FundPoolCode, @TxnRecordId,
        @TenantName, @CampName,
        'Security Deposit received', '',
        GETDATE(), GETDATE(), 0
    );

    -- ── Step 6: Update ContractRooms (per-room SecurityPaidAmount) ────────
    DECLARE @RoomCount INT;
    SELECT @RoomCount = COUNT(*)
    FROM ContractRooms
    WHERE ContractId = @ContractId
      AND ISNULL(IsDeleted, 0) = 0;

    IF @RoomCount = 0 SET @RoomCount = 1;

    DECLARE @PerRoomAmt DECIMAL(18,2) = ROUND(@Amount / @RoomCount, 2);

    ;WITH RoomRanked AS (
        SELECT Id, RoomId, CampId,
               ISNULL(SecurityAmount, 0)     AS SecurityAmount,
               ISNULL(SecurityPaidAmount, 0) AS SecurityPaidAmount,
               ROW_NUMBER() OVER (ORDER BY RoomId) AS RowNum
        FROM ContractRooms
        WHERE ContractId = @ContractId
          AND ISNULL(IsDeleted, 0) = 0
    )
    UPDATE cr
    SET
        cr.SecurityPaidAmount = ISNULL(cr.SecurityPaidAmount, 0)
            + CASE WHEN rr.RowNum = @RoomCount
                   THEN @Amount - (@PerRoomAmt * (@RoomCount - 1))
                   ELSE @PerRoomAmt END,
        cr.SecurityDueAmount  = CASE
            WHEN ISNULL(cr.SecurityAmount, 0)
                 - (ISNULL(cr.SecurityPaidAmount, 0)
                    + CASE WHEN rr.RowNum = @RoomCount
                           THEN @Amount - (@PerRoomAmt * (@RoomCount - 1))
                           ELSE @PerRoomAmt END) < 0
            THEN 0
            ELSE ISNULL(cr.SecurityAmount, 0)
                 - (ISNULL(cr.SecurityPaidAmount, 0)
                    + CASE WHEN rr.RowNum = @RoomCount
                           THEN @Amount - (@PerRoomAmt * (@RoomCount - 1))
                           ELSE @PerRoomAmt END)
        END,
        cr.UpdatedAt = GETDATE()
    FROM ContractRooms cr
    INNER JOIN RoomRanked rr ON rr.Id = cr.Id;

    -- ── Step 7: Insert ContractRoomsTrns (per-room SD-CR) ─────────────────
    ;WITH RoomRanked2 AS (
        SELECT RoomId, CampId,
               ROW_NUMBER() OVER (ORDER BY RoomId) AS RowNum
        FROM ContractRooms
        WHERE ContractId = @ContractId
          AND ISNULL(IsDeleted, 0) = 0
    )
    INSERT INTO ContractRoomsTrns (
        ContractId, RoomId, CampId,
        TxnType, TxnRecordId,
        TotalAmount, Amount,
        TxnDate, Month,
        Description,
        PaymentStatus,             -- ✅ 'Paid' or 'Advanced'
        CreatedAt, IsDeleted
    )
    SELECT
        @ContractId,
        rr.RoomId,
        rr.CampId,
        'SD-CR',
        @TxnRecordId,
        CASE WHEN rr.RowNum = @RoomCount
             THEN @Amount - (@PerRoomAmt * (@RoomCount - 1))
             ELSE @PerRoomAmt END,
        CASE WHEN rr.RowNum = @RoomCount
             THEN @Amount - (@PerRoomAmt * (@RoomCount - 1))
             ELSE @PerRoomAmt END,
        @PaidDate,
        LEFT(DATENAME(MONTH, @PaidDate), 3) + RIGHT(CAST(YEAR(@PaidDate) AS NVARCHAR(4)), 2),
        'Security Deposit - ' + @PaymentStatus,
        @PaymentStatus,            -- ✅ 'Paid' or 'Advanced'
        GETDATE(),
        0
    FROM RoomRanked2 rr;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '✅ sp_ReceiveSecurityDeposit successfully updated with TxnId auto-generation!';
GO
