-- ============================================================
-- Update sp_CreateOwnerContract to handle MonthlyInstallments
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateOwnerContract
    @CampId             INT,
    @OwnerId            INT,
    @PaymentType        NVARCHAR(MAX),
    @TotalAmount        DECIMAL(18,2),
    @StartDate          DATE,
    @InstallmentsJson   NVARCHAR(MAX),
    @MonthlyInstallmentsJson NVARCHAR(MAX) = '[]',
    @NewId              INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Generate OcCode
    DECLARE @OcCode NVARCHAR(50) = 'OC-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContracts) AS NVARCHAR), 6);
    
    -- Get Camp and Owner details
    DECLARE @CampName  NVARCHAR(MAX) = (SELECT Name FROM Camps WHERE Id = @CampId);
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
    
    -- Insert OwnerInstallments
    IF @InstallmentsJson IS NOT NULL AND LEN(@InstallmentsJson) > 2
        INSERT INTO OwnerInstallments (OwnerContractId, No, Amount, DueDate, PaidAmount, Status)
        SELECT @NewId, No, Amount, DueDate, 0, 'Pending'
        FROM OPENJSON(@InstallmentsJson) WITH (
            No      INT            '$.No',
            Amount  DECIMAL(18,2)  '$.Amount',
            DueDate DATE           '$.DueDate'
        );
    
    -- Insert OwnerMonthlyContractInstallments
    IF @MonthlyInstallmentsJson IS NOT NULL AND LEN(@MonthlyInstallmentsJson) > 2
    BEGIN
        INSERT INTO OwnerMonthlyContractInstallments (
            MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId, 
            InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate, 
            Status, ExpenseId, PaymentMode, PaymentStatus, CreatedAt, UpdatedAt
        )
        SELECT 
            'MCI-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0) + ROW_NUMBER() OVER(ORDER BY InstallmentNo) FROM OwnerMonthlyContractInstallments) AS NVARCHAR), 6),
            @NewId,
            @OwnerId,
            @CampId,
            InstallmentNo,
            Amount,
            PaidAmount,
            Balance,
            DueDate,
            PaidDate,
            Status,
            ExpenseId,
            PaymentMode,
            PaymentStatus,
            GETUTCDATE(),
            GETUTCDATE()
        FROM OPENJSON(@MonthlyInstallmentsJson) WITH (
            InstallmentNo INT            '$.InstallmentNo',
            Amount        DECIMAL(18,2)  '$.Amount',
            PaidAmount    DECIMAL(18,2)  '$.PaidAmount',
            Balance       DECIMAL(18,2)  '$.Balance',
            DueDate       DATE           '$.DueDate',
            PaidDate      DATE           '$.PaidDate',
            Status        NVARCHAR(MAX)  '$.Status',
            ExpenseId     INT            '$.ExpenseId',
            PaymentMode   NVARCHAR(MAX)  '$.PaymentMode',
            PaymentStatus NVARCHAR(MAX)  '$.PaymentStatus'
        );
    END
    
    -- Create initial DR transaction
    DECLARE @TxnCode NVARCHAR(50) = 'OT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR), 6);
    INSERT INTO OwnerTransactions (
        TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName, 
        Type, Amount, Date, Description, CreatedAt
    ) VALUES (
        @TxnCode, @NewId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
        'DR', @TotalAmount, @StartDate, 'Contract created', GETUTCDATE()
    );
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteOwnerContract @Id INT
AS 
BEGIN
    SET NOCOUNT ON;
    DELETE FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @Id;
    DELETE FROM OwnerTransactions WHERE OwnerContractId = @Id;
    DELETE FROM OwnerInstallments WHERE OwnerContractId = @Id;
    DELETE FROM OwnerContracts WHERE Id = @Id;
END
GO

PRINT '✅ sp_CreateOwnerContract and sp_DeleteOwnerContract updated with MonthlyInstallments support';
GO
