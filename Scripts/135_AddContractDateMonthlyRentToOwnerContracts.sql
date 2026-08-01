-- ============================================================
-- 135: Add ContractDate + MonthlyRent to OwnerContracts table
--      + Update sp_CreateOwnerContract + sp_GetOwnerContracts
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: Columns add karo ──────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='ContractDate')
    ALTER TABLE OwnerContracts ADD ContractDate NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('OwnerContracts') AND name='MonthlyRent')
    ALTER TABLE OwnerContracts ADD MonthlyRent DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
PRINT '✅ OwnerContracts: ContractDate + MonthlyRent columns added';
GO

-- ── Step 2: sp_CreateOwnerContract — new params add karo ──────
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
    SELECT @CampName=ISNULL(Name,'')                              FROM Camps  WHERE Id=@CampId;

    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount,
        StartDate, EndDate,
        SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate,
        ContractDate, MonthlyRent,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @OcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @ContractDate, @MonthlyRent,
        @Status, @AddedBy, 0, GETUTCDATE(), GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();

    -- Installments — PaymentMode, ReferenceNo, Month bhi save karo
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments(
            OwnerContractId, No, Amount, PaidAmount,
            DueDate, Status, PaymentMode, ReferenceNo, Month,
            AddedBy, IsDeleted)
        SELECT
            @NewId,
            ISNULL(j.NoPascal,  ISNULL(j.NoCamel,  0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0,
            CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE),
            'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal,       ISNULL(j.MonthCamel,       '')),
            @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal          INT           '$.No',
            NoCamel           INT           '$.no',
            AmtPascal         DECIMAL(18,2) '$.Amount',
            AmtCamel          DECIMAL(18,2) '$.amount',
            DuePascal         NVARCHAR(50)  '$.DueDate',
            DueCamel          NVARCHAR(50)  '$.dueDate',
            PaymentModePascal NVARCHAR(MAX) '$.PaymentMode',
            PaymentModeCamel  NVARCHAR(MAX) '$.paymentMode',
            ReferenceNoPascal NVARCHAR(MAX) '$.ReferenceNo',
            ReferenceNoCamel  NVARCHAR(MAX) '$.referenceNo',
            MonthPascal       NVARCHAR(MAX) '$.Month',
            MonthCamel        NVARCHAR(MAX) '$.month'
        ) j;

    -- MonthlyInstallments
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, ReferenceNo, Month,
            CreatedAt, UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @NewId, @OwnerId, @CampId,
            InstallmentNo, Amount, ISNULL(PaidAmount,0), ISNULL(Balance,Amount),
            DueDate,
            CASE WHEN ISNULL(PaidDate,'')='' THEN NULL ELSE TRY_CAST(PaidDate AS DATE) END,
            ISNULL(NULLIF(Status,''),'Pending'), NULL,
            ISNULL(PaymentMode,''), ISNULL(NULLIF(PaymentStatus,''),'Pending'),
            ISNULL(ReferenceNo,''), ISNULL(Month,''),
            GETUTCDATE(), GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH(
            InstallmentNo INT           '$.InstallmentNo',
            Amount        DECIMAL(18,2) '$.Amount',
            PaidAmount    DECIMAL(18,2) '$.PaidAmount',
            Balance       DECIMAL(18,2) '$.Balance',
            DueDate       DATE          '$.DueDate',
            PaidDate      NVARCHAR(50)  '$.PaidDate',
            Status        NVARCHAR(MAX) '$.Status',
            PaymentMode   NVARCHAR(MAX) '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX) '$.PaymentStatus',
            ReferenceNo   NVARCHAR(MAX) '$.ReferenceNo',
            Month         NVARCHAR(MAX) '$.Month');
    END

    -- DR Transaction
    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(
        TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
        Type, Amount, Date, Description, InstallmentNos, ReferenceNo, PaymentMode, CreatedAt)
    VALUES(
        @TxnCode, @NewId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
        'DR', @TotalAmount, GETUTCDATE(),
        CONCAT('Contract Created - Total: ', @TotalAmount), '', '', '', GETUTCDATE());

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_CreateOwnerContract updated with ContractDate + MonthlyRent';
GO

-- ── Step 3: sp_GetOwnerContracts — new fields select karo ─────
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT = NULL,
    @CampId  INT = NULL,
    @Status  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        oc.Id,
        oc.OcCode,
        oc.CampId,
        ISNULL(c.Name, oc.CampName)  AS CampName,
        oc.OwnerId,
        ISNULL(o.Name, oc.OwnerName) AS OwnerName,
        ISNULL(o.Code, oc.OwnerCode) AS OwnerCode,
        oc.PaymentType,
        oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0))
                FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS Balance,
        oc.StartDate,
        oc.EndDate,
        ISNULL(oc.SecurityDeposit,     0) AS SecurityDeposit,
        ISNULL(oc.SecurityDepositPaid, 0) AS SecurityDepositPaid,
        oc.SecurityDepositPaidDate,
        oc.ContractDate,
        ISNULL(oc.MonthlyRent, 0)         AS MonthlyRent,
        oc.Status,
        oc.CreatedAt,
        oc.UpdatedAt,
        oc.AddedBy,
        oc.UpdatedBy,
        oc.IsDeleted
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId AND o.IsDeleted = 0
    LEFT JOIN Camps  c ON c.Id = oc.CampId  AND c.IsDeleted = 0
    WHERE oc.IsDeleted = 0
      AND (@OwnerId IS NULL OR oc.OwnerId = @OwnerId)
      AND (@CampId  IS NULL OR oc.CampId  = @CampId)
      AND (@Status  IS NULL OR oc.Status  = @Status)
    ORDER BY oc.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOwnerContracts updated with ContractDate + MonthlyRent';
GO

PRINT '';
PRINT '✅✅ 135 - ContractDate + MonthlyRent added to OwnerContracts everywhere';
GO
