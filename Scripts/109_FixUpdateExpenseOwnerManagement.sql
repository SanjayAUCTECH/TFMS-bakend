-- ============================================================
-- 109: Fix sp_UpdateExpense - Owner payment revert + re-apply
-- When RecipientRole='Owner':
--   Step A: Revert old owner payment (undo previous installment updates)
--   Step B: Update Expense + FundPool
--   Step C: Re-apply new amount to owner tables
-- IsDeleted=0 filters on all tables
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id            INT,
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
    @ExpenseId     NVARCHAR(MAX) = '',
    @OldRole       NVARCHAR(MAX) = '',
    @UpdatedBy     INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Get old values
    DECLARE @OldAmount      DECIMAL(18,2);
    DECLARE @OldFPool       NVARCHAR(MAX);
    DECLARE @OldRecipientId INT;
    DECLARE @OldCampId      INT;

    SELECT
        @OldAmount      = Amount,
        @OldFPool       = FundPool,
        @OldRecipientId = RecipientId,
        @OldCampId      = CampId
    FROM Expenses WHERE Id=@Id AND IsDeleted=0;

    IF @OldAmount IS NULL
    BEGIN RAISERROR('Expense %d not found.', 16, 1, @Id); RETURN; END

    -- ── Step A: Revert old Owner payment if was Owner expense ─────
    IF (@OldRole='Owner' OR @RecipientRole='Owner') AND @OldRecipientId IS NOT NULL
    BEGIN
        -- Find old OwnerContract
        DECLARE @OldOcId INT;
        SELECT TOP 1 @OldOcId=oc.Id
        FROM OwnerContracts oc
        WHERE oc.OwnerId=@OldRecipientId AND oc.IsDeleted=0 AND oc.Status='Active'
          AND (@OldCampId IS NULL OR oc.CampId=@OldCampId)
        ORDER BY oc.CreatedAt DESC;

        IF @OldOcId IS NOT NULL
        BEGIN
            -- Revert OwnerInstallments (undo what this expense applied)
            UPDATE oi
            SET oi.PaidAmount = CASE WHEN ISNULL(oi.PaidAmount,0) - @OldAmount < 0 THEN 0
                                ELSE ISNULL(oi.PaidAmount,0) - @OldAmount END,
                oi.PaidDate  = NULL,
                oi.Status    = CASE
                    WHEN (CASE WHEN ISNULL(oi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(oi.PaidAmount,0)-@OldAmount END)=0 THEN 'Pending'
                    WHEN (CASE WHEN ISNULL(oi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(oi.PaidAmount,0)-@OldAmount END)>=oi.Amount THEN 'Paid'
                    ELSE 'Partial' END,
                oi.ExpenseId = NULL
            FROM OwnerInstallments oi
            WHERE oi.OwnerContractId=@OldOcId
              AND oi.ExpenseId=@Id
              AND ISNULL(oi.IsDeleted,0)=0;

            -- Revert OwnerMonthlyContractInstallments
            UPDATE mi
            SET mi.PaidAmount    = CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0
                                   ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END,
                mi.Balance       = mi.Amount - (CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END),
                mi.PaidDate      = NULL,
                mi.Status        = CASE
                    WHEN (CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END)=0 THEN 'Pending'
                    WHEN (CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END)>=mi.Amount THEN 'Paid'
                    ELSE 'Partial' END,
                mi.PaymentStatus = CASE
                    WHEN (CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END)=0 THEN 'Pending'
                    WHEN (CASE WHEN ISNULL(mi.PaidAmount,0)-@OldAmount<0 THEN 0 ELSE ISNULL(mi.PaidAmount,0)-@OldAmount END)>=mi.Amount THEN 'Paid'
                    ELSE 'Partial' END,
                mi.ExpenseId     = NULL,
                mi.UpdatedAt     = GETUTCDATE()
            FROM OwnerMonthlyContractInstallments mi
            WHERE mi.OwnerContractId=@OldOcId
              AND mi.ExpenseId=@Id
              AND ISNULL(mi.IsDeleted,0)=0;

            -- Update OwnerTransactions linked to this expense
            UPDATE OwnerTransactions
            SET Amount=@Amount, Date=@Date,
                CampId=@CampId, CampName=@CampName
            WHERE ExpenseId=@Id AND ISNULL(IsDeleted,0)=0;
        END
    END

    -- ── Step B: Update Expense + FundPool ─────────────────────────
    UPDATE Expenses
    SET Date=@Date, Head=@Head, Nature=@Nature,
        CampId=@CampId, CampName=@CampName,
        RecipientRole=@RecipientRole, RecipientId=@RecipientId, RecipientName=@RecipientName,
        Amount=@Amount, FundPool=@FundPool, FundPoolName=@FundPoolName,
        Mode=@Mode, Purpose=@Purpose,
        UpdatedBy=@UpdatedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;

    -- FundPool: restore old, apply new
    IF @OldFPool IS NOT NULL AND LEN(@OldFPool)>0 AND @OldAmount>0
        UPDATE FundPools SET Balance=Balance+@OldAmount, UpdatedAt=GETUTCDATE()
        WHERE Code=@OldFPool AND IsDeleted=0;
    IF @FundPool IS NOT NULL AND LEN(@FundPool)>0 AND @Amount>0
        UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE()
        WHERE Code=@FundPool AND IsDeleted=0;

    -- ── Step C: Re-apply new Owner payment ───────────────────────
    IF @RecipientRole='Owner' AND @RecipientId IS NOT NULL
    BEGIN
        DECLARE @NewOcId INT;
        SELECT TOP 1 @NewOcId=oc.Id
        FROM OwnerContracts oc
        WHERE oc.OwnerId=@RecipientId AND oc.IsDeleted=0 AND oc.Status='Active'
          AND (@CampId IS NULL OR oc.CampId=@CampId)
        ORDER BY oc.CreatedAt DESC;

        IF @NewOcId IS NOT NULL
        BEGIN
            -- Re-apply to OwnerInstallments
            DECLARE @Rem   DECIMAL(18,2) = @Amount;
            DECLARE @IId   INT; DECLARE @IAmt DECIMAL(18,2);
            DECLARE @IPaid DECIMAL(18,2); DECLARE @IDue DECIMAL(18,2);
            DECLARE @IToa  DECIMAL(18,2); DECLARE @INP  DECIMAL(18,2);
            DECLARE @ISt   NVARCHAR(MAX);

            DECLARE ic CURSOR LOCAL FAST_FORWARD FOR
                SELECT Id, Amount, ISNULL(PaidAmount,0), Amount-ISNULL(PaidAmount,0)
                FROM OwnerInstallments
                WHERE OwnerContractId=@NewOcId AND ISNULL(IsDeleted,0)=0
                  AND Status IN ('Pending','Partial')
                ORDER BY No;
            OPEN ic;
            FETCH NEXT FROM ic INTO @IId, @IAmt, @IPaid, @IDue;
            WHILE @@FETCH_STATUS=0 AND @Rem>0
            BEGIN
                SET @IToa = CASE WHEN @Rem>=@IDue THEN @IDue ELSE @Rem END;
                SET @INP  = @IPaid + @IToa;
                SET @ISt  = CASE WHEN @INP>=@IAmt THEN 'Paid' WHEN @INP>0 THEN 'Partial' ELSE 'Pending' END;
                UPDATE OwnerInstallments
                SET PaidAmount=@INP, PaidDate=@Date, Status=@ISt, ExpenseId=@Id, UpdatedBy=@UpdatedBy
                WHERE Id=@IId AND ISNULL(IsDeleted,0)=0;
                SET @Rem = @Rem - @IToa;
                FETCH NEXT FROM ic INTO @IId, @IAmt, @IPaid, @IDue;
            END;
            CLOSE ic; DEALLOCATE ic;

            -- Re-apply to OwnerMonthlyContractInstallments
            DECLARE @MRem  DECIMAL(18,2) = @Amount;
            DECLARE @MId   INT; DECLARE @MAmt  DECIMAL(18,2);
            DECLARE @MPaid DECIMAL(18,2); DECLARE @MBal DECIMAL(18,2);
            DECLARE @MToa  DECIMAL(18,2); DECLARE @MNP  DECIMAL(18,2);
            DECLARE @MNB   DECIMAL(18,2); DECLARE @MSt  NVARCHAR(MAX);

            DECLARE mc CURSOR LOCAL FAST_FORWARD FOR
                SELECT Id, Amount, ISNULL(PaidAmount,0), ISNULL(Balance,Amount)
                FROM OwnerMonthlyContractInstallments
                WHERE OwnerContractId=@NewOcId AND ISNULL(IsDeleted,0)=0
                  AND PaymentStatus IN ('Pending','Partial')
                ORDER BY InstallmentNo;
            OPEN mc;
            FETCH NEXT FROM mc INTO @MId, @MAmt, @MPaid, @MBal;
            WHILE @@FETCH_STATUS=0 AND @MRem>0
            BEGIN
                SET @MToa = CASE WHEN @MRem>=@MBal THEN @MBal ELSE @MRem END;
                SET @MNP  = @MPaid + @MToa;
                SET @MNB  = CASE WHEN @MAmt-@MNP<0 THEN 0 ELSE @MAmt-@MNP END;
                SET @MSt  = CASE WHEN @MNP>=@MAmt THEN 'Paid' WHEN @MNP>0 THEN 'Partial' ELSE 'Pending' END;
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount=@MNP, Balance=@MNB, PaidDate=@Date,
                    Status=@MSt, PaymentStatus=@MSt,
                    PaymentMode=@Mode, ExpenseId=@Id, UpdatedAt=GETUTCDATE()
                WHERE Id=@MId AND ISNULL(IsDeleted,0)=0;
                SET @MRem = @MRem - @MToa;
                FETCH NEXT FROM mc INTO @MId, @MAmt, @MPaid, @MBal;
            END;
            CLOSE mc; DEALLOCATE mc;
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

PRINT '✅ sp_UpdateExpense fixed - Owner revert + re-apply on edit';
GO
