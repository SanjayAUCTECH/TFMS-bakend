-- ============================================================
-- 125: Fix sp_ReceiveSecurityDeposit — Missing Column Guard
--
-- Problem: Script 123 ka SP sahi hai but DB mein run nahi hua tha
--          + ContractRooms mein Security columns exist nahi karte
--          + Incomes mein TxnRecordId, ContractId, TenantId etc missing
--          + ContractRoomsTrns mein TxnType, TxnDate, Month etc missing
--
-- This script:
--  STEP 1: ContractRooms    — add missing Security columns (safe IF NOT EXISTS)
--  STEP 2: Incomes          — add missing columns (safe IF NOT EXISTS)
--  STEP 3: ContractRoomsTrns— add missing columns (safe IF NOT EXISTS)
--  STEP 4: Recreate sp_ReceiveSecurityDeposit with all new logic
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- STEP 1: ContractRooms — Security columns add karo
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='SecurityAmount')
    ALTER TABLE ContractRooms ADD SecurityAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='SecurityPaidAmount')
    ALTER TABLE ContractRooms ADD SecurityPaidAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='SecurityDueAmount')
    ALTER TABLE ContractRooms ADD SecurityDueAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRooms') AND name='SecurityPaidDate')
    ALTER TABLE ContractRooms ADD SecurityPaidDate DATE NULL;
GO

PRINT '✅ STEP 1: ContractRooms security columns ready';
GO

-- ══════════════════════════════════════════════════════════════
-- STEP 2: Incomes — missing columns add karo
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TxnRecordId')
    ALTER TABLE Incomes ADD TxnRecordId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='ContractId')
    ALTER TABLE Incomes ADD ContractId NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='ContractCode')
    ALTER TABLE Incomes ADD ContractCode NVARCHAR(MAX) NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TenantId')
    ALTER TABLE Incomes ADD TenantId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TenantName')
    ALTER TABLE Incomes ADD TenantName NVARCHAR(MAX) NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='CampId')
    ALTER TABLE Incomes ADD CampId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='CampName')
    ALTER TABLE Incomes ADD CampName NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='IsDeleted')
    ALTER TABLE Incomes ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO

PRINT '✅ STEP 2: Incomes columns ready';
GO

-- ══════════════════════════════════════════════════════════════
-- STEP 3: ContractRoomsTrns — missing columns add karo
-- ══════════════════════════════════════════════════════════════
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='TxnType')
    ALTER TABLE ContractRoomsTrns ADD TxnType NVARCHAR(50) NULL DEFAULT 'CR';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='TotalAmount')
    ALTER TABLE ContractRoomsTrns ADD TotalAmount DECIMAL(18,2) NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='TxnDate')
    ALTER TABLE ContractRoomsTrns ADD TxnDate DATE NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='Month')
    ALTER TABLE ContractRoomsTrns ADD Month NVARCHAR(10) NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='InstallmentNo')
    ALTER TABLE ContractRoomsTrns ADD InstallmentNo INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('ContractRoomsTrns') AND name='CriId')
    ALTER TABLE ContractRoomsTrns ADD CriId INT NULL;
GO

PRINT '✅ STEP 3: ContractRoomsTrns columns ready';
GO

-- ══════════════════════════════════════════════════════════════
-- STEP 4: Recreate sp_ReceiveSecurityDeposit
-- ══════════════════════════════════════════════════════════════
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
    @NewPaid       DECIMAL(18,2)  OUTPUT,
    @NewStatus     NVARCHAR(MAX)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Step 1: Validate ──────────────────────────────────────────────────
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

    -- ── Step 2: New status ────────────────────────────────────────────────
    SET @NewPaid   = @DepositPaid + @Amount;
    SET @NewStatus = CASE WHEN @NewPaid >= @DepositAmount THEN 'Received' ELSE 'Partially Received' END;

    -- ── Step 3: UPDATE Contracts ──────────────────────────────────────────
    UPDATE Contracts
    SET SecurityDepositPaid   = @NewPaid,
        SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    -- ── Step 4: UPDATE FundPool ───────────────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

    -- ── Step 5: Generate TxnId + fetch CampId ────────────────────────────
    DECLARE @TxnSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
    DECLARE @TxnId  NVARCHAR(MAX) = 'TXN-' + CONVERT(NVARCHAR, @PaidDate, 112)
                                    + '-' + RIGHT('000000' + CAST(@TxnSeq AS NVARCHAR), 6);
    DECLARE @CampId INT = ISNULL(
        (SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId ORDER BY Id), 0);

    -- ── Step 6: INSERT TxnRecords (SD-CR) ────────────────────────────────
    DECLARE @TxnRecordId INT;
    INSERT INTO TxnRecords(
        TxnId, TxnType, ContractId, ContractCode,
        TenantId, CampId, TotalAmount, Amount,
        PaidDate, PaymentMode, PaymentModeId, ChequeNumber,
        Description, ReceivedBy, IssuedBy,
        FundPoolId, FundPoolName,
        CreatedAt, UpdatedAt
    )
    VALUES(
        @TxnId, 'SD-CR', @ContractId, @ContractId,
        @TenantId, @CampId, @Amount, @Amount,
        @PaidDate, ISNULL(@PaymentMode,'Cash'), @PaymentModeId, ISNULL(@ChequeNumber,''),
        'Security Deposit Received - ' + ISNULL(@Notes,''),
        @ReceivedBy, @ReceivedBy,
        @FundPoolId, ISNULL(@FundPoolName,''),
        GETDATE(), GETDATE()
    );
    SET @TxnRecordId = SCOPE_IDENTITY();

    -- ── Step 7: Fetch Tenant, Camp, FundPool info for Incomes ────────────
    DECLARE @TenantName     NVARCHAR(MAX) = '';
    DECLARE @CampName       NVARCHAR(MAX) = '';
    DECLARE @FPCode         NVARCHAR(MAX) = '';
    DECLARE @ActualFPName   NVARCHAR(MAX) = '';

    SELECT @TenantName = ISNULL(Name,'') FROM Tenants WHERE Id = @TenantId;

    SELECT TOP 1 @CampName = ISNULL(ca.Name,'')
    FROM ContractCamps cc
    LEFT JOIN Camps ca ON ca.Id = cc.CampId
    WHERE cc.ContractId = @ContractId
    ORDER BY cc.Id;

    IF @FundPoolId IS NOT NULL
        SELECT @FPCode = ISNULL(Code,''), @ActualFPName = ISNULL(Name,'')
        FROM FundPools WHERE Id = @FundPoolId;

    IF @ActualFPName = ''
        SET @ActualFPName = ISNULL(NULLIF(@FundPoolName,''),'');

    -- ── Step 8: INSERT Incomes (SD-CR) ────────────────────────────────────
    DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' +
        CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR), 6);

    INSERT INTO Incomes(
        IncomeId, Date, Mode, Head,
        FundPool, FundPoolName,
        Amount, Purpose, Source, SourceRef,
        CampId, CampName,
        ContractId, ContractCode,
        TenantId, TenantName,
        TxnRecordId,
        IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @IncomeId, @PaidDate,
        ISNULL(NULLIF(@PaymentMode,''),'Cash'),
        'Security Deposit',
        ISNULL(NULLIF(@FPCode,''),'MAIN'),
        @ActualFPName,
        @Amount,
        'Security Deposit Received | Contract: ' + @ContractId
            + ' | Tenant: ' + @TenantName
            + ' | TxnId: '  + @TxnId
            + CASE WHEN ISNULL(@Notes,'') <> '' THEN ' | ' + @Notes ELSE '' END,
        'SecurityDeposit', @ContractId,
        @CampId, @CampName,
        @ContractId, @ContractId,
        @TenantId, @TenantName,
        @TxnRecordId,
        0, GETDATE(), GETDATE()
    );

    -- ── Step 9: Per-room distribution ─────────────────────────────────────
    DECLARE @TotalRoomSecurity DECIMAL(18,2) = 0;
    SELECT @TotalRoomSecurity = ISNULL(SUM(ISNULL(SecurityAmount,0)), 0)
    FROM ContractRooms
    WHERE ContractId = @ContractId AND ISNULL(IsDeleted,0) = 0;

    IF @TotalRoomSecurity > 0
    BEGIN
        DECLARE @RoomCount INT;
        SELECT @RoomCount = COUNT(*) FROM ContractRooms
        WHERE ContractId = @ContractId AND ISNULL(IsDeleted,0) = 0;

        CREATE TABLE #RoomSD(
            RoomId          INT,
            RoomCampId      INT,
            RoomNo          NVARCHAR(MAX),
            RoomCampName    NVARCHAR(MAX),
            SecurityAmount  DECIMAL(18,2),
            ProportionalAmt DECIMAL(18,2),
            RowNum          INT
        );

        INSERT INTO #RoomSD(RoomId, RoomCampId, RoomNo, RoomCampName, SecurityAmount, ProportionalAmt, RowNum)
        SELECT
            cr.RoomId,
            cr.CampId,
            ISNULL(r.RoomNo, 'Room-' + CAST(cr.RoomId AS NVARCHAR)),
            ISNULL(ca.Name,''),
            ISNULL(cr.SecurityAmount, 0),
            ROUND(ISNULL(cr.SecurityAmount,0) / @TotalRoomSecurity * @Amount, 2),
            ROW_NUMBER() OVER (ORDER BY cr.RoomId)
        FROM ContractRooms cr
        LEFT JOIN Rooms r  ON r.Id  = cr.RoomId
        LEFT JOIN Camps ca ON ca.Id = cr.CampId
        WHERE cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted,0) = 0;

        -- Last room remainder fix
        DECLARE @SumExceptLast DECIMAL(18,2);
        SELECT @SumExceptLast = ISNULL(SUM(ProportionalAmt),0) FROM #RoomSD WHERE RowNum < @RoomCount;
        UPDATE #RoomSD SET ProportionalAmt = ROUND(@Amount - @SumExceptLast, 2) WHERE RowNum = @RoomCount;

        -- Step 9a: UPDATE ContractRooms
        UPDATE cr
        SET
            cr.SecurityPaidAmount = ISNULL(cr.SecurityPaidAmount,0) + rsd.ProportionalAmt,
            cr.SecurityDueAmount  = CASE
                WHEN ISNULL(cr.SecurityAmount,0) - (ISNULL(cr.SecurityPaidAmount,0) + rsd.ProportionalAmt) < 0
                THEN 0
                ELSE ISNULL(cr.SecurityAmount,0) - (ISNULL(cr.SecurityPaidAmount,0) + rsd.ProportionalAmt)
            END,
            cr.SecurityPaidDate   = @PaidDate,
            cr.UpdatedAt          = GETDATE()
        FROM ContractRooms cr
        INNER JOIN #RoomSD rsd ON rsd.RoomId = cr.RoomId
        WHERE cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted,0) = 0;

        -- Step 9b: INSERT ContractRoomsTrns (SD-CR per room)
        DECLARE @MonthName NVARCHAR(10) =
            CASE MONTH(@PaidDate)
                WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
            END + RIGHT(CAST(YEAR(@PaidDate) AS NVARCHAR), 2);

        INSERT INTO ContractRoomsTrns(
            ContractId, RoomId, CampId,
            TxnType, TxnRecordId,
            TotalAmount, Amount, TxnDate, Month,
            PaymentMode, Description,
            CreatedAt, UpdatedAt
        )
        SELECT
            @ContractId, rsd.RoomId, rsd.RoomCampId,
            'SD-CR', @TxnRecordId,
            rsd.ProportionalAmt, rsd.ProportionalAmt,
            @PaidDate, @MonthName,
            ISNULL(@PaymentMode,'Cash'),
            'Security Deposit Received | Camp: ' + rsd.RoomCampName
                + ' | Room: ' + rsd.RoomNo
                + ' | ' + ISNULL(@Notes,''),
            GETDATE(), GETDATE()
        FROM #RoomSD rsd;

        DROP TABLE #RoomSD;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#RoomSD') IS NOT NULL DROP TABLE #RoomSD;
        THROW;
    END CATCH
END
GO

PRINT '✅ 125 - All columns added + sp_ReceiveSecurityDeposit fully updated';
PRINT '   ContractRooms:     SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate';
PRINT '   Incomes:           TxnRecordId, ContractId, TenantId, TenantName, CampId, CampName, IsDeleted';
PRINT '   ContractRoomsTrns: TxnType, TotalAmount, TxnDate, Month, InstallmentNo, CriId';
PRINT '   SP: ContractRooms UPDATE + ContractRoomsTrns INSERT + Incomes INSERT on SD receive';
GO
