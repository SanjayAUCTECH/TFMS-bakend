-- ============================================================
-- 105: Fix sp_SettleSecurityDeposit
-- Bugs fixed:
--   1. ContractRoomsTrns.TxnRecordId is INT but string was passed
--   2. Missing IsDeleted=0 filters on Contracts, Tenants, ContractCamps, Camps
--   3. Penalty (ForfeitAmount) → Income entry + TxnRecord proper
--   4. FundPool deduction on forfeit added (if fundPoolId provided)
--   5. ContractRoomsTrns insert removed (not needed for SD settlement)
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

    -- Fetch contract info (IsDeleted=0 filter added)
    DECLARE @DepositPaid DECIMAL(18,2), @TenantId INT,
            @CampId INT, @CampName NVARCHAR(MAX), @FPCode NVARCHAR(MAX)='';

    SELECT
        @DepositPaid = ISNULL(c.SecurityDepositPaid, 0),
        @TenantId    = c.TenantId,
        @CampId      = ISNULL((
            SELECT TOP 1 cc.CampId FROM ContractCamps cc
            WHERE cc.ContractId=c.ContractId AND ISNULL(cc.IsDeleted,0)=0
            ORDER BY cc.Id
        ), 0),
        @CampName    = ISNULL((
            SELECT TOP 1 ca.Name FROM ContractCamps cc
            JOIN Camps ca ON ca.Id=cc.CampId AND ca.IsDeleted=0
            WHERE cc.ContractId=c.ContractId AND ISNULL(cc.IsDeleted,0)=0
            ORDER BY cc.Id
        ), '')
    FROM Contracts c
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0;

    IF @TenantId IS NULL
    BEGIN RAISERROR('Contract %s not found.', 16, 1, @ContractId); RETURN; END

    DECLARE @TotalSettled DECIMAL(18,2) = @AdjustAmount + @RefundAmount + @ForfeitAmount;
    IF @TotalSettled > @DepositPaid
    BEGIN
        DECLARE @Msg NVARCHAR(MAX) = 'Settlement total (' + CAST(@TotalSettled AS NVARCHAR)
            + ') exceeds deposit paid (' + CAST(@DepositPaid AS NVARCHAR) + ').';
        RAISERROR(@Msg, 16, 1); RETURN;
    END

    IF @FundPoolId IS NOT NULL
        SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId AND IsDeleted=0;

    -- ── 1. Adjust against rent dues (SD-ADJ) ─────────────────────
    IF @AdjustAmount > 0
    BEGIN
        DECLARE @AdjSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-SD-ADJ-' + RIGHT('000000' + CAST(@AdjSeq AS NVARCHAR), 6),
            'SD-ADJ', @ContractId, @ContractId,
            @TenantId, @CampId, @AdjustAmount, @AdjustAmount,
            GETDATE(),
            'Security Deposit adjusted against rent dues - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            0, GETDATE(), GETDATE()
        );
    END

    -- ── 2. Refund to tenant (SD-REF) ─────────────────────────────
    IF @RefundAmount > 0
    BEGIN
        DECLARE @RefSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            FundPoolId, FundPoolName,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-SD-REF-' + RIGHT('000000' + CAST(@RefSeq AS NVARCHAR), 6),
            'SD-REF', @ContractId, @ContractId,
            @TenantId, @CampId, @RefundAmount, @RefundAmount,
            GETDATE(),
            'Security Deposit refunded to tenant - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            @FundPoolId, ISNULL(@FundPoolName,''),
            0, GETDATE(), GETDATE()
        );

        -- Deduct from FundPool on refund
        IF @FundPoolId IS NOT NULL
            UPDATE FundPools
            SET Balance=Balance - @RefundAmount, UpdatedAt=GETDATE()
            WHERE Id=@FundPoolId AND IsDeleted=0;
    END

    -- ── 3. Forfeit / Penalty (SD-FRF) + Income ───────────────────
    IF @ForfeitAmount > 0
    BEGIN
        DECLARE @FrfSeq  INT = ISNULL((SELECT MAX(Id) FROM TxnRecords WHERE ISNULL(IsDeleted,0)=0), 0) + 1;

        -- TxnRecord for forfeit
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            FundPoolId, FundPoolName,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-SD-FRF-' + RIGHT('000000' + CAST(@FrfSeq AS NVARCHAR), 6),
            'SD-FRF', @ContractId, @ContractId,
            @TenantId, @CampId, @ForfeitAmount, @ForfeitAmount,
            GETDATE(),
            'Security Deposit forfeited (penalty/damage) - ' + ISNULL(@Notes,''),
            @SettledBy, @SettledBy,
            @FundPoolId, ISNULL(@FundPoolName,''),
            0, GETDATE(), GETDATE()
        );

        -- Penalty → Income entry (company ke liye income)
        DECLARE @IncSeq  INT          = ISNULL((SELECT MAX(Id) FROM Incomes WHERE ISNULL(IsDeleted,0)=0), 0) + 1;
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST(@IncSeq AS NVARCHAR), 6);
        INSERT INTO Incomes(
            IncomeId, Date, Mode, Head,
            FundPool, FundPoolName,
            Amount, Purpose, Source, SourceRef,
            ContractId, ContractCode, CampId, CampName,
            IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES(
            @IncomeId, CAST(GETDATE() AS DATE), 'System', 'Security Deposit Penalty',
            ISNULL(@FPCode,''), ISNULL(@FundPoolName,''),
            @ForfeitAmount,
            'Security deposit forfeited - ' + @ContractId + ' - ' + ISNULL(@Notes,''),
            'SecurityDeposit', @ContractId,
            @ContractId, @ContractId, @CampId, @CampName,
            0, GETDATE(), GETDATE()
        );

        -- Add to FundPool on forfeit (company receives money)
        IF @FundPoolId IS NOT NULL
            UPDATE FundPools
            SET Balance=Balance + @ForfeitAmount, UpdatedAt=GETDATE()
            WHERE Id=@FundPoolId AND IsDeleted=0;
    END

    -- ── 4. Update Contract status ─────────────────────────────────
    SET @NewStatus = CASE
        WHEN @RefundAmount  > 0 AND @ForfeitAmount=0 AND @AdjustAmount=0 THEN 'Refunded'
        WHEN @AdjustAmount  > 0 AND @ForfeitAmount=0 AND @RefundAmount =0 THEN 'Adjusted'
        WHEN @ForfeitAmount > 0 AND @RefundAmount =0 AND @AdjustAmount =0 THEN 'Forfeited'
        ELSE 'Settled'
    END;

    UPDATE Contracts
    SET SecurityDepositStatus=@NewStatus, UpdatedAt=GETDATE()
    WHERE ContractId=@ContractId AND IsDeleted=0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_SettleSecurityDeposit fixed - INT conversion error resolved + IsDeleted filters added';
GO
