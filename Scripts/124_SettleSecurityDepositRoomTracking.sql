-- ============================================================
-- 124: Update sp_SettleSecurityDeposit
-- Changes:
--
--   REFUND (SD-REF):
--     1. TxnRecords      → INSERT TxnType='SD-REF'   (same as before)
--     2. FundPools       → Balance -= refundAmount    (same as before)
--     3. Expenses        → INSERT (refund = company ka kharcha) ← NEW
--     4. ContractRoomsTrns → INSERT TxnType='SD-REF' per room  ← NEW
--
--   FORFEIT/PENALTY (SD-FRF):
--     5. TxnRecords      → INSERT TxnType='SD-FRF'   (same as before)
--     6. ContractRoomsTrns → INSERT TxnType='SD-FRF' per room  ← NEW
--     7. Incomes         → ❌ REMOVED (penalty ab income nahi)
--     8. FundPools       → ❌ REMOVED (forfeit pe pool update nahi)
--
--   ALWAYS:
--     9. Contracts       → UPDATE SecurityDepositStatus
--
-- Room distribution: proportional to room's SecurityAmount
-- Last room gets remainder to avoid rounding loss
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_SettleSecurityDeposit
    @ContractId    NVARCHAR(MAX),
    @AdjustAmount  DECIMAL(18,2) = 0,
    @RefundAmount  DECIMAL(18,2) = 0,
    @ForfeitAmount DECIMAL(18,2) = 0,
    @FundPoolId    INT           = NULL,
    @FundPoolName  NVARCHAR(MAX) = '',
    @Notes         NVARCHAR(MAX) = '',
    @SettledBy     NVARCHAR(MAX) = 'Admin',
    @NewStatus     NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Step 1: Validate & fetch contract info ─────────────────────────────
    DECLARE @DepositPaid  DECIMAL(18,2),
            @TenantId     INT,
            @TenantName   NVARCHAR(MAX) = '',
            @CampId       INT,
            @CampName     NVARCHAR(MAX) = '',
            @FPCode       NVARCHAR(MAX) = '',
            @ActualFPName NVARCHAR(MAX) = '';

    SELECT
        @DepositPaid = ISNULL(c.SecurityDepositPaid, 0),
        @TenantId    = c.TenantId,
        @CampId      = ISNULL((
            SELECT TOP 1 cc.CampId FROM ContractCamps cc
            WHERE cc.ContractId = c.ContractId AND ISNULL(cc.IsDeleted,0)=0
            ORDER BY cc.Id
        ), 0),
        @CampName    = ISNULL((
            SELECT TOP 1 ca.Name FROM ContractCamps cc
            JOIN Camps ca ON ca.Id = cc.CampId AND ca.IsDeleted = 0
            WHERE cc.ContractId = c.ContractId AND ISNULL(cc.IsDeleted,0)=0
            ORDER BY cc.Id
        ), '')
    FROM Contracts c
    WHERE c.ContractId = @ContractId AND c.IsDeleted = 0;

    IF @TenantId IS NULL
    BEGIN RAISERROR('Contract %s not found.', 16, 1, @ContractId); RETURN; END

    SELECT @TenantName = ISNULL(Name, '') FROM Tenants WHERE Id = @TenantId;

    -- FundPool: DB se actual Code aur Name
    IF @FundPoolId IS NOT NULL
    BEGIN
        SELECT @FPCode = ISNULL(Code, ''), @ActualFPName = ISNULL(Name, '')
        FROM FundPools WHERE Id = @FundPoolId AND IsDeleted = 0;
    END
    IF @ActualFPName = ''
        SET @ActualFPName = ISNULL(NULLIF(@FundPoolName,''), '');

    DECLARE @TotalSettled DECIMAL(18,2) = @AdjustAmount + @RefundAmount + @ForfeitAmount;
    IF @TotalSettled > @DepositPaid
    BEGIN
        DECLARE @ErrMsg NVARCHAR(MAX) = 'Settlement total (' + CAST(@TotalSettled AS NVARCHAR)
            + ') exceeds deposit paid (' + CAST(@DepositPaid AS NVARCHAR) + ').';
        RAISERROR(@ErrMsg, 16, 1); RETURN;
    END

    -- Month format: Jul26
    DECLARE @MonthName NVARCHAR(10) =
        CASE MONTH(GETDATE())
            WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
            WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
            WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
            WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
        END + RIGHT(CAST(YEAR(GETDATE()) AS NVARCHAR), 2);

    -- ── Room distribution helper ───────────────────────────────────────────
    -- Build #RoomDist once — used for both SD-REF and SD-FRF rows
    DECLARE @TotalRoomSecurity DECIMAL(18,2) = 0;
    SELECT @TotalRoomSecurity = ISNULL(SUM(SecurityAmount), 0)
    FROM ContractRooms
    WHERE ContractId = @ContractId AND ISNULL(IsDeleted,0) = 0;

    CREATE TABLE #RoomDist (
        RoomId         INT,
        CampId         INT,
        RoomNo         NVARCHAR(MAX),
        CampName       NVARCHAR(MAX),
        SecurityAmount DECIMAL(18,2),
        RowNum         INT
    );

    DECLARE @RoomCount INT = 0;
    SELECT @RoomCount = COUNT(*)
    FROM ContractRooms
    WHERE ContractId = @ContractId AND ISNULL(IsDeleted,0) = 0;

    IF @RoomCount > 0 AND @TotalRoomSecurity > 0
    BEGIN
        INSERT INTO #RoomDist (RoomId, CampId, RoomNo, CampName, SecurityAmount, RowNum)
        SELECT
            cr.RoomId,
            cr.CampId,
            ISNULL(r.RoomNo, 'Room-' + CAST(cr.RoomId AS NVARCHAR)),
            ISNULL(ca.Name, ''),
            ISNULL(cr.SecurityAmount, 0),
            ROW_NUMBER() OVER (ORDER BY cr.RoomId)
        FROM ContractRooms cr
        LEFT JOIN Rooms r  ON r.Id  = cr.RoomId
        LEFT JOIN Camps ca ON ca.Id = cr.CampId
        WHERE cr.ContractId = @ContractId AND ISNULL(cr.IsDeleted,0) = 0;
    END

    -- ════════════════════════════════════════════════════════════════════════
    -- CASE A: ADJUST (SD-ADJ) — unchanged, just TxnRecord
    -- ════════════════════════════════════════════════════════════════════════
    IF @AdjustAmount > 0
    BEGIN
        DECLARE @AdjSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0),0)+1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount, PaidDate,
            Description, ReceivedBy, IssuedBy,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-SD-ADJ-' + RIGHT('000000'+CAST(@AdjSeq AS NVARCHAR),6),
            'SD-ADJ', @ContractId, @ContractId,
            @TenantId, @CampId, @AdjustAmount, @AdjustAmount, CAST(GETDATE() AS DATE),
            'Security Deposit adjusted against rent dues - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            0, GETDATE(), GETDATE()
        );
    END

    -- ════════════════════════════════════════════════════════════════════════
    -- CASE B: REFUND (SD-REF)
    -- ════════════════════════════════════════════════════════════════════════
    IF @RefundAmount > 0
    BEGIN
        -- ── B1: TxnRecord SD-REF ──────────────────────────────────────────
        DECLARE @RefSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0),0)+1;
        DECLARE @RefTxnId NVARCHAR(MAX) = 'TXN-SD-REF-' + RIGHT('000000'+CAST(@RefSeq AS NVARCHAR),6);
        DECLARE @RefTxnRecordId INT;

        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount, PaidDate,
            Description, ReceivedBy, IssuedBy,
            FundPoolId, FundPoolName,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            @RefTxnId, 'SD-REF', @ContractId, @ContractId,
            @TenantId, @CampId, @RefundAmount, @RefundAmount, CAST(GETDATE() AS DATE),
            'Security Deposit refunded to tenant - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            @FundPoolId, @ActualFPName,
            0, GETDATE(), GETDATE()
        );
        SET @RefTxnRecordId = SCOPE_IDENTITY();

        -- ── B2: FundPool Balance -= refundAmount ──────────────────────────
        IF @FundPoolId IS NOT NULL
            UPDATE FundPools
            SET Balance = Balance - @RefundAmount, UpdatedAt = GETDATE()
            WHERE Id = @FundPoolId AND IsDeleted = 0;

        -- ── B3: Expenses INSERT (refund = company ka kharcha) ── NEW ──────
        DECLARE @ExpSeq  INT          = ISNULL((SELECT MAX(Id) FROM Expenses WHERE ISNULL(IsDeleted,0)=0),0)+1;
        DECLARE @ExpenseId NVARCHAR(MAX) = 'EXP-' + RIGHT('000000'+CAST(@ExpSeq AS NVARCHAR),6);

        INSERT INTO Expenses(
            ExpenseId, Date, Mode, Head,
            FundPool, FundPoolName,
            Amount, Nature,
            CampId, CampName,
            RecipientRole, RecipientName,
            Purpose,
            CreatedAt, UpdatedAt
        )
        VALUES(
            @ExpenseId,
            CAST(GETDATE() AS DATE),
            'System',
            'SD',           -- Head = SD for refund
            ISNULL(NULLIF(@FPCode,''),'MAIN'),
            @ActualFPName,
            @RefundAmount,
            'SD',                                -- Nature
            @CampId,
            @CampName,
            'Tenant',                            -- RecipientRole
            @TenantName,                         -- RecipientName
            'Security Deposit refunded to tenant'
                + ' | Contract: ' + @ContractId
                + ' | Tenant: '   + @TenantName
                + CASE WHEN ISNULL(@Notes,'') <> '' THEN ' | ' + @Notes ELSE '' END,
            GETDATE(), GETDATE()
        );

        -- ── B4: ContractRoomsTrns SD-REF per room (proportional) ── NEW ──
        IF @RoomCount > 0 AND @TotalRoomSecurity > 0
        BEGIN
            -- Calculate proportional refund per room
            CREATE TABLE #RefRoomAmt (
                RoomId          INT,
                CampId          INT,
                RoomNo          NVARCHAR(MAX),
                CampName        NVARCHAR(MAX),
                ProportionalAmt DECIMAL(18,2),
                RowNum          INT
            );

            INSERT INTO #RefRoomAmt (RoomId, CampId, RoomNo, CampName, ProportionalAmt, RowNum)
            SELECT
                RoomId, CampId, RoomNo, CampName,
                ROUND(SecurityAmount / @TotalRoomSecurity * @RefundAmount, 2),
                RowNum
            FROM #RoomDist;

            -- Last room gets remainder
            DECLARE @RefSumExceptLast DECIMAL(18,2);
            SELECT @RefSumExceptLast = ISNULL(SUM(ProportionalAmt),0)
            FROM #RefRoomAmt WHERE RowNum < @RoomCount;

            UPDATE #RefRoomAmt
            SET ProportionalAmt = ROUND(@RefundAmount - @RefSumExceptLast, 2)
            WHERE RowNum = @RoomCount;

            INSERT INTO ContractRoomsTrns(
                ContractId, RoomId, CampId,
                TxnType, TxnRecordId,
                TotalAmount, Amount, TxnDate, Month,
                PaymentMode, Description,
                CreatedAt, UpdatedAt
            )
            SELECT
                @ContractId, rr.RoomId, rr.CampId,
                'SD-REF', @RefTxnRecordId,
                rr.ProportionalAmt, rr.ProportionalAmt,
                CAST(GETDATE() AS DATE), @MonthName,
                'System',
                'Security Deposit Refunded | Camp: ' + rr.CampName
                    + ' | Room: ' + rr.RoomNo
                    + ' | ' + ISNULL(@Notes,''),
                GETDATE(), GETDATE()
            FROM #RefRoomAmt rr;

            DROP TABLE #RefRoomAmt;
        END
    END

    -- ════════════════════════════════════════════════════════════════════════
    -- CASE C: FORFEIT / PENALTY (SD-FRF)
    -- ════════════════════════════════════════════════════════════════════════
    IF @ForfeitAmount > 0
    BEGIN
        -- ── C1: TxnRecord SD-FRF ──────────────────────────────────────────
        DECLARE @FrfSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0),0)+1;
        DECLARE @FrfTxnId NVARCHAR(MAX) = 'TXN-SD-FRF-' + RIGHT('000000'+CAST(@FrfSeq AS NVARCHAR),6);
        DECLARE @FrfTxnRecordId INT;

        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount, PaidDate,
            Description, ReceivedBy, IssuedBy,
            FundPoolId, FundPoolName,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            @FrfTxnId, 'SD-FRF', @ContractId, @ContractId,
            @TenantId, @CampId, @ForfeitAmount, @ForfeitAmount, CAST(GETDATE() AS DATE),
            'Security Deposit forfeited (penalty/damage) - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            @FundPoolId, @ActualFPName,
            0, GETDATE(), GETDATE()
        );
        SET @FrfTxnRecordId = SCOPE_IDENTITY();

        -- ── C2: Incomes  → ❌ REMOVED (penalty income nahi hai)
        -- ── C3: FundPools update on forfeit → ❌ REMOVED

        -- ── C4: ContractRoomsTrns SD-FRF per room (proportional) ── NEW ──
        IF @RoomCount > 0 AND @TotalRoomSecurity > 0
        BEGIN
            CREATE TABLE #FrfRoomAmt (
                RoomId          INT,
                CampId          INT,
                RoomNo          NVARCHAR(MAX),
                CampName        NVARCHAR(MAX),
                ProportionalAmt DECIMAL(18,2),
                RowNum          INT
            );

            INSERT INTO #FrfRoomAmt (RoomId, CampId, RoomNo, CampName, ProportionalAmt, RowNum)
            SELECT
                RoomId, CampId, RoomNo, CampName,
                ROUND(SecurityAmount / @TotalRoomSecurity * @ForfeitAmount, 2),
                RowNum
            FROM #RoomDist;

            -- Last room gets remainder
            DECLARE @FrfSumExceptLast DECIMAL(18,2);
            SELECT @FrfSumExceptLast = ISNULL(SUM(ProportionalAmt),0)
            FROM #FrfRoomAmt WHERE RowNum < @RoomCount;

            UPDATE #FrfRoomAmt
            SET ProportionalAmt = ROUND(@ForfeitAmount - @FrfSumExceptLast, 2)
            WHERE RowNum = @RoomCount;

            INSERT INTO ContractRoomsTrns(
                ContractId, RoomId, CampId,
                TxnType, TxnRecordId,
                TotalAmount, Amount, TxnDate, Month,
                PaymentMode, Description,
                CreatedAt, UpdatedAt
            )
            SELECT
                @ContractId, fr.RoomId, fr.CampId,
                'SD-FRF', @FrfTxnRecordId,
                fr.ProportionalAmt, fr.ProportionalAmt,
                CAST(GETDATE() AS DATE), @MonthName,
                'System',
                'Security Deposit Forfeited (Penalty) | Camp: ' + fr.CampName
                    + ' | Room: ' + fr.RoomNo
                    + ' | ' + ISNULL(@Notes,''),
                GETDATE(), GETDATE()
            FROM #FrfRoomAmt fr;

            DROP TABLE #FrfRoomAmt;
        END
    END

    -- ── Cleanup room dist temp table ───────────────────────────────────────
    IF OBJECT_ID('tempdb..#RoomDist') IS NOT NULL DROP TABLE #RoomDist;

    -- ════════════════════════════════════════════════════════════════════════
    -- STEP FINAL: UPDATE Contracts.SecurityDepositStatus
    -- ════════════════════════════════════════════════════════════════════════
    SET @NewStatus = CASE
        WHEN @RefundAmount  > 0 AND @ForfeitAmount = 0 AND @AdjustAmount = 0 THEN 'Refunded'
        WHEN @AdjustAmount  > 0 AND @ForfeitAmount = 0 AND @RefundAmount  = 0 THEN 'Adjusted'
        WHEN @ForfeitAmount > 0 AND @RefundAmount  = 0 AND @AdjustAmount  = 0 THEN 'Forfeited'
        ELSE 'Settled'
    END;

    UPDATE Contracts
    SET SecurityDepositStatus = @NewStatus, UpdatedAt = GETDATE()
    WHERE ContractId = @ContractId AND IsDeleted = 0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#RoomDist')   IS NOT NULL DROP TABLE #RoomDist;
        IF OBJECT_ID('tempdb..#RefRoomAmt') IS NOT NULL DROP TABLE #RefRoomAmt;
        IF OBJECT_ID('tempdb..#FrfRoomAmt') IS NOT NULL DROP TABLE #FrfRoomAmt;
        THROW;
    END CATCH
END
GO

PRINT '✅ 124 - sp_SettleSecurityDeposit updated:';
PRINT '   REFUND:  TxnRecords(SD-REF) + FundPool(-) + Expenses + ContractRoomsTrns(SD-REF per room)';
PRINT '   FORFEIT: TxnRecords(SD-FRF) + ContractRoomsTrns(SD-FRF per room)';
PRINT '            [Incomes REMOVED] [FundPool update REMOVED on forfeit]';
GO
