-- ============================================================
-- 110: Fix sp_DeleteOwnerContract + verify all GET SPs
--
-- Issues fixed:
-- 1. sp_DeleteOwnerContract: soft delete ALL related tables
--    - OwnerContracts (IsDeleted=1)
--    - OwnerInstallments (IsDeleted=1)
--    - OwnerMonthlyContractInstallments (IsDeleted=1)
--    - OwnerTransactions (IsDeleted=1)
-- 2. sp_GetOwnerInstallments: ensure IsDeleted=0 filter
-- 3. sp_GetOwnerContracts: already has IsDeleted=0 ✅
-- 4. sp_GetOwnerTransactions: already has IsDeleted=0 ✅
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Fix sp_DeleteOwnerContract ────────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteOwnerContract
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@Id AND IsDeleted=0)
    BEGIN RAISERROR('OwnerContract %d not found or already deleted.', 16, 1, @Id); RETURN; END

    -- 1. Soft delete OwnerMonthlyContractInstallments
    UPDATE OwnerMonthlyContractInstallments
    SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE OwnerContractId=@Id AND IsDeleted=0;

    -- 2. Soft delete OwnerInstallments
    UPDATE OwnerInstallments
    SET IsDeleted=1, DeletedBy=@DeletedBy
    WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;

    -- 3. Soft delete OwnerTransactions
    UPDATE OwnerTransactions
    SET IsDeleted=1, DeletedBy=@DeletedBy
    WHERE OwnerContractId=@Id AND ISNULL(IsDeleted,0)=0;

    -- 4. Soft delete OwnerContract itself
    UPDATE OwnerContracts
    SET IsDeleted=1, DeletedBy=@DeletedBy, UpdatedAt=GETUTCDATE()
    WHERE Id=@Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_DeleteOwnerContract - now soft deletes all related tables';
GO

-- ── Fix sp_GetOwnerInstallments — ensure IsDeleted=0 ──────────
CREATE OR ALTER PROCEDURE sp_GetOwnerInstallments
    @OcId        INT,
    @PageNumber  INT           = 1,
    @PageSize    INT           = 500,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId
      AND ISNULL(IsDeleted,0)=0              -- ✅ IsDeleted=0 filter
      AND (@Status IS NULL OR Status=@Status);

    SELECT
        Id, OwnerContractId, No AS InstallmentNo,
        Amount AS InstallAmount,
        ISNULL(PaidAmount,0) AS PaidAmount,
        Amount - ISNULL(PaidAmount,0) AS Balance,
        DueDate,
        ISNULL(PaidDate,NULL) AS PaidDate,
        ISNULL(Status,'Pending') AS Status,
        ExpenseId
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId
      AND ISNULL(IsDeleted,0)=0              -- ✅ IsDeleted=0 filter
      AND (@Status IS NULL OR Status=@Status)
    ORDER BY No
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
PRINT '✅ sp_GetOwnerInstallments - IsDeleted=0 filter confirmed';
GO

-- ── Fix sp_GetOwnerMonthlyInstallments (if exists) ────────────
-- Check and create/fix with IsDeleted filter
IF OBJECT_ID('sp_GetOwnerMonthlyInstallments') IS NOT NULL
BEGIN
    EXEC('
    CREATE OR ALTER PROCEDURE sp_GetOwnerMonthlyInstallments
        @OwnerContractId INT,
        @Status NVARCHAR(MAX) = NULL
    AS BEGIN
        SET NOCOUNT ON;
        SELECT Id, MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
               InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
               Status, ExpenseId, PaymentMode, PaymentStatus, CreatedAt, UpdatedAt
        FROM OwnerMonthlyContractInstallments
        WHERE OwnerContractId=@OwnerContractId
          AND ISNULL(IsDeleted,0)=0
          AND (@Status IS NULL OR PaymentStatus=@Status)
        ORDER BY InstallmentNo;
    END');
END
ELSE
BEGIN
    EXEC('
    CREATE PROCEDURE sp_GetOwnerMonthlyInstallments
        @OwnerContractId INT,
        @Status NVARCHAR(MAX) = NULL
    AS BEGIN
        SET NOCOUNT ON;
        SELECT Id, MonthlyContractInstallmentId, OwnerContractId, OwnerId, CampId,
               InstallmentNo, Amount, PaidAmount, Balance, DueDate, PaidDate,
               Status, ExpenseId, PaymentMode, PaymentStatus, CreatedAt, UpdatedAt
        FROM OwnerMonthlyContractInstallments
        WHERE OwnerContractId=@OwnerContractId
          AND ISNULL(IsDeleted,0)=0
          AND (@Status IS NULL OR PaymentStatus=@Status)
        ORDER BY InstallmentNo;
    END');
END
GO
PRINT '✅ sp_GetOwnerMonthlyInstallments - IsDeleted=0 filter set';
GO

-- ── Verify sp_GetOwnerTransactions has IsDeleted=0 ────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerTransactions
    @OwnerId         INT = NULL,
    @CampId          INT = NULL,
    @OwnerContractId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        Id, TxnCode, OwnerContractId, OcCode,
        CampId, CampName, OwnerId, OwnerName,
        Type, Amount, Date, Description,
        InstallmentNos, ExpenseId, CreatedAt
    FROM OwnerTransactions
    WHERE ISNULL(IsDeleted,0)=0              -- ✅ IsDeleted=0 filter
      AND (@OwnerId IS NULL OR OwnerId=@OwnerId)
      AND (@CampId IS NULL OR CampId=@CampId)
      AND (@OwnerContractId IS NULL OR OwnerContractId=@OwnerContractId)
    ORDER BY Id DESC;
END
GO
PRINT '✅ sp_GetOwnerTransactions - IsDeleted=0 confirmed';
GO

-- ── Verify sp_GetOwnerContracts has IsDeleted=0 ───────────────
-- Already correct but re-apply to ensure
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        oc.Id, oc.OcCode, oc.CampId,
        ISNULL(c.Name, oc.CampName)  AS CampName,
        oc.OwnerId,
        ISNULL(o.Name, oc.OwnerName) AS OwnerName,
        ISNULL(o.Code, oc.OwnerCode) AS OwnerCode,
        oc.PaymentType, oc.TotalAmount,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS PaidAmount,
        oc.TotalAmount - ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi
                WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS Balance,
        oc.StartDate, oc.Status, oc.CreatedAt, oc.UpdatedAt,
        oc.AddedBy, oc.UpdatedBy, oc.IsDeleted
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId AND o.IsDeleted=0
    LEFT JOIN Camps  c ON c.Id=oc.CampId  AND c.IsDeleted=0
    WHERE oc.IsDeleted=0                     -- ✅ soft deleted contracts not shown
      AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
      AND (@CampId  IS NULL OR oc.CampId =@CampId)
      AND (@Status  IS NULL OR oc.Status =@Status)
    ORDER BY oc.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOwnerContracts - IsDeleted=0 confirmed';
GO

PRINT '=== ALL OWNER CONTRACT SPs FIXED ===';
GO
