USE TFMS_TestSoftwareDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 1: sp_GetOwnerInstallments — match repo params exactly
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetOwnerInstallments
    @OcId INT, @PageNumber INT=1, @PageSize INT=500,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OwnerInstallments
    WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (@Status IS NULL OR Status=@Status);
    SELECT Id,OwnerContractId,No AS InstallmentNo,Amount,
           ISNULL(PaidAmount,0) PaidAmount,DueDate,PaidDate,Status,ExpenseId
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (@Status IS NULL OR Status=@Status)
    ORDER BY No OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT 'FIX 1: sp_GetOwnerInstallments DONE';
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 2: sp_GetOwnerContracts — include PaidAmount + Balance
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT
        oc.Id, oc.OcCode, oc.CampId,
        ISNULL(c.Name, oc.CampName) AS CampName,
        oc.OwnerId,
        ISNULL(o.Name, oc.OwnerName) AS OwnerName,
        ISNULL(o.Code, oc.OwnerCode) AS OwnerCode,
        oc.PaymentType, oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS Balance,
        oc.StartDate, oc.Status, oc.CreatedAt, oc.UpdatedAt,
        oc.AddedBy, oc.UpdatedBy, oc.IsDeleted
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId AND o.IsDeleted=0
    LEFT JOIN Camps c ON c.Id=oc.CampId AND c.IsDeleted=0
    WHERE oc.IsDeleted=0
      AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
      AND (@CampId IS NULL OR oc.CampId=@CampId)
      AND (@Status IS NULL OR oc.Status=@Status)
    ORDER BY oc.CreatedAt DESC;
END
GO
PRINT 'FIX 2: sp_GetOwnerContracts DONE';
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 3: sp_CreateOwnerContract — handle both PascalCase + camelCase JSON
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId INT, @OwnerId INT, @PaymentType NVARCHAR(MAX)='Monthly',
    @TotalAmount DECIMAL(18,2), @StartDate NVARCHAR(MAX),
    @Status NVARCHAR(MAX)='Active',
    @InstallmentsJson NVARCHAR(MAX)='[]',
    @MonthlyInstallmentsJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OcCode NVARCHAR(50)=CONCAT('OC-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR),5));
    DECLARE @OwnerCode NVARCHAR(MAX)=''; SELECT @OwnerCode=ISNULL(Code,'') FROM Owners WHERE Id=@OwnerId;
    DECLARE @OwnerName NVARCHAR(MAX)=''; SELECT @OwnerName=ISNULL(Name,'') FROM Owners WHERE Id=@OwnerId;
    DECLARE @CampName NVARCHAR(MAX)=''; SELECT @CampName=ISNULL(Name,'') FROM Camps WHERE Id=@CampId;
    INSERT INTO OwnerContracts(OcCode,CampId,CampName,OwnerId,OwnerName,OwnerCode,PaymentType,TotalAmount,StartDate,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,@OwnerCode,@PaymentType,@TotalAmount,CAST(@StartDate AS DATE),@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    IF @InstallmentsJson IS NOT NULL AND @InstallmentsJson<>'[]'
        INSERT INTO OwnerInstallments(OwnerContractId,No,Amount,PaidAmount,DueDate,Status,AddedBy,IsDeleted)
        SELECT @NewId,
            ISNULL(CAST(j.NoPascal AS INT), ISNULL(CAST(j.NoCamel AS INT), 0)),
            ISNULL(CAST(j.AmtPascal AS DECIMAL(18,2)), ISNULL(CAST(j.AmtCamel AS DECIMAL(18,2)), 0)),
            0,
            CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE),
            'Pending', @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal   INT            '$.No',
            NoCamel    INT            '$.no',
            AmtPascal  DECIMAL(18,2)  '$.Amount',
            AmtCamel   DECIMAL(18,2)  '$.amount',
            DuePascal  NVARCHAR(50)   '$.DueDate',
            DueCamel   NVARCHAR(50)   '$.dueDate'
        ) j;
    DECLARE @TxnCode NVARCHAR(50)=CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,InstallmentNos,CreatedAt)
    VALUES(@TxnCode,@NewId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,'DR',@TotalAmount,GETUTCDATE(),CONCAT('Contract Created - Total: ',@TotalAmount),'',GETUTCDATE());
END
GO
PRINT 'FIX 3: sp_CreateOwnerContract DONE';
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 4: sp_RecordPayment — complete with all NOT NULL columns
-- ══════════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId NVARCHAR(MAX), @InstallmentNo INT, @PaidAmount DECIMAL(18,2),
    @PaidDate DATETIME=NULL, @PaymentModeId INT=NULL, @PaymentMode NVARCHAR(MAX)='',
    @ChequeNumber NVARCHAR(MAX)='', @ClearanceDate NVARCHAR(MAX)='',
    @Description NVARCHAR(MAX)='', @ReceivedBy NVARCHAR(MAX)='',
    @ReceivedContact NVARCHAR(MAX)='', @FundPoolId INT=NULL,
    @FundPoolName NVARCHAR(MAX)='', @IssuedBy NVARCHAR(MAX)='',
    @AddedBy INT=NULL, @NewTxnRecordId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @TenantId INT=0, @CampId INT=0, @Amount DECIMAL(18,2)=0;
    DECLARE @TenantName NVARCHAR(MAX)='', @CampName NVARCHAR(MAX)='';
    SELECT @TenantId=c.TenantId,
           @CampId=ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId=ci.ContractId ORDER BY cc.Id),0),
           @Amount=ci.Amount
    FROM ContractInstallments ci JOIN Contracts c ON c.ContractId=ci.ContractId
    WHERE ci.ContractId=@ContractId AND ci.InstallmentNo=@InstallmentNo AND ISNULL(ci.IsDeleted,0)=0;
    SELECT @TenantName=ISNULL(Name,'') FROM Tenants WHERE Id=@TenantId AND IsDeleted=0;
    SELECT @CampName=ISNULL(Name,'') FROM Camps WHERE Id=@CampId AND IsDeleted=0;
    UPDATE ContractInstallments
    SET PaidAmount=ISNULL(PaidAmount,0)+@PaidAmount,PaidDate=@PaidDate,
        PaymentMode=ISNULL(@PaymentMode,''),PaymentModeId=@PaymentModeId,
        ChequeNumber=ISNULL(@ChequeNumber,''),ClearanceDate=ISNULL(@ClearanceDate,''),
        Description=ISNULL(@Description,''),ReceivedBy=ISNULL(@ReceivedBy,''),
        ReceivedContact=ISNULL(@ReceivedContact,''),
        FundPoolId=@FundPoolId,FundPoolName=ISNULL(@FundPoolName,''),IssuedBy=ISNULL(@IssuedBy,''),
        AddedBy=ISNULL(AddedBy,@AddedBy),
        Status=CASE WHEN ISNULL(PaidAmount,0)+@PaidAmount>=Amount THEN 'Paid'
                    WHEN ISNULL(PaidAmount,0)+@PaidAmount>0 THEN 'Partial' ELSE 'Pending' END
    WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo AND ISNULL(IsDeleted,0)=0;
    DECLARE @TxnId NVARCHAR(50)=CONCAT('TXN-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),5));
    INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,TotalAmount,Amount,
        TxnDate,PaymentMode,PaymentModeId,ChequeNumber,FundPoolId,FundPoolName,Description,
        ReceivedBy,ReceivedContact,IssuedBy,InstallmentNo,AppliedInstallments,Unallocated,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@TxnId,'CR',@ContractId,@ContractId,ISNULL(@TenantId,0),ISNULL(@CampId,0),
        ISNULL(@Amount,0),@PaidAmount,ISNULL(@PaidDate,GETUTCDATE()),
        ISNULL(@PaymentMode,''),@PaymentModeId,ISNULL(@ChequeNumber,''),
        @FundPoolId,ISNULL(@FundPoolName,''),ISNULL(@Description,''),
        ISNULL(@ReceivedBy,''),ISNULL(@ReceivedContact,''),ISNULL(@IssuedBy,''),
        @InstallmentNo,'',0,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewTxnRecordId=SCOPE_IDENTITY();
    IF @FundPoolId IS NOT NULL AND @PaidAmount>0
        UPDATE FundPools SET Balance=Balance+@PaidAmount,UpdatedAt=GETUTCDATE()
        WHERE Id=@FundPoolId AND IsDeleted=0;
    IF @FundPoolId IS NOT NULL
    BEGIN
        DECLARE @FPCode NVARCHAR(MAX)='';
        SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId;
        DECLARE @IncId NVARCHAR(50)=CONCAT('INC-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),5));
        INSERT INTO Incomes(IncomeId,[Date],Mode,Head,FundPool,FundPoolName,Amount,
            Purpose,Source,SourceRef,CampName,PartnerName,TenantName,
            CreatedAt,UpdatedAt,CampId,ContractId,ContractCode,AddedBy,IsDeleted)
        VALUES(@IncId,CAST(ISNULL(@PaidDate,GETUTCDATE()) AS DATE),
            ISNULL(@PaymentMode,'Cash'),'Rent',
            ISNULL(@FPCode,''),ISNULL(@FundPoolName,''),@PaidAmount,
            'Rent Payment','Room Payment',@ContractId,
            ISNULL(@CampName,''),'',ISNULL(@TenantName,''),
            GETUTCDATE(),GETUTCDATE(),ISNULL(@CampId,0),
            @ContractId,@ContractId,@AddedBy,0);
    END
END
GO
PRINT 'FIX 4: sp_RecordPayment DONE';
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 5: Verify all SPs have QUOTED_IDENTIFIER=ON
-- ══════════════════════════════════════════════════════════════════
SELECT COUNT(*) AS SPsWithQIOff FROM sys.sql_modules sm
JOIN sys.objects o ON o.object_id=sm.object_id
WHERE o.type='P' AND sm.uses_quoted_identifier=0;
GO

-- ══════════════════════════════════════════════════════════════════
-- FIX 6: Verify AddedBy in all audit tables
-- ══════════════════════════════════════════════════════════════════
SELECT TABLE_NAME,
  CASE WHEN MAX(CASE WHEN COLUMN_NAME='AddedBy' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END AddedBy,
  CASE WHEN MAX(CASE WHEN COLUMN_NAME='UpdatedBy' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END UpdatedBy,
  CASE WHEN MAX(CASE WHEN COLUMN_NAME='DeletedBy' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END DeletedBy,
  CASE WHEN MAX(CASE WHEN COLUMN_NAME='IsDeleted' THEN 1 ELSE 0 END)=1 THEN 'PASS' ELSE 'FAIL' END IsDeleted
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN('AccountsHeads','AppUsers','Camps','CompanyAssets','ContractCancellations',
  'ContractInstallments','ContractRenewals','ContractRoomInstallments','ContractRooms',
  'Contracts','Designations','Expenses','Floors','FundPools','Incomes','OtherPersons',
  'OwnerContracts','Owners','Partners','PaymentModes','Roles','RoomStatuses',
  'Rooms','Staff','Tenants','TxnRecords','Waivers')
  AND COLUMN_NAME IN('AddedBy','UpdatedBy','DeletedBy','IsDeleted')
GROUP BY TABLE_NAME ORDER BY TABLE_NAME;
GO
PRINT '089 - All fixes DONE';
GO
