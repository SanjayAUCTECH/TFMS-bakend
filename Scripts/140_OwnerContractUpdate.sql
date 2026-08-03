-- ============================================================
-- 140: sp_UpdateOwnerContract — full update with installments
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

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
    @InstallmentsJson        NVARCHAR(MAX) = NULL,   -- NULL = purane rakho, array = replace
    @MonthlyInstallmentsJson NVARCHAR(MAX) = NULL    -- NULL = purane rakho, array = replace
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@Id AND ISNULL(IsDeleted,0)=0)
    BEGIN RAISERROR('Owner contract not found.', 16, 1); RETURN; END

    -- ── 1. Main contract fields update ───────────────────────
    UPDATE OwnerContracts SET
        CampId                  = ISNULL(@CampId,                  CampId),
        OwnerId                 = ISNULL(@OwnerId,                 OwnerId),
        CampName                = CASE WHEN @CampId IS NOT NULL THEN ISNULL((SELECT Name FROM Camps WHERE Id=@CampId), CampName) ELSE CampName END,
        OwnerName               = CASE WHEN @OwnerId IS NOT NULL THEN ISNULL((SELECT Name FROM Owners WHERE Id=@OwnerId), OwnerName) ELSE OwnerName END,
        OwnerCode               = CASE WHEN @OwnerId IS NOT NULL THEN ISNULL((SELECT Code FROM Owners WHERE Id=@OwnerId), OwnerCode) ELSE OwnerCode END,
        PaymentType             = ISNULL(@PaymentType,             PaymentType),
        TotalAmount             = ISNULL(@TotalAmount,             TotalAmount),
        StartDate               = CASE WHEN @StartDate IS NULL OR @StartDate='' THEN StartDate
                                        ELSE CAST(@StartDate AS DATE) END,
        EndDate                 = CASE WHEN @EndDate IS NULL THEN EndDate
                                        WHEN @EndDate='' THEN NULL
                                        ELSE CAST(@EndDate AS DATE) END,
        ContractDate            = ISNULL(@ContractDate,            ContractDate),
        MonthlyRent             = ISNULL(@MonthlyRent,             MonthlyRent),
        NoOfMonths              = ISNULL(@NoOfMonths,              NoOfMonths),
        SecurityDeposit         = ISNULL(@SecurityDeposit,         SecurityDeposit),
        SecurityDepositPaid     = ISNULL(@SecurityDepositPaid,     SecurityDepositPaid),
        SecurityDepositPaidDate = CASE WHEN @SecurityDepositPaidDate IS NULL THEN SecurityDepositPaidDate
                                        WHEN @SecurityDepositPaidDate='' THEN NULL
                                        ELSE CAST(@SecurityDepositPaidDate AS DATE) END,
        Status                  = ISNULL(@Status,                  Status),
        UpdatedBy               = @UpdatedBy,
        UpdatedAt               = GETUTCDATE()
    WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    -- ── 2. Installments — agar JSON aaya toh soft-delete + re-insert ─
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
    BEGIN
        -- Purane soft-delete karo
        UPDATE OwnerInstallments
        SET IsDeleted=1
        WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;

        -- Naye insert karo
        INSERT INTO OwnerInstallments(
            OwnerContractId, No, Amount, PaidAmount,
            DueDate, Status, PaymentMode, ReferenceNo, Month,
            AddedBy, IsDeleted)
        SELECT
            @Id,
            ISNULL(j.NoPascal,  ISNULL(j.NoCamel,  0)),
            ISNULL(j.AmtPascal, ISNULL(j.AmtCamel, 0)),
            0,
            CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE),
            'Pending',
            ISNULL(j.PaymentModePascal, ISNULL(j.PaymentModeCamel, '')),
            ISNULL(j.ReferenceNoPascal, ISNULL(j.ReferenceNoCamel, '')),
            ISNULL(j.MonthPascal,       ISNULL(j.MonthCamel,       '')),
            @UpdatedBy, 0
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
    END

    -- ── 3. MonthlyInstallments — agar JSON aaya toh soft-delete + re-insert ─
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        -- Purane soft-delete karo
        UPDATE OwnerMonthlyContractInstallments
        SET IsDeleted=1, UpdatedAt=GETUTCDATE()
        WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;

        -- Naye insert karo
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);
        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, ReferenceNo, Month,
            CreatedAt, UpdatedAt)
        SELECT
            'MCI-'+RIGHT('000000'+CAST(@MciBase+ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR),6),
            @Id,
            (SELECT OwnerId FROM OwnerContracts WHERE Id=@Id),
            (SELECT CampId  FROM OwnerContracts WHERE Id=@Id),
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

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ 140 - sp_UpdateOwnerContract created (with installments + monthly installments replace)';
GO
