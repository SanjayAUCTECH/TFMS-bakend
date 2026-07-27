-- ============================================================
-- FIX: sp_CreateOwnerContract - MonthlyInstallments bug
-- Bug: ROW_NUMBER() inside subquery was invalid SQL causing
--      MonthlyContractInstallmentId generation to fail and
--      all monthly installments to NOT be saved.
-- Fix: Use a base offset variable + InstallmentNo for unique ID.
-- Also: Added @AddedBy parameter (repository sends it).
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId                  INT,
    @OwnerId                 INT,
    @PaymentType             NVARCHAR(MAX),
    @TotalAmount             DECIMAL(18,2),
    @StartDate               DATE,
    @InstallmentsJson        NVARCHAR(MAX),
    @MonthlyInstallmentsJson NVARCHAR(MAX) = '[]',
    @AddedBy                 INT           = NULL,
    @NewId                   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Generate OcCode
    DECLARE @OcCode NVARCHAR(50) = 'OC-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR), 6);

    -- Get Camp and Owner details
    DECLARE @CampName  NVARCHAR(MAX) = (SELECT Name FROM Camps  WHERE Id = @CampId);
    DECLARE @OwnerName NVARCHAR(MAX) = (SELECT Name FROM Owners WHERE Id = @OwnerId);
    DECLARE @OwnerCode NVARCHAR(MAX) = (SELECT Code FROM Owners WHERE Id = @OwnerId);

    -- Insert OwnerContract
    INSERT INTO OwnerContracts (
        OcCode, CampId, CampName, OwnerId, OwnerName, OwnerCode,
        PaymentType, TotalAmount, StartDate, Status, CreatedAt, UpdatedAt
    ) VALUES (
        @OcCode, @CampId, @CampName, @OwnerId, @OwnerName, @OwnerCode,
        @PaymentType, @TotalAmount, @StartDate, 'Active', GETUTCDATE(), GETUTCDATE()
    );

    SET @NewId = SCOPE_IDENTITY();

    -- ── Insert OwnerInstallments ──────────────────────────────────────────────
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments (OwnerContractId, No, Amount, DueDate, PaidAmount, Status)
        SELECT @NewId, No, Amount, DueDate, 0, 'Pending'
        FROM OPENJSON(@InstallmentsJson) WITH (
            No      INT            '$.No',
            Amount  DECIMAL(18,2)  '$.Amount',
            DueDate DATE           '$.DueDate'
        );

    -- ── Insert OwnerMonthlyContractInstallments ──────────────────────────────
    -- FIX: Get base ID offset BEFORE insert, then use InstallmentNo for unique suffix
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        DECLARE @MciBase INT = ISNULL((SELECT MAX(Id) FROM OwnerMonthlyContractInstallments), 0);

        INSERT INTO OwnerMonthlyContractInstallments (
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
            Status, ExpenseId, PaymentMode, PaymentStatus, CreatedAt, UpdatedAt
        )
        SELECT
            'MCI-' + RIGHT('000000' + CAST(@MciBase + InstallmentNo AS NVARCHAR), 6),
            @NewId,
            @OwnerId,
            @CampId,
            InstallmentNo,
            Amount,
            ISNULL(PaidAmount, 0),
            ISNULL(Balance, Amount),
            DueDate,
            NULLIF(PaidDate, ''),
            ISNULL(NULLIF(Status, ''), 'Pending'),
            NULLIF(ExpenseId, 0),
            ISNULL(PaymentMode, ''),
            ISNULL(NULLIF(PaymentStatus, ''), 'Pending'),
            GETUTCDATE(),
            GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH (
            InstallmentNo INT            '$.InstallmentNo',
            Amount        DECIMAL(18,2)  '$.Amount',
            PaidAmount    DECIMAL(18,2)  '$.PaidAmount',
            Balance       DECIMAL(18,2)  '$.Balance',
            DueDate       DATE           '$.DueDate',
            PaidDate      NVARCHAR(50)   '$.PaidDate',
            Status        NVARCHAR(MAX)  '$.Status',
            ExpenseId     INT            '$.ExpenseId',
            PaymentMode   NVARCHAR(MAX)  '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX)  '$.PaymentStatus'
        );
    END

    -- ── Create initial DR transaction ─────────────────────────────────────────
    DECLARE @TxnCode NVARCHAR(50) = 'OT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR), 6);
    INSERT INTO OwnerTransactions (
        TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
        Type, Amount, Date, Description, CreatedAt
    ) VALUES (
        @TxnCode, @NewId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
        'DR', @TotalAmount, @StartDate, 'Contract created', GETUTCDATE()
    );

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_CreateOwnerContract fixed - MonthlyInstallments now saved correctly';
GO
