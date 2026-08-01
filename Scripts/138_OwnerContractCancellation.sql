-- ============================================================
-- 138: Owner Contract Cancellation
--      + OwnerContractCancellations table
--      + sp_CancelOwnerContract
--      + sp_GetOwnerContractCancellations
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Step 1: Table create karo ─────────────────────────────────
IF OBJECT_ID('OwnerContractCancellations', 'U') IS NULL
BEGIN
    CREATE TABLE OwnerContractCancellations (
        Id                  INT IDENTITY(1,1) PRIMARY KEY,
        CancellationCode    NVARCHAR(50)  NOT NULL DEFAULT '',
        OwnerContractId     INT           NOT NULL,
        OcCode              NVARCHAR(50)  NOT NULL DEFAULT '',
        CampId              INT           NOT NULL DEFAULT 0,
        CampName            NVARCHAR(MAX) NOT NULL DEFAULT '',
        OwnerId             INT           NOT NULL DEFAULT 0,
        OwnerName           NVARCHAR(MAX) NOT NULL DEFAULT '',
        CancellationDate    DATE          NOT NULL,
        Remarks             NVARCHAR(MAX) NULL,
        CancelledBy         NVARCHAR(MAX) NULL,
        CancelledByUserId   INT           NULL,
        Status              NVARCHAR(50)  NOT NULL DEFAULT 'Cancelled',
        IsDeleted           BIT           NOT NULL DEFAULT 0,
        CreatedAt           DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt           DATETIME2     NOT NULL DEFAULT GETUTCDATE()
    );
    PRINT '✅ OwnerContractCancellations table created';
END
ELSE
    PRINT '⚠️ OwnerContractCancellations already exists';
GO

-- ── Step 2: sp_CancelOwnerContract ───────────────────────────
CREATE OR ALTER PROCEDURE sp_CancelOwnerContract
    @OwnerContractId   INT,
    @CancellationDate  NVARCHAR(MAX),
    @Remarks           NVARCHAR(MAX) = NULL,
    @CancelledBy       NVARCHAR(MAX) = NULL,
    @CancelledByUserId INT           = NULL,
    @NewId             INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Check contract exists
    IF NOT EXISTS (SELECT 1 FROM OwnerContracts WHERE Id=@OwnerContractId AND ISNULL(IsDeleted,0)=0)
    BEGIN
        RAISERROR('Owner contract not found.', 16, 1);
        RETURN;
    END

    -- Fetch contract details
    DECLARE @OcCode   NVARCHAR(50),
            @CampId   INT,  @CampName  NVARCHAR(MAX),
            @OwnerId  INT,  @OwnerName NVARCHAR(MAX);

    SELECT @OcCode=OcCode, @CampId=CampId, @CampName=CampName,
           @OwnerId=OwnerId, @OwnerName=OwnerName
    FROM OwnerContracts WHERE Id=@OwnerContractId;

    -- 1. OwnerContract status = Cancelled
    UPDATE OwnerContracts
    SET Status='Cancelled', UpdatedAt=GETUTCDATE()
    WHERE Id=@OwnerContractId;

    -- 2. Pending installments = Cancelled
    UPDATE OwnerInstallments
    SET Status='Cancelled'
    WHERE OwnerContractId=@OwnerContractId
      AND ISNULL(IsDeleted,0)=0
      AND Status='Pending';

    -- 3. Pending monthly installments = Cancelled
    UPDATE OwnerMonthlyContractInstallments
    SET Status='Cancelled', UpdatedAt=GETUTCDATE()
    WHERE OwnerContractId=@OwnerContractId
      AND ISNULL(IsDeleted,0)=0
      AND Status='Pending';

    -- 4. Cancellation record save karo
    DECLARE @CancCode NVARCHAR(50) = CONCAT('OCC-',RIGHT('00000'+CAST(
        (SELECT ISNULL(MAX(Id),0)+1 FROM OwnerContractCancellations) AS NVARCHAR),5));

    INSERT INTO OwnerContractCancellations(
        CancellationCode, OwnerContractId, OcCode,
        CampId, CampName, OwnerId, OwnerName,
        CancellationDate, Remarks, CancelledBy, CancelledByUserId,
        Status, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(
        @CancCode, @OwnerContractId, @OcCode,
        @CampId, @CampName, @OwnerId, @OwnerName,
        CAST(@CancellationDate AS DATE),
        @Remarks, @CancelledBy, @CancelledByUserId,
        'Cancelled', 0, GETUTCDATE(), GETUTCDATE());

    SET @NewId = SCOPE_IDENTITY();

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
PRINT '✅ sp_CancelOwnerContract created';
GO

-- ── Step 3: sp_GetOwnerContractCancellations ─────────────────
CREATE OR ALTER PROCEDURE sp_GetOwnerContractCancellations
    @OwnerContractId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.Id, c.CancellationCode,
        c.OwnerContractId, c.OcCode,
        c.CampId, c.CampName,
        c.OwnerId, c.OwnerName,
        c.CancellationDate,
        c.Remarks, c.CancelledBy, c.CancelledByUserId,
        c.Status, c.CreatedAt, c.UpdatedAt
    FROM OwnerContractCancellations c
    WHERE c.IsDeleted = 0
      AND (@OwnerContractId IS NULL OR c.OwnerContractId = @OwnerContractId)
    ORDER BY c.CreatedAt DESC;
END
GO
PRINT '✅ sp_GetOwnerContractCancellations created';
GO

PRINT '';
PRINT '✅✅ 138 - Owner Contract Cancellation complete!';
GO
