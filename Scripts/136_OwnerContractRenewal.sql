-- ============================================================
-- 136: Owner Contract Renewal
--      + OwnerContractRenewals table
--      + sp_RenewOwnerContract
--      + sp_GetOwnerContractRenewals
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: OwnerContractRenewals table create karo ──────────
IF OBJECT_ID('OwnerContractRenewals', 'U') IS NULL
BEGIN
    CREATE TABLE OwnerContractRenewals (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,
        RenewalCode             NVARCHAR(50)   NOT NULL DEFAULT '',
        OriginalOwnerContractId INT            NOT NULL,
        OriginalOcCode          NVARCHAR(50)   NOT NULL DEFAULT '',
        NewOwnerContractId      INT            NOT NULL,
        NewOcCode               NVARCHAR(50)   NOT NULL DEFAULT '',
        CampId                  INT            NOT NULL,
        CampName                NVARCHAR(MAX)  NOT NULL DEFAULT '',
        OwnerId                 INT            NOT NULL,
        OwnerName               NVARCHAR(MAX)  NOT NULL DEFAULT '',
        TotalAmount             DECIMAL(18,2)  NOT NULL DEFAULT 0,
        MonthlyRent             DECIMAL(18,2)  NOT NULL DEFAULT 0,
        StartDate               DATE           NOT NULL,
        EndDate                 DATE           NULL,
        ContractDate            NVARCHAR(MAX)  NULL,
        ExpireOldContract       BIT            NOT NULL DEFAULT 1,
        Notes                   NVARCHAR(MAX)  NULL,
        Status                  NVARCHAR(50)   NOT NULL DEFAULT 'Active',
        AddedBy                 INT            NULL,
        IsDeleted               BIT            NOT NULL DEFAULT 0,
        CreatedAt               DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt               DATETIME2      NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '✅ OwnerContractRenewals table created';
END
ELSE
    PRINT '⚠️ OwnerContractRenewals already exists';
GO

-- ── Step 2: sp_RenewOwnerContract ────────────────────────────
CREATE OR ALTER PROCEDURE sp_RenewOwnerContract
    @OriginalOwnerContractId INT,
    @StartDate               NVARCHAR(MAX),
    @EndDate                 NVARCHAR(MAX)  = NULL,
    @ContractDate            NVARCHAR(MAX)  = NULL,
    @TotalAmount             DECIMAL(18,2),
    @MonthlyRent             DECIMAL(18,2)  = 0,
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

    -- 1. Original contract check
    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@OriginalOwnerContractId AND ISNULL(IsDeleted,0)=0)
    BEGIN
        RAISERROR('Original owner contract not found.', 16, 1);
        RETURN;
    END

    -- 2. Original contract info fetch karo
    DECLARE @CampId    INT, @OwnerId   INT,
            @CampName  NVARCHAR(MAX), @OwnerName NVARCHAR(MAX),
            @OwnerCode NVARCHAR(MAX), @OriginalOcCode NVARCHAR(50);

    SELECT @CampId=CampId, @OwnerId=OwnerId, @CampName=CampName,
           @OwnerName=OwnerName, @OwnerCode=OwnerCode, @OriginalOcCode=OcCode
    FROM OwnerContracts WHERE Id=@OriginalOwnerContractId;

    -- 3. New OcCode generate karo
    DECLARE @NewOcCode NVARCHAR(50) = CONCAT('OC-', RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR),5));

    -- 4. New OwnerContract insert
    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, EndDate,
        SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate,
        ContractDate, MonthlyRent,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @NewOcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @ContractDate, @MonthlyRent,
        'Active', @AddedBy, 0, GETUTCDATE(), GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();

    -- 5. Installments insert
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

    -- 6. MonthlyInstallments insert
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

    -- 7. DR Transaction for new contract
    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(
        TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
        Type, Amount, Date, Description, InstallmentNos, ReferenceNo, PaymentMode, CreatedAt)
    VALUES(
        @TxnCode, @NewId, @NewOcCode, @CampId, @CampName, @OwnerId, @OwnerName,
        'DR', @TotalAmount, GETUTCDATE(),
        CONCAT('Contract Renewed from ', @OriginalOcCode, ' - Total: ', @TotalAmount),
        '', '', '', GETUTCDATE());

    -- 8. Purana contract Expire karo (agar ExpireOldContract = 1)
    IF @ExpireOldContract = 1
        UPDATE OwnerContracts
        SET Status='Expired', UpdatedAt=GETUTCDATE()
        WHERE Id=@OriginalOwnerContractId;

    -- 9. Renewal record save karo
    DECLARE @RenewalCode NVARCHAR(50) = CONCAT('OCR-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContractRenewals) AS NVARCHAR),5));
    INSERT INTO OwnerContractRenewals(
        RenewalCode, OriginalOwnerContractId, OriginalOcCode,
        NewOwnerContractId, NewOcCode,
        CampId, CampName, OwnerId, OwnerName,
        TotalAmount, MonthlyRent,
        StartDate, EndDate, ContractDate,
        ExpireOldContract, Notes,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @RenewalCode, @OriginalOwnerContractId, @OriginalOcCode,
        @NewId, @NewOcCode,
        @CampId, @CampName, @OwnerId, @OwnerName,
        @TotalAmount, @MonthlyRent,
        CAST(@StartDate AS DATE),
        CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        @ContractDate,
        @ExpireOldContract, @Notes,
        'Active', @AddedBy, 0, GETUTCDATE(), GETUTCDATE());

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_RenewOwnerContract created';
GO

-- ── Step 3: sp_GetOwnerContractRenewals ──────────────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerContractRenewals
    @OriginalOwnerContractId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.Id, r.RenewalCode,
        r.OriginalOwnerContractId, r.OriginalOcCode,
        r.NewOwnerContractId,      r.NewOcCode,
        r.CampId,    r.CampName,
        r.OwnerId,   r.OwnerName,
        r.TotalAmount, r.MonthlyRent,
        r.StartDate, r.EndDate, r.ContractDate,
        r.ExpireOldContract, r.Notes,
        r.Status, r.CreatedAt, r.UpdatedAt
    FROM OwnerContractRenewals r
    WHERE r.IsDeleted = 0
      AND (@OriginalOwnerContractId IS NULL OR r.OriginalOwnerContractId = @OriginalOwnerContractId)
    ORDER BY r.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOwnerContractRenewals created';
GO

PRINT '';
PRINT '✅✅ 136 - Owner Contract Renewal complete!';
GO
