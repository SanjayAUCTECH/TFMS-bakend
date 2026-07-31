-- ============================================================
-- 122: Update sp_RenewContract
-- Change: SecurityDeposit logged in ContractRenewals =
--         SUM of 5% of each room TotalAmount (auto-calculated)
--         NOT from @SecurityDeposit user input param
--
-- sp_CreateContract (Script 120) already handles 5% per room.
-- This script fixes the ContractRenewals log entry to record
-- the correct auto-calculated SecurityDeposit value.
--
-- @SecurityDeposit param kept for backward compatibility but ignored.
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
    -- sp_CreateContract (Script 120) auto-calculates SecurityDeposit = 5%
    -- @SecurityDeposit param is passed but ignored inside sp_CreateContract
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
        @ActualSecurity = SecurityDeposit,   -- ← 5% auto-calc value from sp_CreateContract
        @ActualMonthly  = MonthlyTotal,
        @ActualTotal    = ContractTotal
    FROM Contracts
    WHERE ContractId = @NewContractId;

    -- ── Step 3: Log renewal with ACTUAL security deposit (5% auto-calc) ───
    INSERT INTO ContractRenewals (
        OriginalContractId, NewContractId, RenewalType, RenewalDate,
        NewStartDate, NewEndDate, NewMonths,
        NewMonthlyTotal, NewContractTotal,
        SecurityDeposit,        -- ← actual auto-calculated value
        Notes, RenewedBy, Status
    )
    VALUES (
        @OriginalContractId, @NewContractId, @RenewalType, GETDATE(),
        @StartDate, @NewEndDate, @Months,
        @ActualMonthly, @ActualTotal,
        @ActualSecurity,        -- ← NOT @SecurityDeposit from user
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

    INSERT INTO TxnRecords (
        TxnType, ContractId, ContractCode, TenantId, CampId,
        TotalAmount, Amount, TxnDate, FromDate, ToDate,
        Description, ReceivedBy, IssuedBy
    )
    VALUES (
        'DR', @NewContractId, @NewContractId, @TenantId, @CampId,
        @ActualTotal, @ActualTotal, @StartDate, @StartDate, @NewEndDate,
        'Contract Renewal from ' + @OriginalContractId + ' - '
            + CAST(@Months AS NVARCHAR) + ' months',
        @IssuedBy, @IssuedBy
    );
END
GO

PRINT '✅ 122 - sp_RenewContract: SecurityDeposit in ContractRenewals = 5% auto-calc (from sp_CreateContract)';
GO
