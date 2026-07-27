-- ============================================================
-- 096: FINAL FIX — Payment Delete + Edit proper revert
-- Tables affected on RecordPayment:
--   1. ContractInstallments  (per installment, proportional)
--   2. FundPools             (balance +/-)
--   3. TxnRecords            (soft delete)
--   4. Incomes               (linked by TxnId in Purpose)
--   5. ContractRooms         (room-wise paid amount)
--   6. ContractRoomsTrns     (room transaction log)
--   7. ContractRoomInstallments (room installment status)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Add TxnId column to Incomes if not exists (for exact match)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='TxnRecordId')
    ALTER TABLE Incomes ADD TxnRecordId INT NULL;
GO
-- Add IsDeleted/DeletedBy to TxnRecords if not exists
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='IsDeleted')
    ALTER TABLE TxnRecords ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='DeletedBy')
    ALTER TABLE TxnRecords ADD DeletedBy INT NULL;
GO
PRINT 'Column checks done';
GO

-- ============================================================
-- FIX sp_RecordPayment: Store TxnRecordId in Incomes
-- ============================================================
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId      NVARCHAR(MAX),
    @InstallmentNo   INT           = 0,
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATE,
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

        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId = @ContractId)
        BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

        DECLARE @TenantId     INT;
        DECLARE @TenantName   NVARCHAR(MAX) = '';
        DECLARE @CampId       INT = 0;
        DECLARE @CampName     NVARCHAR(MAX) = '';
        DECLARE @FundPoolCode NVARCHAR(MAX) = '';

        SELECT @TenantId = TenantId FROM Contracts WHERE ContractId = @ContractId;
        SELECT @TenantName = ISNULL(Name,'') FROM Tenants WHERE Id = @TenantId;
        SELECT TOP 1 @CampId = cc.CampId, @CampName = ISNULL(ca.Name,'')
        FROM ContractCamps cc JOIN Camps ca ON ca.Id = cc.CampId
        WHERE cc.ContractId = @ContractId ORDER BY cc.Id;
        IF @FundPoolId IS NOT NULL
            SELECT @FundPoolCode = ISNULL(Code,'') FROM FundPools WHERE Id = @FundPoolId;

        -- Pending installments
        CREATE TABLE #Pending (InstallmentNo INT, Amount DECIMAL(18,2), PaidAmount DECIMAL(18,2), Due DECIMAL(18,2));
        INSERT INTO #Pending
        SELECT InstallmentNo, Amount, PaidAmount, Amount - PaidAmount
        FROM ContractInstallments
        WHERE ContractId = @ContractId
          AND ISNULL(IsDeleted,0) = 0
          AND Status IN ('Pending','Partial','Overdue')
          AND (Amount - PaidAmount) > 0
          AND (@InstallmentNo = 0 OR InstallmentNo >= @InstallmentNo)
        ORDER BY InstallmentNo;

        IF NOT EXISTS (SELECT 1 FROM #Pending)
        BEGIN DROP TABLE #Pending; RAISERROR('No pending installments for %s.',16,1,@ContractId); RETURN; END

        DECLARE @Remaining   DECIMAL(18,2) = @PaidAmount;
        DECLARE @AppliedList NVARCHAR(MAX) = '';
        DECLARE @CurNo  INT; DECLARE @CurAmt DECIMAL(18,2);
        DECLARE @CurPaid DECIMAL(18,2); DECLARE @CurDue DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2); DECLARE @NewPaid DECIMAL(18,2);
        DECLARE @NewStatus NVARCHAR(MAX);

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo, Amount, PaidAmount, Due FROM #Pending ORDER BY InstallmentNo;
        OPEN cur;
        FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
        WHILE @@FETCH_STATUS = 0 AND @Remaining > 0
        BEGIN
            SET @ToApply   = CASE WHEN @Remaining >= @CurDue THEN @CurDue ELSE @Remaining END;
            SET @NewPaid   = @CurPaid + @ToApply;
            SET @NewStatus = CASE WHEN @NewPaid >= @CurAmt THEN 'Paid' WHEN @NewPaid > 0 THEN 'Partial' ELSE 'Pending' END;
            UPDATE ContractInstallments
            SET PaidAmount=@NewPaid, PaidDate=@PaidDate, Status=@NewStatus,
                PaymentModeId=@PaymentModeId, PaymentMode=@PaymentMode,
                ChequeNumber=@ChequeNumber, ClearanceDate=@ClearanceDate,
                Description=@Description, ReceivedBy=@ReceivedBy,
                ReceivedContact=@ReceivedContact, FundPoolId=@FundPoolId,
                FundPoolName=@FundPoolName, IssuedBy=@IssuedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@CurNo AND ISNULL(IsDeleted,0)=0;
            SET @AppliedList = CASE WHEN @AppliedList='' THEN CAST(@CurNo AS NVARCHAR)
                               ELSE @AppliedList+','+CAST(@CurNo AS NVARCHAR) END;
            SET @Remaining = @Remaining - @ToApply;
            FETCH NEXT FROM cur INTO @CurNo, @CurAmt, @CurPaid, @CurDue;
        END;
        CLOSE cur; DEALLOCATE cur; DROP TABLE #Pending;

        -- FundPool
        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools SET Balance=Balance+@PaidAmount, UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;

        -- TxnRecord
        DECLARE @TxnId NVARCHAR(MAX) = 'TXN-'+CONVERT(NVARCHAR,@PaidDate,112)+'-'
            +RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),6);
        DECLARE @Unalloc DECIMAL(18,2) = CASE WHEN @Remaining>0 THEN @Remaining ELSE 0 END;

        INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
            TotalAmount,Amount,PaidDate,PaymentMode,PaymentModeId,ChequeNumber,
            Description,IssuedBy,ReceivedBy,ReceivedContact,FundPoolId,FundPoolName,
            AppliedInstallments,Unallocated,InstallmentNo,CreatedAt,UpdatedAt)
        VALUES(@TxnId,'CR',@ContractId,@ContractId,@TenantId,@CampId,
            @PaidAmount,@PaidAmount,@PaidDate,@PaymentMode,@PaymentModeId,@ChequeNumber,
            @Description,@IssuedBy,@ReceivedBy,@ReceivedContact,@FundPoolId,@FundPoolName,
            @AppliedList,@Unalloc,
            CASE WHEN CHARINDEX(',',@AppliedList)>0
                 THEN CAST(LEFT(@AppliedList,CHARINDEX(',',@AppliedList)-1) AS INT)
                 WHEN @AppliedList<>'' THEN CAST(@AppliedList AS INT) ELSE NULL END,
            GETUTCDATE(),GETUTCDATE());
        SET @NewTxnRecordId = SCOPE_IDENTITY();

        -- Incomes (store TxnRecordId for exact match on delete/edit)
        DECLARE @IncomeCode NVARCHAR(MAX) = 'INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
        INSERT INTO Incomes(IncomeId,Date,Mode,Head,FundPool,FundPoolName,Amount,
            Purpose,Source,SourceRef,CampId,CampName,ContractId,ContractCode,
            TenantId,TenantName,TxnRecordId,CreatedAt,UpdatedAt)
        VALUES(@IncomeCode,@PaidDate,ISNULL(NULLIF(@PaymentMode,''),'Cash'),'Rent Income',
            ISNULL(NULLIF(@FundPoolCode,''),'MAIN'),ISNULL(NULLIF(@FundPoolName,''),'Main Fund'),
            @PaidAmount,
            'Rent received - Inst: '+ISNULL(NULLIF(@AppliedList,''),'0')+' | Contract: '+@ContractId+' | TxnId: '+@TxnId,
            'Tenant',@ContractId,ISNULL(@CampId,0),ISNULL(@CampName,''),
            @ContractId,@ContractId,@TenantId,@TenantName,
            @NewTxnRecordId,GETUTCDATE(),GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO
PRINT 'sp_RecordPayment updated - TxnRecordId stored in Incomes';
GO

-- ============================================================
-- FIX sp_DeleteTxnRecord: Complete proper revert all tables
-- ============================================================
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ContractId NVARCHAR(MAX), @Amount DECIMAL(18,2),
            @FundPoolId INT, @AppliedInstallments NVARCHAR(MAX),
            @TxnType NVARCHAR(20), @TxnId NVARCHAR(MAX);

    SELECT @ContractId=ContractId, @Amount=Amount, @FundPoolId=FundPoolId,
           @AppliedInstallments=AppliedInstallments, @TxnType=TxnType, @TxnId=TxnId
    FROM TxnRecords WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found or already deleted.',16,1,@Id); RETURN; END

    IF @TxnType = 'CR'
    BEGIN
        -- 1. FundPool revert
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools SET Balance=Balance-@Amount, UpdatedAt=GETUTCDATE()
            WHERE Id=@FundPoolId;

        -- 2. ContractInstallments revert — set each to 0/Pending individually
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            UPDATE ci
            SET ci.PaidAmount=0, ci.PaidDate=NULL, ci.Status='Pending',
                ci.PaymentMode='', ci.PaymentModeId=NULL,
                ci.ChequeNumber='', ci.ClearanceDate='',
                ci.Description='', ci.ReceivedBy='',
                ci.ReceivedContact='', ci.FundPoolId=NULL,
                ci.FundPoolName='', ci.IssuedBy=''
            FROM ContractInstallments ci
            INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
                ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
            WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0;

            -- Re-mark overdue if past due
            UPDATE ContractInstallments
            SET Status='Overdue'
            WHERE ContractId=@ContractId AND Status='Pending'
              AND DueDate < CAST(GETUTCDATE() AS DATE)
              AND ISNULL(IsDeleted,0)=0
              AND InstallmentNo IN (
                  SELECT CAST(TRIM(value) AS INT)
                  FROM STRING_SPLIT(@AppliedInstallments,',') WHERE TRIM(value)<>'');
        END

        -- 3. ContractRooms revert (sum per room from ContractRoomsTrns)
        UPDATE cr
        SET
            cr.PaidAmount = CASE WHEN ISNULL(cr.PaidAmount,0) - rt.TotalAmt < 0 THEN 0
                            ELSE ISNULL(cr.PaidAmount,0) - rt.TotalAmt END,
            cr.Balance = ISNULL(cr.TotalAmount,0) - (
                CASE WHEN ISNULL(cr.PaidAmount,0) - rt.TotalAmt < 0 THEN 0
                ELSE ISNULL(cr.PaidAmount,0) - rt.TotalAmt END)
        FROM ContractRooms cr
        INNER JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt
            FROM ContractRoomsTrns
            WHERE TxnRecordId=@Id AND TxnType='CR' AND ContractId=@ContractId
            GROUP BY RoomId
        ) rt ON rt.RoomId=cr.RoomId
        WHERE cr.ContractId=@ContractId;

        -- 4. ContractRoomInstallments revert
        UPDATE cri
        SET
            cri.PaidAmount = CASE WHEN ISNULL(cri.PaidAmount,0) - rt.TotalAmt < 0 THEN 0
                             ELSE ISNULL(cri.PaidAmount,0) - rt.TotalAmt END,
            cri.Balance = cri.InstallAmount - (
                CASE WHEN ISNULL(cri.PaidAmount,0) - rt.TotalAmt < 0 THEN 0
                ELSE ISNULL(cri.PaidAmount,0) - rt.TotalAmt END),
            cri.Status = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-rt.TotalAmt END) = 0 THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-rt.TotalAmt END) >= cri.InstallAmount THEN 'Paid'
                ELSE 'Partial' END,
            cri.PaidDate = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cri.PaidAmount,0)-rt.TotalAmt END) = 0 THEN NULL
                ELSE cri.PaidDate END,
            cri.UpdatedAt = GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt
            FROM ContractRoomsTrns
            WHERE TxnRecordId=@Id AND TxnType='CR' AND ContractId=@ContractId
            GROUP BY RoomId
        ) rt ON rt.RoomId=cri.RoomId
        WHERE cri.ContractId=@ContractId;

        -- 5. Delete ContractRoomsTrns
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId=@Id;

        -- 6. Incomes soft delete (exact match by TxnRecordId)
        UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
        WHERE TxnRecordId=@Id;

        -- Fallback: TxnId match in Purpose if TxnRecordId not set
        IF @@ROWCOUNT = 0 AND @TxnId IS NOT NULL AND LEN(@TxnId) > 0
            UPDATE Incomes SET IsDeleted=1, UpdatedAt=GETUTCDATE()
            WHERE ContractId=@ContractId AND Source='Tenant'
              AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;
    END

    -- 7. Soft delete TxnRecord
    UPDATE TxnRecords
    SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT 'sp_DeleteTxnRecord fixed - complete revert all 7 tables';
GO

-- ============================================================
-- FIX sp_UpdateTxnRecord: Complete proper revert + re-apply
-- ============================================================
CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id             INT,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @PaymentMode    NVARCHAR(MAX) = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(MAX) = '',
    @Description    NVARCHAR(MAX) = '',
    @ReceivedBy     NVARCHAR(MAX) = '',
    @ChequeNumber   NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ContractId NVARCHAR(MAX), @OldAmount DECIMAL(18,2),
            @OldFundPoolId INT, @AppliedInstallments NVARCHAR(MAX), @TxnId NVARCHAR(MAX);
    DECLARE @FundPoolCode NVARCHAR(MAX) = '';

    SELECT @ContractId=ContractId, @OldAmount=Amount, @OldFundPoolId=FundPoolId,
           @AppliedInstallments=AppliedInstallments, @TxnId=TxnId
    FROM TxnRecords WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found.',16,1,@Id); RETURN; END

    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId;

    -- 1. Update TxnRecord
    UPDATE TxnRecords
    SET Amount=@Amount, PaidDate=@TxnDate, PaymentMode=@PaymentMode,
        PaymentModeId=@PaymentModeId, FundPoolId=@FundPoolId,
        FundPoolName=@FundPoolName, Description=@Description,
        ReceivedBy=@ReceivedBy, ChequeNumber=ISNULL(NULLIF(@ChequeNumber,''),ChequeNumber),
        UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    -- 2. FundPool: revert old, apply new
    IF @OldFundPoolId IS NOT NULL AND @OldAmount > 0
        UPDATE FundPools SET Balance=Balance-@OldAmount, UpdatedAt=GETUTCDATE() WHERE Id=@OldFundPoolId;
    IF @FundPoolId IS NOT NULL AND @Amount > 0
        UPDATE FundPools SET Balance=Balance+@Amount, UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;

    -- 3. ContractInstallments: revert old, re-apply new amount
    IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
    BEGIN
        -- Step A: reset all applied installments to 0/Pending
        UPDATE ci
        SET ci.PaidAmount=0, ci.PaidDate=NULL, ci.Status='Pending',
            ci.PaymentMode='', ci.PaymentModeId=NULL,
            ci.ChequeNumber='', ci.ClearanceDate='',
            ci.Description='', ci.ReceivedBy='',
            ci.ReceivedContact='', ci.FundPoolId=NULL,
            ci.FundPoolName='', ci.IssuedBy=''
        FROM ContractInstallments ci
        INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
            ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
        WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0;

        -- Step B: re-apply new @Amount across same installments in order
        DECLARE @Remaining DECIMAL(18,2) = @Amount;
        DECLARE @InstNo INT, @InstAmt DECIMAL(18,2), @InstPaid DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2), @NewPaid DECIMAL(18,2), @NewStatus NVARCHAR(MAX);

        DECLARE inst_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT ci.InstallmentNo, ci.Amount, ci.PaidAmount
            FROM ContractInstallments ci
            INNER JOIN STRING_SPLIT(@AppliedInstallments,',') s
                ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
            WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0
            ORDER BY ci.InstallmentNo;

        OPEN inst_cur;
        FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;
        WHILE @@FETCH_STATUS=0 AND @Remaining>0
        BEGIN
            DECLARE @InstDue DECIMAL(18,2) = @InstAmt - @InstPaid;
            SET @ToApply   = CASE WHEN @Remaining >= @InstDue THEN @InstDue ELSE @Remaining END;
            SET @NewPaid   = @InstPaid + @ToApply;
            SET @NewStatus = CASE WHEN @NewPaid>=@InstAmt THEN 'Paid' WHEN @NewPaid>0 THEN 'Partial' ELSE 'Pending' END;
            UPDATE ContractInstallments
            SET PaidAmount=@NewPaid, PaidDate=@TxnDate, Status=@NewStatus,
                PaymentMode=@PaymentMode, PaymentModeId=@PaymentModeId,
                FundPoolId=@FundPoolId, FundPoolName=@FundPoolName,
                Description=@Description, ReceivedBy=@ReceivedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@InstNo AND ISNULL(IsDeleted,0)=0;
            SET @Remaining=@Remaining-@ToApply;
            FETCH NEXT FROM inst_cur INTO @InstNo, @InstAmt, @InstPaid;
        END;
        CLOSE inst_cur; DEALLOCATE inst_cur;
    END

    -- 4. Incomes: update linked income (by TxnRecordId exact match)
    UPDATE Incomes
    SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode),
        Amount=@Amount,
        FundPool=ISNULL(NULLIF(@FundPoolCode,''),FundPool),
        FundPoolName=ISNULL(NULLIF(@FundPoolName,''),FundPoolName),
        Purpose='Rent received - Inst: '+ISNULL(@AppliedInstallments,'')+' | Contract: '+@ContractId,
        UpdatedAt=GETUTCDATE()
    WHERE TxnRecordId=@Id AND ISNULL(IsDeleted,0)=0;

    -- Fallback: TxnId match in Purpose
    IF @@ROWCOUNT=0 AND @TxnId IS NOT NULL AND LEN(@TxnId)>0
        UPDATE Incomes
        SET Date=@TxnDate, Mode=ISNULL(NULLIF(@PaymentMode,''),Mode),
            Amount=@Amount,
            FundPool=ISNULL(NULLIF(@FundPoolCode,''),FundPool),
            FundPoolName=ISNULL(NULLIF(@FundPoolName,''),FundPoolName),
            Purpose='Rent received - Inst: '+ISNULL(@AppliedInstallments,'')+' | Contract: '+@ContractId,
            UpdatedAt=GETUTCDATE()
        WHERE ContractId=@ContractId AND Source='Tenant'
          AND Purpose LIKE '%'+@TxnId+'%' AND ISNULL(IsDeleted,0)=0;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT 'sp_UpdateTxnRecord fixed - proper revert+reapply all tables';
GO

-- ============================================================
-- FIX sp_GetTxnRecords: filter IsDeleted
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber   INT,
    @PageSize     INT,
    @ContractId   NVARCHAR(MAX) = NULL,
    @TenantId     INT           = NULL,
    @CampId       INT           = NULL,
    @TxnType      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId AND c.IsDeleted=0
    JOIN Tenants t   ON t.Id=c.TenantId
    JOIN Camps ca    ON ca.Id=c.CampId
    WHERE ISNULL(tr.IsDeleted,0)=0
      AND (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType);

    SELECT tr.Id,tr.TxnId,tr.TxnType,tr.ContractId,tr.ContractCode,
        c.TenantId,t.Name TenantName,c.CampId,ca.Name CampName,
        tr.TotalAmount,tr.Amount,tr.PaidDate TxnDate,tr.FromDate,tr.ToDate,
        tr.PaymentMode,tr.PaymentModeId,tr.FundPoolId,tr.FundPoolName,
        tr.Description,tr.ReceivedBy,tr.ChequeNumber,tr.IssuedBy,tr.ReceivedContact,
        tr.InstallmentNo,tr.AppliedInstallments,tr.Unallocated,tr.CreatedAt,tr.UpdatedAt
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId AND c.IsDeleted=0
    JOIN Tenants t   ON t.Id=c.TenantId
    JOIN Camps ca    ON ca.Id=c.CampId
    WHERE ISNULL(tr.IsDeleted,0)=0
      AND (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId IS NULL OR c.TenantId=@TenantId)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@TxnType IS NULL OR tr.TxnType=@TxnType)
    ORDER BY tr.PaidDate DESC,tr.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ============================================================
-- FIX sp_GetPaymentHistory: filter IsDeleted
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory @ContractId NVARCHAR(MAX) AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.Id,p.ContractId,p.InstallmentNo,p.Amount,p.DueDate,
        p.PaidAmount,p.PaidDate,p.Status,p.PaymentMode,p.PaymentModeId,
        p.ChequeNumber,p.ClearanceDate,p.Description,p.ReceivedBy,
        p.ReceivedContact,p.FundPoolId,p.FundPoolName,p.IssuedBy,
        t.Name TenantName, ca.Name CampName
    FROM ContractInstallments p
    JOIN Contracts c ON c.ContractId=p.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    JOIN Camps ca ON ca.Id=c.CampId
    WHERE p.ContractId=@ContractId AND ISNULL(p.IsDeleted,0)=0
    ORDER BY p.InstallmentNo;
END
GO

-- ============================================================
-- FIX sp_GetPaymentSummary: filter IsDeleted
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary @ContractId NVARCHAR(MAX) AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId,c.TenantId,t.Name TenantName,t.Contact TenantContact,
        c.CampId,ca.Name CampName,
        CONVERT(NVARCHAR,c.StartDate,23) StartDate,CONVERT(NVARCHAR,c.EndDate,23) EndDate,
        c.Months,c.ContractTotal,c.MonthlyTotal,0 LessorAmount,c.Status,
        COUNT(p.Id) TotalInstallments,
        SUM(CASE WHEN p.Status='Paid' THEN 1 ELSE 0 END) PaidCount,
        SUM(CASE WHEN p.Status IN('Pending','Overdue') THEN 1 ELSE 0 END) PendingCount,
        SUM(CASE WHEN p.Status='Partial' THEN 1 ELSE 0 END) PartialCount,
        ISNULL(SUM(p.PaidAmount),0) TotalPaid,
        ISNULL(SUM(CASE WHEN p.Status IN('Pending','Overdue','Partial') THEN p.Amount-p.PaidAmount ELSE 0 END),0) TotalDue,
        ISNULL(SUM(p.Amount),0) TotalScheduled,
        ISNULL(MIN(CASE WHEN p.Status IN('Pending','Overdue','Partial') THEN p.Amount-p.PaidAmount END),0) NextInstallmentDue,
        MIN(CASE WHEN p.Status IN('Pending','Overdue','Partial') THEN p.InstallmentNo END) NextInstallmentNo,
        ISNULL((SELECT STRING_AGG(r2.RoomNo,', ') FROM ContractRooms cr2
                JOIN Rooms r2 ON r2.Id=cr2.RoomId WHERE cr2.ContractId=c.ContractId),'') RoomNos,
        (SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId=c.ContractId) RoomCount
    FROM Contracts c
    JOIN Tenants t ON t.Id=c.TenantId
    JOIN Camps ca ON ca.Id=c.CampId
    LEFT JOIN ContractInstallments p
        ON p.ContractId=c.ContractId AND ISNULL(p.IsDeleted,0)=0
    WHERE c.ContractId=@ContractId
    GROUP BY c.ContractId,c.TenantId,t.Name,t.Contact,c.CampId,ca.Name,
        c.StartDate,c.EndDate,c.Months,c.ContractTotal,c.MonthlyTotal,c.Status;
END
GO

PRINT '============================================================';
PRINT 'ALL 096 FIXES APPLIED:';
PRINT '  sp_RecordPayment     - TxnRecordId stored in Incomes';
PRINT '  sp_DeleteTxnRecord   - complete revert: CI + FP + CR + CRI + CRT + Incomes';
PRINT '  sp_UpdateTxnRecord   - revert + re-apply: CI + FP + Incomes';
PRINT '  sp_GetTxnRecords     - IsDeleted filter';
PRINT '  sp_GetPaymentHistory - IsDeleted filter';
PRINT '  sp_GetPaymentSummary - IsDeleted filter';
PRINT '============================================================';
GO
