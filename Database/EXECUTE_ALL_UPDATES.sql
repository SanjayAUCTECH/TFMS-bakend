-- =============================================
-- EXECUTE ALL STORED PROCEDURE UPDATES
-- Date: 2026-09-17
-- Database: TFMS_TestSoftwareDB
-- =============================================

USE [TFMS_TestSoftwareDB];
GO

PRINT '========================================';
PRINT 'Starting Stored Procedure Updates...';
PRINT '========================================';
PRINT '';

-- =============================================
-- 1. UPDATE sp_CreateAccountMaster
-- =============================================
PRINT '1. Updating sp_CreateAccountMaster...';

ALTER PROCEDURE [dbo].[sp_CreateAccountMaster]
    @TransDate      DATETIME,
    @Mode           NVARCHAR(100),
    @VoucherNo      NVARCHAR(100)   = NULL,
    @FundPool       NVARCHAR(50)    = '',
    @FundPoolName   NVARCHAR(200)   = '',
    @Nature         NVARCHAR(50)    = '',
    @CampId         INT             = NULL,
    @CampName       NVARCHAR(200)   = '',
    @RecipientRole  NVARCHAR(100)   = '',
    @RecipientId    INT             = NULL,
    @RecipientName  NVARCHAR(200)   = '',
    @Purpose        NVARCHAR(500)   = '',
    @AddedBy        INT             = NULL,
    @Heads          dbo.AccountMasterHeadType READONLY,
    @NewId          INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @AccSeq    INT;
        DECLARE @AccountId NVARCHAR(20);
        SELECT @AccSeq = ISNULL(MAX(Id), 0) + 1 FROM AccountMasters;
        SET @AccountId = 'ACC-' + RIGHT('000000' + CAST(@AccSeq AS NVARCHAR), 6);
        
        DECLARE @FinalVoucherNo NVARCHAR(100);
        IF @VoucherNo IS NOT NULL AND LTRIM(RTRIM(@VoucherNo)) != ''
        BEGIN
            IF EXISTS (SELECT 1 FROM AccountMasters WHERE VoucherNo = LTRIM(RTRIM(@VoucherNo)) AND IsDeleted = 0)
            BEGIN
                ROLLBACK TRANSACTION;
                RAISERROR('VOUCHER_EXISTS', 16, 1);
                RETURN;
            END
            SET @FinalVoucherNo = LTRIM(RTRIM(@VoucherNo));
        END
        ELSE
        BEGIN
            SET @FinalVoucherNo = 'VCH-' + RIGHT('000000' + CAST(@AccSeq AS NVARCHAR), 6);
        END
        
        DECLARE @TotalAmount  DECIMAL(18,2);
        DECLARE @PaymentType  NVARCHAR(20);
        DECLARE @IncomeCount  INT;
        DECLARE @ExpenseCount INT;
        
        SELECT @TotalAmount  = ISNULL(SUM(Amount), 0) FROM @Heads;
        SELECT @IncomeCount  = COUNT(*) FROM @Heads WHERE PaymentType = 'Income';
        SELECT @ExpenseCount = COUNT(*) FROM @Heads WHERE PaymentType = 'Expense';
        
        SET @PaymentType = CASE
            WHEN @IncomeCount  > 0 AND @ExpenseCount = 0 THEN 'Income'
            WHEN @ExpenseCount > 0 AND @IncomeCount  = 0 THEN 'Expense'
            ELSE 'Mixed'
        END;
        
        INSERT INTO AccountMasters (AccountId, VoucherNo, TransDate, PaymentType, Mode, FundPool, FundPoolName, Amount, Nature, RecipientRole, RecipientId, RecipientName, Purpose, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
        VALUES (@AccountId, @FinalVoucherNo, @TransDate, @PaymentType, @Mode, @FundPool, @FundPoolName, @TotalAmount, @Nature, @RecipientRole, @RecipientId, @RecipientName, @Purpose, @AddedBy, 0, GETDATE(), GETDATE());
        
        SET @NewId = SCOPE_IDENTITY();
        
        DECLARE @HeadPaymentType NVARCHAR(20);
        DECLARE @HeadHead        NVARCHAR(200);
        DECLARE @HeadAmount      DECIMAL(18,2);
        DECLARE @HeadPurpose     NVARCHAR(500);
        
        DECLARE head_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Head, Amount, Purpose FROM @Heads;
        OPEN head_cursor;
        FETCH NEXT FROM head_cursor INTO @HeadPaymentType, @HeadHead, @HeadAmount, @HeadPurpose;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @HeadPaymentType = 'Income'
            BEGIN
                DECLARE @IncomeId NVARCHAR(20);
                SELECT @IncomeId = 'INC-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6) FROM Incomes;
                INSERT INTO Incomes (IncomeId, [Date], Mode, Head, FundPool, FundPoolName, Amount, Purpose, Source, SourceRef, CampId, CampName, AccountId, VoucherNo, TransDate, AddedBy, IsDeleted, CreatedAt, UpdatedAt, PartnerId, PartnerName)
                VALUES (@IncomeId, @TransDate, @Mode, @HeadHead, @FundPool, @FundPoolName, @HeadAmount, ISNULL(NULLIF(@HeadPurpose,''), @Purpose), 'Partner', '', @CampId, @CampName, @AccountId, @FinalVoucherNo, @TransDate, @AddedBy, 0, GETDATE(), GETDATE(), @RecipientId, @RecipientName);
            END
            ELSE IF @HeadPaymentType = 'Expense'
            BEGIN
                DECLARE @ExpenseId NVARCHAR(20);
                SELECT @ExpenseId = 'EXP-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6) FROM Expenses;
                INSERT INTO Expenses (ExpenseId, [Date], Mode, Head, FundPool, FundPoolName, Amount, Nature, CampId, CampName, RecipientRole, RecipientId, RecipientName, Purpose, AccountId, VoucherNo, TransDate, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES (@ExpenseId, @TransDate, @Mode, @HeadHead, @FundPool, @FundPoolName, @HeadAmount, @Nature, @CampId, @CampName, @RecipientRole, @RecipientId, @RecipientName, ISNULL(NULLIF(@HeadPurpose,''), @Purpose), @AccountId, @FinalVoucherNo, @TransDate, @AddedBy, 0, GETDATE(), GETDATE());
            END
            FETCH NEXT FROM head_cursor INTO @HeadPaymentType, @HeadHead, @HeadAmount, @HeadPurpose;
        END
        
        CLOSE head_cursor;
        DEALLOCATE head_cursor;
        
        IF @RecipientRole = 'Partner' AND @RecipientId IS NOT NULL AND @RecipientId > 0
        BEGIN
            DECLARE @HeadPaymentTypeP NVARCHAR(20);
            DECLARE @HeadHeadP        NVARCHAR(200);
            DECLARE @HeadAmountP      DECIMAL(18,2);
            DECLARE @HeadPurposeP     NVARCHAR(500);
            
            DECLARE partner_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Head, Amount, Purpose FROM @Heads;
            OPEN partner_cursor;
            FETCH NEXT FROM partner_cursor INTO @HeadPaymentTypeP, @HeadHeadP, @HeadAmountP, @HeadPurposeP;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO PartnerTrans (PartnerId, PaymentMode, [Type], AccountHead, Amount, AccountId, Remark, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
                VALUES (@RecipientId, @Mode, @HeadPaymentTypeP, @HeadHeadP, @HeadAmountP, @AccountId, ISNULL(NULLIF(@HeadPurposeP,''), @Purpose), @AddedBy, 0, GETDATE(), GETDATE());
                FETCH NEXT FROM partner_cursor INTO @HeadPaymentTypeP, @HeadHeadP, @HeadAmountP, @HeadPurposeP;
            END
            
            CLOSE partner_cursor;
            DEALLOCATE partner_cursor;
        END
        
        -- NEW FUNDPOOL LOGIC
        IF @FundPool IS NOT NULL AND @FundPool != ''
        BEGIN
            DECLARE @FundPoolAdjustment DECIMAL(18,2) = 0;
            DECLARE @HeadAmountForAdj DECIMAL(18,2);
            DECLARE @HeadTypeForAdj NVARCHAR(20);
            
            DECLARE fundpool_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PaymentType, Amount FROM @Heads;
            OPEN fundpool_cursor;
            FETCH NEXT FROM fundpool_cursor INTO @HeadTypeForAdj, @HeadAmountForAdj;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @HeadTypeForAdj = 'Income'
                    SET @FundPoolAdjustment = @FundPoolAdjustment + @HeadAmountForAdj;
                ELSE IF @HeadTypeForAdj = 'Expense'
                    SET @FundPoolAdjustment = @FundPoolAdjustment - @HeadAmountForAdj;
                FETCH NEXT FROM fundpool_cursor INTO @HeadTypeForAdj, @HeadAmountForAdj;
            END
            
            CLOSE fundpool_cursor;
            DEALLOCATE fundpool_cursor;
            
            UPDATE FundPools SET Balance = ISNULL(Balance, 0) + @FundPoolAdjustment, UpdatedAt = GETDATE()
            WHERE Code = @FundPool AND ISNULL(IsDeleted, 0) = 0;
        END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT '   ✅ sp_CreateAccountMaster updated successfully!';
PRINT '';

PRINT '========================================';
PRINT 'All procedures updated successfully!';
PRINT '========================================';
