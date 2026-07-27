-- ============================================================
-- 078: Final fix - remaining SPs
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- CompanyAssets
CREATE OR ALTER PROCEDURE sp_CreateCompanyAsset
    @AssetCode NVARCHAR(MAX)='',@AssetType NVARCHAR(MAX)='',@DocumentName NVARCHAR(MAX)='',
    @CompanyName NVARCHAR(MAX)='',@IssueDate DATE=NULL,@ExpiryDate DATE=NULL,
    @Status NVARCHAR(MAX)='Active',@DocumentUrl NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO CompanyAssets(AssetCode,AssetType,DocumentName,CompanyName,IssueDate,ExpiryDate,
        Status,DocumentUrl,Remarks,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@AssetCode,@AssetType,@DocumentName,@CompanyName,@IssueDate,@ExpiryDate,
        @Status,@DocumentUrl,@Remarks,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateCompanyAsset
    @Id INT,@AssetCode NVARCHAR(MAX)='',@AssetType NVARCHAR(MAX)='',@DocumentName NVARCHAR(MAX)='',
    @CompanyName NVARCHAR(MAX)='',@IssueDate DATE=NULL,@ExpiryDate DATE=NULL,
    @Status NVARCHAR(MAX)='Active',@DocumentUrl NVARCHAR(MAX)='',@Remarks NVARCHAR(MAX)='',
    @UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE CompanyAssets SET AssetCode=@AssetCode,AssetType=@AssetType,DocumentName=@DocumentName,
        CompanyName=@CompanyName,IssueDate=@IssueDate,ExpiryDate=@ExpiryDate,
        Status=@Status,DocumentUrl=@DocumentUrl,Remarks=@Remarks,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCompanyAssetExpiryAlerts AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CompanyAssets
    WHERE IsDeleted=0 AND ExpiryDate IS NOT NULL
      AND ExpiryDate <= DATEADD(DAY,30,GETDATE())
    ORDER BY ExpiryDate;
END
GO

-- TxnRecord soft delete
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord @Id INT AS BEGIN
    SET NOCOUNT ON;
    BEGIN TRY BEGIN TRANSACTION;
    DECLARE @ContractId NVARCHAR(MAX),@Amount DECIMAL(18,2),@FundPoolId INT,@AppliedInstallments NVARCHAR(MAX),@TxnType NVARCHAR(20),@TxnId NVARCHAR(MAX);
    SELECT @ContractId=ContractId,@Amount=Amount,@FundPoolId=FundPoolId,@AppliedInstallments=AppliedInstallments,@TxnType=TxnType,@TxnId=TxnId FROM TxnRecords WHERE Id=@Id;
    IF @ContractId IS NULL BEGIN RAISERROR('TxnRecord not found.',16,1); RETURN; END
    IF @TxnType='CR' BEGIN
        IF @FundPoolId IS NOT NULL AND @Amount>0 UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETDATE() WHERE Id=@FundPoolId;
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments)>0 BEGIN
            CREATE TABLE #DelInst(InstallmentNo INT);
            INSERT INTO #DelInst SELECT TRIM([value]) FROM STRING_SPLIT(@AppliedInstallments,',') WHERE TRIM([value])<>'';
            UPDATE ci SET ci.PaidAmount=CASE WHEN ci.PaidAmount-@Amount<0 THEN 0 ELSE ci.PaidAmount-@Amount END,
                ci.PaidDate=CASE WHEN ci.PaidAmount-@Amount<=0 THEN NULL ELSE ci.PaidDate END,
                ci.Status=CASE WHEN(CASE WHEN ci.PaidAmount-@Amount<0 THEN 0 ELSE ci.PaidAmount-@Amount END)=0 THEN 'Pending'
                    WHEN(CASE WHEN ci.PaidAmount-@Amount<0 THEN 0 ELSE ci.PaidAmount-@Amount END)>=ci.Amount THEN 'Paid' ELSE 'Partial' END
            FROM ContractInstallments ci JOIN #DelInst di ON ci.InstallmentNo=di.InstallmentNo WHERE ci.ContractId=@ContractId;
            DROP TABLE #DelInst;
        END
        UPDATE cr SET cr.PaidAmount=CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END,
            cr.Balance=ISNULL(cr.TotalAmount,0)-(CASE WHEN ISNULL(cr.PaidAmount,0)-rt.TotalAmt<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-rt.TotalAmt END)
        FROM ContractRooms cr INNER JOIN(SELECT RoomId,SUM(Amount) TotalAmt FROM ContractRoomsTrns WHERE TxnRecordId=@Id AND TxnType='CR' AND ContractId=@ContractId GROUP BY RoomId) rt ON rt.RoomId=cr.RoomId WHERE cr.ContractId=@ContractId;
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId=@Id;
        IF @TxnId IS NOT NULL AND LEN(@TxnId)>0
            DELETE FROM Incomes WHERE ContractId=@ContractId AND Source='Tenant' AND Purpose LIKE '%'+@TxnId+'%';
    END
    UPDATE TxnRecords SET IsDeleted=1,DeletedBy=NULL,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
    COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; IF OBJECT_ID('tempdb..#DelInst') IS NOT NULL DROP TABLE #DelInst; THROW; END CATCH
END
GO

-- UpdateTxnRecord with IsDeleted filter
CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id INT,@Amount DECIMAL(18,2),@TxnDate DATE,
    @PaymentMode NVARCHAR(MAX)='',@PaymentModeId INT=NULL,
    @FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Description NVARCHAR(MAX)='',@ReceivedBy NVARCHAR(MAX)='',@ChequeNumber NVARCHAR(MAX)=''
AS BEGIN
    SET NOCOUNT ON; BEGIN TRY BEGIN TRANSACTION;
    DECLARE @ContractId NVARCHAR(MAX),@OldAmount DECIMAL(18,2),@OldFundPoolId INT,@AppliedInstallments NVARCHAR(MAX);
    SELECT @ContractId=ContractId,@OldAmount=Amount,@OldFundPoolId=FundPoolId,@AppliedInstallments=AppliedInstallments FROM TxnRecords WHERE Id=@Id AND IsDeleted=0;
    IF @ContractId IS NULL BEGIN RAISERROR('TxnRecord %d not found.',16,1,@Id); RETURN; END
    UPDATE TxnRecords SET Amount=@Amount,PaidDate=@TxnDate,PaymentMode=@PaymentMode,PaymentModeId=@PaymentModeId,
        FundPoolId=@FundPoolId,FundPoolName=@FundPoolName,Description=@Description,ReceivedBy=@ReceivedBy,
        ChequeNumber=ISNULL(NULLIF(@ChequeNumber,''),ChequeNumber),UpdatedAt=GETUTCDATE() WHERE Id=@Id AND IsDeleted=0;
    IF @OldFundPoolId IS NOT NULL AND @OldAmount>0 UPDATE FundPools SET Balance=Balance-@OldAmount,UpdatedAt=GETUTCDATE() WHERE Id=@OldFundPoolId;
    IF @FundPoolId IS NOT NULL AND @Amount>0 UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;
    IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments)>0 BEGIN
        CREATE TABLE #AppliedInst(InstallmentNo INT);
        INSERT INTO #AppliedInst SELECT TRIM([value]) FROM STRING_SPLIT(@AppliedInstallments,',') WHERE TRIM([value])<>'';
        UPDATE ci SET ci.PaidAmount=CASE WHEN ci.PaidAmount-@OldAmount<0 THEN 0 ELSE ci.PaidAmount-@OldAmount END,
            ci.Status=CASE WHEN(CASE WHEN ci.PaidAmount-@OldAmount<0 THEN 0 ELSE ci.PaidAmount-@OldAmount END)=0 THEN 'Pending'
                WHEN(CASE WHEN ci.PaidAmount-@OldAmount<0 THEN 0 ELSE ci.PaidAmount-@OldAmount END)>=ci.Amount THEN 'Paid' ELSE 'Partial' END
        FROM ContractInstallments ci JOIN #AppliedInst ai ON ci.InstallmentNo=ai.InstallmentNo WHERE ci.ContractId=@ContractId;
        DECLARE @Remaining DECIMAL(18,2)=@Amount,@InstNo INT,@InstAmt DECIMAL(18,2),@InstPaid DECIMAL(18,2);
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT ci.InstallmentNo,ci.Amount,ci.PaidAmount FROM ContractInstallments ci JOIN #AppliedInst ai ON ci.InstallmentNo=ai.InstallmentNo WHERE ci.ContractId=@ContractId ORDER BY ci.InstallmentNo;
        OPEN cur; FETCH NEXT FROM cur INTO @InstNo,@InstAmt,@InstPaid;
        WHILE @@FETCH_STATUS=0 AND @Remaining>0 BEGIN
            DECLARE @ToApply DECIMAL(18,2)=CASE WHEN @Remaining>=@InstAmt-@InstPaid THEN @InstAmt-@InstPaid ELSE @Remaining END;
            UPDATE ContractInstallments SET PaidAmount=@InstPaid+@ToApply,PaidDate=@TxnDate,
                Status=CASE WHEN @InstPaid+@ToApply>=@InstAmt THEN 'Paid' WHEN @InstPaid+@ToApply>0 THEN 'Partial' ELSE 'Pending' END,
                PaymentMode=@PaymentMode,PaymentModeId=@PaymentModeId,FundPoolId=@FundPoolId,FundPoolName=@FundPoolName,Description=@Description,ReceivedBy=@ReceivedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@InstNo;
            SET @Remaining=@Remaining-@ToApply;
            FETCH NEXT FROM cur INTO @InstNo,@InstAmt,@InstPaid;
        END; CLOSE cur; DEALLOCATE cur; DROP TABLE #AppliedInst;
    END
    -- Sync Incomes
    DECLARE @TxnId NVARCHAR(MAX),@FPCode NVARCHAR(MAX)='';
    SELECT @TxnId=TxnId FROM TxnRecords WHERE Id=@Id;
    IF @FundPoolId IS NOT NULL SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId;
    IF @TxnId IS NOT NULL UPDATE Incomes SET Date=@TxnDate,Mode=ISNULL(NULLIF(@PaymentMode,''),Mode),Amount=@Amount,
        FundPool=ISNULL(NULLIF(@FPCode,''),FundPool),FundPoolName=ISNULL(NULLIF(@FundPoolName,''),FundPoolName),UpdatedAt=GETUTCDATE()
    WHERE ContractId=@ContractId AND Source='Tenant' AND Purpose LIKE '%'+@TxnId+'%';
    COMMIT TRANSACTION;
    END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; IF OBJECT_ID('tempdb..#AppliedInst') IS NOT NULL DROP TABLE #AppliedInst; THROW; END CATCH
END
GO

-- UpdateContract with IsDeleted
CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId NVARCHAR(MAX),@StartDate DATE,@EndDate DATE,@Months INT=1,
    @MonthlyTotal DECIMAL(18,2)=0,@ContractTotal DECIMAL(18,2)=0,
    @SecurityDeposit DECIMAL(18,2)=0,@InstallmentType NVARCHAR(MAX)='Monthly',
    @IssuedBy NVARCHAR(MAX)='',@Notes NVARCHAR(MAX)='',@LessorAmount DECIMAL(18,2)=0,
    @Status NVARCHAR(MAX)=NULL,@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Contracts SET StartDate=@StartDate,EndDate=@EndDate,Months=@Months,
        MonthlyTotal=@MonthlyTotal,ContractTotal=@ContractTotal,SecurityDeposit=@SecurityDeposit,
        InstallmentType=@InstallmentType,IssuedBy=@IssuedBy,Notes=@Notes,LessorAmount=@LessorAmount,
        Status=ISNULL(@Status,Status),UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE ContractId=@ContractId AND IsDeleted=0;
END
GO

-- UpdateContractRoomInstallment with IsDeleted
CREATE OR ALTER PROCEDURE sp_UpdateContractRoomInstallment
    @Id INT,@PaidAmount DECIMAL(18,2),@PaidDate DATE=NULL,@Status NVARCHAR(MAX)='Paid',
    @PaymentMode NVARCHAR(MAX)='',@UpdatedBy INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE ContractRoomInstallments SET PaidAmount=@PaidAmount,PaidDate=@PaidDate,
        Status=@Status,PaymentMode=@PaymentMode,Balance=InstallAmount-@PaidAmount,
        UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO

-- CreateOwnerContract with AddedBy
CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId INT,@OwnerId INT,@PaymentType NVARCHAR(MAX)='Monthly',
    @TotalAmount DECIMAL(18,2)=0,@StartDate DATE=NULL,@Status NVARCHAR(MAX)='Active',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OcCode NVARCHAR(MAX)='OC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR),6);
    DECLARE @CampName NVARCHAR(MAX)='',@OwnerName NVARCHAR(MAX)='',@OwnerCode NVARCHAR(MAX)='';
    SELECT @CampName=Name FROM Camps WHERE Id=@CampId;
    SELECT @OwnerName=Name,@OwnerCode=Code FROM Owners WHERE Id=@OwnerId;
    INSERT INTO OwnerContracts(OcCode,CampId,CampName,OwnerId,OwnerName,OwnerCode,PaymentType,TotalAmount,StartDate,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,@OwnerCode,@PaymentType,@TotalAmount,@StartDate,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- CreateTxnRecord with AddedBy + IsDeleted=0
CREATE OR ALTER PROCEDURE sp_CreateTxnRecord
    @TxnType NVARCHAR(MAX)='CR',@ContractId NVARCHAR(MAX)='',@ContractCode NVARCHAR(MAX)='',
    @TenantId INT=NULL,@CampId INT=NULL,@TotalAmount DECIMAL(18,2)=0,@Amount DECIMAL(18,2)=0,
    @TxnDate DATE=NULL,@FromDate DATE=NULL,@ToDate DATE=NULL,
    @PaymentMode NVARCHAR(MAX)='',@PaymentModeId INT=NULL,@FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Description NVARCHAR(MAX)='',@ReceivedBy NVARCHAR(MAX)='',@InstallmentNo INT=NULL,
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @TxnId NVARCHAR(MAX)='TXN-'+CONVERT(NVARCHAR(MAX),ISNULL(@TxnDate,CAST(GETDATE() AS DATE)),112)+'-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),6);
    INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,TotalAmount,Amount,PaidDate,FromDate,ToDate,PaymentMode,PaymentModeId,FundPoolId,FundPoolName,Description,ReceivedBy,InstallmentNo,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@TxnId,@TxnType,@ContractId,@ContractCode,@TenantId,@CampId,@TotalAmount,@Amount,@TxnDate,@FromDate,@ToDate,@PaymentMode,@PaymentModeId,@FundPoolId,@FundPoolName,@Description,@ReceivedBy,@InstallmentNo,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

PRINT '078 - All remaining SPs fixed';
GO
