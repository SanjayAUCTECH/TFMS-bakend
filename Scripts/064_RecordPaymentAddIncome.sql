-- ============================================================
-- 064: sp_RecordPayment — Also INSERT into Incomes table
--      Payment received → Incomes tbl mai bhi data jaye
-- Date: July 24, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Incomes table mai ContractId, ContractCode columns add karo agar nahi hain
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='ContractId')
    ALTER TABLE Incomes ADD ContractId NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='ContractCode')
    ALTER TABLE Incomes ADD ContractCode NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TenantId')
    ALTER TABLE Incomes ADD TenantId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TenantName')
    ALTER TABLE Incomes ADD TenantName NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

-- ── sp_RecordPayment — updated with Incomes INSERT ───────────
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId           NVARCHAR(MAX),
    @InstallmentNo        INT           = 0,
    @PaidAmount           DECIMAL(18,2),
    @PaidDate             DATE,
    @PaymentModeId        INT           = NULL,
    @PaymentMode          NVARCHAR(MAX) = '',
    @ChequeNumber         NVARCHAR(MAX) = '',
    @ClearanceDate        NVARCHAR(MAX) = '',
    @Description          NVARCHAR(MAX) = '',
    @ReceivedBy           NVARCHAR(MAX) = '',
    @ReceivedContact      NVARCHAR(MAX) = '',
    @FundPoolId           INT           = NULL,
    @FundPoolName         NVARCHAR(MAX) = '',
    @IssuedBy             NVARCHAR(MAX) = '',
    @NewTxnRecordId       INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId = @ContractId)
        BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

        -- Tenant and Camp info
        DECLARE @TenantId   INT;
        DECLARE @TenantName NVARCHAR(MAX) = '';
        DECLARE @CampId     INT;
        DECLARE @CampName   NVARCHAR(MAX) = '';
        DECLARE @FundPoolCode NVARCHAR(MAX) = '';

        SELECT @TenantId = TenantId FROM Contracts WHERE ContractId = @ContractId;
        SELECT @TenantName = ISNULL(Name, '') FROM Tenants WHERE Id = @TenantId;
        SELECT TOP 1 @CampId = cc.CampId, @CampName = ISNULL(ca.Name,'')
        FROM ContractCamps cc
        JOIN Camps ca ON ca.Id = cc.CampId
        WHERE cc.ContractId = @ContractId ORDER BY cc.Id;

        -- FundPool code
        IF @FundPoolId IS NOT NULL
            SELECT @FundPoolCode = ISNULL(Code, '') FROM FundPools WHERE Id = @FundPoolId;

        -- ── Pending installments ─────────────────────────────────────
        CREATE TABLE #Pending (InstallmentNo INT, Amount DECIMAL(18,2), PaidAmount DECIMAL(18,2), Due DECIMAL(18,2));
        INSERT INTO #Pending
        SELECT InstallmentNo, Amount, PaidAmount, Amount - PaidAmount
        FROM ContractInstallments
        WHERE ContractId = @ContractId
          AND Status IN ('Pending','Partial','Overdue')
          AND (Amount - PaidAmount) > 0
          AND (@InstallmentNo = 0 OR InstallmentNo >= @InstallmentNo)
        ORDER BY InstallmentNo;

        IF NOT EXISTS (SELECT 1 FROM #Pending)
        BEGIN DROP TABLE #Pending; RAISERROR('No pending installments found for contract %s.',16,1,@ContractId); RETURN; END

        DECLARE @Remaining   DECIMAL(18,2) = @PaidAmount;
        DECLARE @AppliedList NVARCHAR(MAX) = '';
        DECLARE @CurNo INT, @CurAmt DECIMAL(18,2), @CurPaid DECIMAL(18,2), @CurDue DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(MAX);

        -- ── Loop: har pending installment update karo ────────────────
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Due FROM #Pending ORDER BY InstallmentNo;
        OPEN cur;
        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;

        WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
        BEGIN
            SET @ToApply  = CASE WHEN @Remaining >= @CurDue THEN @CurDue ELSE @Remaining END;
            SET @NewPaid  = @CurPaid + @ToApply;
            SET @NewStatus= CASE WHEN @NewPaid >= @CurAmt THEN 'Paid' WHEN @NewPaid > 0 THEN 'Partial' ELSE 'Pending' END;

            -- 1. ContractInstallments UPDATE
            UPDATE ContractInstallments
            SET PaidAmount      = @NewPaid,
                PaidDate        = @PaidDate,
                Status          = @NewStatus,
                PaymentModeId   = @PaymentModeId,
                PaymentMode     = @PaymentMode,
                ChequeNumber    = @ChequeNumber,
                ClearanceDate   = @ClearanceDate,
                Description     = @Description,
                ReceivedBy      = @ReceivedBy,
                ReceivedContact = @ReceivedContact,
                FundPoolId      = @FundPoolId,
                FundPoolName    = @FundPoolName,
                IssuedBy        = @IssuedBy
            WHERE ContractId = @ContractId AND InstallmentNo = @CurNo;

            SET @AppliedList = CASE WHEN @AppliedList = '' THEN CAST(@CurNo AS NVARCHAR)
                               ELSE @AppliedList + ',' + CAST(@CurNo AS NVARCHAR) END;
            SET @Remaining = @Remaining - @ToApply;
            FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
        END;
        CLOSE cur; DEALLOCATE cur; DROP TABLE #Pending;

        -- 2. FundPools UPDATE
        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools SET Balance = Balance + @PaidAmount, UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- 3. TxnRecords INSERT
        DECLARE @TxnId NVARCHAR(MAX) = 'TXN-' + CONVERT(NVARCHAR(MAX), @PaidDate, 112) + '-'
            + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM TxnRecords) AS NVARCHAR), 6);
        DECLARE @Unallocated DECIMAL(18,2) = CASE WHEN @Remaining > 0 THEN @Remaining ELSE 0 END;

        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode, TenantId, CampId,
            TotalAmount, Amount, PaidDate, PaymentMode, PaymentModeId, ChequeNumber,
            Description, IssuedBy, ReceivedBy, ReceivedContact,
            FundPoolId, FundPoolName, AppliedInstallments, Unallocated, InstallmentNo,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @TxnId, 'CR', @ContractId, @ContractId, @TenantId, ISNULL(@CampId, 0),
            @PaidAmount, @PaidAmount, @PaidDate, @PaymentMode, @PaymentModeId, @ChequeNumber,
            @Description, @IssuedBy, @ReceivedBy, @ReceivedContact,
            @FundPoolId, @FundPoolName, @AppliedList, @Unallocated,
            CASE WHEN CHARINDEX(',', @AppliedList) > 0
                 THEN CAST(LEFT(@AppliedList, CHARINDEX(',', @AppliedList) - 1) AS INT)
                 WHEN @AppliedList <> '' THEN CAST(@AppliedList AS INT)
                 ELSE NULL END,
            GETUTCDATE(), GETUTCDATE()
        );

        SET @NewTxnRecordId = SCOPE_IDENTITY();

        -- 4. Incomes INSERT
        DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR), 6);

        INSERT INTO Incomes (
            IncomeId, Date, Mode, Head,
            FundPool, FundPoolName,
            Amount, Purpose, Source, SourceRef,
            CampId, CampName,
            ContractId, ContractCode,
            TenantId, TenantName,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @IncomeId,
            @PaidDate,
            ISNULL(NULLIF(@PaymentMode,''), 'Cash'),
            'Rent Income',
            ISNULL(NULLIF(@FundPoolCode,''), 'MAIN'),
            ISNULL(NULLIF(@FundPoolName,''), 'Main Fund'),
            @PaidAmount,
            'Rent received - Installment(s): ' + ISNULL(NULLIF(@AppliedList,''), '0') + ' | Contract: ' + @ContractId + ' | TxnId: ' + @TxnId,
            'Tenant',
            @ContractId,
            ISNULL(@CampId,  0),
            ISNULL(@CampName, ''),
            @ContractId,
            @ContractId,
            @TenantId,
            @TenantName,
            GETUTCDATE(),
            GETUTCDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

PRINT '064 - sp_RecordPayment updated: Incomes table mai bhi data insert hoga';
GO
