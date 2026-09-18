USE [TFMS_TestSoftwareDB];
GO

ALTER PROCEDURE [dbo].[sp_DeleteAccountMaster]
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @AccountId NVARCHAR(20);
        DECLARE @FundPool NVARCHAR(50);
        SELECT @AccountId = AccountId, @FundPool = FundPool FROM AccountMasters WHERE Id = @Id AND IsDeleted = 0;
        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END
        IF @FundPool IS NOT NULL AND @FundPool != ''
        BEGIN
            DECLARE @IncomeTotal DECIMAL(18,2) = 0;
            DECLARE @ExpenseTotal DECIMAL(18,2) = 0;
            SELECT @IncomeTotal = ISNULL(SUM(Amount), 0) FROM Incomes WHERE AccountId = @AccountId AND IsDeleted = 0;
            SELECT @ExpenseTotal = ISNULL(SUM(Amount), 0) FROM Expenses WHERE AccountId = @AccountId AND IsDeleted = 0;
            DECLARE @ReversalAdjustment DECIMAL(18,2);
            SET @ReversalAdjustment = -@IncomeTotal + @ExpenseTotal;
            UPDATE FundPools SET Balance = ISNULL(Balance, 0) + @ReversalAdjustment, UpdatedAt = GETDATE() WHERE Code = @FundPool AND ISNULL(IsDeleted, 0) = 0;
        END
        UPDATE Incomes SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        UPDATE Expenses SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        UPDATE PartnerTrans SET IsDeleted = 1, IsDeletedBy = @DeletedBy, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        UPDATE AccountMasters SET IsDeleted = 1, DeletedBy = @DeletedBy, UpdatedAt = GETDATE() WHERE Id = @Id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

PRINT 'sp_DeleteAccountMaster updated successfully with NEW FundPool reversal logic!';
GO
