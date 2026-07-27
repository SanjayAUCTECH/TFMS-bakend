-- ============================================================
-- 084: Final fix - sp_CreateContract @AddedBy + Payment SPs IsDeleted=0
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── sp_CreateContract — add @AddedBy (full replacement) ──────────────────
CREATE OR ALTER PROCEDURE sp_CreateContract
    @TenantId              INT,
    @CampIdsJson           NVARCHAR(MAX) = NULL,
    @StartDate             DATE,
    @Months                INT,
    @RoomIdsJson           NVARCHAR(MAX),
    @ContractType          NVARCHAR(MAX) = 'Monthly',
    @SecurityDeposit       DECIMAL(18,2) = 0,
    @InstallmentType       NVARCHAR(MAX) = 'monthly',
    @IssuedBy              NVARCHAR(MAX) = '',
    @Notes                 NVARCHAR(MAX) = '',
    @LessorAmount          DECIMAL(18,2) = 0,
    @MonthlyTotal          DECIMAL(18,2) = NULL,
    @ContractTotal         DECIMAL(18,2) = NULL,
    @ContractPropertyUsage NVARCHAR(MAX) = '',
    @ContractBuildingName  NVARCHAR(MAX) = '',
    @ContractPropertyType  NVARCHAR(MAX) = '',
    @ContractLocation      NVARCHAR(MAX) = '',
    @ContractPropertyNo    NVARCHAR(MAX) = '',
    @ContractPropertyArea  NVARCHAR(MAX) = '',
    @ContractPremisesNo    NVARCHAR(MAX) = '',
    @ContractPaymentMode   NVARCHAR(MAX) = '',
    @ContractPlotNo        NVARCHAR(MAX) = '',
    @ContractMakaniNo      NVARCHAR(MAX) = '',
    @AddedBy               INT = NULL,        -- IsDeleted=0 set in INSERT below
    @NewContractId         NVARCHAR(450) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NewContractId = 'CNT-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id), 0) + 1 FROM Contracts) AS NVARCHAR), 6);
    DECLARE @EndDate DATE = DATEADD(MONTH, @Months, @StartDate);

    -- Parse RoomIds — support BOTH formats
    CREATE TABLE #ParsedRooms (RoomId INT, MonthlyAmount DECIMAL(18,2) NULL, CampId INT NULL);
    IF LOWER(@RoomIdsJson) LIKE '%"roomid"%'
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT j.roomId, j.monthlyAmount, j.campId
        FROM OPENJSON(@RoomIdsJson)
        WITH (roomId INT '$.roomId', monthlyAmount DECIMAL(18,2) '$.monthlyAmount', campId INT '$.campId') j;
    ELSE
        INSERT INTO #ParsedRooms (RoomId, MonthlyAmount, CampId)
        SELECT CAST([value] AS INT), NULL, NULL FROM OPENJSON(@RoomIdsJson);

    -- Resolve CampId from Rooms table if missing
    UPDATE pr SET pr.CampId = r.CampId FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId WHERE pr.CampId IS NULL;

    -- Calculate monthly total
    DECLARE @CalcMonthly DECIMAL(18,2) = 0;
    IF @MonthlyTotal IS NULL OR @MonthlyTotal = 0
        SELECT @CalcMonthly = ISNULL(SUM(CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0
            THEN pr.MonthlyAmount ELSE r.MonthlyPrice END), 0)
        FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId;
    ELSE
        SET @CalcMonthly = @MonthlyTotal;

    DECLARE @FinalTotal DECIMAL(18,2) = ISNULL(@ContractTotal, @CalcMonthly * @Months);

    -- Insert contract with AddedBy and IsDeleted=0
    INSERT INTO Contracts (
        ContractId, TenantId, StartDate, Months, EndDate,
        MonthlyTotal, ContractTotal, SecurityDeposit,
        ContractType, InstallmentType,
        IssuedBy, Notes, LessorAmount,
        ContractPropertyUsage, ContractBuildingName, ContractPropertyType,
        ContractLocation, ContractPropertyNo, ContractPropertyArea,
        ContractPremisesNo, ContractPaymentMode, ContractPlotNo, ContractMakaniNo,
        Status, AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES (
        @NewContractId, @TenantId, @StartDate, @Months, @EndDate,
        @CalcMonthly, @FinalTotal, @SecurityDeposit,
        @ContractType, @InstallmentType,
        @IssuedBy, @Notes, @LessorAmount,
        @ContractPropertyUsage, @ContractBuildingName, @ContractPropertyType,
        @ContractLocation, @ContractPropertyNo, @ContractPropertyArea,
        @ContractPremisesNo, @ContractPaymentMode, @ContractPlotNo, @ContractMakaniNo,
        'Active', @AddedBy, 0, GETUTCDATE(), GETUTCDATE());

    -- Link rooms
    INSERT INTO ContractRooms (ContractId, RoomId, CampId, MonthlyAmount, TotalAmount, PaidAmount, Balance)
    SELECT @NewContractId, pr.RoomId, ISNULL(pr.CampId, r.CampId),
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0 THEN pr.MonthlyAmount ELSE r.MonthlyPrice END,
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0 THEN pr.MonthlyAmount * @Months ELSE r.MonthlyPrice * @Months END,
        0,
        CASE WHEN pr.MonthlyAmount IS NOT NULL AND pr.MonthlyAmount > 0 THEN pr.MonthlyAmount * @Months ELSE r.MonthlyPrice * @Months END
    FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId;

    -- Mark rooms occupied
    UPDATE Rooms SET Occupied=1, Status='Occupied', UpdatedAt=GETUTCDATE() WHERE Id IN (SELECT RoomId FROM #ParsedRooms);

    -- Link camps
    IF @CampIdsJson IS NOT NULL AND LEN(@CampIdsJson) > 2
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT @NewContractId, CAST([value] AS INT) FROM OPENJSON(@CampIdsJson)
        WHERE NOT EXISTS (SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=@NewContractId AND cc.CampId=CAST([value] AS INT));
    ELSE
        INSERT INTO ContractCamps (ContractId, CampId)
        SELECT DISTINCT @NewContractId, ISNULL(pr.CampId, r.CampId)
        FROM #ParsedRooms pr JOIN Rooms r ON r.Id = pr.RoomId
        WHERE ISNULL(pr.CampId, r.CampId) > 0
          AND NOT EXISTS (SELECT 1 FROM ContractCamps cc WHERE cc.ContractId=@NewContractId AND cc.CampId=ISNULL(pr.CampId, r.CampId));

    -- Generate monthly installments
    DECLARE @i INT = 1;
    WHILE @i <= @Months
    BEGIN
        INSERT INTO ContractInstallments (ContractId, InstallmentNo, Amount, DueDate, PaidAmount, Status)
        VALUES (@NewContractId, @i, @CalcMonthly, DATEADD(MONTH, @i-1, @StartDate), 0, 'Pending');
        SET @i += 1;
    END

    -- Auto-generate room-wise installments
    EXEC sp_GenerateContractRoomInstallments @NewContractId;
    DROP TABLE #ParsedRooms;
END
GO

-- ── Payment SPs — add IsDeleted=0 filters ────────────────────────────────
-- Ensure Payments table has IsDeleted column
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Payments') AND name='IsDeleted')
    ALTER TABLE Payments ADD IsDeleted BIT NOT NULL DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Payments') AND name='AddedBy')
    ALTER TABLE Payments ADD AddedBy INT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Payments') AND name='DeletedBy')
    ALTER TABLE Payments ADD DeletedBy INT NULL;
GO

UPDATE Payments SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

CREATE OR ALTER PROCEDURE sp_GetPayments
    @PageNumber INT=1, @PageSize INT=2147483647,
    @ContractId NVARCHAR(MAX)=NULL, @TenantId INT=NULL, @Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0
    WHERE p.IsDeleted=0
        AND (@ContractId IS NULL OR p.ContractId=@ContractId)
        AND (@TenantId IS NULL OR c.TenantId=@TenantId)
        AND (@Status IS NULL OR p.Status=@Status);

    SELECT p.*,c.TenantId,t.Name TenantName FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    WHERE p.IsDeleted=0
        AND (@ContractId IS NULL OR p.ContractId=@ContractId)
        AND (@TenantId IS NULL OR c.TenantId=@TenantId)
        AND (@Status IS NULL OR p.Status=@Status)
    ORDER BY p.DueDate
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPaymentById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT p.* FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0
    WHERE p.Id=@Id AND p.IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPaymentSummary @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) TotalInstallments,
        SUM(CASE WHEN Status='Paid' THEN 1 ELSE 0 END) PaidCount,
        SUM(CASE WHEN Status='Pending' THEN 1 ELSE 0 END) PendingCount,
        SUM(Amount) TotalAmount,
        SUM(PaidAmount) TotalPaid,
        SUM(Amount)-SUM(PaidAmount) TotalDue
    FROM Payments WHERE ContractId=@ContractId AND IsDeleted=0;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPaymentHistory @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT p.* FROM Payments p WHERE p.ContractId=@ContractId AND p.IsDeleted=0 ORDER BY p.DueDate;
END
GO

PRINT '084 - sp_CreateContract has @AddedBy+IsDeleted=0, Payments table patched';
GO
