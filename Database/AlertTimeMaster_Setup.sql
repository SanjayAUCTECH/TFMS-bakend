-- ============================================
-- Alert Time Master Setup
-- ============================================

-- Drop existing objects if they exist
IF OBJECT_ID('sp_DeleteAlertTime', 'P') IS NOT NULL DROP PROCEDURE sp_DeleteAlertTime;
IF OBJECT_ID('sp_UpdateAlertTime', 'P') IS NOT NULL DROP PROCEDURE sp_UpdateAlertTime;
IF OBJECT_ID('sp_CreateAlertTime', 'P') IS NOT NULL DROP PROCEDURE sp_CreateAlertTime;
IF OBJECT_ID('sp_GetAlertTimeById', 'P') IS NOT NULL DROP PROCEDURE sp_GetAlertTimeById;
IF OBJECT_ID('sp_GetAlertTimes', 'P') IS NOT NULL DROP PROCEDURE sp_GetAlertTimes;
IF OBJECT_ID('AlertTimeMaster', 'U') IS NOT NULL DROP TABLE AlertTimeMaster;
GO

-- ============================================
-- Create Table: AlertTimeMaster
-- ============================================
CREATE TABLE AlertTimeMaster
(
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    AlertName   NVARCHAR(100) NOT NULL,
    Days        INT NOT NULL DEFAULT 0,
    Status      NVARCHAR(20) NOT NULL DEFAULT 'Active',
    CreatedAt   DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt   DATETIME NOT NULL DEFAULT GETDATE(),
    AddedBy     INT NULL,
    UpdatedBy   INT NULL,
    IsDeleted   BIT NOT NULL DEFAULT 0
);
GO

-- Create index for performance
CREATE INDEX IX_AlertTimeMaster_AlertName ON AlertTimeMaster(AlertName);
CREATE INDEX IX_AlertTimeMaster_IsDeleted ON AlertTimeMaster(IsDeleted);
GO

-- ============================================
-- SP: Get All Alert Times (with pagination)
-- ============================================
CREATE PROCEDURE sp_GetAlertTimes
    @SearchText   NVARCHAR(100) = NULL,
    @Status       NVARCHAR(20) = NULL,
    @PageNumber   INT = 1,
    @PageSize     INT = 10,
    @SortBy       NVARCHAR(50) = 'Id',
    @SortOrder    NVARCHAR(4) = 'ASC',
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Calculate offset
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Get total count
    SELECT @TotalRecords = COUNT(*)
    FROM AlertTimeMaster
    WHERE IsDeleted = 0
        AND (@SearchText IS NULL OR AlertName LIKE '%' + @SearchText + '%')
        AND (@Status IS NULL OR Status = @Status);

    -- Get paginated results
    SELECT 
        Id,
        AlertName,
        Days,
        Status,
        CreatedAt,
        UpdatedAt,
        AddedBy,
        UpdatedBy
    FROM AlertTimeMaster
    WHERE IsDeleted = 0
        AND (@SearchText IS NULL OR AlertName LIKE '%' + @SearchText + '%')
        AND (@Status IS NULL OR Status = @Status)
    ORDER BY 
        CASE WHEN @SortBy = 'Id' AND @SortOrder = 'ASC' THEN Id END ASC,
        CASE WHEN @SortBy = 'Id' AND @SortOrder = 'DESC' THEN Id END DESC,
        CASE WHEN @SortBy = 'AlertName' AND @SortOrder = 'ASC' THEN AlertName END ASC,
        CASE WHEN @SortBy = 'AlertName' AND @SortOrder = 'DESC' THEN AlertName END DESC,
        CASE WHEN @SortBy = 'Days' AND @SortOrder = 'ASC' THEN Days END ASC,
        CASE WHEN @SortBy = 'Days' AND @SortOrder = 'DESC' THEN Days END DESC,
        CASE WHEN @SortBy = 'CreatedAt' AND @SortOrder = 'ASC' THEN CreatedAt END ASC,
        CASE WHEN @SortBy = 'CreatedAt' AND @SortOrder = 'DESC' THEN CreatedAt END DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ============================================
-- SP: Get Alert Time By ID
-- ============================================
CREATE PROCEDURE sp_GetAlertTimeById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Id,
        AlertName,
        Days,
        Status,
        CreatedAt,
        UpdatedAt,
        AddedBy,
        UpdatedBy
    FROM AlertTimeMaster
    WHERE Id = @Id AND IsDeleted = 0;
END
GO

-- ============================================
-- SP: Create Alert Time
-- ============================================
CREATE PROCEDURE sp_CreateAlertTime
    @AlertName  NVARCHAR(100),
    @Days       INT,
    @Status     NVARCHAR(20) = 'Active',
    @AddedBy    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if alert name already exists
    IF EXISTS (SELECT 1 FROM AlertTimeMaster WHERE AlertName = @AlertName AND IsDeleted = 0)
    BEGIN
        SELECT -1 AS Id, 'Alert name already exists.' AS Message;
        RETURN;
    END

    -- Insert new record
    INSERT INTO AlertTimeMaster (AlertName, Days, Status, AddedBy, CreatedAt, UpdatedAt)
    VALUES (@AlertName, @Days, @Status, @AddedBy, GETDATE(), GETDATE());

    -- Return the newly created record
    DECLARE @NewId INT = SCOPE_IDENTITY();
    
    SELECT 
        Id,
        AlertName,
        Days,
        Status,
        CreatedAt,
        UpdatedAt,
        AddedBy,
        UpdatedBy
    FROM AlertTimeMaster
    WHERE Id = @NewId;
END
GO

-- ============================================
-- SP: Update Alert Time
-- ============================================
CREATE PROCEDURE sp_UpdateAlertTime
    @Id         INT,
    @AlertName  NVARCHAR(100),
    @Days       INT,
    @Status     NVARCHAR(20),
    @UpdatedBy  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if record exists
    IF NOT EXISTS (SELECT 1 FROM AlertTimeMaster WHERE Id = @Id AND IsDeleted = 0)
    BEGIN
        SELECT -1 AS Id, 'Alert time not found.' AS Message;
        RETURN;
    END

    -- Check if alert name already exists (excluding current record)
    IF EXISTS (SELECT 1 FROM AlertTimeMaster WHERE AlertName = @AlertName AND Id != @Id AND IsDeleted = 0)
    BEGIN
        SELECT -1 AS Id, 'Alert name already exists.' AS Message;
        RETURN;
    END

    -- Update record
    UPDATE AlertTimeMaster
    SET 
        AlertName = @AlertName,
        Days = @Days,
        Status = @Status,
        UpdatedBy = @UpdatedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @Id;

    -- Return updated record
    SELECT 
        Id,
        AlertName,
        Days,
        Status,
        CreatedAt,
        UpdatedAt,
        AddedBy,
        UpdatedBy
    FROM AlertTimeMaster
    WHERE Id = @Id;
END
GO

-- ============================================
-- SP: Delete Alert Time (Soft Delete)
-- ============================================
CREATE PROCEDURE sp_DeleteAlertTime
    @Id        INT,
    @UpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if record exists
    IF NOT EXISTS (SELECT 1 FROM AlertTimeMaster WHERE Id = @Id AND IsDeleted = 0)
    BEGIN
        SELECT -1 AS Result, 'Alert time not found.' AS Message;
        RETURN;
    END

    -- Soft delete
    UPDATE AlertTimeMaster
    SET 
        IsDeleted = 1,
        UpdatedBy = @UpdatedBy,
        UpdatedAt = GETDATE()
    WHERE Id = @Id;

    SELECT 1 AS Result, 'Alert time deleted successfully.' AS Message;
END
GO

-- ============================================
-- Insert Default Alert Times
-- ============================================
INSERT INTO AlertTimeMaster (AlertName, Days, Status, CreatedAt, UpdatedAt)
VALUES 
    ('Emirates ID Expiry Alert', 30, 'Active', GETDATE(), GETDATE()),
    ('Passport Expiry Alert', 60, 'Active', GETDATE(), GETDATE()),
    ('Visa Expiry Alert', 45, 'Active', GETDATE(), GETDATE()),
    ('Labour Card Expiry Alert', 30, 'Active', GETDATE(), GETDATE()),
    ('Insurance Expiry Alert', 30, 'Active', GETDATE(), GETDATE()),
    ('Contract Renewal Alert', 90, 'Active', GETDATE(), GETDATE());
GO

PRINT 'AlertTimeMaster table and stored procedures created successfully!';
GO
