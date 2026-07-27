-- ============================================================
-- 108: Fix sp_CreateExpense - Owner payment management
-- When RecipientRole='Owner', update:
--   1. Expenses (always)
--   2. FundPools (always if fundpool set)
--   3. OwnerTransactions → CR entry
--   4. OwnerContracts → PaidAmount, Balance update
--   5. OwnerInstallments → apply payment, mark Paid/Partial
--   6. OwnerMonthlyContractInstallments → apply payment
-- All with IsDeleted=0 filters
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date          DATE,
    @Head          NVARCHAR(MAX),
    @Nature        NVARCHAR(MAX) = 'Camp',
    @CampId        INT           = NULL,
    @CampName      NVARCHAR(MAX) = '',
    @RecipientRole NVARCHAR(MAX) = '',
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = '',
    @Amount        DECIMAL(18,2),
    @FundPool      NVARCHAR(MAX) = '',
    @FundPoolId    INT           = NULL,
    @FundPoolName  NVARCHAR(MAX) = '',
    @Mode          NVARCHAR(MAX) = '',
    @Purpose       NVARCHAR(MAX) = '',
    @AddedBy       INT           = NULL,
    @NewId         INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- ── 1. Insert Expense ─────────────────────────────────────────
    DECLARE @ExpenseId NVARCHAR(MAX) = 'EXP-' +
        RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);

    INSERT INTO Expenses(
        ExpenseId, Date, Head, Nature,
        CampId, CampName,
        RecipientRole, RecipientId, RecipientName,
        Amount, FundPool, FundPoolName, Mode, Purpose,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @ExpenseId, @Date, @Head, @Nature,
        @CampId, @CampName,
        @RecipientRole, @RecipientId, @RecipientName,
        @Amount, @FundPool, @FundPoolName, @Mode, @Purpose,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );
    SET @NewId = SCOPE_IDENTITY();

    -- ── 2. FundPool balance deduct ────────────────────────────────
    IF @FundPool IS NOT NULL AND LEN(@FundPool) > 0 AND @Amount > 0
        UPDATE FundPools
        SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE()
        WHERE Code=@FundPool AND IsDeleted=0;

    -- ── 3. Owner payment logic ────────────────────────────────────
    IF @RecipientRole = 'Owner' AND @RecipientId IS NOT NULL
    BEGIN
        -- Get latest active OwnerContract for this owner+camp
        DECLARE @OcId    INT;
        DECLARE @OcCode  NVARCHAR(MAX);

        SELECT TOP 1
            @OcId   = oc.Id,
            @OcCode = oc.OcCode
        FROM OwnerContracts oc
        WHERE oc.OwnerId  = @RecipientId
          AND oc.IsDeleted = 0
          AND oc.Status    = 'Active'
          AND (@CampId IS NULL OR oc.CampId = @CampId)
        ORDER BY oc.CreatedAt DESC;

        IF @OcId IS NOT NULL
        BEGIN
            -- ── 3a. OwnerTransactions CR entry ────────────────────
            DECLARE @OtCode NVARCHAR(MAX) = 'OTX-' +
                RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions WHERE ISNULL(IsDeleted,0)=0) AS NVARCHAR), 6);

            INSERT INTO OwnerTransactions(
                TxnCode, OwnerContractId, OcCode,
                CampId, CampName, OwnerId, OwnerName,
                Type, Amount, Date, Description,
                InstallmentNos, ExpenseId, IsDeleted, CreatedAt
            )
            VALUES(
                @OtCode, @OcId, @OcCode,
                @CampId, @CampName, @RecipientId, @RecipientName,
                'CR', @Amount, @Date,
                'Payment via expense - ' + @ExpenseId,
                '', @NewId, 0, GETUTCDATE()
            );

            -- ── 3b. OwnerInstallments — apply payment in order ────
            DECLARE @Remaining DECIMAL(18,2) = @Amount;
            DECLARE @InstId  INT;
            DECLARE @InstAmt DECIMAL(18,2);
            DECLARE @InstPaid DECIMAL(18,2);
            DECLARE @InstDue  DECIMAL(18,2);
            DECLARE @ToApply  DECIMAL(18,2);
            DECLARE @NewPaid  DECIMAL(18,2);
            DECLARE @NewStatus NVARCHAR(MAX);
            DECLARE @AppliedNos NVARCHAR(MAX) = '';

            DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT Id, Amount, ISNULL(PaidAmount,0), Amount - ISNULL(PaidAmount,0)
                FROM OwnerInstallments
                WHERE OwnerContractId=@OcId
                  AND ISNULL(IsDeleted,0)=0
                  AND Status IN ('Pending','Partial')
                ORDER BY No;

            OPEN inst_cur;
            FETCH NEXT FROM inst_cur INTO @InstId, @InstAmt, @InstPaid, @InstDue;

            WHILE @@FETCH_STATUS=0 AND @Remaining>0
            BEGIN
                SET @ToApply   = CASE WHEN @Remaining>=@InstDue THEN @InstDue ELSE @Remaining END;
                SET @NewPaid   = @InstPaid + @ToApply;
                SET @NewStatus = CASE
                    WHEN @NewPaid >= @InstAmt THEN 'Paid'
                    WHEN @NewPaid  > 0        THEN 'Partial'
                    ELSE 'Pending'
                END;

                UPDATE OwnerInstallments
                SET PaidAmount=@NewPaid, PaidDate=@Date,
                    Status=@NewStatus, ExpenseId=@NewId,
                    UpdatedBy=@AddedBy
                WHERE Id=@InstId AND ISNULL(IsDeleted,0)=0;

                SET @AppliedNos = CASE WHEN @AppliedNos='' THEN CAST(@InstId AS NVARCHAR)
                                  ELSE @AppliedNos+','+CAST(@InstId AS NVARCHAR) END;
                SET @Remaining  = @Remaining - @ToApply;

                FETCH NEXT FROM inst_cur INTO @InstId, @InstAmt, @InstPaid, @InstDue;
            END;
            CLOSE inst_cur; DEALLOCATE inst_cur;

            -- Update TxnRecord with applied installment nos
            IF LEN(@AppliedNos) > 0
                UPDATE OwnerTransactions
                SET InstallmentNos=@AppliedNos
                WHERE ExpenseId=@NewId AND ISNULL(IsDeleted,0)=0;

            -- ── 3c. OwnerMonthlyContractInstallments — apply ──────
            DECLARE @MRemaining DECIMAL(18,2) = @Amount;
            DECLARE @MInstId  INT;
            DECLARE @MInstAmt DECIMAL(18,2);
            DECLARE @MInstPaid DECIMAL(18,2);
            DECLARE @MInstBal  DECIMAL(18,2);
            DECLARE @MToApply  DECIMAL(18,2);
            DECLARE @MNewPaid  DECIMAL(18,2);
            DECLARE @MNewBal   DECIMAL(18,2);
            DECLARE @MNewStatus NVARCHAR(MAX);
            DECLARE @MNewPayStatus NVARCHAR(MAX);

            DECLARE minst_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT Id, Amount, ISNULL(PaidAmount,0), ISNULL(Balance,Amount)
                FROM OwnerMonthlyContractInstallments
                WHERE OwnerContractId=@OcId
                  AND ISNULL(IsDeleted,0)=0
                  AND PaymentStatus IN ('Pending','Partial')
                ORDER BY InstallmentNo;

            OPEN minst_cur;
            FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;

            WHILE @@FETCH_STATUS=0 AND @MRemaining>0
            BEGIN
                SET @MToApply      = CASE WHEN @MRemaining>=@MInstBal THEN @MInstBal ELSE @MRemaining END;
                SET @MNewPaid      = @MInstPaid + @MToApply;
                SET @MNewBal       = @MInstAmt  - @MNewPaid;
                SET @MNewStatus    = CASE WHEN @MNewPaid>=@MInstAmt THEN 'Paid' WHEN @MNewPaid>0 THEN 'Partial' ELSE 'Pending' END;
                SET @MNewPayStatus = @MNewStatus;

                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount    = @MNewPaid,
                    Balance       = CASE WHEN @MNewBal<0 THEN 0 ELSE @MNewBal END,
                    PaidDate      = @Date,
                    Status        = @MNewStatus,
                    PaymentStatus = @MNewPayStatus,
                    PaymentMode   = @Mode,
                    ExpenseId     = @NewId,
                    UpdatedAt     = GETUTCDATE()
                WHERE Id=@MInstId AND ISNULL(IsDeleted,0)=0;

                SET @MRemaining = @MRemaining - @MToApply;
                FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;
            END;
            CLOSE minst_cur; DEALLOCATE minst_cur;

            -- ── 3d. OwnerContracts — track payment via TxnRecord (no PaidAmount/Balance col) ──
            -- PaidAmount/Balance not in OwnerContracts table — tracked via OwnerTransactions CR sum
            -- Just update UpdatedAt timestamp
            UPDATE OwnerContracts
            SET UpdatedAt=GETUTCDATE()
            WHERE Id=@OcId AND IsDeleted=0;
        END
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CreateExpense fixed - Owner payment now updates OwnerInstallments, OwnerMonthlyContractInstallments, OwnerTransactions, OwnerContracts';
GO
