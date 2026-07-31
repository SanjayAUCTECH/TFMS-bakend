-- ============================================================
-- 123: Update sp_ReceiveSecurityDeposit
-- Changes:
--   1. Contracts:         UPDATE SecurityPaidAmount, Status
--   2. FundPools:         UPDATE Balance
--   3. TxnRecords:        INSERT SD-CR row
--   4. Incomes:           INSERT SD-CR income entry  ← NEW
--   5. ContractRooms:     UPDATE SecurityPaidAmount, SecurityDueAmount,
--                         SecurityPaidDate per room (proportional)  ← NEW
--   6. ContractRoomsTrns: INSERT one row per room TxnType='SD-CR'   ← NEW
--
-- Security distribution per room:
--   Room's share = ROUND(@Amount * room.SecurityAmount / totalSecurityAmount, 2)
--   Last room gets remainder to avoid rounding loss
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_ReceiveSecurityDeposit
    @ContractId    NVARCHAR(MAX),
    @Amount        DECIMAL(18,2),
    @PaidDate      DATE,
    @PaymentMode   NVARCHAR(MAX)  = 'Cash',
    @PaymentModeId INT            = NULL,
    @ChequeNumber  NVARCHAR(MAX)  = '',
    @FundPoolId    INT            = NULL,
    @FundPoolName  NVARCHAR(MAX)  = '',
    @ReceivedBy    NVARCHAR(MAX)  = 'Admin',
    @Notes         NVARCHAR(MAX)  = '',
    -- OUTPUT
    @NewPaid       DECIMAL(18,2)  OUTPUT,
    @NewStatus     NVARCHAR(MAX)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Step 1: Validate contract ──────────────────────────────────────────
    DECLARE @DepositAmount DECIMAL(18,2),
            @DepositPaid   DECIMAL(18,2),
            @TenantId      INT;

    SELECT
        @DepositAmount = ISNULL(SecurityDeposit, 0),
        @DepositPaid   = ISNULL(SecurityDepositPaid, 0),
        @TenantId      = TenantId
    FROM Contracts WHERE ContractId = @ContractId;

    IF @TenantId IS NULL
        BEGIN RAISERROR('Contract not found.', 16, 1); RETURN; END

    IF @DepositAmount <= 0
        BEGIN RAISERROR('No security deposit set for this contract.', 16, 1); RETURN; END

    IF @Amount > (@DepositAmount - @DepositPaid)
        BEGIN RAISERROR('Amount exceeds pending deposit balance.', 16, 1); RETURN; END

    -- ── Step 2: Calculate new status ──────────────────────────────────────
    SET @NewPaid   = @DepositPaid + @Amount;
    SET @NewStatus = CASE
        WHEN @NewPaid >= @DepositAmount THEN 'Received'
        ELSE 'Partially Received'
    END;

    -- ── Step 3: UPDATE Contracts ───────────────────────────────────────────
    UPDATE Contracts
    SET SecurityDepositPaid   = @NewPaid,
        SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    -- ── Step 4: UPDATE FundPool ────────────────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools
        SET Balance   = Balance + @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

    -- ── Step 5: Generate TxnId & fetch CampId ─────────────────────────────
    DECLARE @TxnSeq  INT          = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
    DECLARE @TxnId   NVARCHAR(MAX) = 'TXN-' + CONVERT(NVARCHAR, @PaidDate, 112)
                                     + '-' + RIGHT('000000' + CAST(@TxnSeq AS NVARCHAR), 6);
    DECLARE @CampId  INT = ISNULL(
        (SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId ORDER BY Id), 0);

    -- ── Step 6: INSERT TxnRecord (SD-CR) ──────────────────────────────────
    DECLARE @TxnRecordId INT;

    INSERT INTO TxnRecords (
        TxnId, TxnType, ContractId, ContractCode,
        TenantId, CampId, TotalAmount, Amount,
        PaidDate, PaymentMode, PaymentModeId, ChequeNumber,
        Description, ReceivedBy, IssuedBy,
        FundPoolId, FundPoolName,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @TxnId, 'SD-CR', @ContractId, @ContractId,
        @TenantId, @CampId, @Amount, @Amount,
        @PaidDate,
        ISNULL(@PaymentMode,  'Cash'),
        @PaymentModeId,
        ISNULL(@ChequeNumber, ''),
        'Security Deposit Received - ' + ISNULL(@Notes, ''),
        @ReceivedBy, @ReceivedBy,
        @FundPoolId, ISNULL(@FundPoolName, ''),
        GETDATE(), GETDATE()
    );

    SET @TxnRecordId = SCOPE_IDENTITY();

    -- ── Step 6b: Fetch extra info for Incomes ─────────────────────────────
    DECLARE @TenantName   NVARCHAR(MAX) = '';
    DECLARE @CampName     NVARCHAR(MAX) = '';
    DECLARE @FundPoolCode NVARCHAR(MAX) = '';
    DECLARE @ActualFundPoolName NVARCHAR(MAX) = '';

    SELECT @TenantName = ISNULL(t.Name, '')
    FROM Tenants t
    WHERE t.Id = @TenantId;

    SELECT @CampName = ISNULL(ca.Name, '')
    FROM ContractCamps cc
    LEFT JOIN Camps ca ON ca.Id = cc.CampId
    WHERE cc.ContractId = @ContractId
    ORDER BY cc.Id
    OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

    -- FundPool: DB se actual Code aur Name fetch karo (param par depend mat karo)
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT
            @FundPoolCode       = ISNULL(Code, ''),
            @ActualFundPoolName = ISNULL(Name, '')
        FROM FundPools
        WHERE Id = @FundPoolId;
    END

    -- Fallback: agar FundPoolId nahi diya to param value use karo
    IF @ActualFundPoolName = ''
        SET @ActualFundPoolName = ISNULL(NULLIF(@FundPoolName, ''), '');

    -- ── Step 6c: INSERT Incomes (SD-CR) ───────────────────────────────────
    DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' +
        CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Incomes) AS NVARCHAR), 6);

    INSERT INTO Incomes (
        IncomeId, Date, Mode, Head,
        FundPool, FundPoolName,
        Amount,
        Purpose, Source, SourceRef,
        CampId, CampName,
        ContractId, ContractCode,
        TenantId, TenantName,
        TxnRecordId,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @IncomeId,
        @PaidDate,
        ISNULL(NULLIF(@PaymentMode, ''), 'Cash'),
        'Security Deposit',                              -- Head
        ISNULL(NULLIF(@FundPoolCode, ''), 'MAIN'),
        @ActualFundPoolName,                             -- ← DB se actual name
        @Amount,
        'Security Deposit Received | Contract: ' + @ContractId
            + ' | Tenant: ' + @TenantName
            + ' | TxnId: '  + @TxnId
            + CASE WHEN ISNULL(@Notes,'') <> '' THEN ' | ' + @Notes ELSE '' END,
        'SecurityDeposit',                               -- Source
        @ContractId,                                     -- SourceRef
        @CampId,
        @CampName,
        @ContractId,
        @ContractId,
        @TenantId,
        @TenantName,
        @TxnRecordId,                                    -- links to TxnRecords.Id
        GETDATE(), GETDATE()
    );

    -- ── Step 7: Per-room Security distribution ────────────────────────────
    -- Total SecurityAmount in ContractRooms for this contract
    DECLARE @TotalRoomSecurity DECIMAL(18,2) = 0;
    SELECT @TotalRoomSecurity = ISNULL(SUM(SecurityAmount), 0)
    FROM ContractRooms
    WHERE ContractId = @ContractId AND ISNULL(IsDeleted, 0) = 0;

    IF @TotalRoomSecurity > 0
    BEGIN
        -- Temp table: per-room proportional share
        CREATE TABLE #RoomSD (
            RoomId           INT,
            CampId           INT,
            RoomNo           NVARCHAR(MAX),
            CampName         NVARCHAR(MAX),
            SecurityAmount   DECIMAL(18,2),
            ProportionalAmt  DECIMAL(18,2),
            RowNum           INT
        );

        -- Get room count for last-row remainder fix
        DECLARE @RoomCount INT;
        SELECT @RoomCount = COUNT(*)
        FROM ContractRooms
        WHERE ContractId = @ContractId AND ISNULL(IsDeleted, 0) = 0;

        INSERT INTO #RoomSD (RoomId, CampId, RoomNo, CampName, SecurityAmount, ProportionalAmt, RowNum)
        SELECT
            cr.RoomId,
            cr.CampId,
            ISNULL(r.RoomNo, 'Room-' + CAST(cr.RoomId AS NVARCHAR)),
            ISNULL(ca.Name, ''),
            cr.SecurityAmount,
            -- proportional share: room's % of total security × payment amount
            ROUND(cr.SecurityAmount / @TotalRoomSecurity * @Amount, 2),
            ROW_NUMBER() OVER (ORDER BY cr.RoomId)
        FROM ContractRooms cr
        LEFT JOIN Rooms r  ON r.Id  = cr.RoomId
        LEFT JOIN Camps ca ON ca.Id = cr.CampId
        WHERE cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted, 0) = 0;

        -- Fix last room rounding: give it the remainder
        DECLARE @SumExceptLast DECIMAL(18,2);
        SELECT @SumExceptLast = ISNULL(SUM(ProportionalAmt), 0)
        FROM #RoomSD WHERE RowNum < @RoomCount;

        UPDATE #RoomSD
        SET ProportionalAmt = ROUND(@Amount - @SumExceptLast, 2)
        WHERE RowNum = @RoomCount;

        -- ── Step 7a: UPDATE ContractRooms security columns ────────────────
        UPDATE cr
        SET
            cr.SecurityPaidAmount = ISNULL(cr.SecurityPaidAmount, 0) + rsd.ProportionalAmt,
            cr.SecurityDueAmount  = CASE
                WHEN (ISNULL(cr.SecurityAmount, 0) - (ISNULL(cr.SecurityPaidAmount, 0) + rsd.ProportionalAmt)) < 0
                THEN 0
                ELSE ISNULL(cr.SecurityAmount, 0) - (ISNULL(cr.SecurityPaidAmount, 0) + rsd.ProportionalAmt)
            END,
            cr.SecurityPaidDate   = @PaidDate,
            cr.UpdatedAt          = GETDATE()
        FROM ContractRooms cr
        INNER JOIN #RoomSD rsd ON rsd.RoomId = cr.RoomId
        WHERE cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted, 0) = 0;

        -- ── Step 7b: INSERT ContractRoomsTrns (SD-CR per room) ────────────
        -- Month column format: Jul26, Aug26 etc.
        DECLARE @MonthName NVARCHAR(10) =
            CASE MONTH(@PaidDate)
                WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
            END + RIGHT(CAST(YEAR(@PaidDate) AS NVARCHAR), 2);

        INSERT INTO ContractRoomsTrns (
            ContractId, RoomId, CampId,
            TxnType,
            TxnRecordId,
            TotalAmount, Amount,
            TxnDate,
            Month,
            PaymentMode,
            Description,
            CreatedAt, UpdatedAt
        )
        SELECT
            @ContractId,
            rsd.RoomId,
            rsd.CampId,
            'SD-CR',                -- ← Security Deposit Credit
            @TxnRecordId,           -- ← links to TxnRecords.Id
            rsd.ProportionalAmt,    -- TotalAmount = this room's share
            rsd.ProportionalAmt,    -- Amount = same
            @PaidDate,              -- TxnDate
            @MonthName,             -- 'Jul26' format
            ISNULL(@PaymentMode, 'Cash'),
            'Security Deposit Received | Camp: ' + rsd.CampName
                + ' | Room: ' + rsd.RoomNo
                + ' | ' + ISNULL(@Notes, ''),
            GETDATE(), GETDATE()
        FROM #RoomSD rsd;

        DROP TABLE #RoomSD;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ 123 - sp_ReceiveSecurityDeposit updated:';
PRINT '        Incomes:          SD-CR income entry inserted';
PRINT '        ContractRooms:    SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate updated';
PRINT '        ContractRoomsTrns: SD-CR row per room inserted (Camp, Room, Amount, Date)';
GO
