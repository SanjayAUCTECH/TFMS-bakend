-- ============================================================
-- 123: Fix sp_RenewContract — TxnId NULL error
-- Problem: INSERT into TxnRecords was missing TxnId column,
--          causing "Cannot insert NULL into TxnId" error.
-- Fix: Generate TxnId before INSERT (same pattern as other SPs)
-- Date: July 31, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_RenewContract
    @OriginalContractId     NVARCHAR(MAX),
    @TenantId               INT,
    @CampIdsJson            NVARCHAR(MAX) = '[]',
    @StartDate              DATE,
    @Months                 INT           = 12,
    @RoomIdsJson            NVARCHAR(MAX) = '[]',
    @ContractType           NVARCHAR(MAX) = 'Monthly',
    @SecurityDeposit        DECIMAL(18,2) = 0,   -- kept for compat, ignored
    @InstallmentType        NVARCHAR(MAX) = 'monthly',
    @IssuedBy               NVARCHAR(MAX) = '',
    @Notes                  NVARCHAR(MAX) = '',
    @LessorAmount           DECIMAL(18,2) = 0,
    @MonthlyTotal           DECIMAL(18,2) = NULL,
    @ContractTotal          DECIMAL(18,2) = NULL,
    @RenewalType            NVARCHAR(MAX) = 'Monthly',
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
    @ExpireOldContract      BIT           = 1,
    @NewContractId          NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Step 1: Create new contract via sp_CreateContract ─────────────────
    EXEC sp_CreateContract
        @TenantId              = @TenantId,
        @CampIdsJson           = @CampIdsJson,
        @StartDate             = @StartDate,
        @Months                = @Months,
        @RoomIdsJson           = @RoomIdsJson,
        @ContractType          = @ContractType,
        @SecurityDeposit       = @SecurityDeposit,
        @InstallmentType       = @InstallmentType,
        @IssuedBy              = @IssuedBy,
        @Notes                 = @Notes,
        @LessorAmount          = @LessorAmount,
        @MonthlyTotal          = @MonthlyTotal,
        @ContractTotal         = @ContractTotal,
        @ContractPropertyUsage = @ContractPropertyUsage,
        @ContractBuildingName  = @ContractBuildingName,
        @ContractPropertyType  = @ContractPropertyType,
        @ContractLocation      = @ContractLocation,
        @ContractPropertyNo    = @ContractPropertyNo,
        @ContractPropertyArea  = @ContractPropertyArea,
        @ContractPremisesNo    = @ContractPremisesNo,
        @ContractPaymentMode   = @ContractPaymentMode,
        @ContractPlotNo        = @ContractPlotNo,
        @ContractMakaniNo      = @ContractMakaniNo,
        @NewContractId         = @NewContractId OUTPUT;

    -- ── Step 2: Read auto-calculated values from the new contract ─────────
    DECLARE @NewEndDate       DATE;
    DECLARE @ActualSecurity   DECIMAL(18,2);
    DECLARE @ActualMonthly    DECIMAL(18,2);
    DECLARE @ActualTotal      DECIMAL(18,2);

    SELECT
        @NewEndDate     = EndDate,
        @ActualSecurity = SecurityDeposit,
        @ActualMonthly  = MonthlyTotal,
        @ActualTotal    = ContractTotal
    FROM Contracts
    WHERE ContractId = @NewContractId;

    -- ── Step 3: Log renewal ───────────────────────────────────────────────
    INSERT INTO ContractRenewals (
        OriginalContractId, NewContractId, RenewalType, RenewalDate,
        NewStartDate, NewEndDate, NewMonths,
        NewMonthlyTotal, NewContractTotal,
        SecurityDeposit,
        Notes, RenewedBy, Status
    )
    VALUES (
        @OriginalContractId, @NewContractId, @RenewalType, GETDATE(),
        @StartDate, @NewEndDate, @Months,
        @ActualMonthly, @ActualTotal,
        @ActualSecurity,
        @Notes, @IssuedBy, 'Active'
    );

    -- ── Step 4: Expire old contract (optional) ────────────────────────────
    IF @ExpireOldContract = 1
    BEGIN
        UPDATE Contracts
        SET Status    = 'Expired',
            UpdatedAt = GETDATE()
        WHERE ContractId = @OriginalContractId
          AND Status = 'Active';
    END

    -- ── Step 5: Create DR TxnRecord for the new contract ──────────────────
    DECLARE @CampId INT = 0;
    SELECT TOP 1 @CampId = CampId FROM ContractCamps WHERE ContractId = @NewContractId;

    -- Generate TxnId (same pattern used across all other SPs)
    DECLARE @TxnId NVARCHAR(MAX) =
        'TXN-' + CONVERT(NVARCHAR(MAX), @StartDate, 112) + '-' +
        RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM TxnRecords) AS NVARCHAR), 6);

    INSERT INTO TxnRecords (
        TxnId, TxnType, ContractId, ContractCode, TenantId, CampId,
        TotalAmount, Amount, TxnDate, FromDate, ToDate,
        Description, ReceivedBy, IssuedBy
    )
    VALUES (
        @TxnId, 'DR', @NewContractId, @NewContractId, @TenantId, @CampId,
        @ActualTotal, @ActualTotal, @StartDate, @StartDate, @NewEndDate,
        'Contract Renewal from ' + @OriginalContractId + ' - '
            + CAST(@Months AS NVARCHAR) + ' months',
        @IssuedBy, @IssuedBy
    );
END
GO

PRINT '✅ 123 - sp_RenewContract: Fixed TxnId NULL error in TxnRecords INSERT';
GO
