-- ============================================================
-- 101: FINAL FIX sp_CreateOwnerContract
-- Problem: OwnerMonthlyContractInstallments INSERT missing in SP
-- This replaces all previous versions with complete correct SP
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId                  INT,
    @OwnerId                 INT,
    @PaymentType             NVARCHAR(MAX) = 'Monthly',
    @TotalAmount             DECIMAL(18,2),
    @StartDate               NVARCHAR(MAX),
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

    -- Generate OcCode
    DECLARE @OcCode NVARCHAR(50) = CONCAT('OC-', RIGHT('00000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR), 5));

    -- Get names
    DECLARE @OwnerCode NVARCHAR(MAX) = '';
    DECLARE @OwnerName NVARCHAR(MAX) = '';
    DECLARE @CampName  NVARCHAR(MAX) = '';
    SELECT @OwnerCode = ISNULL(Code,''), @OwnerName = ISNULL(Name,'') FROM Owners WHERE Id = @OwnerId;
    SELECT @CampName  = ISNULL(Name,'') FROM Camps  WHERE Id = @CampId;

    -- Insert OwnerContract
    INSERT INTO OwnerContracts(
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, Status,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @OcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount, CAST(@StartDate AS DATE), @Status,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE()
    );
    SET @NewId = SCOPE_IDENTITY();

    -- ── Insert OwnerInstallments ──────────────────────────────────
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments(OwnerContractId, No, Amount, PaidAmount, DueDate, Status, AddedBy, IsDeleted)
        SELECT
            @NewId,
            ISNULL(CAST(j.NoPascal AS INT),    ISNULL(CAST(j.NoCamel AS INT), 0)),
            ISNULL(CAST(j.AmtPascal AS DECIMAL(18,2)), ISNULL(CAST(j.AmtCamel AS DECIMAL(18,2)), 0)),
            0,
            CAST(ISNULL(j.DuePascal, j.DueCamel) AS DATE),
            'Pending', @AddedBy, 0
        FROM OPENJSON(@InstallmentsJson) WITH(
            NoPascal  INT           '$.No',
            NoCamel   INT           '$.no',
            AmtPascal DECIMAL(18,2) '$.Amount',
            AmtCamel  DECIMAL(18,2) '$.amount',
            DuePascal NVARCHAR(50)  '$.DueDate',
            DueCamel  NVARCHAR(50)  '$.dueDate'
        ) j;

    -- ── Insert OwnerMonthlyContractInstallments ───────────────────
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        -- Base offset for MCI code generation
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);

        INSERT INTO OwnerMonthlyContractInstallments(
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, CreatedAt, UpdatedAt
        )
        SELECT
            'MCI-' + RIGHT('000000' + CAST(@MciBase + ROW_NUMBER() OVER(ORDER BY InstallmentNo) AS NVARCHAR), 6),
            @NewId,
            @OwnerId,
            @CampId,
            InstallmentNo,
            Amount,
            ISNULL(PaidAmount, 0),
            ISNULL(Balance, Amount),
            DueDate,
            CASE WHEN ISNULL(PaidDate,'') = '' THEN NULL ELSE TRY_CAST(PaidDate AS DATE) END,
            ISNULL(NULLIF(Status,''), 'Pending'),
            NULL,   -- ExpenseId always NULL on create
            ISNULL(PaymentMode, ''),
            ISNULL(NULLIF(PaymentStatus,''), 'Pending'),
            GETUTCDATE(),
            GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH (
            -- Support both PascalCase (from C# serializer) and camelCase (direct frontend)
            InstallmentNo INT            '$.InstallmentNo',
            Amount        DECIMAL(18,2)  '$.Amount',
            PaidAmount    DECIMAL(18,2)  '$.PaidAmount',
            Balance       DECIMAL(18,2)  '$.Balance',
            DueDate       DATE           '$.DueDate',
            PaidDate      NVARCHAR(50)   '$.PaidDate',
            Status        NVARCHAR(MAX)  '$.Status',
            PaymentMode   NVARCHAR(MAX)  '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX)  '$.PaymentStatus'
        );
    END

    -- ── Create DR transaction ─────────────────────────────────────
    DECLARE @TxnCode NVARCHAR(50) = CONCAT('OTX-', RIGHT('00000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR), 5));
    INSERT INTO OwnerTransactions(
        TxnCode, OwnerContractId, OcCode, CampId, CampName,
        OwnerId, OwnerName, Type, Amount, Date, Description, InstallmentNos, CreatedAt
    )
    VALUES(
        @TxnCode, @NewId, @OcCode, @CampId, @CampName,
        @OwnerId, @OwnerName, 'DR', @TotalAmount, GETUTCDATE(),
        CONCAT('Contract Created - Total: ', @TotalAmount), '', GETUTCDATE()
    );

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_CreateOwnerContract FINAL FIX - MCI insert now included';
GO
