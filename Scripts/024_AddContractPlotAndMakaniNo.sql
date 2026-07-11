-- ============================================================
-- Script 024: Add ContractPlotNo & ContractMakaniNo columns
--             + Fix all 3 GET SPs + Update CREATE/UPDATE SPs
-- ============================================================
USE TFMS_softwareDB;
GO

-- ── Step 1: Add new columns if not already there ─────────────
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Contracts' AND COLUMN_NAME = 'ContractPlotNo'
)
BEGIN
    ALTER TABLE Contracts ADD ContractPlotNo NVARCHAR(100) NOT NULL DEFAULT '';
    PRINT 'Column ContractPlotNo added.';
END
ELSE
    PRINT 'Column ContractPlotNo already exists.';

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Contracts' AND COLUMN_NAME = 'ContractMakaniNo'
)
BEGIN
    ALTER TABLE Contracts ADD ContractMakaniNo NVARCHAR(100) NOT NULL DEFAULT '';
    PRINT 'Column ContractMakaniNo added.';
END
ELSE
    PRINT 'Column ContractMakaniNo already exists.';
GO

-- ── Step 2: Fix sp_GetContracts — add all missing columns ─────
CREATE OR ALTER PROCEDURE sp_GetContracts
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(200) = NULL,
    @SortBy        NVARCHAR(50)  = NULL,
    @SortDirection NVARCHAR(4)   = 'ASC',
    @Status        NVARCHAR(20)  = NULL,
    @TenantId      INT           = NULL,
    @CampId        INT           = NULL,
    @DateFrom      NVARCHAR(20)  = NULL,
    @DateTo        NVARCHAR(20)  = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    WHERE (@Status     IS NULL OR c.Status     = @Status)
      AND (@TenantId   IS NULL OR c.TenantId   = @TenantId)
      AND (@CampId     IS NULL OR c.CampId     = @CampId)
      AND (@DateFrom   IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo     IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%'
                               OR t.Name        LIKE '%'+@SearchText+'%');

    SELECT
        c.Id, c.ContractId,
        c.TenantId,  t.Name  TenantName,
        c.CampId,    ca.Name CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)        SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.IssuedBy,  '')             IssuedBy,
        ISNULL(c.Notes,     '')             Notes,
        ISNULL(c.LessorAmount, 0)           LessorAmount,
        c.Status,
        -- Property fields
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        -- Payment summary
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount   FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    WHERE (@Status     IS NULL OR c.Status     = @Status)
      AND (@TenantId   IS NULL OR c.TenantId   = @TenantId)
      AND (@CampId     IS NULL OR c.CampId     = @CampId)
      AND (@DateFrom   IS NULL OR c.StartDate >= CAST(@DateFrom AS DATE))
      AND (@DateTo     IS NULL OR c.StartDate <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR c.ContractId LIKE '%'+@SearchText+'%'
                               OR t.Name        LIKE '%'+@SearchText+'%')
    ORDER BY
        CASE WHEN @SortBy = 'StartDate' AND @SortDirection = 'DESC' THEN c.StartDate END DESC,
        c.CreatedAt DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── Step 3: Fix sp_GetContractById ────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetContractById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Contract header
    SELECT
        c.Id, c.ContractId,
        c.TenantId,  t.Name  TenantName,
        c.CampId,    ca.Name CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)         SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.IssuedBy,  '')              IssuedBy,
        ISNULL(c.Notes,     '')              Notes,
        ISNULL(c.LessorAmount, 0)            LessorAmount,
        c.Status,
        -- Property fields
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        -- Payment summary
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount   FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt,
        -- Room + Payment join columns (for C# ReadContractWithPayments)
        cr.RoomId,
        p.Id   PayId,
        p.ContractId,
        p.InstallmentNo,
        p.Amount       PayAmount,
        p.DueDate,
        p.PaidAmount,
        p.PaidDate,
        p.Status       PayStatus,
        ISNULL(p.PaymentMode,   '') PaymentMode,
        ISNULL(p.ChequeNumber,  '') ChequeNumber,
        ISNULL(p.ClearanceDate, '') ClearanceDate
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    LEFT JOIN ContractRooms cr ON cr.ContractId = c.ContractId
    LEFT JOIN ContractInstallments p ON p.ContractId = c.ContractId
    WHERE c.Id = @Id;
END
GO

-- ── Step 4: Fix sp_GetContractByContractId ────────────────────
CREATE OR ALTER PROCEDURE sp_GetContractByContractId
    @ContractId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.Id, c.ContractId,
        c.TenantId,  t.Name  TenantName,
        c.CampId,    ca.Name CampName,
        c.StartDate, c.Months, c.EndDate,
        c.MonthlyTotal, c.ContractTotal,
        ISNULL(c.SecurityDeposit, 0)         SecurityDeposit,
        ISNULL(c.InstallmentType, 'monthly') InstallmentType,
        ISNULL(c.IssuedBy,  '')              IssuedBy,
        ISNULL(c.Notes,     '')              Notes,
        ISNULL(c.LessorAmount, 0)            LessorAmount,
        c.Status,
        -- Property fields
        ISNULL(c.ContractPropertyUsage, '') ContractPropertyUsage,
        ISNULL(c.ContractBuildingName,  '') ContractBuildingName,
        ISNULL(c.ContractPropertyType,  '') ContractPropertyType,
        ISNULL(c.ContractLocation,      '') ContractLocation,
        ISNULL(c.ContractPropertyNo,    '') ContractPropertyNo,
        ISNULL(c.ContractPropertyArea,  '') ContractPropertyArea,
        ISNULL(c.ContractPremisesNo,    '') ContractPremisesNo,
        ISNULL(c.ContractPaymentMode,   '') ContractPaymentMode,
        ISNULL(c.ContractPlotNo,        '') ContractPlotNo,
        ISNULL(c.ContractMakaniNo,      '') ContractMakaniNo,
        -- Payment summary
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalPaid,
        c.ContractTotal - ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments WHERE ContractId = c.ContractId), 0) TotalDue,
        (SELECT TOP 1 Amount   FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentAmount,
        (SELECT TOP 1 PaidDate FROM TxnRecords WHERE ContractId = c.ContractId AND TxnType = 'CR' ORDER BY PaidDate DESC, Id DESC) LastPaymentDate,
        c.CreatedAt, c.UpdatedAt,
        -- Room + Payment join columns (for C# ReadContractWithPayments)
        cr.RoomId,
        p.Id   PayId,
        p.ContractId,
        p.InstallmentNo,
        p.Amount       PayAmount,
        p.DueDate,
        p.PaidAmount,
        p.PaidDate,
        p.Status       PayStatus,
        ISNULL(p.PaymentMode,   '') PaymentMode,
        ISNULL(p.ChequeNumber,  '') ChequeNumber,
        ISNULL(p.ClearanceDate, '') ClearanceDate
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    LEFT JOIN ContractRooms cr ON cr.ContractId = c.ContractId
    LEFT JOIN ContractInstallments p ON p.ContractId = c.ContractId
    WHERE c.ContractId = @ContractId;
END
GO

-- ── Step 5: Recreate sp_CreateContract with all columns ───────
CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId              INT,
    @CampId                INT,
    @StartDate             DATE,
    @Months                INT,
    @RoomIdsJson           NVARCHAR(MAX),
    @SecurityDeposit       DECIMAL(18,2) = 0,
    @InstallmentType       NVARCHAR(20)  = 'monthly',
    @IssuedBy              NVARCHAR(100) = '',
    @Notes                 NVARCHAR(MAX) = '',
    @LessorAmount          DECIMAL(18,2) = 0,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(200) = '',
    @ContractBuildingName  NVARCHAR(200) = '',
    @ContractPropertyType  NVARCHAR(100) = '',
    @ContractLocation      NVARCHAR(200) = '',
    @ContractPropertyNo    NVARCHAR(100) = '',
    @ContractPropertyArea  NVARCHAR(100) = '',
    @ContractPremisesNo    NVARCHAR(100) = '',
    @ContractPaymentMode   NVARCHAR(100) = '',
    @ContractPlotNo        NVARCHAR(100) = '',
    @ContractMakaniNo      NVARCHAR(100) = '',
    @NewContractId         NVARCHAR(20)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Contracts) AS NVARCHAR), 6);

    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    DECLARE @EndDate     DATE          = DATEADD(MONTH, @Months, @StartDate);

    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
        SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
        FROM Rooms r
        JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;

    DECLARE @FinalMonthly DECIMAL(18,2) = ISNULL(@MonthlyTotal,  @CalcMonthly);
    DECLARE @FinalTotal   DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @Months);

    INSERT INTO Contracts (
        ContractId, TenantId, CampId, StartDate, Months, EndDate,
        MonthlyTotal, ContractTotal, SecurityDeposit, InstallmentType,
        IssuedBy, Notes, LessorAmount, Status,
        ContractPropertyUsage, ContractBuildingName, ContractPropertyType,
        ContractLocation, ContractPropertyNo, ContractPropertyArea,
        ContractPremisesNo, ContractPaymentMode,
        ContractPlotNo, ContractMakaniNo,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @NewContractId, @TenantId, @CampId, @StartDate, @Months, @EndDate,
        @FinalMonthly, @FinalTotal, @SecurityDeposit, @InstallmentType,
        @IssuedBy, @Notes, @LessorAmount, 'Active',
        @ContractPropertyUsage, @ContractBuildingName, @ContractPropertyType,
        @ContractLocation, @ContractPropertyNo, @ContractPropertyArea,
        @ContractPremisesNo, @ContractPaymentMode,
        @ContractPlotNo, @ContractMakaniNo,
        GETUTCDATE(), GETUTCDATE()
    );

    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        INSERT INTO ContractRooms (ContractId, RoomId)
        SELECT @NewContractId, RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$');

        UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$'));
    END

    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @FinalMonthly, DATEADD(MONTH, @i-1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END
END
GO

-- ── Step 6: Recreate sp_UpdateContract with all columns ───────
CREATE OR ALTER PROCEDURE sp_UpdateContract
    @ContractId            NVARCHAR(20),
    @TenantId              INT           = NULL,
    @StartDate             DATE          = NULL,
    @Months                INT           = NULL,
    @RoomIdsJson           NVARCHAR(MAX) = NULL,
    @LessorAmount          DECIMAL(18,2) = NULL,
    @Notes                 NVARCHAR(MAX) = NULL,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(200) = NULL,
    @ContractBuildingName  NVARCHAR(200) = NULL,
    @ContractPropertyType  NVARCHAR(100) = NULL,
    @ContractLocation      NVARCHAR(200) = NULL,
    @ContractPropertyNo    NVARCHAR(100) = NULL,
    @ContractPropertyArea  NVARCHAR(100) = NULL,
    @ContractPremisesNo    NVARCHAR(100) = NULL,
    @ContractPaymentMode   NVARCHAR(100) = NULL,
    @ContractPlotNo        NVARCHAR(100) = NULL,
    @ContractMakaniNo      NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExTenantId  INT;
    DECLARE @ExStartDate DATE;
    DECLARE @ExMonths    INT;
    DECLARE @ExLessor    DECIMAL(18,2);
    SELECT @ExTenantId=TenantId, @ExStartDate=StartDate, @ExMonths=Months, @ExLessor=LessorAmount
    FROM Contracts WHERE ContractId = @ContractId;

    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
        SELECT @CalcMonthly = ISNULL(SUM(r.MonthlyPrice), 0)
        FROM Rooms r
        JOIN OPENJSON(@RoomIdsJson) WITH (RoomId INT '$') j ON j.RoomId = r.Id;

    DECLARE @FinalMonths  INT           = ISNULL(@Months,    @ExMonths);
    DECLARE @FinalStart   DATE          = ISNULL(@StartDate, @ExStartDate);
    DECLARE @FinalMonthly DECIMAL(18,2) = ISNULL(@MonthlyTotal,  @CalcMonthly);
    DECLARE @FinalTotal   DECIMAL(18,2) = ISNULL(@ContractTotal, @FinalMonthly * @FinalMonths);
    DECLARE @FinalEnd     DATE          = DATEADD(MONTH, @FinalMonths, @FinalStart);

    UPDATE Contracts SET
        TenantId               = ISNULL(@TenantId,              TenantId),
        StartDate              = @FinalStart,
        Months                 = @FinalMonths,
        EndDate                = @FinalEnd,
        MonthlyTotal           = @FinalMonthly,
        ContractTotal          = @FinalTotal,
        LessorAmount           = ISNULL(@LessorAmount,           LessorAmount),
        Notes                  = ISNULL(@Notes,                  Notes),
        ContractPropertyUsage  = ISNULL(@ContractPropertyUsage,  ContractPropertyUsage),
        ContractBuildingName   = ISNULL(@ContractBuildingName,   ContractBuildingName),
        ContractPropertyType   = ISNULL(@ContractPropertyType,   ContractPropertyType),
        ContractLocation       = ISNULL(@ContractLocation,       ContractLocation),
        ContractPropertyNo     = ISNULL(@ContractPropertyNo,     ContractPropertyNo),
        ContractPropertyArea   = ISNULL(@ContractPropertyArea,   ContractPropertyArea),
        ContractPremisesNo     = ISNULL(@ContractPremisesNo,     ContractPremisesNo),
        ContractPaymentMode    = ISNULL(@ContractPaymentMode,    ContractPaymentMode),
        ContractPlotNo         = ISNULL(@ContractPlotNo,         ContractPlotNo),
        ContractMakaniNo       = ISNULL(@ContractMakaniNo,       ContractMakaniNo),
        UpdatedAt              = GETUTCDATE()
    WHERE ContractId = @ContractId;

    IF @RoomIdsJson IS NOT NULL AND LEN(@RoomIdsJson) > 2
    BEGIN
        UPDATE Rooms SET Occupied=0, Status='Vacant', UpdatedAt=GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM ContractRooms WHERE ContractId = @ContractId);

        DELETE FROM ContractRooms WHERE ContractId = @ContractId;

        INSERT INTO ContractRooms (ContractId, RoomId)
        SELECT @ContractId, RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$');

        UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE()
        WHERE Id IN (SELECT RoomId FROM OPENJSON(@RoomIdsJson) WITH (RoomId INT '$'));
    END
END
GO

PRINT '=== Script 024 completed successfully ===';
