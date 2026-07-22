-- ============================================================
-- 058: Fix sp_UpdateTxnRecord
--      Bug: revert sets Status='Pending' even when other TxnRecords
--           also contributed to the same installment
--      Fix: after revert, recalculate status from actual PaidAmount
-- ============================================================
USE TFMS_TestSoftwareDB;
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
    @ReceivedBy     NVARCHAR(MAX) = '',
    @ChequeNumber   NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Get existing TxnRecord
        DECLARE @ContractId          NVARCHAR(MAX),
                @OldAmount           DECIMAL(18,2),
                @OldFundPoolId       INT,
                @AppliedInstallments NVARCHAR(MAX);

        SELECT  @ContractId          = ContractId,
                @OldAmount           = Amount,
                @OldFundPoolId       = FundPoolId,
                @AppliedInstallments = AppliedInstallments
        FROM TxnRecords WHERE Id = @Id;

        IF @ContractId IS NULL
        BEGIN RAISERROR('TxnRecord %d not found.', 16, 1, @Id); RETURN; END

        -- 2. Update TxnRecord fields
        UPDATE TxnRecords
        SET Amount        = @Amount,
            PaidDate      = @TxnDate,
            PaymentMode   = @PaymentMode,
            PaymentModeId = @PaymentModeId,
            FundPoolId    = @FundPoolId,
            FundPoolName  = @FundPoolName,
            Description   = @Description,
            ReceivedBy    = @ReceivedBy,
            ChequeNumber  = ISNULL(NULLIF(@ChequeNumber,''), ChequeNumber),
            UpdatedAt     = GETUTCDATE()
        WHERE Id = @Id;

        -- 3. Revert FundPool (old amount out)
        IF @OldFundPoolId IS NOT NULL AND @OldAmount > 0
            UPDATE FundPools SET Balance = Balance - @OldAmount, UpdatedAt = GETUTCDATE()
            WHERE Id = @OldFundPoolId;

        -- 4. Add new amount to FundPool
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- 5. Revert installments contribution from this TxnRecord
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            CREATE TABLE #AppliedInst (InstallmentNo INT);
            INSERT INTO #AppliedInst
            SELECT TRIM([value]) FROM STRING_SPLIT(@AppliedInstallments, ',')
            WHERE TRIM([value]) <> '';

            -- ✅ FIX: Subtract old contribution, recalculate Status from remaining PaidAmount
            UPDATE ci
            SET
                ci.PaidAmount = CASE WHEN ci.PaidAmount - @OldAmount < 0 THEN 0 ELSE ci.PaidAmount - @OldAmount END,
                ci.PaidDate   = CASE WHEN ci.PaidAmount - @OldAmount <= 0 THEN NULL ELSE ci.PaidDate END,
                -- ✅ Status based on remaining PaidAmount after subtract
                ci.Status     = CASE
                    WHEN (CASE WHEN ci.PaidAmount - @OldAmount < 0 THEN 0 ELSE ci.PaidAmount - @OldAmount END) = 0
                         THEN 'Pending'
                    WHEN (CASE WHEN ci.PaidAmount - @OldAmount < 0 THEN 0 ELSE ci.PaidAmount - @OldAmount END) >= ci.Amount
                         THEN 'Paid'
                    ELSE 'Partial'
                END
            FROM ContractInstallments ci
            JOIN #AppliedInst ai ON ci.InstallmentNo = ai.InstallmentNo
            WHERE ci.ContractId = @ContractId;

            -- 6. Re-distribute new amount across same installments
            DECLARE @Remaining DECIMAL(18,2) = @Amount;
            DECLARE @InstNo INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2), @InstDue DECIMAL(18,2);
            DECLARE @ToApply DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(MAX);

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
                    WHEN @NewPaid > 0         THEN 'Partial'
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

PRINT '058 - sp_UpdateTxnRecord fixed: Status recalculated after revert, not hardcoded Pending';
GO
