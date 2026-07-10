USE TFMS_softwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id             INT,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @PaymentMode    NVARCHAR(50)  = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(200) = '',
    @Description    NVARCHAR(500) = '',
    @ReceivedBy     NVARCHAR(200) = '',
    @ChequeNumber   NVARCHAR(50)  = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Get existing record
        DECLARE @ContractId          NVARCHAR(20);
        DECLARE @OldAmount           DECIMAL(18,2);
        DECLARE @OldFundPoolId       INT;
        DECLARE @AppliedInstallments NVARCHAR(200);

        SELECT @ContractId          = ContractId,
               @OldAmount           = Amount,
               @OldFundPoolId       = FundPoolId,
               @AppliedInstallments = AppliedInstallments
        FROM TxnRecords WHERE Id = @Id;

        IF @ContractId IS NULL
        BEGIN
            RAISERROR('TxnRecord %d not found.', 16, 1, @Id);
            RETURN;
        END

        -- Update TxnRecord
        UPDATE TxnRecords
        SET Amount        = @Amount,
            PaidDate      = @TxnDate,
            PaymentMode   = @PaymentMode,
            PaymentModeId = @PaymentModeId,
            FundPoolId    = @FundPoolId,
            FundPoolName  = @FundPoolName,
            Description   = @Description,
            ReceivedBy    = @ReceivedBy,
            ChequeNumber  = @ChequeNumber,
            UpdatedAt     = GETUTCDATE()
        WHERE Id = @Id;

        -- Reverse old FundPool balance
        IF @OldFundPoolId IS NOT NULL AND @OldAmount > 0
            UPDATE FundPools SET Balance = Balance - @OldAmount, UpdatedAt = GETUTCDATE()
            WHERE Id = @OldFundPoolId;

        -- Add new FundPool balance
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- Redistribute installments
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            CREATE TABLE #AI2 (InstallmentNo INT);
            INSERT INTO #AI2
            SELECT TRIM(value) FROM STRING_SPLIT(@AppliedInstallments, ',')
            WHERE TRIM(value) <> '';

            -- Revert installments (remove old payment contribution)
            UPDATE ci
            SET ci.PaidAmount = CASE WHEN ci.PaidAmount >= @OldAmount THEN ci.PaidAmount - @OldAmount ELSE 0 END,
                ci.PaidDate   = NULL,
                ci.Status     = 'Pending'
            FROM ContractInstallments ci
            JOIN #AI2 a ON ci.InstallmentNo = a.InstallmentNo
            WHERE ci.ContractId = @ContractId;

            -- Re-distribute new amount
            DECLARE @Rem   DECIMAL(18,2) = @Amount;
            DECLARE @INo   INT;
            DECLARE @IAmt  DECIMAL(18,2);
            DECLARE @IPaid DECIMAL(18,2);
            DECLARE @IDue  DECIMAL(18,2);
            DECLARE @IApply DECIMAL(18,2);
            DECLARE @INewPaid DECIMAL(18,2);
            DECLARE @IStatus NVARCHAR(20);

            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT ci.InstallmentNo, ci.Amount, ci.PaidAmount
                FROM ContractInstallments ci
                JOIN #AI2 a ON ci.InstallmentNo = a.InstallmentNo
                WHERE ci.ContractId = @ContractId
                ORDER BY ci.InstallmentNo;

            OPEN cur;
            FETCH NEXT FROM cur INTO @INo, @IAmt, @IPaid;

            WHILE @@FETCH_STATUS = 0 AND @Rem > 0
            BEGIN
                SET @IDue     = @IAmt - @IPaid;
                SET @IApply   = CASE WHEN @Rem >= @IDue THEN @IDue ELSE @Rem END;
                SET @INewPaid = @IPaid + @IApply;
                SET @IStatus  = CASE
                    WHEN @INewPaid >= @IAmt THEN 'Paid'
                    WHEN @INewPaid  > 0     THEN 'Partial'
                    ELSE 'Pending'
                END;

                UPDATE ContractInstallments
                SET PaidAmount    = @INewPaid,
                    PaidDate      = @TxnDate,
                    Status        = @IStatus,
                    PaymentMode   = @PaymentMode,
                    PaymentModeId = @PaymentModeId,
                    FundPoolId    = @FundPoolId,
                    FundPoolName  = @FundPoolName,
                    Description   = @Description,
                    ReceivedBy    = @ReceivedBy,
                    ChequeNumber  = @ChequeNumber
                WHERE ContractId = @ContractId AND InstallmentNo = @INo;

                SET @Rem = @Rem - @IApply;
                FETCH NEXT FROM cur INTO @INo, @IAmt, @IPaid;
            END;

            CLOSE cur;
            DEALLOCATE cur;
            DROP TABLE #AI2;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#AI2') IS NOT NULL DROP TABLE #AI2;
        THROW;
    END CATCH
END
GO

PRINT 'sp_UpdateTxnRecord v2 — ChequeNumber added, installments + fundpool synced';
GO
