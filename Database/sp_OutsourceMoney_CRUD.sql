-- ══════════════════════════════════════════════════════════════════════════════
-- OutsourceMoney Master - Complete CRUD Stored Procedures
-- ══════════════════════════════════════════════════════════════════════════════

USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. CREATE TABLE (Run this first if table doesn't exist)
-- ══════════════════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OutsourceMoney')
BEGIN
    CREATE TABLE OutsourceMoney (
        Id           INT IDENTITY(1,1) PRIMARY KEY,
        Date         DATE NOT NULL,
        Month        NVARCHAR(100) NOT NULL DEFAULT '',
        CampId       INT NOT NULL,
        FundPoolId   INT NOT NULL,
        Amount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        Mode         NVARCHAR(100) NOT NULL DEFAULT '',
        Purpose      NVARCHAR(500) NOT NULL DEFAULT '',
        Remarks      NVARCHAR(1000) NULL,
        ReferenceNo  NVARCHAR(200) NULL,
        CreatedAt    DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedAt    DATETIME NOT NULL DEFAULT GETDATE(),
        AddedBy      INT NULL,
        UpdatedBy    INT NULL,
        IsDeleted    BIT NOT NULL DEFAULT 0,
        
        CONSTRAINT FK_OutsourceMoney_Camp FOREIGN KEY (CampId) REFERENCES Camps(Id),
        CONSTRAINT FK_OutsourceMoney_FundPool FOREIGN KEY (FundPoolId) REFERENCES FundPools(Id)
    );
    
    PRINT 'Table OutsourceMoney created successfully.';
END
ELSE
BEGIN
    PRINT 'Table OutsourceMoney already exists.';
END
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. GET ALL (with pagination and filters)
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetAllOutsourceMoney')
    DROP PROCEDURE sp_GetAllOutsourceMoney;
GO

CREATE PROCEDURE sp_GetAllOutsourceMoney
    @Search     NVARCHAR(200) = '',
    @CampId     INT = NULL,
    @FundPoolId INT = NULL,
    @Mode       NVARCHAR(100) = '',
    @Month      NVARCHAR(100) = '',
    @FromDate   NVARCHAR(20) = '',
    @ToDate     NVARCHAR(20) = '',
    @PageNumber INT = 1,
    @PageSize   INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Main query with pagination
    SELECT 
        om.Id,
        om.Date,
        om.Month,
        om.CampId,
        c.Name AS CampName,
        om.FundPoolId,
        fp.Name AS FundPoolName,
        om.Amount,
        om.Mode,
        om.Purpose,
        om.Remarks,
        om.ReferenceNo,
        om.CreatedAt,
        om.UpdatedAt
    FROM OutsourceMoney om
    LEFT JOIN Camps c ON om.CampId = c.Id
    LEFT JOIN FundPools fp ON om.FundPoolId = fp.Id
    WHERE om.IsDeleted = 0
        AND (@Search = '' OR om.Purpose LIKE '%' + @Search + '%' 
            OR om.Remarks LIKE '%' + @Search + '%'
            OR om.ReferenceNo LIKE '%' + @Search + '%'
            OR c.Name LIKE '%' + @Search + '%'
            OR fp.Name LIKE '%' + @Search + '%')
        AND (@CampId IS NULL OR om.CampId = @CampId)
        AND (@FundPoolId IS NULL OR om.FundPoolId = @FundPoolId)
        AND (@Mode = '' OR om.Mode = @Mode)
        AND (@Month = '' OR om.Month = @Month)
        AND (@FromDate = '' OR om.Date >= CAST(@FromDate AS DATE))
        AND (@ToDate = '' OR om.Date <= CAST(@ToDate AS DATE))
    ORDER BY om.Date DESC, om.Id DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;

    -- Total count
    SELECT COUNT(*) AS TotalCount
    FROM OutsourceMoney om
    LEFT JOIN Camps c ON om.CampId = c.Id
    LEFT JOIN FundPools fp ON om.FundPoolId = fp.Id
    WHERE om.IsDeleted = 0
        AND (@Search = '' OR om.Purpose LIKE '%' + @Search + '%' 
            OR om.Remarks LIKE '%' + @Search + '%'
            OR om.ReferenceNo LIKE '%' + @Search + '%'
            OR c.Name LIKE '%' + @Search + '%'
            OR fp.Name LIKE '%' + @Search + '%')
        AND (@CampId IS NULL OR om.CampId = @CampId)
        AND (@FundPoolId IS NULL OR om.FundPoolId = @FundPoolId)
        AND (@Mode = '' OR om.Mode = @Mode)
        AND (@Month = '' OR om.Month = @Month)
        AND (@FromDate = '' OR om.Date >= CAST(@FromDate AS DATE))
        AND (@ToDate = '' OR om.Date <= CAST(@ToDate AS DATE));
END
GO

PRINT 'sp_GetAllOutsourceMoney created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. GET BY ID
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetOutsourceMoneyById')
    DROP PROCEDURE sp_GetOutsourceMoneyById;
GO

CREATE PROCEDURE sp_GetOutsourceMoneyById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        om.Id,
        om.Date,
        om.Month,
        om.CampId,
        c.Name AS CampName,
        om.FundPoolId,
        fp.Name AS FundPoolName,
        om.Amount,
        om.Mode,
        om.Purpose,
        om.Remarks,
        om.ReferenceNo,
        om.CreatedAt,
        om.UpdatedAt
    FROM OutsourceMoney om
    LEFT JOIN Camps c ON om.CampId = c.Id
    LEFT JOIN FundPools fp ON om.FundPoolId = fp.Id
    WHERE om.Id = @Id AND om.IsDeleted = 0;
END
GO

PRINT 'sp_GetOutsourceMoneyById created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. CREATE
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_CreateOutsourceMoney')
    DROP PROCEDURE sp_CreateOutsourceMoney;
GO

CREATE PROCEDURE sp_CreateOutsourceMoney
    @Date        DATE,
    @Month       NVARCHAR(100),
    @CampId      INT,
    @FundPoolId  INT,
    @Amount      DECIMAL(18,2),
    @Mode        NVARCHAR(100),
    @Purpose     NVARCHAR(500),
    @Remarks     NVARCHAR(1000) = NULL,
    @ReferenceNo NVARCHAR(200) = NULL,
    @AddedBy     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Insert OutsourceMoney record
        INSERT INTO OutsourceMoney (
            Date, Month, CampId, FundPoolId, Amount, Mode, Purpose, 
            Remarks, ReferenceNo, AddedBy, CreatedAt, UpdatedAt
        )
        VALUES (
            @Date, @Month, @CampId, @FundPoolId, @Amount, @Mode, @Purpose,
            @Remarks, @ReferenceNo, @AddedBy, GETDATE(), GETDATE()
        );

        DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);

        -- Deduct amount from FundPool Balance (Expense)
        UPDATE FundPools
        SET Balance = Balance - @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

        COMMIT TRANSACTION;

        -- Return the newly created ID
        SELECT @NewId AS NewId;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_CreateOutsourceMoney created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. UPDATE
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_UpdateOutsourceMoney')
    DROP PROCEDURE sp_UpdateOutsourceMoney;
GO

CREATE PROCEDURE sp_UpdateOutsourceMoney
    @Id          INT,
    @Date        DATE,
    @Month       NVARCHAR(100),
    @CampId      INT,
    @FundPoolId  INT,
    @Amount      DECIMAL(18,2),
    @Mode        NVARCHAR(100),
    @Purpose     NVARCHAR(500),
    @Remarks     NVARCHAR(1000) = NULL,
    @ReferenceNo NVARCHAR(200) = NULL,
    @UpdatedBy   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Get old record details
        DECLARE @OldFundPoolId INT;
        DECLARE @OldAmount DECIMAL(18,2);

        SELECT @OldFundPoolId = FundPoolId, @OldAmount = Amount
        FROM OutsourceMoney
        WHERE Id = @Id AND IsDeleted = 0;

        -- If record doesn't exist, rollback
        IF @OldFundPoolId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Reverse old expense: Add back old amount to old FundPool
        UPDATE FundPools
        SET Balance = Balance + @OldAmount,
            UpdatedAt = GETDATE()
        WHERE Id = @OldFundPoolId;

        -- Update OutsourceMoney record
        UPDATE OutsourceMoney
        SET 
            Date        = @Date,
            Month       = @Month,
            CampId      = @CampId,
            FundPoolId  = @FundPoolId,
            Amount      = @Amount,
            Mode        = @Mode,
            Purpose     = @Purpose,
            Remarks     = @Remarks,
            ReferenceNo = @ReferenceNo,
            UpdatedBy   = @UpdatedBy,
            UpdatedAt   = GETDATE()
        WHERE Id = @Id AND IsDeleted = 0;

        -- Apply new expense: Deduct new amount from new FundPool
        UPDATE FundPools
        SET Balance = Balance - @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_UpdateOutsourceMoney created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. DELETE (Soft Delete)
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_DeleteOutsourceMoney')
    DROP PROCEDURE sp_DeleteOutsourceMoney;
GO

CREATE PROCEDURE sp_DeleteOutsourceMoney
    @Id        INT,
    @UpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Get record details before deletion
        DECLARE @FundPoolId INT;
        DECLARE @Amount DECIMAL(18,2);

        SELECT @FundPoolId = FundPoolId, @Amount = Amount
        FROM OutsourceMoney
        WHERE Id = @Id AND IsDeleted = 0;

        -- If record doesn't exist, rollback
        IF @FundPoolId IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS RowsAffected;
            RETURN;
        END

        -- Soft delete the record
        UPDATE OutsourceMoney
        SET 
            IsDeleted = 1,
            UpdatedBy = @UpdatedBy,
            UpdatedAt = GETDATE()
        WHERE Id = @Id;

        -- Capture the rows affected from OutsourceMoney update
        DECLARE @RowsAffected INT = @@ROWCOUNT;

        -- Add amount back to FundPool (reversing the expense)
        UPDATE FundPools
        SET Balance = Balance + @Amount,
            UpdatedAt = GETDATE()
        WHERE Id = @FundPoolId;

        COMMIT TRANSACTION;

        -- Return the correct rows affected count
        SELECT @RowsAffected AS RowsAffected;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_DeleteOutsourceMoney created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. GET STATISTICS (for dashboard cards)
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetOutsourceMoneyStats')
    DROP PROCEDURE sp_GetOutsourceMoneyStats;
GO

CREATE PROCEDURE sp_GetOutsourceMoneyStats
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalRecords INT;
    DECLARE @TotalAmount DECIMAL(18,2);
    DECLARE @ThisMonthAmount DECIMAL(18,2);
    DECLARE @ThisYearAmount DECIMAL(18,2);

    -- Total Records
    SELECT @TotalRecords = COUNT(*) 
    FROM OutsourceMoney 
    WHERE IsDeleted = 0;

    -- Total Amount (All Time)
    SELECT @TotalAmount = ISNULL(SUM(Amount), 0)
    FROM OutsourceMoney 
    WHERE IsDeleted = 0;

    -- This Month Amount
    SELECT @ThisMonthAmount = ISNULL(SUM(Amount), 0)
    FROM OutsourceMoney 
    WHERE IsDeleted = 0
        AND MONTH(Date) = MONTH(GETDATE())
        AND YEAR(Date) = YEAR(GETDATE());

    -- This Year Amount
    SELECT @ThisYearAmount = ISNULL(SUM(Amount), 0)
    FROM OutsourceMoney 
    WHERE IsDeleted = 0
        AND YEAR(Date) = YEAR(GETDATE());

    -- Return stats
    SELECT 
        @TotalRecords AS TotalRecords,
        @TotalAmount AS TotalAmount,
        @ThisMonthAmount AS ThisMonthAmount,
        @ThisYearAmount AS ThisYearAmount;
END
GO

PRINT 'sp_GetOutsourceMoneyStats created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. ADDITIONAL HELPER PROCEDURE - Get Modes (Distinct)
-- ══════════════════════════════════════════════════════════════════════════════
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetOutsourceMoneyModes')
    DROP PROCEDURE sp_GetOutsourceMoneyModes;
GO

CREATE PROCEDURE sp_GetOutsourceMoneyModes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Mode
    FROM OutsourceMoney
    WHERE IsDeleted = 0 AND Mode IS NOT NULL AND Mode != ''
    ORDER BY Mode;
END
GO

PRINT 'sp_GetOutsourceMoneyModes created successfully.';
GO

-- ══════════════════════════════════════════════════════════════════════════════
-- EXECUTION COMPLETE
-- ══════════════════════════════════════════════════════════════════════════════
PRINT '';
PRINT '══════════════════════════════════════════════════════════════════════════════';
PRINT 'OutsourceMoney Module - All stored procedures created successfully!';
PRINT '══════════════════════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'Created Procedures:';
PRINT '  ✓ sp_GetAllOutsourceMoney     - List with pagination and filters';
PRINT '  ✓ sp_GetOutsourceMoneyById    - Get single record by ID';
PRINT '  ✓ sp_CreateOutsourceMoney     - Create new record';
PRINT '  ✓ sp_UpdateOutsourceMoney     - Update existing record';
PRINT '  ✓ sp_DeleteOutsourceMoney     - Soft delete record';
PRINT '  ✓ sp_GetOutsourceMoneyStats   - Dashboard statistics';
PRINT '  ✓ sp_GetOutsourceMoneyModes   - Get distinct payment modes';
PRINT '';
PRINT 'Table Created/Verified:';
PRINT '  ✓ OutsourceMoney              - Main table with FK to Camps and FundPools';
PRINT '';
PRINT '══════════════════════════════════════════════════════════════════════════════';
GO
