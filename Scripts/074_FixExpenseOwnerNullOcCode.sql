-- ============================================================
-- Fix: sp_CreateExpense / sp_UpdateExpense
-- Error: Cannot insert NULL into OcCode in OwnerTransactions
-- Cause: @OcId is NULL when no OwnerContract exists for owner+camp
--        SP was still inserting OwnerTransaction with NULL OcCode
-- Fix:   Wrap all owner transaction/installment logic in IF @OcId IS NOT NULL
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date          DATE,
    @Mode          NVARCHAR(MAX),
    @Head          NVARCHAR(MAX),
    @FundPool      NVARCHAR(MAX),
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX),
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(MAX),
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX),
    @Purpose       NVARCHAR(MAX),
    @NewId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExpenseId    NVARCHAR(MAX) = 'EXP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);
    DECLARE @FundPoolName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Code = @FundPool);
    DECLARE @CampName     NVARCHAR(MAX) = ISNULL((SELECT Name FROM Camps WHERE Id = @CampId), '');

    INSERT INTO Expenses(ExpenseId, Date, Mode, Head, FundPool, FundPoolName, Amount, Nature,
        CampId, CampName, RecipientRole, RecipientId, RecipientName, Purpose, CreatedAt, UpdatedAt)
    VALUES(@ExpenseId, @Date, @Mode, @Head, @FundPool, @FundPoolName, @Amount, @Nature,
        @CampId, @CampName, @RecipientRole, @RecipientId, @RecipientName, @Purpose, GETUTCDATE(), GETUTCDATE());

    SET @NewId = SCOPE_IDENTITY();

    -- Deduct FundPool balance
    UPDATE FundPools SET Balance = Balance - @Amount, UpdatedAt = GETUTCDATE() WHERE Code = @FundPool;

    -- ── Owner payment ──────────────────────────────────────────────────────────
    IF @RecipientRole = 'Owner'
    BEGIN
        DECLARE @OwnerId INT = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Owners WHERE Name = @RecipientName));

        IF @OwnerId IS NOT NULL
        BEGIN
            DECLARE @OcId   INT           = (SELECT TOP 1 Id    FROM OwnerContracts WHERE OwnerId = @OwnerId AND (@CampId IS NULL OR CampId = @CampId) AND Status = 'Active' ORDER BY CreatedAt DESC);
            DECLARE @OcCode NVARCHAR(MAX) = (SELECT OcCode FROM OwnerContracts WHERE Id = @OcId);

            -- Only process if an active OwnerContract exists
            IF @OcId IS NOT NULL
            BEGIN
                DECLARE @OtCode NVARCHAR(MAX) = 'OT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR), 6);

                INSERT INTO OwnerTransactions(TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName, Type, Amount, Date, Description, ExpenseId, CreatedAt)
                VALUES(@OtCode, @OcId, @OcCode, @CampId, @CampName, @OwnerId, @RecipientName, 'CR', @Amount, @Date, 'Payment via expense - ' + @ExpenseId, @NewId, GETUTCDATE());

                -- Update OwnerInstallments
                DECLARE @Remaining DECIMAL(18,2) = @Amount;
                DECLARE @InstId    INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2), @InstDue DECIMAL(18,2);
                DECLARE @ToApply   DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(20);

                DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Amount - PaidAmount
                    FROM OwnerInstallments
                    WHERE OwnerContractId = @OcId AND Status IN ('Pending','Partial')
                    ORDER BY No;

                OPEN inst_cur;
                FETCH NEXT FROM inst_cur INTO @InstId, @InstAmt, @InstPaid, @InstDue;

                WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
                BEGIN
                    SET @ToApply   = CASE WHEN @Remaining >= @InstDue THEN @InstDue ELSE @Remaining END;
                    SET @NewPaid   = @InstPaid + @ToApply;
                    SET @NewStatus = CASE WHEN @NewPaid >= @InstAmt THEN 'Paid' WHEN @NewPaid > 0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerInstallments SET PaidAmount=@NewPaid, PaidDate=@Date, Status=@NewStatus, ExpenseId=@NewId WHERE Id=@InstId;
                    SET @Remaining = @Remaining - @ToApply;
                    FETCH NEXT FROM inst_cur INTO @InstId, @InstAmt, @InstPaid, @InstDue;
                END;
                CLOSE inst_cur; DEALLOCATE inst_cur;

                -- Update OwnerMonthlyContractInstallments
                DECLARE @RemainingM DECIMAL(18,2) = @Amount;
                DECLARE @MInstId INT, @MInstAmt DECIMAL(18,2), @MInstPaid DECIMAL(18,2), @MInstBal DECIMAL(18,2);
                DECLARE @MToApply DECIMAL(18,2), @MNewPaid DECIMAL(18,2), @MNewBal DECIMAL(18,2), @MNewStatus NVARCHAR(20), @MNewPayStatus NVARCHAR(20);

                DECLARE minst_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Balance
                    FROM OwnerMonthlyContractInstallments
                    WHERE OwnerContractId = @OcId AND PaymentStatus IN ('Pending','Partial')
                    ORDER BY InstallmentNo;

                OPEN minst_cur;
                FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;

                WHILE @@FETCH_STATUS = 0 AND @RemainingM > 0
                BEGIN
                    SET @MToApply      = CASE WHEN @RemainingM >= @MInstBal THEN @MInstBal ELSE @RemainingM END;
                    SET @MNewPaid      = @MInstPaid + @MToApply;
                    SET @MNewBal       = @MInstAmt - @MNewPaid;
                    SET @MNewStatus    = CASE WHEN @MNewPaid >= @MInstAmt THEN 'Paid' WHEN @MNewPaid > 0 THEN 'Partial' ELSE 'Pending' END;
                    SET @MNewPayStatus = @MNewStatus;
                    UPDATE OwnerMonthlyContractInstallments
                    SET PaidAmount=@MNewPaid, Balance=@MNewBal, PaidDate=@Date, Status=@MNewStatus,
                        PaymentStatus=@MNewPayStatus, PaymentMode=@Mode, ExpenseId=@NewId, UpdatedAt=GETUTCDATE()
                    WHERE Id=@MInstId;
                    SET @RemainingM = @RemainingM - @MToApply;
                    FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;
                END;
                CLOSE minst_cur; DEALLOCATE minst_cur;
            END
            -- If no OwnerContract found, expense is saved but no installment/transaction update
        END
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id            INT,
    @Date          DATE,
    @Mode          NVARCHAR(MAX),
    @Head          NVARCHAR(MAX),
    @FundPool      NVARCHAR(MAX),
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX),
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(MAX),
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX),
    @Purpose       NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @OldAmount    DECIMAL(18,2),
            @OldFundPool  NVARCHAR(MAX),
            @OldExpenseId NVARCHAR(MAX);

    SELECT @OldAmount=Amount, @OldFundPool=FundPool, @OldExpenseId=ExpenseId FROM Expenses WHERE Id=@Id;

    DECLARE @NewFundPoolName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Code=@FundPool);
    DECLARE @CampName        NVARCHAR(MAX) = ISNULL((SELECT Name FROM Camps WHERE Id=@CampId), '');

    UPDATE Expenses
    SET Date=@Date, Mode=@Mode, Head=@Head, FundPool=@FundPool, FundPoolName=@NewFundPoolName,
        Amount=@Amount, Nature=@Nature, CampId=@CampId, CampName=@CampName,
        RecipientRole=@RecipientRole, RecipientId=@RecipientId, RecipientName=@RecipientName,
        Purpose=@Purpose, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- FundPool: restore old, apply new
    UPDATE FundPools SET Balance=Balance+@OldAmount, UpdatedAt=GETUTCDATE() WHERE Code=@OldFundPool;
    UPDATE FundPools SET Balance=Balance-@Amount,    UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;

    IF @RecipientRole = 'Owner'
    BEGIN
        DECLARE @OwnerId2 INT = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Owners WHERE Name=@RecipientName));

        IF @OwnerId2 IS NOT NULL
        BEGIN
            DECLARE @OcId2 INT = (SELECT TOP 1 Id FROM OwnerContracts WHERE OwnerId=@OwnerId2 AND (@CampId IS NULL OR CampId=@CampId) AND Status='Active' ORDER BY CreatedAt DESC);

            IF @OcId2 IS NOT NULL
            BEGIN
                -- Step 1A: Revert OwnerInstallments
                UPDATE OwnerInstallments
                SET PaidAmount = CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END,
                    PaidDate   = NULL,
                    Status     = CASE
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) = 0 THEN 'Pending'
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) >= Amount THEN 'Paid'
                        ELSE 'Partial' END,
                    ExpenseId  = NULL
                WHERE ExpenseId=@Id;

                -- Step 1B: Revert OwnerMonthlyContractInstallments
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount = CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END,
                    Balance    = Amount-(CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END),
                    PaidDate   = NULL,
                    Status     = CASE
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) = 0 THEN 'Pending'
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) >= Amount THEN 'Paid'
                        ELSE 'Partial' END,
                    PaymentStatus = CASE
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) = 0 THEN 'Pending'
                        WHEN (CASE WHEN PaidAmount-@OldAmount < 0 THEN 0 ELSE PaidAmount-@OldAmount END) >= Amount THEN 'Paid'
                        ELSE 'Partial' END,
                    ExpenseId  = NULL, UpdatedAt=GETUTCDATE()
                WHERE ExpenseId=@Id;

                -- Step 2A: Re-apply OwnerInstallments
                DECLARE @Remaining2 DECIMAL(18,2) = @Amount;
                DECLARE @InstId2 INT, @InstAmt2 DECIMAL(18,2), @InstPaid2 DECIMAL(18,2), @InstDue2 DECIMAL(18,2);
                DECLARE @ToApply2 DECIMAL(18,2), @NewPaid2 DECIMAL(18,2), @NewStatus2 NVARCHAR(20);

                DECLARE inst_cur2 CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Amount-PaidAmount FROM OwnerInstallments
                    WHERE OwnerContractId=@OcId2 AND Status IN ('Pending','Partial') ORDER BY No;

                OPEN inst_cur2;
                FETCH NEXT FROM inst_cur2 INTO @InstId2, @InstAmt2, @InstPaid2, @InstDue2;
                WHILE @@FETCH_STATUS=0 AND @Remaining2>0
                BEGIN
                    SET @ToApply2   = CASE WHEN @Remaining2>=@InstDue2 THEN @InstDue2 ELSE @Remaining2 END;
                    SET @NewPaid2   = @InstPaid2+@ToApply2;
                    SET @NewStatus2 = CASE WHEN @NewPaid2>=@InstAmt2 THEN 'Paid' WHEN @NewPaid2>0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerInstallments SET PaidAmount=@NewPaid2, PaidDate=@Date, Status=@NewStatus2, ExpenseId=@Id WHERE Id=@InstId2;
                    SET @Remaining2=@Remaining2-@ToApply2;
                    FETCH NEXT FROM inst_cur2 INTO @InstId2, @InstAmt2, @InstPaid2, @InstDue2;
                END;
                CLOSE inst_cur2; DEALLOCATE inst_cur2;

                -- Step 2B: Re-apply OwnerMonthlyContractInstallments
                DECLARE @RemainingM2 DECIMAL(18,2) = @Amount;
                DECLARE @MInstId2 INT, @MInstAmt2 DECIMAL(18,2), @MInstPaid2 DECIMAL(18,2), @MInstBal2 DECIMAL(18,2);
                DECLARE @MToApply2 DECIMAL(18,2), @MNewPaid2 DECIMAL(18,2), @MNewBal2 DECIMAL(18,2), @MNewStatus2 NVARCHAR(20);

                DECLARE minst_cur2 CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Balance FROM OwnerMonthlyContractInstallments
                    WHERE OwnerContractId=@OcId2 AND PaymentStatus IN ('Pending','Partial') ORDER BY InstallmentNo;

                OPEN minst_cur2;
                FETCH NEXT FROM minst_cur2 INTO @MInstId2, @MInstAmt2, @MInstPaid2, @MInstBal2;
                WHILE @@FETCH_STATUS=0 AND @RemainingM2>0
                BEGIN
                    SET @MToApply2  = CASE WHEN @RemainingM2>=@MInstBal2 THEN @MInstBal2 ELSE @RemainingM2 END;
                    SET @MNewPaid2  = @MInstPaid2+@MToApply2;
                    SET @MNewBal2   = @MInstAmt2-@MNewPaid2;
                    SET @MNewStatus2 = CASE WHEN @MNewPaid2>=@MInstAmt2 THEN 'Paid' WHEN @MNewPaid2>0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerMonthlyContractInstallments
                    SET PaidAmount=@MNewPaid2, Balance=@MNewBal2, PaidDate=@Date, Status=@MNewStatus2,
                        PaymentStatus=@MNewStatus2, PaymentMode=@Mode, ExpenseId=@Id, UpdatedAt=GETUTCDATE()
                    WHERE Id=@MInstId2;
                    SET @RemainingM2=@RemainingM2-@MToApply2;
                    FETCH NEXT FROM minst_cur2 INTO @MInstId2, @MInstAmt2, @MInstPaid2, @MInstBal2;
                END;
                CLOSE minst_cur2; DEALLOCATE minst_cur2;

                -- Update OwnerTransactions
                UPDATE OwnerTransactions SET Amount=@Amount, Date=@Date, CampId=@CampId, CampName=@CampName WHERE ExpenseId=@Id;
            END
        END
    END

    -- Update TxnRecords if tenant expense
    IF EXISTS (SELECT 1 FROM TxnRecords WHERE Description LIKE '%'+@OldExpenseId+'%')
        UPDATE TxnRecords
        SET Amount=@Amount, PaidDate=@Date, PaymentMode=@Mode, FundPoolName=@NewFundPoolName, UpdatedAt=GETUTCDATE()
        WHERE Description LIKE '%'+@OldExpenseId+'%';

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CreateExpense and sp_UpdateExpense fixed - NULL OcCode guard added';
GO
