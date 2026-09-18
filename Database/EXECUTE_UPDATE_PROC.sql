USE [TFMS_TestSoftwareDB];
GO

ALTER PROCEDURE [dbo].[sp_UpdateAccountMaster]
    @Id             INT,
    @TransDate      DATETIME,
    @Mode           NVARCHAR(100),
    @FundPool       NVARCHAR(50)    = '',
    @FundPoolName   NVARCHAR(200)   = '',
    @Nature         NVARCHAR(50)    = '',
    @CampId         INT             = NULL,
    @CampName       NVARCHAR(200)   = '',
    @RecipientRole  NVARCHAR(100)   = '',
    @RecipientId    INT             = NULL,
    @RecipientName  NVARCHAR(200)   = '',
    @Purpose        NVARCHAR(500)   = '',
    @UpdatedBy      INT             = NULL,
    @Heads          dbo.AccountMasterHeadType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @AccountId NVARCHAR(20);
        DECLARE @VoucherNo NVARCHAR(100);
        DECLARE @OldFundPool NVARCHAR(50);
        SELECT @AccountId = AccountId, @VoucherNo = VoucherNo, @OldFundPool = FundPool FROM AccountMasters WHERE Id = @Id AND IsDeleted = 0;
        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END
        IF @OldFundPool IS NOT NULL AND @OldFundPool != ''
        BEGIN
            DECLARE @OldIncomeTotal DECIMAL(18,2) = 0;
            DECLARE @OldExpenseTotal DECIMAL(18,2) = 0;
            SELECT @OldIncomeTotal = ISNULL(SUM(Amount), 0) FROM Incomes WHERE AccountId = @AccountId AND IsDeleted = 0;
            SELECT @OldExpenseTotal = ISNULL(SUM(Amount), 0) FROM Expenses WHERE AccountId = @AccountId AND IsDeleted = 0;
            DECLARE @OldAdjustment DECIMAL(18,2);
            SET @OldAdjustment = @OldIncomeTotal - @OldExpenseTotal;
            UPDATE FundPools SET Balance = ISNULL(Balance, 0) - @OldAdjustment, UpdatedAt = GETDATE() WHERE Code = @OldFundPool AND ISNULL(IsDeleted, 0) = 0;
        END
        DECLARE @TotalAmount DECIMAL(18,2);
        DECLARE @PaymentType NVARCHAR(20);
        DECLARE @IncomeCount INT;
        DECLARE @ExpenseCount INT;
        SELECT @TotalAmount = ISNULL(SUM(Amount), 0) FROM @Heads;
        SELECT @IncomeCount = COUNT(*) FROM @Heads WHERE PaymentType = 'Income';
        SELECT @ExpenseCount = COUNT(*) FROM @Heads WHERE PaymentType = 'Expense';
        SET @PaymentType = CASE
            WHEN @IncomeCount > 0 AND @ExpenseCount = 0 THEN 'Income'
            WHEN @ExpenseCount > 0 AND @IncomeCount = 0 THEN 'Expense'
            ELSE 'Mixed'
        END;
        UPDATE AccountMasters SET TransDate = @TransDate, PaymentType = @PaymentType, Mode = @Mode, FundPool = @FundPool, FundPoolName = @FundPoolName, Amount = @TotalAmount, Nature = @Nature, RecipientRole = @RecipientRole, RecipientId = @RecipientId, RecipientName = @RecipientName, Purpose = @Purpose, UpdatedBy = @UpdatedBy, UpdatedAt = GETDATE() WHERE Id = @Id;
        UPDATE Incomes SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        UPDATE Expenses SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        DECLARE @HeadPaymentType2 NVARCHAR(20);
        DECLARE @HeadHead2 NVARCHAR(200);
        DECLARE @HeadAmount2 DECIMAL(18,2);
        DECLARE @HeadPurpose2 NVARCHAR(500);
        DECLARE head_cursor2 CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Head, Amount, Purpose FROM @Heads;
        OPEN head_cursor2;
        FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @HeadPaymentType2 = 'Income'
            BEGIN
                DECLARE @IncomeId2 NVARCHAR(20);
                SELECT @IncomeId2 = 'INC-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6) FROM Incomes;
                INSERT INTO Incomes (IncomeId, [Date], Mode, Head, FundPool, FundPoolName, Amount, Purpose, Source, SourceRef, CampId, CampName, AccountId, VoucherNo, TransDate, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES (@IncomeId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName, @HeadAmount2, ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), 'Manual', '', @CampId, @CampName, @AccountId, @VoucherNo, @TransDate, @UpdatedBy, 0, GETDATE(), GETDATE());
            END
            ELSE IF @HeadPaymentType2 = 'Expense'
            BEGIN
                DECLARE @ExpenseId2 NVARCHAR(20);
                SELECT @ExpenseId2 = 'EXP-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6) FROM Expenses;
                INSERT INTO Expenses (ExpenseId, [Date], Mode, Head, FundPool, FundPoolName, Amount, Nature, CampId, CampName, RecipientRole, RecipientId, RecipientName, Purpose, AccountId, VoucherNo, TransDate, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES (@ExpenseId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName, @HeadAmount2, @Nature, @CampId, @CampName, @RecipientRole, @RecipientId, @RecipientName, ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), @AccountId, @VoucherNo, @TransDate, @UpdatedBy, 0, GETDATE(), GETDATE());
            END
            FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;
        END
        CLOSE head_cursor2;
        DEALLOCATE head_cursor2;
        IF @RecipientRole = 'Partner' AND @RecipientId IS NOT NULL AND @RecipientId > 0
        BEGIN
            UPDATE PartnerTrans SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
            DECLARE @HeadPaymentTypeP2 NVARCHAR(20);
            DECLARE @HeadHeadP2 NVARCHAR(200);
            DECLARE @HeadAmountP2 DECIMAL(18,2);
            DECLARE @HeadPurposeP2 NVARCHAR(500);
            DECLARE partner_cursor2 CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Head, Amount, Purpose FROM @Heads;
            OPEN partner_cursor2;
            FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO PartnerTrans (PartnerId, PaymentMode, [Type], AccountHead, Amount, AccountId, Remark, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES (@RecipientId, @Mode, @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @AccountId, ISNULL(NULLIF(@HeadPurposeP2,''), @Purpose), @UpdatedBy, 0, GETDATE(), GETDATE());
                FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;
            END
            CLOSE partner_cursor2;
            DEALLOCATE partner_cursor2;
        END
        ELSE
        BEGIN
            UPDATE PartnerTrans SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE AccountId = @AccountId AND IsDeleted = 0;
        END
        IF @FundPool IS NOT NULL AND @FundPool != ''
        BEGIN
            DECLARE @NewFundPoolAdjustment DECIMAL(18,2) = 0;
            DECLARE @NewHeadAmount DECIMAL(18,2);
            DECLARE @NewHeadType NVARCHAR(20);
            DECLARE newfundpool_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Amount FROM @Heads;
            OPEN newfundpool_cursor;
            FETCH NEXT FROM newfundpool_cursor INTO @NewHeadType, @NewHeadAmount;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @NewHeadType = 'Income'
                    SET @NewFundPoolAdjustment = @NewFundPoolAdjustment + @NewHeadAmount;
                ELSE IF @NewHeadType = 'Expense'
                    SET @NewFundPoolAdjustment = @NewFundPoolAdjustment - @NewHeadAmount;
                FETCH NEXT FROM newfundpool_cursor INTO @NewHeadType, @NewHeadAmount;
            END
            CLOSE newfundpool_cursor;
            DEALLOCATE newfundpool_cursor;
            UPDATE FundPools SET Balance = ISNULL(Balance, 0) + @NewFundPoolAdjustment, UpdatedAt = GETDATE() WHERE Code = @FundPool AND ISNULL(IsDeleted, 0) = 0;
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','head_cursor2') >= 0
        BEGIN
            CLOSE head_cursor2;
            DEALLOCATE head_cursor2;
        END
        IF CURSOR_STATUS('local','partner_cursor2') >= 0
        BEGIN
            CLOSE partner_cursor2;
            DEALLOCATE partner_cursor2;
        END
        IF CURSOR_STATUS('local','newfundpool_cursor') >= 0
        BEGIN
            CLOSE newfundpool_cursor;
            DEALLOCATE newfundpool_cursor;
        END
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'sp_UpdateAccountMaster updated successfully with NEW FundPool logic!';
GO
