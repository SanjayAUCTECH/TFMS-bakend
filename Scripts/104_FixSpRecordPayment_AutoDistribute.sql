-- ============================================================
-- 104: FINAL FIX sp_RecordPayment
-- Problem: When @InstallmentNo=0, SP did WHERE InstallmentNo=0
--          which matches nothing → ContractInstallments NOT updated
-- Fix: InstallmentNo=0 → auto-distribute across pending installments
--      (same logic as Script 018 Smart SP)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId      NVARCHAR(MAX),
    @InstallmentNo   INT           = 0,   -- 0 = auto-distribute from first pending
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATETIME      = NULL,
    @PaymentModeId   INT           = NULL,
    @PaymentMode     NVARCHAR(MAX) = '',
    @ChequeNumber    NVARCHAR(MAX) = '',
    @ClearanceDate   NVARCHAR(MAX) = '',
    @Description     NVARCHAR(MAX) = '',
    @ReceivedBy      NVARCHAR(MAX) = '',
    @ReceivedContact NVARCHAR(MAX) = '',
    @FundPoolId      INT           = NULL,
    @FundPoolName    NVARCHAR(MAX) = '',
    @IssuedBy        NVARCHAR(MAX) = '',
    @AddedBy         INT           = NULL,
    @NewTxnRecordId  INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0)
    BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

    -- Get tenant / camp info
    DECLARE @TenantId   INT = 0;
    DECLARE @TenantName NVARCHAR(MAX) = '';
    DECLARE @CampId     INT = 0;
    DECLARE @CampName   NVARCHAR(MAX) = '';
    DECLARE @FPCode     NVARCHAR(MAX) = '';

    SELECT @TenantId = TenantId FROM Contracts WHERE ContractId=@ContractId AND IsDeleted=0;
    SELECT @TenantName = ISNULL(Name,'') FROM Tenants WHERE Id=@TenantId AND IsDeleted=0;
    SELECT TOP 1 @CampId=cc.CampId, @CampName=ISNULL(ca.Name,'')
    FROM ContractCamps cc JOIN Camps ca ON ca.Id=cc.CampId AND ca.IsDeleted=0
    WHERE cc.ContractId=@ContractId AND ISNULL(cc.IsDeleted,0)=0 ORDER BY cc.Id;
    IF @FundPoolId IS NOT NULL
        SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId AND IsDeleted=0;

    -- ── Load pending installments (ordered) ──────────────────────
    CREATE TABLE #Pending (
        InstallmentNo INT,
        Amount        DECIMAL(18,2),
        PaidAmount    DECIMAL(18,2),
        Due           DECIMAL(18,2)
    );

    IF @InstallmentNo = 0
        -- Auto-distribute: start from first pending
        INSERT INTO #Pending
        SELECT InstallmentNo, Amount, ISNULL(PaidAmount,0), Amount - ISNULL(PaidAmount,0)
        FROM ContractInstallments
        WHERE ContractId=@ContractId AND ISNULL(IsDeleted,0)=0
          AND Status IN ('Pending','Partial','Overdue')
          AND Amount - ISNULL(PaidAmount,0) > 0
        ORDER BY InstallmentNo;
    ELSE
        -- Specific installment
        INSERT INTO #Pending
        SELECT InstallmentNo, Amount, ISNULL(PaidAmount,0), Amount - ISNULL(PaidAmount,0)
        FROM ContractInstallments
        WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo AND ISNULL(IsDeleted,0)=0;

    IF NOT EXISTS (SELECT 1 FROM #Pending)
    BEGIN
        DROP TABLE #Pending;
        RAISERROR('No pending installments for contract %s.',16,1,@ContractId);
        RETURN;
    END

    -- ── Distribute payment across installments ────────────────────
    DECLARE @Remaining    DECIMAL(18,2) = @PaidAmount;
    DECLARE @AppliedList  NVARCHAR(MAX) = '';
    DECLARE @CurNo  INT; DECLARE @CurAmt DECIMAL(18,2);
    DECLARE @CurPaid DECIMAL(18,2); DECLARE @CurDue DECIMAL(18,2);
    DECLARE @ToApply DECIMAL(18,2); DECLARE @NewPaid DECIMAL(18,2);
    DECLARE @NewStatus NVARCHAR(MAX);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT InstallmentNo, Amount, PaidAmount, Due FROM #Pending ORDER BY InstallmentNo;
    OPEN cur;
    FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;

    WHILE @@FETCH_STATUS=0 AND @Remaining>0
    BEGIN
        SET @ToApply   = CASE WHEN @Remaining >= @CurDue THEN @CurDue ELSE @Remaining END;
        SET @NewPaid   = @CurPaid + @ToApply;
        SET @NewStatus = CASE
            WHEN @NewPaid >= @CurAmt THEN 'Paid'
            WHEN @NewPaid > 0        THEN 'Partial'
            ELSE 'Pending'
        END;

        UPDATE ContractInstallments
        SET PaidAmount      = @NewPaid,
            PaidDate        = @PaidDate,
            Status          = @NewStatus,
            PaymentMode     = ISNULL(@PaymentMode,''),
            PaymentModeId   = @PaymentModeId,
            ChequeNumber    = ISNULL(@ChequeNumber,''),
            ClearanceDate   = ISNULL(@ClearanceDate,''),
            Description     = ISNULL(@Description,''),
            ReceivedBy      = ISNULL(@ReceivedBy,''),
            ReceivedContact = ISNULL(@ReceivedContact,''),
            FundPoolId      = @FundPoolId,
            FundPoolName    = ISNULL(@FundPoolName,''),
            IssuedBy        = ISNULL(@IssuedBy,''),
            AddedBy         = ISNULL(AddedBy, @AddedBy)
        WHERE ContractId=@ContractId AND InstallmentNo=@CurNo AND ISNULL(IsDeleted,0)=0;

        SET @AppliedList = CASE WHEN @AppliedList=''
            THEN CAST(@CurNo AS NVARCHAR)
            ELSE @AppliedList+','+CAST(@CurNo AS NVARCHAR)
        END;
        SET @Remaining = @Remaining - @ToApply;

        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
    END;
    CLOSE cur; DEALLOCATE cur; DROP TABLE #Pending;

    -- ── FundPool update ───────────────────────────────────────────
    IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
        UPDATE FundPools SET Balance=Balance+@PaidAmount, UpdatedAt=GETUTCDATE()
        WHERE Id=@FundPoolId AND IsDeleted=0;

    -- ── TxnRecord insert ──────────────────────────────────────────
    DECLARE @TxnId NVARCHAR(50) = CONCAT('TXN-',
        RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 5));
    DECLARE @Unalloc DECIMAL(18,2) = CASE WHEN @Remaining>0 THEN @Remaining ELSE 0 END;
    DECLARE @FirstInstNo INT = NULL;
    IF CHARINDEX(',', @AppliedList) > 0
        SET @FirstInstNo = CAST(LEFT(@AppliedList, CHARINDEX(',',@AppliedList)-1) AS INT);
    ELSE IF @AppliedList <> ''
        SET @FirstInstNo = CAST(@AppliedList AS INT);

    INSERT INTO TxnRecords(
        TxnId, TxnType, ContractId, ContractCode, TenantId, CampId,
        TotalAmount, Amount, TxnDate, PaymentMode, PaymentModeId, ChequeNumber,
        FundPoolId, FundPoolName, Description, ReceivedBy, ReceivedContact, IssuedBy,
        InstallmentNo, AppliedInstallments, Unallocated,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @TxnId, 'CR', @ContractId, @ContractId, ISNULL(@TenantId,0), ISNULL(@CampId,0),
        @PaidAmount, @PaidAmount,
        ISNULL(@PaidDate, GETUTCDATE()),
        ISNULL(@PaymentMode,''), @PaymentModeId, ISNULL(@ChequeNumber,''),
        @FundPoolId, ISNULL(@FundPoolName,''), ISNULL(@Description,''),
        ISNULL(@ReceivedBy,''), ISNULL(@ReceivedContact,''), ISNULL(@IssuedBy,''),
        @FirstInstNo, @AppliedList, @Unalloc,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );
    SET @NewTxnRecordId = SCOPE_IDENTITY();

    -- ── Income insert ─────────────────────────────────────────────
    IF @FundPoolId IS NOT NULL
    BEGIN
        DECLARE @IncId NVARCHAR(50) = CONCAT('INC-',
            RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR), 5));
        INSERT INTO Incomes(
            IncomeId, [Date], Mode, Head, FundPool, FundPoolName, Amount,
            Purpose, Source, SourceRef, CampName, TenantName,
            CreatedAt, UpdatedAt, CampId, ContractId, ContractCode,
            TxnRecordId, AddedBy, IsDeleted
        )
        VALUES(
            @IncId, CAST(ISNULL(@PaidDate,GETUTCDATE()) AS DATE),
            ISNULL(@PaymentMode,'Cash'), 'Rent',
            ISNULL(@FPCode,''), ISNULL(@FundPoolName,''), @PaidAmount,
            CONCAT('Rent received - Inst: ', @AppliedList, ' | Contract: ', @ContractId),
            'Tenant', @ContractId, ISNULL(@CampName,''), ISNULL(@TenantName,''),
            GETUTCDATE(), GETUTCDATE(), ISNULL(@CampId,0), @ContractId, @ContractId,
            @NewTxnRecordId, @AddedBy, 0
        );
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_RecordPayment FIXED - auto-distribute when InstallmentNo=0';
GO
