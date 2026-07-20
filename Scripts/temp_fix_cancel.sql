CREATE PROCEDURE sp_CancelContract
    @ContractId NVARCHAR(MAX),
    @CancellationDate DATE = NULL,
    @CancellationReason NVARCHAR(MAX) = NULL,
    @RefundAmount DECIMAL(18,2) = 0,
    @PenaltyAmount DECIMAL(18,2) = 0,
    @SettlementAmount DECIMAL(18,2) = 0,
    @CancelledBy NVARCHAR(MAX) = NULL,
    @Notes NVARCHAR(MAX) = NULL,
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId=@ContractId AND Status='Active')
    BEGIN RAISERROR('Contract not found',16,1); RETURN; END

    DECLARE @TenantId INT, @CampId INT, @DP DECIMAL(18,2);
    SELECT @TenantId=TenantId, @DP=ISNULL(SecurityDepositPaid,0) FROM Contracts WHERE ContractId=@ContractId;
    SET @CampId=ISNULL((SELECT TOP 1 CampId FROM ContractCamps WHERE ContractId=@ContractId),0);

    UPDATE Contracts SET Status='Cancelled', UpdatedAt=GETDATE() WHERE ContractId=@ContractId;
    UPDATE ContractInstallments SET Status='Cancelled' WHERE ContractId=@ContractId AND Status IN('Pending','Partial','Overdue');
    UPDATE Rooms SET Occupied=0, Status='Vacant', UpdatedAt=GETDATE() WHERE Id IN(SELECT RoomId FROM ContractRooms WHERE ContractId=@ContractId);

    INSERT INTO ContractCancellations(ContractId,TenantId,CancellationDate,CancellationReason,RefundAmount,PenaltyAmount,SettlementAmount,CancelledBy,Notes,Status)
    VALUES(@ContractId,@TenantId,ISNULL(@CancellationDate,GETDATE()),@CancellationReason,@RefundAmount,@PenaltyAmount,@SettlementAmount,@CancelledBy,@Notes,'Cancelled');
    SET @NewId=SCOPE_IDENTITY();

    IF @PenaltyAmount > 0
    BEGIN
        INSERT INTO Incomes(Date,Mode,Head,FundPool,Amount,Purpose,Source,SourceRef,CreatedAt,UpdatedAt)
        VALUES(ISNULL(@CancellationDate,GETDATE()),'System','Penalty Income','',@PenaltyAmount,'Cancellation penalty - '+@ContractId,'Cancellation',@ContractId,GETDATE(),GETDATE());

        INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,TotalAmount,Amount,PaidDate,Description,IssuedBy,ReceivedBy,CreatedAt,UpdatedAt)
        VALUES('TXN-PEN-'+RIGHT('000000'+CAST(@NewId AS NVARCHAR),6),'DR',@ContractId,@ContractId,@TenantId,@CampId,@PenaltyAmount,@PenaltyAmount,ISNULL(@CancellationDate,GETDATE()),'Cancellation penalty',@CancelledBy,@CancelledBy,GETDATE(),GETDATE());
    END

    IF @RefundAmount > 0
    BEGIN
        INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,TotalAmount,Amount,PaidDate,Description,IssuedBy,ReceivedBy,CreatedAt,UpdatedAt)
        VALUES('TXN-REF-'+RIGHT('000000'+CAST(@NewId AS NVARCHAR),6),'SD-REF',@ContractId,@ContractId,@TenantId,@CampId,@RefundAmount,@RefundAmount,ISNULL(@CancellationDate,GETDATE()),'Security deposit refund',@CancelledBy,@CancelledBy,GETDATE(),GETDATE());
    END

    IF @DP > 0
    BEGIN
        UPDATE Contracts SET SecurityDepositStatus = CASE WHEN @RefundAmount>=@DP THEN 'Refunded' WHEN @PenaltyAmount>=@DP THEN 'Forfeited' WHEN @RefundAmount>0 THEN 'Adjusted' ELSE 'Forfeited' END WHERE ContractId=@ContractId;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
