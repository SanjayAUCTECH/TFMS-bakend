-- ============================================================
-- Add Tenant payment logic to sp_CreateExpense & sp_UpdateExpense
-- When RecipientRole = 'Tenant':
--   → INSERT into TxnRecords with TxnType = 'DR'
-- When updated/deleted:
--   → UPDATE/DELETE the linked TxnRecord
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
            DECLARE @OcId   INT           = (SELECT TOP 1 Id FROM OwnerContracts WHERE OwnerId = @OwnerId AND (@CampId IS NULL OR CampId = @CampId) AND Status = 'Active' ORDER BY CreatedAt DESC);
            DECLARE @OcCode NVARCHAR(MAX) = (SELECT OcCode FROM OwnerContracts WHERE Id = @OcId);

            IF @OcId IS NOT NULL
            BEGIN
                DECLARE @OtCode NVARCHAR(MAX) = 'OT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR), 6);

                INSERT INTO OwnerTransactions(TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName, Type, Amount, Date, Description, ExpenseId, CreatedAt)
                VALUES(@OtCode, @OcId, @OcCode, @CampId, @CampName, @OwnerId, @RecipientName, 'CR', @Amount, @Date, 'Payment via expense - ' + @ExpenseId, @NewId, GETUTCDATE());

                -- Update OwnerInstallments
                DECLARE @Remaining DECIMAL(18,2) = @Amount;
                DECLARE @InstId INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2), @InstDue DECIMAL(18,2);
                DECLARE @ToApply DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(20);

                DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Amount - PaidAmount FROM OwnerInstallments
                    WHERE OwnerContractId = @OcId AND Status IN ('Pending','Partial') ORDER BY No;

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
                DECLARE @MToApply DECIMAL(18,2), @MNewPaid DECIMAL(18,2), @MNewBal DECIMAL(18,2), @MNewSt NVARCHAR(20);

                DECLARE minst_cur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id, Amount, PaidAmount, Balance FROM OwnerMonthlyContractInstallments
                    WHERE OwnerContractId = @OcId AND PaymentStatus IN ('Pending','Partial') ORDER BY InstallmentNo;

                OPEN minst_cur;
                FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;
                WHILE @@FETCH_STATUS = 0 AND @RemainingM > 0
                BEGIN
                    SET @MToApply  = CASE WHEN @RemainingM >= @MInstBal THEN @MInstBal ELSE @RemainingM END;
                    SET @MNewPaid  = @MInstPaid + @MToApply;
                    SET @MNewBal   = @MInstAmt - @MNewPaid;
                    SET @MNewSt    = CASE WHEN @MNewPaid >= @MInstAmt THEN 'Paid' WHEN @MNewPaid > 0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerMonthlyContractInstallments
                    SET PaidAmount=@MNewPaid, Balance=@MNewBal, PaidDate=@Date, Status=@MNewSt,
                        PaymentStatus=@MNewSt, PaymentMode=@Mode, ExpenseId=@NewId, UpdatedAt=GETUTCDATE()
                    WHERE Id=@MInstId;
                    SET @RemainingM = @RemainingM - @MToApply;
                    FETCH NEXT FROM minst_cur INTO @MInstId, @MInstAmt, @MInstPaid, @MInstBal;
                END;
                CLOSE minst_cur; DEALLOCATE minst_cur;
            END
        END
    END

    -- ── Tenant payment → TxnRecords (DR) ──────────────────────────────────────
    IF @RecipientRole = 'Tenant'
    BEGIN
        DECLARE @TenantId    INT           = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Tenants WHERE Name = @RecipientName));
        DECLARE @ContractId  NVARCHAR(MAX) = (SELECT TOP 1 ContractId FROM Contracts WHERE TenantId = @TenantId AND (@CampId IS NULL OR CampId = @CampId) AND Status = 'Active' ORDER BY CreatedAt DESC);
        DECLARE @TxnId       NVARCHAR(MAX) = 'TXN-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6);

        INSERT INTO TxnRecords (
            TxnId, ContractId, Amount, PaidDate, PaymentMode, Description,
            IssuedBy, FundPoolName, TxnType, TenantId, CampId, TotalAmount,
            AppliedInstallments, Unallocated, CreatedAt
        )
        VALUES (
            @TxnId,
            ISNULL(@ContractId, ''),       -- ContractId (empty if no active contract)
            @Amount,
            @Date,
            @Mode,
            'Refund/Payment to Tenant via expense - ' + @ExpenseId,
            '',                            -- IssuedBy
            @FundPoolName,
            'DR',                          -- TxnType = DR (money going OUT to tenant)
            @TenantId,
            @CampId,
            @Amount,
            '',                            -- AppliedInstallments
            0,                             -- Unallocated
            GETUTCDATE()
        );
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
            @OldExpenseId NVARCHAR(MAX),
            @OldRole      NVARCHAR(MAX);

    SELECT @OldAmount=Amount, @OldFundPool=FundPool, @OldExpenseId=ExpenseId, @OldRole=RecipientRole
    FROM Expenses WHERE Id=@Id;

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

    -- ── Owner: revert + re-apply ───────────────────────────────────────────────
    IF @RecipientRole = 'Owner'
    BEGIN
        DECLARE @OwnerId2 INT = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Owners WHERE Name=@RecipientName));

        IF @OwnerId2 IS NOT NULL
        BEGIN
            DECLARE @OcId2 INT = (SELECT TOP 1 Id FROM OwnerContracts WHERE OwnerId=@OwnerId2 AND (@CampId IS NULL OR CampId=@CampId) AND Status='Active' ORDER BY CreatedAt DESC);

            IF @OcId2 IS NOT NULL
            BEGIN
                -- Revert OwnerInstallments
                UPDATE OwnerInstallments
                SET PaidAmount=CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END,
                    PaidDate=NULL,
                    Status=CASE WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)=0 THEN 'Pending'
                                WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)>=Amount THEN 'Paid'
                                ELSE 'Partial' END,
                    ExpenseId=NULL
                WHERE ExpenseId=@Id;

                -- Revert OwnerMonthlyContractInstallments
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount=CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END,
                    Balance=Amount-(CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END),
                    PaidDate=NULL,
                    Status=CASE WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)=0 THEN 'Pending'
                                WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)>=Amount THEN 'Paid'
                                ELSE 'Partial' END,
                    PaymentStatus=CASE WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)=0 THEN 'Pending'
                                       WHEN (CASE WHEN PaidAmount-@OldAmount<0 THEN 0 ELSE PaidAmount-@OldAmount END)>=Amount THEN 'Paid'
                                       ELSE 'Partial' END,
                    ExpenseId=NULL, UpdatedAt=GETUTCDATE()
                WHERE ExpenseId=@Id;

                -- Re-apply OwnerInstallments
                DECLARE @Rem2 DECIMAL(18,2)=@Amount;
                DECLARE @II2 INT, @IA2 DECIMAL(18,2), @IP2 DECIMAL(18,2), @ID2 DECIMAL(18,2);
                DECLARE @TA2 DECIMAL(18,2), @NP2 DECIMAL(18,2), @NS2 NVARCHAR(20);
                DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id,Amount,PaidAmount,Amount-PaidAmount FROM OwnerInstallments
                    WHERE OwnerContractId=@OcId2 AND Status IN ('Pending','Partial') ORDER BY No;
                OPEN c2; FETCH NEXT FROM c2 INTO @II2,@IA2,@IP2,@ID2;
                WHILE @@FETCH_STATUS=0 AND @Rem2>0 BEGIN
                    SET @TA2=CASE WHEN @Rem2>=@ID2 THEN @ID2 ELSE @Rem2 END;
                    SET @NP2=@IP2+@TA2;
                    SET @NS2=CASE WHEN @NP2>=@IA2 THEN 'Paid' WHEN @NP2>0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerInstallments SET PaidAmount=@NP2,PaidDate=@Date,Status=@NS2,ExpenseId=@Id WHERE Id=@II2;
                    SET @Rem2=@Rem2-@TA2;
                    FETCH NEXT FROM c2 INTO @II2,@IA2,@IP2,@ID2;
                END; CLOSE c2; DEALLOCATE c2;

                -- Re-apply OwnerMonthlyContractInstallments
                DECLARE @RemM2 DECIMAL(18,2)=@Amount;
                DECLARE @MI2 INT, @MA2 DECIMAL(18,2), @MP2 DECIMAL(18,2), @MB2 DECIMAL(18,2);
                DECLARE @MT2 DECIMAL(18,2), @MNP2 DECIMAL(18,2), @MNB2 DECIMAL(18,2), @MNS2 NVARCHAR(20);
                DECLARE mc2 CURSOR LOCAL FAST_FORWARD FOR
                    SELECT Id,Amount,PaidAmount,Balance FROM OwnerMonthlyContractInstallments
                    WHERE OwnerContractId=@OcId2 AND PaymentStatus IN ('Pending','Partial') ORDER BY InstallmentNo;
                OPEN mc2; FETCH NEXT FROM mc2 INTO @MI2,@MA2,@MP2,@MB2;
                WHILE @@FETCH_STATUS=0 AND @RemM2>0 BEGIN
                    SET @MT2=CASE WHEN @RemM2>=@MB2 THEN @MB2 ELSE @RemM2 END;
                    SET @MNP2=@MP2+@MT2; SET @MNB2=@MA2-@MNP2;
                    SET @MNS2=CASE WHEN @MNP2>=@MA2 THEN 'Paid' WHEN @MNP2>0 THEN 'Partial' ELSE 'Pending' END;
                    UPDATE OwnerMonthlyContractInstallments
                    SET PaidAmount=@MNP2,Balance=@MNB2,PaidDate=@Date,Status=@MNS2,
                        PaymentStatus=@MNS2,PaymentMode=@Mode,ExpenseId=@Id,UpdatedAt=GETUTCDATE()
                    WHERE Id=@MI2;
                    SET @RemM2=@RemM2-@MT2;
                    FETCH NEXT FROM mc2 INTO @MI2,@MA2,@MP2,@MB2;
                END; CLOSE mc2; DEALLOCATE mc2;

                -- Update OwnerTransactions
                UPDATE OwnerTransactions SET Amount=@Amount,Date=@Date,CampId=@CampId,CampName=@CampName WHERE ExpenseId=@Id;
            END
        END
    END

    -- ── Tenant payment → update TxnRecords ────────────────────────────────────
    IF @RecipientRole = 'Tenant'
    BEGIN
        -- If TxnRecord exists for this expense, update it
        IF EXISTS (SELECT 1 FROM TxnRecords WHERE Description LIKE '%' + @OldExpenseId + '%' AND TxnType = 'DR')
        BEGIN
            UPDATE TxnRecords
            SET Amount      = @Amount,
                TotalAmount = @Amount,
                PaidDate    = @Date,
                PaymentMode = @Mode,
                FundPoolName = @NewFundPoolName,
                CampId      = @CampId,
                UpdatedAt   = GETUTCDATE()
            WHERE Description LIKE '%' + @OldExpenseId + '%' AND TxnType = 'DR';
        END
        ELSE
        BEGIN
            -- Create new TxnRecord if not exists (role might have changed to Tenant on edit)
            DECLARE @TenantId2   INT           = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Tenants WHERE Name=@RecipientName));
            DECLARE @ContractId2 NVARCHAR(MAX) = (SELECT TOP 1 ContractId FROM Contracts WHERE TenantId=@TenantId2 AND (@CampId IS NULL OR CampId=@CampId) AND Status='Active' ORDER BY CreatedAt DESC);
            DECLARE @TxnId2      NVARCHAR(MAX) = 'TXN-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6);

            INSERT INTO TxnRecords (
                TxnId, ContractId, Amount, PaidDate, PaymentMode, Description,
                IssuedBy, FundPoolName, TxnType, TenantId, CampId, TotalAmount,
                AppliedInstallments, Unallocated, CreatedAt
            )
            VALUES (
                @TxnId2, ISNULL(@ContractId2,''), @Amount, @Date, @Mode,
                'Refund/Payment to Tenant via expense - ' + @OldExpenseId,
                '', @NewFundPoolName, 'DR', @TenantId2, @CampId, @Amount,
                '', 0, GETUTCDATE()
            );
        END
    END
    ELSE IF @OldRole = 'Tenant' AND @RecipientRole != 'Tenant'
    BEGIN
        -- Role changed away from Tenant — remove the DR TxnRecord
        DELETE FROM TxnRecords WHERE Description LIKE '%' + @OldExpenseId + '%' AND TxnType = 'DR';
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ Tenant payment logic added to Expense SPs - TxnRecords DR entry created';
GO
