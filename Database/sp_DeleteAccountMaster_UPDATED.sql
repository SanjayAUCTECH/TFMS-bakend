-- =============================================
-- Stored Procedure: sp_DeleteAccountMaster
-- Modified: 2026-09-17
-- Purpose: Delete Account Master with FundPool REVERSAL logic
-- 
-- FundPool Reversal Logic:
-- When deleting, we need to REVERSE the original FundPool adjustment
-- 
-- Original Logic:
--   Income  → FundPool += Amount
--   Expense → FundPool -= Amount
-- 
-- Delete/Reversal Logic:
--   Income  → FundPool -= Amount (reverse)
--   Expense → FundPool += Amount (reverse)
-- =============================================

ALTER PROCEDURE [dbo].[sp_DeleteAccountMaster]
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- ========================================
        -- Step 1: Get AccountId and FundPool info
        -- ========================================
        DECLARE @AccountId   NVARCHAR(20);
        DECLARE @FundPool    NVARCHAR(50);
        
        SELECT @AccountId = AccountId,
               @FundPool  = FundPool
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END

        -- ========================================
        -- Step 2: Calculate FundPool REVERSAL
        -- ========================================
        IF @FundPool IS NOT NULL AND @FundPool != ''
        BEGIN
            DECLARE @IncomeTotal  DECIMAL(18,2) = 0;
            DECLARE @ExpenseTotal DECIMAL(18,2) = 0;

            -- Get total Income amounts that are about to be deleted
            SELECT @IncomeTotal = ISNULL(SUM(Amount), 0)
            FROM Incomes
            WHERE AccountId = @AccountId 
              AND IsDeleted = 0;

            -- Get total Expense amounts that are about to be deleted
            SELECT @ExpenseTotal = ISNULL(SUM(Amount), 0)
            FROM Expenses
            WHERE AccountId = @AccountId 
              AND IsDeleted = 0;

            -- Calculate reversal adjustment
            -- Original: Income adds (+), Expense subtracts (-)
            -- Reversal: Income subtracts (-), Expense adds (+)
            -- So we need to SUBTRACT Income and ADD Expense
            DECLARE @ReversalAdjustment DECIMAL(18,2);
            SET @ReversalAdjustment = -@IncomeTotal + @ExpenseTotal;

            -- Apply the reversal to FundPool
            UPDATE FundPools
            SET Balance   = ISNULL(Balance, 0) + @ReversalAdjustment,
                UpdatedAt = GETDATE()
            WHERE Code = @FundPool
              AND ISNULL(IsDeleted, 0) = 0;

            -- Log for debugging
            PRINT 'FundPool Reversal Applied: ' + CAST(@ReversalAdjustment AS NVARCHAR(50));
            PRINT 'Income Total Reversed: ' + CAST(@IncomeTotal AS NVARCHAR(50));
            PRINT 'Expense Total Reversed: ' + CAST(@ExpenseTotal AS NVARCHAR(50));
        END

        -- ========================================
        -- Step 3: Soft-delete linked Incomes
        -- ========================================
        UPDATE Incomes
        SET IsDeleted = 1, 
            UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId 
          AND IsDeleted = 0;

        -- ========================================
        -- Step 4: Soft-delete linked Expenses
        -- ========================================
        UPDATE Expenses
        SET IsDeleted = 1, 
            UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId 
          AND IsDeleted = 0;

        -- ========================================
        -- Step 5: Soft-delete linked PartnerTrans
        -- ========================================
        UPDATE PartnerTrans
        SET IsDeleted   = 1, 
            IsDeletedBy = @DeletedBy, 
            UpdatedAt   = GETDATE()
        WHERE AccountId = @AccountId 
          AND IsDeleted = 0;

        -- ========================================
        -- Step 6: Soft-delete AccountMaster
        -- ========================================
        UPDATE AccountMasters
        SET IsDeleted = 1,
            DeletedBy = @DeletedBy,
            UpdatedAt = GETDATE()
        WHERE Id = @Id;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        -- Re-throw the error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

-- =============================================
-- DEPLOYMENT INSTRUCTIONS
-- =============================================
/*
1. Backup current procedure:
   EXEC sp_helptext 'sp_DeleteAccountMaster'
   -- Save output to file

2. Execute this ALTER statement in your database

3. Test delete scenarios:
   - Delete income entry → FundPool should decrease
   - Delete expense entry → FundPool should increase
   - Verify FundPool balances are correctly reversed

4. Monitor the PRINT statements in SQL Server Messages tab
*/

-- =============================================
-- TEST SCENARIOS
-- =============================================
/*
-- Setup: Create a test entry first
DECLARE @TestId INT;
DECLARE @TestHeads AccountMasterHeadType;
INSERT INTO @TestHeads (PaymentType, Amount, Head, Purpose) 
VALUES ('Income', 1000, 'Test Income', 'Will be deleted');

EXEC sp_CreateAccountMaster
    @TransDate = GETDATE(),
    @Mode = 'Cash',
    @FundPool = 'YOUR_POOL_CODE',
    @FundPoolName = 'Test Pool',
    @RecipientRole = 'Tenant',
    @RecipientName = 'Test User',
    @Purpose = 'Test delete',
    @Heads = @TestHeads,
    @NewId = @TestId OUTPUT;

SELECT @TestId AS CreatedRecordId;

-- Check FundPool balance BEFORE delete
SELECT Code, Balance FROM FundPools WHERE Code = 'YOUR_POOL_CODE';

-- Now DELETE the entry
EXEC sp_DeleteAccountMaster
    @Id = @TestId,
    @DeletedBy = 1;

-- Check FundPool balance AFTER delete
-- Should be back to original (before create)
SELECT Code, Balance FROM FundPools WHERE Code = 'YOUR_POOL_CODE';

-- Verify the record is soft-deleted
SELECT * FROM AccountMasters WHERE Id = @TestId;
-- IsDeleted should be 1
*/

-- =============================================
-- EXAMPLES
-- =============================================
/*
Example 1: Delete Income Entry
- Original Income: +1000
- FundPool was: +1000 (increased)
- After Delete: -1000 (reversed/decreased)

Example 2: Delete Expense Entry  
- Original Expense: +500
- FundPool was: -500 (decreased)
- After Delete: +500 (reversed/increased)

Example 3: Delete Negative Income Entry
- Original Income: -300
- FundPool was: -300 (decreased)
- After Delete: +300 (reversed/increased)

Example 4: Delete Negative Expense Entry
- Original Expense: -400
- FundPool was: +400 (increased)
- After Delete: -400 (reversed/decreased)
*/
