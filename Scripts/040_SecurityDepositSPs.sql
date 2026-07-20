-- ============================================================
-- 040: Security Deposit Stored Procedures
--      sp_GetSecurityDepositStatus
--      sp_ReceiveSecurityDeposit
--      sp_SettleSecurityDeposit
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. sp_GetSecurityDepositStatus ───────────────────────────
CREATE OR ALTER PROCEDURE sp_GetSecurityDepositStatus
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.ContractId,
        t.Name                                                          AS TenantName,
        ISNULL(c.SecurityDeposit, 0)                                    AS DepositAmount,
        ISNULL(c.SecurityDepositPaid, 0)                                AS DepositPaid,
        ISNULL(c.SecurityDeposit, 0) - ISNULL(c.SecurityDepositPaid, 0) AS DepositBalance,
        ISNULL(c.SecurityDepositStatus, 'Pending')                      AS Status
    FROM Contracts c
    JOIN Tenants t ON t.Id = c.TenantId
    WHERE c.ContractId = @ContractId;
END
GO

-- ── 2. sp_ReceiveSecurityDeposit ─────────────────────────────
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

    -- Validate contract
    DECLARE @DepositAmount DECIMAL(18,2), @DepositPaid DECIMAL(18,2), @TenantId INT;
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

    SET @NewPaid   = @DepositPaid + @Amount;
    SET @NewStatus = CASE WHEN @NewPaid >= @DepositAmount THEN 'Received' ELSE 'Partially Received' END;

    -- Update Contracts
    UPDATE Contracts
    SET SecurityDepositPaid   = @NewPaid,
        SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    -- Update Fund Pool (add to balance)
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools
        SET Balance   = Balance + @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

    -- Generate TxnId
    DECLARE @TxnSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
    DECLARE @TxnId  NVARCHAR(MAX) = 'TXN-' + CONVERT(NVARCHAR, @PaidDate, 112) + '-' + RIGHT('000000' + CAST(@TxnSeq AS NVARCHAR), 6);
    DECLARE @CampId INT = ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId = @ContractId), 0);

    -- Insert TxnRecord (SD-CR)
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
        @PaidDate, ISNULL(@PaymentMode, 'Cash'), @PaymentModeId, ISNULL(@ChequeNumber, ''),
        'Security Deposit Received - ' + ISNULL(@Notes, ''), @ReceivedBy, @ReceivedBy,
        @FundPoolId, ISNULL(@FundPoolName, ''),
        GETDATE(), GETDATE()
    );

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 3. sp_SettleSecurityDeposit ──────────────────────────────
CREATE OR ALTER PROCEDURE sp_SettleSecurityDeposit
    @ContractId    NVARCHAR(MAX),
    @AdjustAmount  DECIMAL(18,2) = 0,   -- adjust against rent dues
    @RefundAmount  DECIMAL(18,2) = 0,   -- refund to tenant
    @ForfeitAmount DECIMAL(18,2) = 0,   -- forfeit / penalty / damage
    @FundPoolId    INT           = NULL,
    @FundPoolName  NVARCHAR(MAX) = '',
    @Notes         NVARCHAR(MAX) = '',
    @SettledBy     NVARCHAR(MAX) = 'Admin',
    -- OUTPUT
    @NewStatus     NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Fetch contract info
    DECLARE @DepositPaid DECIMAL(18,2), @TenantId INT,
            @CampId INT, @CampName NVARCHAR(MAX);

    SELECT
        @DepositPaid = ISNULL(c.SecurityDepositPaid, 0),
        @TenantId    = c.TenantId,
        @CampId      = ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId = c.ContractId), 0),
        @CampName    = ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc JOIN Camps ca ON ca.Id = cc.CampId WHERE cc.ContractId = c.ContractId), '')
    FROM Contracts c
    WHERE c.ContractId = @ContractId;

    IF @TenantId IS NULL
    BEGIN RAISERROR('Contract not found.', 16, 1); RETURN; END

    DECLARE @TotalSettled DECIMAL(18,2) = @AdjustAmount + @RefundAmount + @ForfeitAmount;
    IF @TotalSettled > @DepositPaid
    BEGIN
        DECLARE @Msg NVARCHAR(MAX) = 'Settlement total (' + CAST(@TotalSettled AS NVARCHAR) + ') exceeds deposit paid (' + CAST(@DepositPaid AS NVARCHAR) + ').';
        RAISERROR(@Msg, 16, 1); RETURN;
    END

    -- ── Adjust against rent dues (SD-ADJ) ──────────────────
    IF @AdjustAmount > 0
    BEGIN
        DECLARE @AdjSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            CreatedAt, UpdatedAt
        )
        VALUES (
            'TXN-SD-ADJ-' + RIGHT('000000' + CAST(@AdjSeq AS NVARCHAR), 6),
            'SD-ADJ', @ContractId, @ContractId,
            @TenantId, @CampId, @AdjustAmount, @AdjustAmount,
            GETDATE(), 'Security Deposit adjusted against rent dues - ' + ISNULL(@Notes, ''),
            @SettledBy, @SettledBy,
            GETDATE(), GETDATE()
        );
    END

    -- ── Refund to tenant (SD-REF) ───────────────────────────
    IF @RefundAmount > 0
    BEGIN
        DECLARE @RefSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            FundPoolId, FundPoolName,
            CreatedAt, UpdatedAt
        )
        VALUES (
            'TXN-SD-REF-' + RIGHT('000000' + CAST(@RefSeq AS NVARCHAR), 6),
            'SD-REF', @ContractId, @ContractId,
            @TenantId, @CampId, @RefundAmount, @RefundAmount,
            GETDATE(), 'Security Deposit refunded to tenant - ' + ISNULL(@Notes, ''),
            @SettledBy, @SettledBy,
            @FundPoolId, ISNULL(@FundPoolName, ''),
            GETDATE(), GETDATE()
        );

        -- Deduct from Fund Pool
        IF @FundPoolId IS NOT NULL
            UPDATE FundPools
            SET Balance   = Balance - @RefundAmount,
                UpdatedAt = GETDATE()
            WHERE Id = @FundPoolId;
    END

    -- ── Forfeit / Penalty / Damage (SD-FRF) + Income ────────
    IF @ForfeitAmount > 0
    BEGIN
        DECLARE @FrfSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, ReceivedBy, IssuedBy,
            CreatedAt, UpdatedAt
        )
        VALUES (
            'TXN-SD-FRF-' + RIGHT('000000' + CAST(@FrfSeq AS NVARCHAR), 6),
            'SD-FRF', @ContractId, @ContractId,
            @TenantId, @CampId, @ForfeitAmount, @ForfeitAmount,
            GETDATE(), 'Security Deposit forfeited (penalty/damage) - ' + ISNULL(@Notes, ''),
            @SettledBy, @SettledBy,
            GETDATE(), GETDATE()
        );

        -- Create Income entry (forfeited deposit = company income)
        DECLARE @IncSeq  INT          = ISNULL((SELECT MAX(Id) FROM Incomes), 0) + 1;
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST(@IncSeq AS NVARCHAR), 6);
        INSERT INTO Incomes (
            IncomeId, Date, Mode, Head, FundPool, FundPoolName,
            Amount, Purpose, Source, SourceRef,
            ContractId, ContractCode, CampId, CampName,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @IncomeId, GETDATE(), 'System', 'Security Deposit Forfeited', '', '',
            @ForfeitAmount,
            'Security deposit forfeited - ' + @ContractId + ' - ' + ISNULL(@Notes, ''),
            'SecurityDeposit', @ContractId,
            @ContractId, @ContractId, @CampId, @CampName,
            GETDATE(), GETDATE()
        );
    END

    -- ── Update Contract status ──────────────────────────────
    SET @NewStatus =
        CASE
            WHEN @RefundAmount  > 0 AND @ForfeitAmount = 0 AND @AdjustAmount = 0 THEN 'Refunded'
            WHEN @AdjustAmount  > 0 AND @ForfeitAmount = 0 AND @RefundAmount  = 0 THEN 'Adjusted'
            WHEN @ForfeitAmount > 0 AND @RefundAmount  = 0 AND @AdjustAmount  = 0 THEN 'Forfeited'
            ELSE 'Settled'
        END;

    UPDATE Contracts
    SET SecurityDepositStatus = @NewStatus,
        UpdatedAt             = GETDATE()
    WHERE ContractId = @ContractId;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '040 - Security Deposit SPs created: sp_GetSecurityDepositStatus, sp_ReceiveSecurityDeposit, sp_SettleSecurityDeposit';
GO
