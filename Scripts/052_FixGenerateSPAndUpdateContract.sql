-- ============================================================
-- 052: Fix sp_GenerateContractRoomInstallments (cursor JOIN bug)
--      + Add CRI regeneration to sp_UpdateContract
-- Date: July 21, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. Fix sp_GenerateContractRoomInstallments ────────────────
CREATE OR ALTER PROCEDURE sp_GenerateContractRoomInstallments
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM ContractRoomInstallments WHERE ContractId = @ContractId;

    DECLARE @StartDate DATE, @Months INT;
    SELECT @StartDate = StartDate, @Months = Months
    FROM Contracts WHERE ContractId = @ContractId;

    IF @StartDate IS NULL OR @Months IS NULL OR @Months <= 0
    BEGIN ROLLBACK TRANSACTION; RETURN; END

    DECLARE @RoomId       INT;
    DECLARE @RoomNo       NVARCHAR(MAX);
    DECLARE @MonthlyAmt   DECIMAL(18,2);
    DECLARE @CampId       INT;
    DECLARE @CampName     NVARCHAR(MAX);

    -- ✅ Fixed cursor: proper JOIN Camps ON ca.Id = r.CampId
    -- Use CampId from ContractRooms (set when contract created), fallback to Rooms.CampId
    DECLARE room_cursor CURSOR FOR
        SELECT
            cr.RoomId,
            r.RoomNo,
            ISNULL(cr.MonthlyAmount, r.MonthlyPrice)  MonthlyAmount,
            ISNULL(cr.CampId, r.CampId)               CampId,
            ISNULL(ca.Name, '')                        CampName
        FROM ContractRooms cr
        JOIN Rooms r  ON r.Id  = cr.RoomId
        LEFT JOIN Camps ca ON ca.Id = ISNULL(cr.CampId, r.CampId)
        WHERE cr.ContractId = @ContractId;

    OPEN room_cursor;
    FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmt, @CampId, @CampName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @i INT = 1;
        WHILE @i <= @Months
        BEGIN
            DECLARE @DueDate DATE = DATEADD(MONTH, @i - 1, @StartDate);

            -- Month name + last 2 digits of year: Jun26, Feb27
            DECLARE @MonthName NVARCHAR(10) =
                CASE MONTH(@DueDate)
                    WHEN 1  THEN 'Jan' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                    WHEN 4  THEN 'Apr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                    WHEN 7  THEN 'Jul' WHEN 8  THEN 'Aug' WHEN 9  THEN 'Sep'
                    WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dec'
                END + RIGHT(CAST(YEAR(@DueDate) AS NVARCHAR), 2);

            INSERT INTO ContractRoomInstallments (
                ContractId, CampId, CampName, RoomId, RoomNo,
                InstallmentNo, InstallAmount, DueDate, Month,
                PaymentMode, ReferenceNo, ClearanceDate,
                Status, PaidAmount, PaidDate, CreatedAt, UpdatedAt
            )
            VALUES (
                @ContractId, @CampId, @CampName, @RoomId, @RoomNo,
                @i, @MonthlyAmt, @DueDate, @MonthName,
                '', '', NULL,
                'Pending', 0, NULL, GETDATE(), GETDATE()
            );

            SET @i += 1;
        END

        FETCH NEXT FROM room_cursor INTO @RoomId, @RoomNo, @MonthlyAmt, @CampId, @CampName;
    END

    CLOSE room_cursor;
    DEALLOCATE room_cursor;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── 2. sp_UpdateContract — add CRI regeneration ──────────────
-- Get current SP definition and patch it
DECLARE @spDef NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('sp_UpdateContract'));

IF @spDef IS NOT NULL AND CHARINDEX('sp_GenerateContractRoomInstallments', @spDef) = 0
BEGIN
    -- Add CRI call just before the last END
    DECLARE @patchLine NVARCHAR(MAX) =
        CHAR(13) + CHAR(10) +
        '    -- Regenerate room-wise installments after contract update' + CHAR(13) + CHAR(10) +
        '    EXEC sp_GenerateContractRoomInstallments @ContractId;' + CHAR(13) + CHAR(10);

    -- Find last END position (find 'END' followed only by whitespace till end)
    DECLARE @lastEndPos INT;
    DECLARE @pos INT = 1;
    DECLARE @found INT = 0;

    -- Search for END from end of string backward
    SET @lastEndPos = LEN(@spDef);
    WHILE @lastEndPos > 0
    BEGIN
        IF UPPER(SUBSTRING(@spDef, @lastEndPos - 2, 3)) = 'END'
        BEGIN
            SET @found = 1;
            BREAK;
        END
        SET @lastEndPos -= 1;
    END

    IF @found = 1
    BEGIN
        DECLARE @newDef NVARCHAR(MAX) =
            LEFT(@spDef, @lastEndPos - 3) +
            @patchLine +
            'END';

        SET @newDef = REPLACE(@newDef, 'CREATE PROCEDURE', 'ALTER PROCEDURE');
        SET @newDef = REPLACE(@newDef, 'CREATE   PROCEDURE', 'ALTER PROCEDURE');
        EXEC sp_executesql @newDef;
        PRINT 'sp_UpdateContract patched — CRI regeneration added.';
    END
    ELSE
        PRINT 'sp_UpdateContract: could not find END position.';
END
ELSE IF @spDef IS NULL
    PRINT 'sp_UpdateContract not found.';
ELSE
    PRINT 'sp_UpdateContract already has CRI call.';
GO

-- Verify
SELECT
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID('sp_UpdateContract')) LIKE '%sp_GenerateContractRoomInstallments%'
         THEN 'sp_UpdateContract ✓ has CRI call'
         ELSE 'sp_UpdateContract ✗ missing CRI call'
    END AS UpdateContractStatus,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID('sp_GenerateContractRoomInstallments')) LIKE '%LEFT JOIN Camps ca ON ca.Id%'
         THEN 'sp_GenerateContractRoomInstallments ✓ fixed JOIN'
         ELSE 'sp_GenerateContractRoomInstallments ✗ old JOIN'
    END AS GenerateSPStatus;
GO

PRINT '052 - Done';
GO
