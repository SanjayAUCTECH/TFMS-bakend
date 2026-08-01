-- ============================================================
-- 137: Add NoOfMonths column to OwnerContracts +
--      OwnerContractRenewals + update all related SPs
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: OwnerContracts — NoOfMonths column add karo ──────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='ContractDate')
    ALTER TABLE OwnerContracts ADD ContractDate NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='MonthlyRent')
    ALTER TABLE OwnerContracts ADD MonthlyRent DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='NoOfMonths')
    ALTER TABLE OwnerContracts ADD NoOfMonths INT NOT NULL DEFAULT 0;
GO
PRINT '✅ OwnerContracts: ContractDate + MonthlyRent + NoOfMonths columns added';
GO

-- ── Step 2: OwnerContractRenewals — missing columns add karo ─
IF OBJECT_ID('OwnerContractRenewals','U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContractRenewals') AND name='ContractDate')
        ALTER TABLE OwnerContractRenewals ADD ContractDate NVARCHAR(MAX) NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContractRenewals') AND name='MonthlyRent')
        ALTER TABLE OwnerContractRenewals ADD MonthlyRent DECIMAL(18,2) NOT NULL DEFAULT 0;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContractRenewals') AND name='NoOfMonths')
        ALTER TABLE OwnerContractRenewals ADD NoOfMonths INT NOT NULL DEFAULT 0;
    PRINT '✅ OwnerContractRenewals: ContractDate + MonthlyRent + NoOfMonths columns added';
END
GO

-- ── Step 3: sp_CreateOwnerContract — @NoOfMonths param add ───
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
    @ContractDate            NVARCHAR(MAX) = NULL,
    @MonthlyRent             DECIMAL(18,2) = 0,
    @NoOfMonths              INT           = 0,
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

    DECLARE @OcCode NVARCHAR(50) = CONCAT('OC-', RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR),5));
    DECLARE @OwnerCode NVARCHAR(MAX)='', @OwnerName NVARCHAR(MAX)='', @CampName NVARCHAR(MAX)='';
    SELECT @OwnerCode=ISNULL(Code,''), @OwnerName=ISNULL(Name,'') FROM Owners WHERE Id=@OwnerId;
    SELECT @CampName=ISNULL(Name,'')                              FROM Camps  WHERE Id=@CampId;

    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, EndDate,
        SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate,
        ContractDate, MonthlyRent, NoOfMonths,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @OcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @ContractDate, @MonthlyRent, @NoOfMonths,
        @Status, @AddedBy, 0, GETUTCDATE(), GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();

    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments(
            OwnerContractId, No, Amount, PaidAmount,
            DueDate, Status, PaymentMode, ReferenceNo, Month, AddedBy, IsDeleted)
        SELECT @NewId,
            ISNULL(j.NoPascal,  ISNULL(j.NoCamel,  0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0, CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE), 'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal,       ISNULL(j.MonthCamel,       '')),
            @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal          INT           '$.No',           NoCamel           INT           '$.no',
            AmtPascal         DECIMAL(18,2) '$.Amount',       AmtCamel          DECIMAL(18,2) '$.amount',
            DuePascal         NVARCHAR(50)  '$.DueDate',      DueCamel          NVARCHAR(50)  '$.dueDate',
            PaymentModePascal NVARCHAR(MAX) '$.PaymentMode',  PaymentModeCamel  NVARCHAR(MAX) '$.paymentMode',
            ReferenceNoPascal NVARCHAR(MAX) '$.ReferenceNo',  ReferenceNoCamel  NVARCHAR(MAX) '$.referenceNo',
            MonthPascal       NVARCHAR(MAX) '$.Month',        MonthCamel        NVARCHAR(MAX) '$.month') j;

    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, ReferenceNo, Month, CreatedAt, UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @NewId, @OwnerId, @CampId,
            InstallmentNo, Amount, ISNULL(PaidAmount,0), ISNULL(Balance,Amount), DueDate,
            CASE WHEN ISNULL(PaidDate,'')='' THEN NULL ELSE TRY_CAST(PaidDate AS DATE) END,
            ISNULL(NULLIF(Status,''),'Pending'), NULL,
            ISNULL(PaymentMode,''), ISNULL(NULLIF(PaymentStatus,''),'Pending'),
            ISNULL(ReferenceNo,''), ISNULL(Month,''), GETUTCDATE(), GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH(
            InstallmentNo INT '$.InstallmentNo', Amount DECIMAL(18,2) '$.Amount',
            PaidAmount DECIMAL(18,2) '$.PaidAmount', Balance DECIMAL(18,2) '$.Balance',
            DueDate DATE '$.DueDate', PaidDate NVARCHAR(50) '$.PaidDate',
            Status NVARCHAR(MAX) '$.Status', PaymentMode NVARCHAR(MAX) '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX) '$.PaymentStatus',
            ReferenceNo NVARCHAR(MAX) '$.ReferenceNo', Month NVARCHAR(MAX) '$.Month');
    END

    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,InstallmentNos,ReferenceNo,PaymentMode,CreatedAt)
    VALUES(@TxnCode,@NewId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,'DR',@TotalAmount,GETUTCDATE(),
        CONCAT('Contract Created - Total: ',@TotalAmount),'','','',GETUTCDATE());

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_CreateOwnerContract updated with NoOfMonths';
GO

-- ── Step 4: sp_GetOwnerContracts — NoOfMonths select karo ────
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT = NULL, @CampId INT = NULL, @Status NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        oc.Id, oc.OcCode,
        oc.CampId,  ISNULL(c.Name, oc.CampName)  AS CampName,
        oc.OwnerId, ISNULL(o.Name, oc.OwnerName) AS OwnerName,
        ISNULL(o.Code, oc.OwnerCode) AS OwnerCode,
        oc.PaymentType, oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS Balance,
        oc.StartDate, oc.EndDate,
        ISNULL(oc.SecurityDeposit,     0) AS SecurityDeposit,
        ISNULL(oc.SecurityDepositPaid, 0) AS SecurityDepositPaid,
        oc.SecurityDepositPaidDate,
        oc.ContractDate,
        ISNULL(oc.MonthlyRent, 0) AS MonthlyRent,
        ISNULL(oc.NoOfMonths,  0) AS NoOfMonths,
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
PRINT '✅ sp_GetOwnerContracts updated with NoOfMonths';
GO

-- ── Step 5: sp_RenewOwnerContract — @NoOfMonths param add ────
CREATE OR ALTER PROCEDURE sp_RenewOwnerContract
    @OriginalOwnerContractId INT,
    @StartDate               NVARCHAR(MAX),
    @EndDate                 NVARCHAR(MAX)  = NULL,
    @ContractDate            NVARCHAR(MAX)  = NULL,
    @TotalAmount             DECIMAL(18,2),
    @MonthlyRent             DECIMAL(18,2)  = 0,
    @NoOfMonths              INT            = 0,
    @PaymentType             NVARCHAR(MAX)  = 'monthly',
    @SecurityDeposit         DECIMAL(18,2)  = 0,
    @SecurityDepositPaid     DECIMAL(18,2)  = 0,
    @SecurityDepositPaidDate NVARCHAR(MAX)  = NULL,
    @ExpireOldContract       BIT            = 1,
    @Notes                   NVARCHAR(MAX)  = NULL,
    @InstallmentsJson        NVARCHAR(MAX)  = '[]',
    @MonthlyInstallmentsJson NVARCHAR(MAX)  = '[]',
    @AddedBy                 INT            = NULL,
    @NewId                   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@OriginalOwnerContractId AND ISNULL(IsDeleted,0)=0)
    BEGIN RAISERROR('Original owner contract not found.', 16, 1); RETURN; END

    DECLARE @CampId INT, @OwnerId INT, @CampName NVARCHAR(MAX), @OwnerName NVARCHAR(MAX),
            @OwnerCode NVARCHAR(MAX), @OriginalOcCode NVARCHAR(50);
    SELECT @CampId=CampId, @OwnerId=OwnerId, @CampName=CampName,
           @OwnerName=OwnerName, @OwnerCode=OwnerCode, @OriginalOcCode=OcCode
    FROM OwnerContracts WHERE Id=@OriginalOwnerContractId;

    DECLARE @NewOcCode NVARCHAR(50) = CONCAT('OC-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR),5));

    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, EndDate,
        SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate,
        ContractDate, MonthlyRent, NoOfMonths,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @NewOcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @ContractDate, @MonthlyRent, @NoOfMonths,
        'Active', @AddedBy, 0, GETUTCDATE(), GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();

    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments(
            OwnerContractId, No, Amount, PaidAmount,
            DueDate, Status, PaymentMode, ReferenceNo, Month, AddedBy, IsDeleted)
        SELECT @NewId,
            ISNULL(j.NoPascal,  ISNULL(j.NoCamel,  0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0, CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE), 'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal,       ISNULL(j.MonthCamel,       '')),
            @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal          INT           '$.No',           NoCamel           INT           '$.no',
            AmtPascal         DECIMAL(18,2) '$.Amount',       AmtCamel          DECIMAL(18,2) '$.amount',
            DuePascal         NVARCHAR(50)  '$.DueDate',      DueCamel          NVARCHAR(50)  '$.dueDate',
            PaymentModePascal NVARCHAR(MAX) '$.PaymentMode',  PaymentModeCamel  NVARCHAR(MAX) '$.paymentMode',
            ReferenceNoPascal NVARCHAR(MAX) '$.ReferenceNo',  ReferenceNoCamel  NVARCHAR(MAX) '$.referenceNo',
            MonthPascal       NVARCHAR(MAX) '$.Month',        MonthCamel        NVARCHAR(MAX) '$.month') j;

    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, ReferenceNo, Month, CreatedAt, UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @NewId, @OwnerId, @CampId,
            InstallmentNo, Amount, ISNULL(PaidAmount,0), ISNULL(Balance,Amount), DueDate,
            CASE WHEN ISNULL(PaidDate,'')='' THEN NULL ELSE TRY_CAST(PaidDate AS DATE) END,
            ISNULL(NULLIF(Status,''),'Pending'), NULL,
            ISNULL(PaymentMode,''), ISNULL(NULLIF(PaymentStatus,''),'Pending'),
            ISNULL(ReferenceNo,''), ISNULL(Month,''), GETUTCDATE(), GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH(
            InstallmentNo INT '$.InstallmentNo', Amount DECIMAL(18,2) '$.Amount',
            PaidAmount DECIMAL(18,2) '$.PaidAmount', Balance DECIMAL(18,2) '$.Balance',
            DueDate DATE '$.DueDate', PaidDate NVARCHAR(50) '$.PaidDate',
            Status NVARCHAR(MAX) '$.Status', PaymentMode NVARCHAR(MAX) '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX) '$.PaymentStatus',
            ReferenceNo NVARCHAR(MAX) '$.ReferenceNo', Month NVARCHAR(MAX) '$.Month');
    END

    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,InstallmentNos,ReferenceNo,PaymentMode,CreatedAt)
    VALUES(@TxnCode,@NewId,@NewOcCode,@CampId,@CampName,@OwnerId,@OwnerName,'DR',@TotalAmount,GETUTCDATE(),
        CONCAT('Contract Renewed from ',@OriginalOcCode,' - Total: ',@TotalAmount),'','','',GETUTCDATE());

    IF @ExpireOldContract = 1
        UPDATE OwnerContracts SET Status='Expired', UpdatedAt=GETUTCDATE() WHERE Id=@OriginalOwnerContractId;

    DECLARE @RenewalCode NVARCHAR(50) = CONCAT('OCR-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContractRenewals) AS NVARCHAR),5));
    INSERT INTO OwnerContractRenewals(
        RenewalCode, OriginalOwnerContractId, OriginalOcCode,
        NewOwnerContractId, NewOcCode, CampId, CampName, OwnerId, OwnerName,
        TotalAmount, MonthlyRent, NoOfMonths,
        StartDate, EndDate, ContractDate, ExpireOldContract, Notes,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @RenewalCode, @OriginalOwnerContractId, @OriginalOcCode,
        @NewId, @NewOcCode, @CampId, @CampName, @OwnerId, @OwnerName,
        @TotalAmount, @MonthlyRent, @NoOfMonths,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @ContractDate, @ExpireOldContract, @Notes,
        'Active', @AddedBy, 0, GETUTCDATE(), GETUTCDATE());

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_RenewOwnerContract updated with NoOfMonths';
GO

-- ── Step 6: sp_GetOwnerContractRenewals — NoOfMonths select ──
CREATE OR ALTER PROCEDURE sp_GetOwnerContractRenewals
    @OriginalOwnerContractId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.Id, r.RenewalCode,
        r.OriginalOwnerContractId, r.OriginalOcCode,
        r.NewOwnerContractId,      r.NewOcCode,
        r.CampId, r.CampName, r.OwnerId, r.OwnerName,
        r.TotalAmount, ISNULL(r.MonthlyRent,0) AS MonthlyRent,
        ISNULL(r.NoOfMonths,0) AS NoOfMonths,
        r.StartDate, r.EndDate, r.ContractDate,
        r.ExpireOldContract, r.Notes,
        r.Status, r.CreatedAt, r.UpdatedAt
    FROM OwnerContractRenewals r
    WHERE r.IsDeleted=0
      AND (@OriginalOwnerContractId IS NULL OR r.OriginalOwnerContractId=@OriginalOwnerContractId)
    ORDER BY r.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOwnerContractRenewals updated with NoOfMonths';
GO

PRINT '';
PRINT '✅✅ 137 - NoOfMonths added everywhere in OwnerContracts + Renewals';
GO
