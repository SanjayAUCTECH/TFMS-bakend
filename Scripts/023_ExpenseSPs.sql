-- ============================================================
-- TFMS Script 023 — Expense SPs: Create / Update / Delete
-- Rules:
--   RecipientRole = 'Owner'  → OwnerTransactions CR entry
--   RecipientRole = 'Tenant' → TxnRecords CR entry
--   Update/Delete: sync related tables + FundPool
-- ============================================================
USE TFMS_softwareDB;
GO

-- ── sp_CreateExpense ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date          DATE,
    @Mode          NVARCHAR(MAX),
    @Head          NVARCHAR(MAX),
    @FundPool      NVARCHAR(MAX),
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX),
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(MAX),
    @RecipientName NVARCHAR(MAX),
    @Purpose       NVARCHAR(MAX),
    @NewId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ExpenseId   NVARCHAR(MAX) = 'EXP-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR),6);
        DECLARE @FundPoolName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Code=@FundPool);
        DECLARE @CampName    NVARCHAR(MAX) = ISNULL((SELECT Name FROM Camps WHERE Id=@CampId),'');

        INSERT INTO Expenses(ExpenseId,Date,Mode,Head,FundPool,FundPoolName,Amount,Nature,
            CampId,CampName,RecipientRole,RecipientName,Purpose,CreatedAt,UpdatedAt)
        VALUES(@ExpenseId,@Date,@Mode,@Head,@FundPool,@FundPoolName,@Amount,@Nature,
            @CampId,@CampName,@RecipientRole,@RecipientName,@Purpose,GETUTCDATE(),GETUTCDATE());

        SET @NewId = SCOPE_IDENTITY();

        -- Deduct FundPool balance
        UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;

        -- ── Owner → OwnerTransactions CR ─────────────────────────────
        IF @RecipientRole = 'Owner'
        BEGIN
            DECLARE @OwnerId INT = (SELECT TOP 1 Id FROM Owners WHERE Name=@RecipientName);
            IF @OwnerId IS NOT NULL
            BEGIN
                DECLARE @OcId   INT          = (SELECT TOP 1 Id   FROM OwnerContracts WHERE OwnerId=@OwnerId AND (@CampId IS NULL OR CampId=@CampId) ORDER BY CreatedAt DESC);
                DECLARE @OcCode NVARCHAR(MAX) = (SELECT OcCode FROM OwnerContracts WHERE Id=@OcId);
                DECLARE @OtCode NVARCHAR(MAX) = 'OT-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),6);

                INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,ExpenseId,CreatedAt)
                VALUES(@OtCode,@OcId,@OcCode,@CampId,@CampName,@OwnerId,@RecipientName,'CR',@Amount,@Date,'Payment via expense - '+@ExpenseId,@NewId,GETUTCDATE());

                -- Mark first pending OwnerInstallment as paid/partial
                UPDATE TOP(1) OwnerInstallments
                SET PaidAmount=@Amount, PaidDate=@Date,
                    Status=CASE WHEN @Amount>=Amount THEN 'Paid' WHEN @Amount>0 THEN 'Partial' ELSE 'Pending' END,
                    ExpenseId=@NewId
                WHERE OwnerContractId=@OcId AND Status IN('Pending','Partial');
            END
        END

        -- ── Tenant → TxnRecords CR ───────────────────────────────────
        IF @RecipientRole = 'Tenant'
        BEGIN
            DECLARE @TenantId  INT = (SELECT TOP 1 Id FROM Tenants WHERE Name=@RecipientName);
            DECLARE @ContractId NVARCHAR(MAX) = NULL;
            IF @TenantId IS NOT NULL
                SELECT TOP 1 @ContractId=ContractId FROM Contracts
                WHERE TenantId=@TenantId AND Status='Active'
                  AND (@CampId IS NULL OR CampId=@CampId)
                ORDER BY CreatedAt DESC;

            DECLARE @TxnId NVARCHAR(MAX) = 'TXN-'+CONVERT(NVARCHAR(MAX),@Date,112)+'-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),6);
            DECLARE @TcId INT = ISNULL(@CampId, 0);

            INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
                TotalAmount,Amount,PaidDate,PaymentMode,
                FundPoolName,Description,ReceivedBy,
                AppliedInstallments,Unallocated,CreatedAt,UpdatedAt)
            VALUES(@TxnId,'CR',
                ISNULL(@ContractId,'—'), ISNULL(@ContractId,'—'),
                ISNULL(@TenantId,0), ISNULL(@CampId,0),
                @Amount, @Amount, @Date, @Mode,
                @FundPoolName, 'Expense payment: '+@ExpenseId, @RecipientName,
                '', 0, GETUTCDATE(), GETUTCDATE());
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── sp_UpdateExpense ─────────────────────────────────────────
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
    @RecipientName NVARCHAR(MAX),
    @Purpose       NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Get old values
        DECLARE @OldAmount        DECIMAL(18,2);
        DECLARE @OldFundPool      NVARCHAR(MAX);
        DECLARE @OldRecipientRole NVARCHAR(MAX);
        DECLARE @OldExpenseId     NVARCHAR(MAX);

        SELECT @OldAmount=Amount, @OldFundPool=FundPool,
               @OldRecipientRole=RecipientRole, @OldExpenseId=ExpenseId
        FROM Expenses WHERE Id=@Id;

        DECLARE @NewFundPoolName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Code=@FundPool);
        DECLARE @CampName        NVARCHAR(MAX) = ISNULL((SELECT Name FROM Camps WHERE Id=@CampId),'');

        -- Update Expenses row
        UPDATE Expenses
        SET Date=@Date, Mode=@Mode, Head=@Head, FundPool=@FundPool,
            FundPoolName=@NewFundPoolName, Amount=@Amount, Nature=@Nature,
            CampId=@CampId, CampName=@CampName,
            RecipientRole=@RecipientRole, RecipientName=@RecipientName,
            Purpose=@Purpose, UpdatedAt=GETUTCDATE()
        WHERE Id=@Id;

        -- Adjust FundPool balance
        UPDATE FundPools SET Balance=Balance+@OldAmount, UpdatedAt=GETUTCDATE() WHERE Code=@OldFundPool;
        UPDATE FundPools SET Balance=Balance-@Amount,    UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;

        -- ── Update OwnerTransactions if existed ──────────────────────
        IF EXISTS (SELECT 1 FROM OwnerTransactions WHERE ExpenseId=@Id)
            UPDATE OwnerTransactions
            SET Amount=@Amount, Date=@Date, Description='Payment via expense - '+@OldExpenseId,
                CampId=@CampId, CampName=@CampName
            WHERE ExpenseId=@Id;

        -- ── Update TxnRecords if existed ─────────────────────────────
        IF EXISTS (SELECT 1 FROM TxnRecords WHERE Description LIKE '%'+@OldExpenseId+'%')
            UPDATE TxnRecords
            SET Amount=@Amount, TotalAmount=@Amount, PaidDate=@Date, PaymentMode=@Mode,
                FundPoolName=@NewFundPoolName, UpdatedAt=GETUTCDATE()
            WHERE Description LIKE '%'+@OldExpenseId+'%';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── sp_DeleteExpense ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteExpense
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Amount      DECIMAL(18,2);
        DECLARE @FundPool    NVARCHAR(MAX);
        DECLARE @ExpenseId   NVARCHAR(MAX);

        SELECT @Amount=Amount, @FundPool=FundPool, @ExpenseId=ExpenseId
        FROM Expenses WHERE Id=@Id;

        IF @Amount IS NULL
        BEGIN
            COMMIT TRANSACTION; RETURN;
        END

        -- Restore FundPool balance
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;

        -- Delete related OwnerTransaction
        DELETE FROM OwnerTransactions WHERE ExpenseId=@Id;

        -- Revert OwnerInstallment if linked
        UPDATE OwnerInstallments
        SET PaidAmount=0, PaidDate=NULL, Status='Pending', ExpenseId=NULL
        WHERE ExpenseId=@Id;

        -- Delete related TxnRecord (tenant payment)
        DELETE FROM TxnRecords WHERE Description LIKE '%'+@ExpenseId+'%';

        -- Delete the expense
        DELETE FROM Expenses WHERE Id=@Id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Script 023 — Expense SPs (Create/Update/Delete) applied!';
GO
