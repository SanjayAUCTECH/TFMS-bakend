-- ============================================================
-- 038: Fix sp_CancelContract — IncomeId NULL fix + FundPoolName
-- Error: Cannot insert NULL into Incomes.IncomeId
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CancelContract
    @ContractId        NVARCHAR(MAX),
    @CancellationDate  DATE          = NULL,
    @CancellationReason NVARCHAR(MAX) = NULL,
    @RefundAmount      DECIMAL(18,2) = 0,
    @PenaltyAmount     DECIMAL(18,2) = 0,
    @SettlementAmount  DECIMAL(18,2) = 0,
    @CancelledBy       NVARCHAR(MAX) = NULL,
    @Notes             NVARCHAR(MAX) = NULL,
    @NewId             INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate contract exists and is Active
    IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId=@ContractId AND Status='Active')
    BEGIN
        RAISERROR('Contract not found or not in Active status.',16,1);
        RETURN;
    END

    -- Get tenant & camp info
    DECLARE @TenantId INT, @CampId INT, @DP DECIMAL(18,2);
    SELECT @TenantId = TenantId, @DP = ISNULL(SecurityDepositPaid, 0)
    FROM Contracts WHERE ContractId = @ContractId;

    SET @CampId = ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId=@ContractId), 0);

    -- Update contract status to Cancelled
    UPDATE Contracts SET Status='Cancelled', UpdatedAt=GETDATE() WHERE ContractId=@ContractId;

    -- Cancel pending installments
    UPDATE ContractInstallments
    SET Status='Cancelled'
    WHERE ContractId=@ContractId AND Status IN('Pending','Partial','Overdue');

    -- Mark rooms as Vacant
    UPDATE Rooms
    SET Occupied=0, Status='Vacant', UpdatedAt=GETDATE()
    WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId=@ContractId);

    -- Insert cancellation record
    INSERT INTO ContractCancellations(
        ContractId, TenantId, CancellationDate, CancellationReason,
        RefundAmount, PenaltyAmount, SettlementAmount, CancelledBy, Notes, Status
    )
    VALUES(
        @ContractId, @TenantId, ISNULL(@CancellationDate, GETDATE()),
        @CancellationReason, @RefundAmount, @PenaltyAmount,
        @SettlementAmount, @CancelledBy, @Notes, 'Cancelled'
    );
    SET @NewId = SCOPE_IDENTITY();

    -- Penalty → create Income entry
    IF @PenaltyAmount > 0
    BEGIN
        -- Generate IncomeId: INC-XXXXXX
        DECLARE @IncomeSeq INT = ISNULL((SELECT MAX(Id) FROM Incomes), 0) + 1;
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST(@IncomeSeq AS NVARCHAR), 6);

        INSERT INTO Incomes(
            IncomeId, Date, Mode, Head, FundPool, FundPoolName,
            Amount, Purpose, Source, SourceRef, ContractId, ContractCode,
            CampId, CampName, CreatedAt, UpdatedAt
        )
        VALUES(
            @IncomeId,
            ISNULL(@CancellationDate, GETDATE()),
            'Cash',
            'Penalty Income',
            '',
            '',
            @PenaltyAmount,
            'Cancellation penalty - ' + @ContractId,
            'Cancellation',
            @ContractId,
            @ContractId,
            @ContractId,
            @CampId,
            ISNULL((SELECT TOP 1 Name FROM Camps WHERE Id=@CampId), ''),
            GETDATE(),
            GETDATE()
        );

        -- TxnRecord for penalty (DR = debit from tenant)
        DECLARE @PenTxnSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, IssuedBy, ReceivedBy, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-PEN-' + RIGHT('000000' + CAST(@PenTxnSeq AS NVARCHAR), 6),
            'DR',
            @ContractId, @ContractId,
            @TenantId, @CampId,
            @PenaltyAmount, @PenaltyAmount,
            ISNULL(@CancellationDate, GETDATE()),
            'Cancellation penalty - ' + @ContractId,
            ISNULL(@CancelledBy, 'System'),
            ISNULL(@CancelledBy, 'System'),
            GETDATE(), GETDATE()
        );
    END

    -- Refund → TxnRecord for SD refund (SD-REF)
    IF @RefundAmount > 0
    BEGIN
        DECLARE @RefTxnSeq INT = ISNULL((SELECT MAX(Id) FROM TxnRecords), 0) + 1;
        INSERT INTO TxnRecords(
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId, TotalAmount, Amount,
            PaidDate, Description, IssuedBy, ReceivedBy, CreatedAt, UpdatedAt
        )
        VALUES(
            'TXN-REF-' + RIGHT('000000' + CAST(@RefTxnSeq AS NVARCHAR), 6),
            'SD-REF',
            @ContractId, @ContractId,
            @TenantId, @CampId,
            @RefundAmount, @RefundAmount,
            ISNULL(@CancellationDate, GETDATE()),
            'Security deposit refund - ' + @ContractId,
            ISNULL(@CancelledBy, 'System'),
            ISNULL(@CancelledBy, 'System'),
            GETDATE(), GETDATE()
        );
    END

    -- Update Security Deposit status on contract
    IF @DP > 0
    BEGIN
        UPDATE Contracts
        SET SecurityDepositStatus = CASE
            WHEN @RefundAmount >= @DP THEN 'Refunded'
            WHEN @PenaltyAmount >= @DP THEN 'Forfeited'
            WHEN @RefundAmount > 0 THEN 'Adjusted'
            ELSE 'Forfeited'
        END
        WHERE ContractId = @ContractId;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '038 — sp_CancelContract fixed (IncomeId + FundPoolName)';
GO
