-- ============================================================================
-- 034: ContractRenewals Table + Stored Procedure
-- Manages contract renewal with installments, DR transaction, full tracking
-- ============================================================================

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ContractRenewals')
BEGIN
    CREATE TABLE ContractRenewals (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        OriginalContractId NVARCHAR(MAX) NOT NULL,     -- e.g., 'CNT-000106' (old contract)
        NewContractId      NVARCHAR(MAX) NOT NULL,     -- e.g., 'CNT-000107' (renewed contract)
        RenewalType        NVARCHAR(MAX) NULL,         -- 'Monthly' | 'Yearly' | 'Custom'
        RenewalDate        DATE DEFAULT GETDATE(),
        NewStartDate       DATE NULL,
        NewEndDate         DATE NULL,
        NewMonths          INT NULL,
        NewMonthlyTotal    DECIMAL(18,2) NULL,
        NewContractTotal   DECIMAL(18,2) NULL,
        SecurityDeposit    DECIMAL(18,2) NULL,
        Notes              NVARCHAR(MAX) NULL,
        RenewedBy          NVARCHAR(MAX) NULL,
        Status             NVARCHAR(MAX) DEFAULT 'Active',
        CreatedAt          DATETIME2 DEFAULT GETDATE(),
        UpdatedAt          DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- ============================================================================
-- sp_RenewContract — Full renewal:
-- 1. Creates new contract (via sp_CreateContract)
-- 2. Logs renewal in ContractRenewals
-- 3. Optionally expires the old contract
-- ============================================================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_RenewContract')
    DROP PROCEDURE sp_RenewContract;
GO

CREATE PROCEDURE sp_RenewContract
    @OriginalContractId NVARCHAR(MAX),
    @TenantId           INT,
    @CampIdsJson        NVARCHAR(MAX) = '[]',
    @StartDate          DATE,
    @Months             INT = 12,
    @RoomIdsJson        NVARCHAR(MAX) = '[]',
    @ContractType       NVARCHAR(MAX) = 'Monthly',
    @SecurityDeposit    DECIMAL(18,2) = 0,
    @InstallmentType    NVARCHAR(MAX) = 'monthly',
    @IssuedBy           NVARCHAR(MAX) = '',
    @Notes              NVARCHAR(MAX) = '',
    @LessorAmount       DECIMAL(18,2) = 0,
    @MonthlyTotal       DECIMAL(18,2) = NULL,
    @ContractTotal      DECIMAL(18,2) = NULL,
    @RenewalType        NVARCHAR(MAX) = 'Monthly',
    @ContractPropertyUsage  NVARCHAR(MAX) = '',
    @ContractBuildingName   NVARCHAR(MAX) = '',
    @ContractPropertyType   NVARCHAR(MAX) = '',
    @ContractLocation       NVARCHAR(MAX) = '',
    @ContractPropertyNo     NVARCHAR(MAX) = '',
    @ContractPropertyArea   NVARCHAR(MAX) = '',
    @ContractPremisesNo     NVARCHAR(MAX) = '',
    @ContractPaymentMode    NVARCHAR(MAX) = '',
    @ContractPlotNo         NVARCHAR(MAX) = '',
    @ContractMakaniNo       NVARCHAR(MAX) = '',
    @ExpireOldContract      BIT = 1,
    @NewContractId      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Create the new contract using existing SP
    EXEC sp_CreateContract
        @TenantId = @TenantId,
        @CampIdsJson = @CampIdsJson,
        @StartDate = @StartDate,
        @Months = @Months,
        @RoomIdsJson = @RoomIdsJson,
        @ContractType = @ContractType,
        @SecurityDeposit = @SecurityDeposit,
        @InstallmentType = @InstallmentType,
        @IssuedBy = @IssuedBy,
        @Notes = @Notes,
        @LessorAmount = @LessorAmount,
        @MonthlyTotal = @MonthlyTotal,
        @ContractTotal = @ContractTotal,
        @ContractPropertyUsage = @ContractPropertyUsage,
        @ContractBuildingName = @ContractBuildingName,
        @ContractPropertyType = @ContractPropertyType,
        @ContractLocation = @ContractLocation,
        @ContractPropertyNo = @ContractPropertyNo,
        @ContractPropertyArea = @ContractPropertyArea,
        @ContractPremisesNo = @ContractPremisesNo,
        @ContractPaymentMode = @ContractPaymentMode,
        @ContractPlotNo = @ContractPlotNo,
        @ContractMakaniNo = @ContractMakaniNo,
        @NewContractId = @NewContractId OUTPUT;

    -- 2. Get new contract end date
    DECLARE @NewEndDate DATE;
    SELECT @NewEndDate = EndDate FROM Contracts WHERE ContractId = @NewContractId;

    -- 3. Log renewal
    INSERT INTO ContractRenewals (
        OriginalContractId, NewContractId, RenewalType, RenewalDate,
        NewStartDate, NewEndDate, NewMonths, NewMonthlyTotal, NewContractTotal,
        SecurityDeposit, Notes, RenewedBy, Status
    )
    VALUES (
        @OriginalContractId, @NewContractId, @RenewalType, GETDATE(),
        @StartDate, @NewEndDate, @Months, @MonthlyTotal, @ContractTotal,
        @SecurityDeposit, @Notes, @IssuedBy, 'Active'
    );

    -- 4. Expire old contract (optional)
    IF @ExpireOldContract = 1
    BEGIN
        UPDATE Contracts SET Status = 'Expired', UpdatedAt = GETDATE()
        WHERE ContractId = @OriginalContractId AND Status = 'Active';
    END

    -- 5. Create DR TxnRecord for the new contract
    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, ISNULL(@MonthlyTotal, 0) * @Months);
    DECLARE @CampId INT = 0;
    SELECT TOP 1 @CampId = CampId FROM ContractCamps WHERE ContractId = @NewContractId;

    INSERT INTO TxnRecords (
        TxnType, ContractId, ContractCode, TenantId, CampId,
        TotalAmount, Amount, TxnDate, FromDate, ToDate,
        Description, ReceivedBy, IssuedBy
    )
    VALUES (
        'DR', @NewContractId, @NewContractId, @TenantId, @CampId,
        @FinalTotal, @FinalTotal, @StartDate, @StartDate, @NewEndDate,
        'Contract Renewal from ' + @OriginalContractId + ' - ' + CAST(@Months AS NVARCHAR) + ' months',
        @IssuedBy, @IssuedBy
    );
END
GO

-- ============================================================================
-- sp_GetContractRenewals — Get renewal history for a contract
-- ============================================================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetContractRenewals')
    DROP PROCEDURE sp_GetContractRenewals;
GO

CREATE PROCEDURE sp_GetContractRenewals
    @ContractId NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        r.Id, r.OriginalContractId, r.NewContractId, r.RenewalType,
        r.RenewalDate, r.NewStartDate, r.NewEndDate, r.NewMonths,
        r.NewMonthlyTotal, r.NewContractTotal, r.SecurityDeposit,
        r.Notes, r.RenewedBy, r.Status, r.CreatedAt, r.UpdatedAt,
        t.Name AS TenantName
    FROM ContractRenewals r
    LEFT JOIN Contracts c ON c.ContractId = r.OriginalContractId
    LEFT JOIN Tenants t ON t.Id = c.TenantId
    WHERE (@ContractId IS NULL OR r.OriginalContractId = @ContractId OR r.NewContractId = @ContractId)
    ORDER BY r.CreatedAt DESC;
END
GO

PRINT 'ContractRenewals table and SPs created successfully.';
GO
