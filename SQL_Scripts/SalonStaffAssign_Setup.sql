-- =============================================
-- SALON STAFF ASSIGN MASTER - SQL Setup Script
-- =============================================

-- -----------------------------------------------
-- 1. CREATE TABLE
-- -----------------------------------------------
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='SalonStaffAssign' AND xtype='U')
BEGIN
    CREATE TABLE SalonStaffAssign (
        AssignId    INT IDENTITY(1,1) PRIMARY KEY,
        SalonId     INT             NOT NULL,
        StaffId     INT             NOT NULL,
        Percentage  DECIMAL(5,2)    NOT NULL DEFAULT 0,
        Description NVARCHAR(500)   NULL,
        Status      NVARCHAR(20)    NOT NULL DEFAULT 'Active',
        IsDeleted   BIT             NOT NULL DEFAULT 0,
        AddedBy     NVARCHAR(100)   NULL,
        UpdatedBy   NVARCHAR(100)   NULL,
        CreatedAt   DATETIME        NOT NULL DEFAULT GETDATE(),
        UpdatedAt   DATETIME        NULL
    );
END;
GO

-- -----------------------------------------------
-- 2. GET ALL (Paginated + Filters + JOIN for Names)
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonStaffAssign
    @PageNumber   INT           = 1,
    @PageSize     INT           = 10,
    @SearchText   NVARCHAR(200) = NULL,
    @SalonId      INT           = NULL,
    @Status       NVARCHAR(20)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- Total count
    SELECT @TotalRecords = COUNT(*)
    FROM SalonStaffAssign   ssa
    JOIN SalonMaster        sm  ON sm.Id      = ssa.SalonId  AND sm.IsDeleted  = 0
    JOIN Staff              st  ON st.StaffId = ssa.StaffId  AND st.IsDeleted  = 0
    WHERE ssa.IsDeleted = 0
      AND (@SalonId    IS NULL OR ssa.SalonId = @SalonId)
      AND (@Status     IS NULL OR ssa.Status  = @Status)
      AND (
            @SearchText IS NULL
            OR sm.Name  LIKE '%' + @SearchText + '%'
            OR st.Name  LIKE '%' + @SearchText + '%'
          );

    -- Paged data
    SELECT
        ssa.AssignId,
        ssa.SalonId,
        sm.Name         AS SalonName,
        ssa.StaffId,
        st.Name         AS StaffName,
        ssa.Percentage,
        ssa.Description,
        ssa.Status,
        ssa.CreatedAt,
        ssa.UpdatedAt
    FROM SalonStaffAssign   ssa
    JOIN SalonMaster        sm  ON sm.Id      = ssa.SalonId  AND sm.IsDeleted  = 0
    JOIN Staff              st  ON st.StaffId = ssa.StaffId  AND st.IsDeleted  = 0
    WHERE ssa.IsDeleted = 0
      AND (@SalonId    IS NULL OR ssa.SalonId = @SalonId)
      AND (@Status     IS NULL OR ssa.Status  = @Status)
      AND (
            @SearchText IS NULL
            OR sm.Name  LIKE '%' + @SearchText + '%'
            OR st.Name  LIKE '%' + @SearchText + '%'
          )
    ORDER BY ssa.CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;
GO

-- -----------------------------------------------
-- 3. GET BY ID
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_GetSalonStaffAssignById
    @AssignId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ssa.AssignId,
        ssa.SalonId,
        sm.Name         AS SalonName,
        ssa.StaffId,
        st.Name         AS StaffName,
        ssa.Percentage,
        ssa.Description,
        ssa.Status,
        ssa.CreatedAt,
        ssa.UpdatedAt
    FROM SalonStaffAssign   ssa
    JOIN SalonMaster        sm  ON sm.Id      = ssa.SalonId  AND sm.IsDeleted  = 0
    JOIN Staff              st  ON st.StaffId = ssa.StaffId  AND st.IsDeleted  = 0
    WHERE ssa.AssignId  = @AssignId
      AND ssa.IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 4. CREATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_CreateSalonStaffAssign
    @SalonId     INT,
    @StaffId     INT,
    @Percentage  DECIMAL(5,2),
    @Description NVARCHAR(500) = NULL,
    @Status      NVARCHAR(20)  = 'Active',
    @AddedBy     NVARCHAR(100) = NULL,
    @NewId       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SalonStaffAssign
        (SalonId, StaffId, Percentage, Description, Status, AddedBy, CreatedAt)
    VALUES
        (@SalonId, @StaffId, @Percentage, @Description, @Status, @AddedBy, GETDATE());

    SET @NewId = SCOPE_IDENTITY();
END;
GO

-- -----------------------------------------------
-- 5. UPDATE
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdateSalonStaffAssign
    @AssignId    INT,
    @SalonId     INT,
    @StaffId     INT,
    @Percentage  DECIMAL(5,2),
    @Description NVARCHAR(500) = NULL,
    @Status      NVARCHAR(20),
    @UpdatedBy   NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonStaffAssign
    SET
        SalonId     = @SalonId,
        StaffId     = @StaffId,
        Percentage  = @Percentage,
        Description = @Description,
        Status      = @Status,
        UpdatedBy   = @UpdatedBy,
        UpdatedAt   = GETDATE()
    WHERE AssignId  = @AssignId
      AND IsDeleted = 0;
END;
GO

-- -----------------------------------------------
-- 6. SOFT DELETE  (IsDeleted = 1)
-- -----------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteSalonStaffAssign
    @AssignId  INT,
    @DeletedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalonStaffAssign
    SET
        IsDeleted = 1,
        UpdatedBy = @DeletedBy,
        UpdatedAt = GETDATE()
    WHERE AssignId = @AssignId;
END;
GO
