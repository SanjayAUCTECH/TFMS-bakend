-- ============================================================
-- 131: Add new columns to Owner-related tables
--
-- OwnerContracts:
--   + EndDate, SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate
-- OwnerInstallments:
--   + PaymentMode, ReferenceNo, Remarks, Month
-- OwnerMonthlyContractInstallments:
--   + ReferenceNo, Month
-- OwnerTransactions:
--   + ReferenceNo, PaymentMode
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. OwnerContracts ─────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='EndDate')
    ALTER TABLE OwnerContracts ADD EndDate DATE NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='SecurityDeposit')
    ALTER TABLE OwnerContracts ADD SecurityDeposit DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='SecurityDepositPaid')
    ALTER TABLE OwnerContracts ADD SecurityDepositPaid DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='SecurityDepositPaidDate')
    ALTER TABLE OwnerContracts ADD SecurityDepositPaidDate DATE NULL;
GO
PRINT '✅ OwnerContracts: 4 columns added';
GO

-- ── 2. OwnerInstallments ──────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerInstallments') AND name='PaymentMode')
    ALTER TABLE OwnerInstallments ADD PaymentMode NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerInstallments') AND name='ReferenceNo')
    ALTER TABLE OwnerInstallments ADD ReferenceNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerInstallments') AND name='Remarks')
    ALTER TABLE OwnerInstallments ADD Remarks NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerInstallments') AND name='Month')
    ALTER TABLE OwnerInstallments ADD Month NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
PRINT '✅ OwnerInstallments: 4 columns added';
GO

-- ── 3. OwnerMonthlyContractInstallments ───────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerMonthlyContractInstallments') AND name='ReferenceNo')
    ALTER TABLE OwnerMonthlyContractInstallments ADD ReferenceNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerMonthlyContractInstallments') AND name='Month')
    ALTER TABLE OwnerMonthlyContractInstallments ADD Month NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
PRINT '✅ OwnerMonthlyContractInstallments: 2 columns added';
GO

-- ── 4. OwnerTransactions ──────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerTransactions') AND name='ReferenceNo')
    ALTER TABLE OwnerTransactions ADD ReferenceNo NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerTransactions') AND name='PaymentMode')
    ALTER TABLE OwnerTransactions ADD PaymentMode NVARCHAR(MAX) NOT NULL DEFAULT '';
GO
PRINT '✅ OwnerTransactions: 2 columns added';
GO

-- ── 5. sp_CreateOwnerContract — add new params ────────────────
CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId                  INT,
    @OwnerId                 INT,
    @PaymentType             NVARCHAR(MAX) = 'Monthly',
    @TotalAmount             DECIMAL(18,2),
    @StartDate               NVARCHAR(MAX),
    @EndDate                 NVARCHAR(MAX) = NULL,
    @SecurityDeposit         DECIMAL(18,2) = 0,
    @SecurityDepositPaid     DECIMAL(18,2) = 0,
    @SecurityDepositPaidDate NVARCHAR(MAX) = NULL,
    @Status                  NVARCHAR(MAX) = 'Active',
    @InstallmentsJson        NVARCHAR(MAX) = '[]',
    @MonthlyInstallmentsJson NVARCHAR(MAX) = '[]',
    @AddedBy                 INT           = NULL,
    @NewId                   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @OcCode NVARCHAR(50) = CONCAT('OC-', RIGHT('00000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR), 5));
    DECLARE @OwnerCode NVARCHAR(MAX)='', @OwnerName NVARCHAR(MAX)='', @CampName NVARCHAR(MAX)='';
    SELECT @OwnerCode=ISNULL(Code,''), @OwnerName=ISNULL(Name,'') FROM Owners WHERE Id=@OwnerId;
    SELECT @CampName=ISNULL(Name,'') FROM Camps WHERE Id=@CampId;

    INSERT INTO OwnerContracts(OcCode,CampId,CampName,OwnerId,OwnerName,OwnerCode,PaymentType,TotalAmount,
        StartDate,EndDate,SecurityDeposit,SecurityDepositPaid,SecurityDepositPaidDate,
        Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,@OwnerCode,@PaymentType,@TotalAmount,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();

    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson)>2
        INSERT INTO OwnerInstallments(OwnerContractId,No,Amount,PaidAmount,DueDate,Status,AddedBy,IsDeleted)
        SELECT @NewId,
            ISNULL(CAST(j.NoPascal AS INT), ISNULL(CAST(j.NoCamel AS INT),0)),
            ISNULL(CAST(j.AmtPascal AS DECIMAL(18,2)), ISNULL(CAST(j.AmtCamel AS DECIMAL(18,2)),0)),
            0, CAST(ISNULL(j.DuePascal,j.DueCamel) AS DATE), 'Pending', @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal  INT '$.No', NoCamel INT '$.no',
            AmtPascal DECIMAL(18,2) '$.Amount', AmtCamel DECIMAL(18,2) '$.amount',
            DuePascal NVARCHAR(50) '$.DueDate', DueCamel NVARCHAR(50) '$.dueDate') j;

    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson)>2
    BEGIN
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments),0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId,OwnerContractId,OwnerId,CampId,
            InstallmentNo,Amount,PaidAmount,Balance,DueDate,PaidDate,
            Status,ExpenseId,PaymentMode,PaymentStatus,ReferenceNo,Month,CreatedAt,UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @NewId,@OwnerId,@CampId,InstallmentNo,Amount,ISNULL(PaidAmount,0),
            ISNULL(Balance,Amount),DueDate,
            CASE WHEN ISNULL(PaidDate,'')='' THEN NULL ELSE TRY_CAST(PaidDate AS DATE) END,
            ISNULL(NULLIF(Status,''),'Pending'),NULL,
            ISNULL(PaymentMode,''),ISNULL(NULLIF(PaymentStatus,''),'Pending'),
            ISNULL(ReferenceNo,''),ISNULL(Month,''),
            GETUTCDATE(),GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH(
            InstallmentNo INT '$.InstallmentNo', Amount DECIMAL(18,2) '$.Amount',
            PaidAmount DECIMAL(18,2) '$.PaidAmount', Balance DECIMAL(18,2) '$.Balance',
            DueDate DATE '$.DueDate', PaidDate NVARCHAR(50) '$.PaidDate',
            Status NVARCHAR(MAX) '$.Status', PaymentMode NVARCHAR(MAX) '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX) '$.PaymentStatus',
            ReferenceNo NVARCHAR(MAX) '$.ReferenceNo', Month NVARCHAR(MAX) '$.Month');
    END

    DECLARE @TxnCode NVARCHAR(50)=CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,InstallmentNos,ReferenceNo,PaymentMode,CreatedAt)
    VALUES(@TxnCode,@NewId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,'DR',@TotalAmount,GETUTCDATE(),
        CONCAT('Contract Created - Total: ',@TotalAmount),'','','',GETUTCDATE());

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 6. sp_GetOwnerContracts — include new fields ──────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT oc.Id, oc.OcCode, oc.CampId, ISNULL(c.Name,oc.CampName) AS CampName,
        oc.OwnerId, ISNULL(o.Name,oc.OwnerName) AS OwnerName, ISNULL(o.Code,oc.OwnerCode) AS OwnerCode,
        oc.PaymentType, oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0),0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0),0) AS Balance,
        oc.StartDate, oc.EndDate,
        oc.SecurityDeposit, oc.SecurityDepositPaid, oc.SecurityDepositPaidDate,
        oc.Status, oc.CreatedAt, oc.UpdatedAt, oc.AddedBy, oc.UpdatedBy, oc.IsDeleted
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId AND o.IsDeleted=0
    LEFT JOIN Camps  c ON c.Id=oc.CampId  AND c.IsDeleted=0
    WHERE oc.IsDeleted=0
      AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
      AND (@CampId  IS NULL OR oc.CampId =@CampId)
      AND (@Status  IS NULL OR oc.Status =@Status)
    ORDER BY oc.CreatedAt DESC;
END
GO

-- ── 7. sp_GetOwnerInstallments — include new fields ───────────
CREATE OR ALTER PROCEDURE sp_GetOwnerInstallments
    @OcId        INT,
    @PageNumber  INT           = 1,
    @PageSize    INT           = 500,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OwnerInstallments
    WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (@Status IS NULL OR Status=@Status);

    SELECT Id, OwnerContractId, No AS InstallmentNo,
        Amount, ISNULL(PaidAmount,0) AS PaidAmount, Amount-ISNULL(PaidAmount,0) AS Balance,
        DueDate, PaidDate, ISNULL(Status,'Pending') AS Status, ExpenseId,
        ISNULL(PaymentMode,'') AS PaymentMode,
        ISNULL(ReferenceNo,'') AS ReferenceNo,
        ISNULL(Remarks,'') AS Remarks,
        ISNULL(Month,'') AS Month
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId AND ISNULL(IsDeleted,0)=0 AND (@Status IS NULL OR Status=@Status)
    ORDER BY No
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── 8. sp_GetOwnerTransactions — include new fields ───────────
CREATE OR ALTER PROCEDURE sp_GetOwnerTransactions
    @OwnerId         INT = NULL,
    @CampId          INT = NULL,
    @OwnerContractId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
        Type, Amount, Date, Description, InstallmentNos, ExpenseId,
        ISNULL(ReferenceNo,'') AS ReferenceNo,
        ISNULL(PaymentMode,'') AS PaymentMode,
        CreatedAt
    FROM OwnerTransactions
    WHERE ISNULL(IsDeleted,0)=0
      AND (@OwnerId IS NULL OR OwnerId=@OwnerId)
      AND (@CampId  IS NULL OR CampId=@CampId)
      AND (@OwnerContractId IS NULL OR OwnerContractId=@OwnerContractId)
    ORDER BY Id DESC;
END
GO

PRINT '✅ 131 - All OwnerContract related new columns + SPs updated';
GO
