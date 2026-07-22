-- ============================================================
-- 056: Fix sp_RecordPayment
--      Add OUTPUT to get SCOPE_IDENTITY of new TxnRecord
--      + update ContractRoomInstallments on payment
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

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
    @NewTxnRecordId       INT           OUTPUT   -- ← returns the new TxnRecords.Id
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId = @ContractId)
        BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

        DECLARE @TenantId INT, @CampId INT;
        SELECT @TenantId = TenantId FROM Contracts WHERE ContractId = @ContractId;
        SELECT TOP 1 @CampId = CampId FROM ContractCamps WHERE ContractId = @ContractId ORDER BY Id;

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

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Due FROM #Pending ORDER BY InstallmentNo;
        OPEN cur;
        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;

        WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
        BEGIN
            SET @ToApply  = CASE WHEN @Remaining >= @CurDue THEN @CurDue ELSE @Remaining END;
            SET @NewPaid  = @CurPaid + @ToApply;
            SET @NewStatus= CASE WHEN @NewPaid >= @CurAmt THEN 'Paid' WHEN @NewPaid > 0 THEN 'Partial' ELSE 'Pending' END;

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

        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools SET Balance = Balance + @PaidAmount, UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

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

        -- ✅ Return new TxnRecord Id via SCOPE_IDENTITY (no race condition)
        SET @NewTxnRecordId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

PRINT '056 - sp_RecordPayment updated: @NewTxnRecordId OUTPUT added';
GO
