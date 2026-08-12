-- ================================================================
-- FILE   : AccountMaster_Procedures.sql
-- PURPOSE: Stored Procedures for AccountMasters
--          1. sp_CreateAccountMaster
--          2. sp_UpdateAccountMaster
--          3. sp_DeleteAccountMaster
-- ================================================================

-- ----------------------------------------------------------------
-- HELPER: User-Defined Table Type for Head Items
-- (Run once — used as parameter in SPs)
-- ----------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.types WHERE name = 'AccountMasterHeadType' AND is_table_type = 1
)
BEGIN
    CREATE TYPE dbo.AccountMasterHeadType AS TABLE (
        PaymentType  NVARCHAR(20),   -- 'Income' or 'Expense'
        Head         NVARCHAR(200),
        Amount       DECIMAL(18,2),
        Purpose      NVARCHAR(500)
    );
    PRINT 'Type AccountMasterHeadType created.';
END
GO

-- ================================================================
-- 1. sp_CreateAccountMaster
-- ================================================================
CREATE OR ALTER PROCEDURE sp_CreateAccountMaster
    @TransDate      DATETIME,
    @Mode           NVARCHAR(100),
    @VoucherNo      NVARCHAR(100)   = NULL,   -- NULL = auto-generate
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
    @Heads          dbo.AccountMasterHeadType READONLY,  -- Table-valued param
    @NewId          INT             OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- ── Step 1: Generate AccountId ──────────────────────────
        DECLARE @AccSeq   INT;
        DECLARE @AccountId NVARCHAR(20);
        SELECT @AccSeq = ISNULL(MAX(Id), 0) + 1 FROM AccountMasters;
        SET @AccountId = 'ACC-' + RIGHT('000000' + CAST(@AccSeq AS NVARCHAR), 6);

        -- ── Step 2: VoucherNo ───────────────────────────────────
        DECLARE @FinalVoucherNo NVARCHAR(100);
        IF @VoucherNo IS NOT NULL AND LTRIM(RTRIM(@VoucherNo)) != ''
        BEGIN
            -- Check uniqueness
            IF EXISTS (
                SELECT 1 FROM AccountMasters
                WHERE VoucherNo = LTRIM(RTRIM(@VoucherNo)) AND IsDeleted = 0
            )
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

        -- ── Step 3: Total Amount & PaymentType ──────────────────
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

        -- ── Step 4: INSERT AccountMasters (parent) ───────────────
        INSERT INTO AccountMasters (
            AccountId, VoucherNo, TransDate, PaymentType,
            Mode, FundPool, FundPoolName, Amount,
            Nature, RecipientRole, RecipientId, RecipientName,
            Purpose, CampId, CampName,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES (
            @AccountId, @FinalVoucherNo, @TransDate, @PaymentType,
            @Mode, @FundPool, @FundPoolName, @TotalAmount,
            @Nature, @RecipientRole, @RecipientId, @RecipientName,
            @Purpose, @CampId, @CampName,
            @AddedBy, 0, GETDATE(), GETDATE()
        );

        SET @NewId = SCOPE_IDENTITY();

        -- ── Step 5: INSERT each Head → Incomes or Expenses ──────
        DECLARE @HeadPaymentType NVARCHAR(20);
        DECLARE @HeadHead        NVARCHAR(200);
        DECLARE @HeadAmount      DECIMAL(18,2);
        DECLARE @HeadPurpose     NVARCHAR(500);

        DECLARE head_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

        OPEN head_cursor;
        FETCH NEXT FROM head_cursor INTO @HeadPaymentType, @HeadHead, @HeadAmount, @HeadPurpose;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @HeadPaymentType = 'Income'
            BEGIN
                DECLARE @IncomeId NVARCHAR(20);
                SELECT @IncomeId = 'INC-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Incomes;

                INSERT INTO Incomes (
                    IncomeId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Purpose, Source, SourceRef,
                    CampId, CampName, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @IncomeId, @TransDate, @Mode, @HeadHead, @FundPool, @FundPoolName,
                    @HeadAmount, ISNULL(NULLIF(@HeadPurpose,''), @Purpose), 'Manual', '',
                    @CampId, @CampName, @AccountId, @FinalVoucherNo, @TransDate,
                    @AddedBy, 0, GETDATE(), GETDATE()
                );
            END
            ELSE IF @HeadPaymentType = 'Expense'
            BEGIN
                DECLARE @ExpenseId NVARCHAR(20);
                SELECT @ExpenseId = 'EXP-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Expenses;

                INSERT INTO Expenses (
                    ExpenseId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Nature, CampId, CampName,
                    RecipientRole, RecipientId, RecipientName,
                    Purpose, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @ExpenseId, @TransDate, @Mode, @HeadHead, @FundPool, @FundPoolName,
                    @HeadAmount, @Nature, @CampId, @CampName,
                    @RecipientRole, @RecipientId, @RecipientName,
                    ISNULL(NULLIF(@HeadPurpose,''), @Purpose), @AccountId, @FinalVoucherNo, @TransDate,
                    @AddedBy, 0, GETDATE(), GETDATE()
                );
            END

            FETCH NEXT FROM head_cursor INTO @HeadPaymentType, @HeadHead, @HeadAmount, @HeadPurpose;
        END

        CLOSE head_cursor;
        DEALLOCATE head_cursor;

        -- ── Step 6: INSERT into PartnerTrans if Role = 'Partner' ─
        IF @RecipientRole = 'Partner'
           AND @RecipientId IS NOT NULL
           AND @RecipientId > 0
        BEGIN
            DECLARE @HeadPaymentTypeP NVARCHAR(20);
            DECLARE @HeadHeadP        NVARCHAR(200);
            DECLARE @HeadAmountP      DECIMAL(18,2);
            DECLARE @HeadPurposeP     NVARCHAR(500);

            DECLARE partner_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

            OPEN partner_cursor;
            FETCH NEXT FROM partner_cursor INTO @HeadPaymentTypeP, @HeadHeadP, @HeadAmountP, @HeadPurposeP;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO PartnerTrans (
                    PartnerId, PaymentMode, [Type], AccountHead,
                    Amount, AccountId, Remark,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @RecipientId,
                    @Mode,
                    @HeadPaymentTypeP,   -- 'Income' or 'Expense'
                    @HeadHeadP,
                    @HeadAmountP,
                    @AccountId,
                    ISNULL(NULLIF(@HeadPurposeP,''), @Purpose),
                    @AddedBy,
                    0,
                    GETDATE(),
                    GETDATE()
                );

                FETCH NEXT FROM partner_cursor INTO @HeadPaymentTypeP, @HeadHeadP, @HeadAmountP, @HeadPurposeP;
            END

            CLOSE partner_cursor;
            DEALLOCATE partner_cursor;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','head_cursor') >= 0
        BEGIN
            CLOSE head_cursor;
            DEALLOCATE head_cursor;
        END
        IF CURSOR_STATUS('local','partner_cursor') >= 0
        BEGIN
            CLOSE partner_cursor;
            DEALLOCATE partner_cursor;
        END
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_CreateAccountMaster created.';
GO

-- ================================================================
-- 2. sp_UpdateAccountMaster
-- ================================================================
CREATE OR ALTER PROCEDURE sp_UpdateAccountMaster
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

        -- ── Step 1: Get existing AccountId & VoucherNo ──────────
        DECLARE @AccountId  NVARCHAR(20);
        DECLARE @VoucherNo  NVARCHAR(100);

        SELECT @AccountId = AccountId, @VoucherNo = VoucherNo
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END

        -- ── Step 2: Total Amount & PaymentType ──────────────────
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

        -- ── Step 3: UPDATE AccountMasters ───────────────────────
        UPDATE AccountMasters SET
            TransDate     = @TransDate,
            PaymentType   = @PaymentType,
            Mode          = @Mode,
            FundPool      = @FundPool,
            FundPoolName  = @FundPoolName,
            Amount        = @TotalAmount,
            Nature        = @Nature,
            CampId        = @CampId,
            CampName      = @CampName,
            RecipientRole = @RecipientRole,
            RecipientId   = @RecipientId,
            RecipientName = @RecipientName,
            Purpose       = @Purpose,
            UpdatedBy     = @UpdatedBy,
            UpdatedAt     = GETDATE()
        WHERE Id = @Id;

        -- ── Step 4: Soft-delete old linked Incomes & Expenses ───
        UPDATE Incomes
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        UPDATE Expenses
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        -- ── Step 5: Re-insert new Heads ─────────────────────────
        DECLARE @HeadPaymentType2 NVARCHAR(20);
        DECLARE @HeadHead2        NVARCHAR(200);
        DECLARE @HeadAmount2      DECIMAL(18,2);
        DECLARE @HeadPurpose2     NVARCHAR(500);

        DECLARE head_cursor2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

        OPEN head_cursor2;
        FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @HeadPaymentType2 = 'Income'
            BEGIN
                DECLARE @IncomeId2 NVARCHAR(20);
                SELECT @IncomeId2 = 'INC-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Incomes;

                INSERT INTO Incomes (
                    IncomeId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Purpose, Source, SourceRef,
                    CampId, CampName, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @IncomeId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName,
                    @HeadAmount2, ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), 'Manual', '',
                    @CampId, @CampName, @AccountId, @VoucherNo, @TransDate,
                    @UpdatedBy, 0, GETDATE(), GETDATE()
                );
            END
            ELSE IF @HeadPaymentType2 = 'Expense'
            BEGIN
                DECLARE @ExpenseId2 NVARCHAR(20);
                SELECT @ExpenseId2 = 'EXP-' + RIGHT('000000' + CAST(ISNULL(MAX(Id),0)+1 AS NVARCHAR), 6)
                FROM Expenses;

                INSERT INTO Expenses (
                    ExpenseId, [Date], Mode, Head, FundPool, FundPoolName,
                    Amount, Nature, CampId, CampName,
                    RecipientRole, RecipientId, RecipientName,
                    Purpose, AccountId, VoucherNo, TransDate,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @ExpenseId2, @TransDate, @Mode, @HeadHead2, @FundPool, @FundPoolName,
                    @HeadAmount2, @Nature, @CampId, @CampName,
                    @RecipientRole, @RecipientId, @RecipientName,
                    ISNULL(NULLIF(@HeadPurpose2,''), @Purpose), @AccountId, @VoucherNo, @TransDate,
                    @UpdatedBy, 0, GETDATE(), GETDATE()
                );
            END

            FETCH NEXT FROM head_cursor2 INTO @HeadPaymentType2, @HeadHead2, @HeadAmount2, @HeadPurpose2;
        END

        CLOSE head_cursor2;
        DEALLOCATE head_cursor2;

        -- ── Step 6: Sync PartnerTrans if Role = 'Partner' ────────
        IF @RecipientRole = 'Partner'
           AND @RecipientId IS NOT NULL
           AND @RecipientId > 0
        BEGIN
            -- Soft-delete old PartnerTrans linked to this AccountId
            UPDATE PartnerTrans
            SET IsDeleted = 1, UpdatedAt = GETDATE()
            WHERE AccountId = @AccountId AND IsDeleted = 0;

            -- Re-insert updated heads
            DECLARE @HeadPaymentTypeP2 NVARCHAR(20);
            DECLARE @HeadHeadP2        NVARCHAR(200);
            DECLARE @HeadAmountP2      DECIMAL(18,2);
            DECLARE @HeadPurposeP2     NVARCHAR(500);

            DECLARE partner_cursor2 CURSOR LOCAL FAST_FORWARD FOR
                SELECT PaymentType, Head, Amount, Purpose FROM @Heads;

            OPEN partner_cursor2;
            FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO PartnerTrans (
                    PartnerId, PaymentMode, [Type], AccountHead,
                    Amount, AccountId, Remark,
                    AddedBy, IsDeleted, CreatedAt, UpdatedAt
                )
                VALUES (
                    @RecipientId,
                    @Mode,
                    @HeadPaymentTypeP2,
                    @HeadHeadP2,
                    @HeadAmountP2,
                    @AccountId,
                    ISNULL(NULLIF(@HeadPurposeP2,''), @Purpose),
                    @UpdatedBy,
                    0,
                    GETDATE(),
                    GETDATE()
                );

                FETCH NEXT FROM partner_cursor2 INTO @HeadPaymentTypeP2, @HeadHeadP2, @HeadAmountP2, @HeadPurposeP2;
            END

            CLOSE partner_cursor2;
            DEALLOCATE partner_cursor2;
        END
        ELSE
        BEGIN
            -- Role change ho gayi (already was Partner, now changed) → soft-delete old records
            UPDATE PartnerTrans
            SET IsDeleted = 1, UpdatedAt = GETDATE()
            WHERE AccountId = @AccountId AND IsDeleted = 0;
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
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_UpdateAccountMaster created.';
GO

-- ================================================================
-- 3. sp_DeleteAccountMaster
-- ================================================================
CREATE OR ALTER PROCEDURE sp_DeleteAccountMaster
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- ── Step 1: Get AccountId ────────────────────────────────
        DECLARE @AccountId NVARCHAR(20);

        SELECT @AccountId = AccountId
        FROM AccountMasters
        WHERE Id = @Id AND IsDeleted = 0;

        IF @AccountId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('RECORD_NOT_FOUND', 16, 1);
            RETURN;
        END

        -- ── Step 2: Soft-delete linked Incomes ───────────────────
        UPDATE Incomes
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        -- ── Step 3: Soft-delete linked Expenses ──────────────────
        UPDATE Expenses
        SET IsDeleted = 1, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        -- ── Step 4: Soft-delete linked PartnerTrans ──────────────
        UPDATE PartnerTrans
        SET IsDeleted = 1, IsDeletedBy = @DeletedBy, UpdatedAt = GETDATE()
        WHERE AccountId = @AccountId AND IsDeleted = 0;

        -- ── Step 5: Soft-delete AccountMaster ────────────────────
        UPDATE AccountMasters
        SET IsDeleted = 1,
            DeletedBy = @DeletedBy,
            UpdatedAt = GETDATE()
        WHERE Id = @Id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_DeleteAccountMaster created.';
GO

-- ================================================================
-- DONE
-- ================================================================
PRINT 'All AccountMaster procedures created successfully.';
