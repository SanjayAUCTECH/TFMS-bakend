-- ============================================================
-- 144: Owner Contract create/update/renew hone pe
--      Camp.StartDate aur Camp.EndDate bhi update karo
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- Helper: SP jo camp dates sync kare (reusable)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_SyncCampDatesFromOwnerContract
    @CampId    INT,
    @StartDate DATE,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @CampId IS NOT NULL AND @StartDate IS NOT NULL
        UPDATE Camps SET
            StartDate = @StartDate,
            EndDate   = @EndDate,
            UpdatedAt = GETUTCDATE()
        WHERE Id = @CampId AND IsDeleted = 0;
END
GO
PRINT '✅ sp_SyncCampDatesFromOwnerContract helper created';
GO

-- ══════════════════════════════════════════════════════════════
-- sp_CreateOwnerContract — COMMIT se pehle camp dates sync
-- ══════════════════════════════════════════════════════════════
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

    DECLARE @StartDt DATE = CAST(@StartDate AS DATE);
    DECLARE @EndDt   DATE = CASE WHEN @EndDate IS NULL OR @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END;

    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, EndDate,
        SecurityDeposit, SecurityDepositPaid, SecurityDepositPaidDate,
        ContractDate, MonthlyRent, NoOfMonths,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @OcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount, @StartDt, @EndDt,
        @SecurityDeposit, @SecurityDepositPaid,
        CASE WHEN @SecurityDepositPaidDate IS NULL OR @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        @ContractDate, @MonthlyRent, @NoOfMonths,
        @Status, @AddedBy, 0, GETUTCDATE(), GETUTCDATE());
    SET @NewId = SCOPE_IDENTITY();

    -- Installments
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments(
            OwnerContractId, No, Amount, PaidAmount, DueDate, Status,
            PaymentMode, ReferenceNo, Month, AddedBy, IsDeleted)
        SELECT @NewId,
            ISNULL(j.NoPascal, ISNULL(j.NoCamel, 0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0, CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE), 'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal, ISNULL(j.MonthCamel, '')),
            @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal INT '$.No', NoCamel INT '$.no',
            AmtPascal DECIMAL(18,2) '$.Amount', AmtCamel DECIMAL(18,2) '$.amount',
            DuePascal NVARCHAR(50) '$.DueDate', DueCamel NVARCHAR(50) '$.dueDate',
            PaymentModePascal NVARCHAR(MAX) '$.PaymentMode', PaymentModeCamel NVARCHAR(MAX) '$.paymentMode',
            ReferenceNoPascal NVARCHAR(MAX) '$.ReferenceNo', ReferenceNoCamel NVARCHAR(MAX) '$.referenceNo',
            MonthPascal NVARCHAR(MAX) '$.Month', MonthCamel NVARCHAR(MAX) '$.month') j;

    -- MonthlyInstallments
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

    -- DR Transaction
    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),5));
    INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,InstallmentNos,ReferenceNo,PaymentMode,CreatedAt)
    VALUES(@TxnCode,@NewId,@OcCode,@CampId,@CampName,@OwnerId,@OwnerName,'DR',@TotalAmount,GETUTCDATE(),
        CONCAT('Contract Created - Total: ',@TotalAmount),'','','',GETUTCDATE());

    -- ✅ Camp dates sync — StartDate aur EndDate camp mein update karo
    EXEC sp_SyncCampDatesFromOwnerContract @CampId=@CampId, @StartDate=@StartDt, @EndDate=@EndDt;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_CreateOwnerContract — Camp dates sync added';
GO

-- ══════════════════════════════════════════════════════════════
-- sp_UpdateOwnerContract — update ke baad camp dates sync
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateOwnerContract
    @Id                      INT,
    @CampId                  INT           = NULL,
    @OwnerId                 INT           = NULL,
    @PaymentType             NVARCHAR(MAX) = NULL,
    @TotalAmount             DECIMAL(18,2) = NULL,
    @StartDate               NVARCHAR(MAX) = NULL,
    @EndDate                 NVARCHAR(MAX) = NULL,
    @ContractDate            NVARCHAR(MAX) = NULL,
    @MonthlyRent             DECIMAL(18,2) = NULL,
    @NoOfMonths              INT           = NULL,
    @SecurityDeposit         DECIMAL(18,2) = NULL,
    @SecurityDepositPaid     DECIMAL(18,2) = NULL,
    @SecurityDepositPaidDate NVARCHAR(MAX) = NULL,
    @Status                  NVARCHAR(MAX) = NULL,
    @UpdatedBy               INT           = NULL,
    @InstallmentsJson        NVARCHAR(MAX) = NULL,
    @MonthlyInstallmentsJson NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@Id AND ISNULL(IsDeleted,0)=0)
    BEGIN RAISERROR('Owner contract not found.', 16, 1); RETURN; END

    UPDATE OwnerContracts SET
        CampId                  = ISNULL(@CampId,                  CampId),
        OwnerId                 = ISNULL(@OwnerId,                 OwnerId),
        CampName                = CASE WHEN @CampId IS NOT NULL THEN ISNULL((SELECT Name FROM Camps WHERE Id=@CampId), CampName) ELSE CampName END,
        OwnerName               = CASE WHEN @OwnerId IS NOT NULL THEN ISNULL((SELECT Name FROM Owners WHERE Id=@OwnerId), OwnerName) ELSE OwnerName END,
        OwnerCode               = CASE WHEN @OwnerId IS NOT NULL THEN ISNULL((SELECT Code FROM Owners WHERE Id=@OwnerId), OwnerCode) ELSE OwnerCode END,
        PaymentType             = ISNULL(@PaymentType,             PaymentType),
        TotalAmount             = ISNULL(@TotalAmount,             TotalAmount),
        StartDate               = CASE WHEN @StartDate IS NULL OR @StartDate='' THEN StartDate ELSE CAST(@StartDate AS DATE) END,
        EndDate                 = CASE WHEN @EndDate IS NULL THEN EndDate WHEN @EndDate='' THEN NULL ELSE CAST(@EndDate AS DATE) END,
        ContractDate            = ISNULL(@ContractDate,            ContractDate),
        MonthlyRent             = ISNULL(@MonthlyRent,             MonthlyRent),
        NoOfMonths              = ISNULL(@NoOfMonths,              NoOfMonths),
        SecurityDeposit         = ISNULL(@SecurityDeposit,         SecurityDeposit),
        SecurityDepositPaid     = ISNULL(@SecurityDepositPaid,     SecurityDepositPaid),
        SecurityDepositPaidDate = CASE WHEN @SecurityDepositPaidDate IS NULL THEN SecurityDepositPaidDate WHEN @SecurityDepositPaidDate='' THEN NULL ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        Status                  = ISNULL(@Status,                  Status),
        UpdatedBy               = @UpdatedBy,
        UpdatedAt               = GETUTCDATE()
    WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    -- Installments replace
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
    BEGIN
        UPDATE OwnerInstallments SET IsDeleted=1 WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;
        INSERT INTO OwnerInstallments(OwnerContractId, No, Amount, PaidAmount, DueDate, Status, PaymentMode, ReferenceNo, Month, AddedBy, IsDeleted)
        SELECT @Id,
            ISNULL(j.NoPascal, ISNULL(j.NoCamel, 0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0, CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE), 'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal, ISNULL(j.MonthCamel, '')),
            @UpdatedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal INT '$.No', NoCamel INT '$.no',
            AmtPascal DECIMAL(18,2) '$.Amount', AmtCamel DECIMAL(18,2) '$.amount',
            DuePascal NVARCHAR(50) '$.DueDate', DueCamel NVARCHAR(50) '$.dueDate',
            PaymentModePascal NVARCHAR(MAX) '$.PaymentMode', PaymentModeCamel NVARCHAR(MAX) '$.paymentMode',
            ReferenceNoPascal NVARCHAR(MAX) '$.ReferenceNo', ReferenceNoCamel NVARCHAR(MAX) '$.referenceNo',
            MonthPascal NVARCHAR(MAX) '$.Month', MonthCamel NVARCHAR(MAX) '$.month') j;
    END

    -- MonthlyInstallments replace
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        UPDATE OwnerMonthlyContractInstallments SET IsDeleted=1, UpdatedAt=GETUTCDATE() WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, ReferenceNo, Month, CreatedAt, UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @Id,
            (SELECT OwnerId FROM OwnerContracts WHERE Id=@Id),
            (SELECT CampId FROM OwnerContracts WHERE Id=@Id),
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

    -- ✅ Camp dates sync — agar StartDate/EndDate change hua toh camp mein bhi update karo
    DECLARE @FinalCampId INT, @FinalStart DATE, @FinalEnd DATE;
    SELECT @FinalCampId=CampId, @FinalStart=StartDate, @FinalEnd=EndDate FROM OwnerContracts WHERE Id=@Id;
    EXEC sp_SyncCampDatesFromOwnerContract @CampId=@FinalCampId, @StartDate=@FinalStart, @EndDate=@FinalEnd;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_UpdateOwnerContract — Camp dates sync added';
GO

-- ══════════════════════════════════════════════════════════════
-- sp_RenewOwnerContract — renew ke baad naye contract ki dates camp mein sync
-- (Script 137 wala SP hai — bas camp sync add karo)
-- ══════════════════════════════════════════════════════════════
-- Note: sp_RenewOwnerContract already sp_CreateOwnerContract jaisa kaam karta hai.
-- Uski COMMIT se pehle bhi camp dates sync hona chahiye.
-- Yahan sirf ALTER karna hai — existing 137 SP mein ek line add:

-- For simplicity: SP ke end mein (COMMIT se pehle) yeh line manually add karo
-- ya 137 script dobara run karo after modifying.
-- Alternatively, just calling sp_SyncCampDatesFromOwnerContract from C# controller after renew.

PRINT '';
PRINT '✅✅ 144 - Owner Contract create/update pe Camp.StartDate + Camp.EndDate sync hoga';
GO
