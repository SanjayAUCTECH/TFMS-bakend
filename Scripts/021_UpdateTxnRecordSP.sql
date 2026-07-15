-- ============================================================
-- TFMS Script 021 — sp_UpdateTxnRecord (smart edit)
-- On edit: reverts old installment payments, re-distributes
-- new amount across same installments, updates FundPool balance
-- ============================================================
USE TFMS_softwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id             INT,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @PaymentMode    NVARCHAR(MAX)  = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(MAX) = '',
    @Description    NVARCHAR(MAX) = '',
    @ReceivedBy     NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- ── 1. Get existing TxnRecord ────────────────────────────────────
        DECLARE @ContractId         NVARCHAR(MAX),
                @OldAmount          DECIMAL(18,2),
                @OldFundPoolId      INT,
                @AppliedInstallments NVARCHAR(MAX);

        SELECT  @ContractId          = ContractId,
                @OldAmount           = Amount,
                @OldFundPoolId       = FundPoolId,
                @AppliedInstallments = AppliedInstallments
        FROM TxnRecords WHERE Id = @Id;

        IF @ContractId IS NULL
        BEGIN
            RAISERROR('TxnRecord %d not found.', 16, 1, @Id);
            RETURN;
        END

        -- ── 2. Update TxnRecord basic fields first ───────────────────────
        UPDATE TxnRecords
        SET Amount        = @Amount,
            PaidDate      = @TxnDate,
            PaymentMode   = @PaymentMode,
            PaymentModeId = @PaymentModeId,
            FundPoolId    = @FundPoolId,
            FundPoolName  = @FundPoolName,
            Description   = @Description,
            ReceivedBy    = @ReceivedBy,
            UpdatedAt     = GETUTCDATE()
        WHERE Id = @Id;

        -- ── 3. Revert FundPool balance (remove old amount) ───────────────
        IF @OldFundPoolId IS NOT NULL AND @OldAmount > 0
            UPDATE FundPools
            SET Balance   = Balance - @OldAmount,
                UpdatedAt = GETUTCDATE()
            WHERE Id = @OldFundPoolId;

        -- ── 4. Add new amount to FundPool ────────────────────────────────
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools
            SET Balance   = Balance + @Amount,
                UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- ── 5. Revert installments that were applied by this TxnRecord ───
        --    Strategy: reset each applied installment's PaidAmount
        --    by subtracting the old contribution, then recalculate status
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            -- Parse comma-separated InstallmentNos into temp table
            CREATE TABLE #AppliedInst (InstallmentNo INT);
            INSERT INTO #AppliedInst
            SELECT TRIM(value)
            FROM STRING_SPLIT(@AppliedInstallments, ',')
            WHERE TRIM(value) <> '';

            -- Revert: set PaidAmount back to 0 for each applied installment
            -- (safe because sp_RecordPayment always sets PaidAmount = paid total)
            UPDATE ci
            SET ci.PaidAmount = CASE
                    WHEN ci.PaidAmount >= @OldAmount THEN ci.PaidAmount - @OldAmount
                    ELSE 0
                END,
                ci.PaidDate  = NULL,
                ci.Status    = 'Pending'
            FROM ContractInstallments ci
            JOIN #AppliedInst ai ON ci.InstallmentNo = ai.InstallmentNo
            WHERE ci.ContractId = @ContractId;

            -- ── 6. Re-distribute new amount across same installments ─────
            DECLARE @Remaining DECIMAL(18,2) = @Amount;
            DECLARE @InstNo    INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2), @InstDue DECIMAL(18,2);
            DECLARE @ToApply   DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(MAX);

            DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT ci.InstallmentNo, ci.Amount, ci.PaidAmount
                FROM ContractInstallments ci
                JOIN #AppliedInst ai ON ci.InstallmentNo = ai.InstallmentNo
                WHERE ci.ContractId = @ContractId
                ORDER BY ci.InstallmentNo;

            OPEN inst_cur;
            FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;

            WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
            BEGIN
                SET @InstDue   = @InstAmt - @InstPaid;
                SET @ToApply   = CASE WHEN @Remaining >= @InstDue THEN @InstDue ELSE @Remaining END;
                SET @NewPaid   = @InstPaid + @ToApply;
                SET @NewStatus = CASE
                    WHEN @NewPaid >= @InstAmt THEN 'Paid'
                    WHEN @NewPaid  > 0        THEN 'Partial'
                    ELSE 'Pending'
                END;

                UPDATE ContractInstallments
                SET PaidAmount    = @NewPaid,
                    PaidDate      = @TxnDate,
                    Status        = @NewStatus,
                    PaymentMode   = @PaymentMode,
                    PaymentModeId = @PaymentModeId,
                    FundPoolId    = @FundPoolId,
                    FundPoolName  = @FundPoolName,
                    Description   = @Description,
                    ReceivedBy    = @ReceivedBy
                WHERE ContractId = @ContractId AND InstallmentNo = @InstNo;

                SET @Remaining = @Remaining - @ToApply;
                FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;
            END;

            CLOSE inst_cur;
            DEALLOCATE inst_cur;
            DROP TABLE #AppliedInst;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#AppliedInst') IS NOT NULL DROP TABLE #AppliedInst;
        THROW;
    END CATCH
END
GO

PRINT 'sp_UpdateTxnRecord updated — installments + fundpool synced on edit';
GO
