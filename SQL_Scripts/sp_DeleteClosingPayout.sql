SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ================================================================
-- sp_DeleteClosingPayout
-- Soft-delete ClosingPayout records by ToDate
-- Optional filters: SalonId, StaffId
-- ================================================================
CREATE OR ALTER PROCEDURE sp_DeleteClosingPayout
    @ToDate    DATE,
    @SalonId   INT = NULL,  -- NULL = delete all salons
    @StaffId   INT = NULL,  -- NULL = delete all staff
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ClosingPayout
    SET    IsDeleted  = 1,
           UpdatedAt  = GETDATE()
    WHERE
        ISNULL(IsDeleted, 0) = 0
        AND DateTo = @ToDate
        AND (@SalonId IS NULL OR SalonId = @SalonId)
        AND (@StaffId IS NULL OR StaffId = @StaffId);

    SELECT @@ROWCOUNT AS DeletedCount;
END
GO

PRINT 'sp_DeleteClosingPayout created successfully.';
GO
