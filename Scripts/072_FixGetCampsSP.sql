-- ============================================================
-- Fix sp_GetCamps — cartesian product bug same as sp_GetCampById
-- Problem: LEFT JOIN CampPartners × LEFT JOIN CampOwners = N×M rows
-- Solution: Return camp list + partners + owners as 3 result sets
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetCamps
    @PageNumber    INT,
    @PageSize      INT,
    @SearchText    NVARCHAR(MAX) = NULL,
    @SortBy        NVARCHAR(MAX) = NULL,
    @SortDirection NVARCHAR(MAX) = 'ASC',
    @Status        NVARCHAR(MAX) = NULL,
    @PartnerId     INT           = NULL,
    @OwnerId       INT           = NULL,
    @TotalRecords  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Count distinct camps
    SELECT @TotalRecords = COUNT(DISTINCT c.Id)
    FROM Camps c
    LEFT JOIN CampPartners cp2 ON cp2.CampId = c.Id
    LEFT JOIN CampOwners   co2 ON co2.CampId = c.Id
    WHERE (@Status     IS NULL OR c.Status = @Status)
      AND (@PartnerId  IS NULL OR cp2.PartnerId = @PartnerId)
      AND (@OwnerId    IS NULL OR co2.OwnerId   = @OwnerId)
      AND (@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%');

    -- Get paged camp IDs
    WITH PagedCamps AS (
        SELECT DISTINCT c.Id
        FROM Camps c
        LEFT JOIN CampPartners cp2 ON cp2.CampId = c.Id
        LEFT JOIN CampOwners   co2 ON co2.CampId = c.Id
        WHERE (@Status     IS NULL OR c.Status = @Status)
          AND (@PartnerId  IS NULL OR cp2.PartnerId = @PartnerId)
          AND (@OwnerId    IS NULL OR co2.OwnerId   = @OwnerId)
          AND (@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%')
        ORDER BY c.Id DESC
        OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
    )

    -- Result Set 1: Camp details only (no partner/owner join)
    SELECT c.Id, c.Code, c.Name, c.Rooms, c.Floors, c.Status,
           c.StartDate, c.EndDate,
           c.CampPropertyUsage, c.CampBuildingName, c.CampPropertyType, c.CampLocation,
           c.CampPropertyNo, c.CampPropertyArea, c.CampPremisesNo, c.CampPlotNo, c.CampMakaniNo,
           c.CreatedAt, c.UpdatedAt
    FROM PagedCamps pc
    JOIN Camps c ON c.Id = pc.Id
    ORDER BY c.Name ASC;

    -- Result Set 2: All partners for those camps
    SELECT cp.CampId, cp.Id AS CampPartnerId, cp.PartnerId,
           p.Name AS PartnerName, cp.ShareType AS PartnerShareType, cp.ShareValue AS PartnerShareValue
    FROM CampPartners cp
    LEFT JOIN Partners p ON p.Id = cp.PartnerId
    WHERE cp.CampId IN (
        SELECT DISTINCT c.Id
        FROM Camps c
        LEFT JOIN CampPartners cp2 ON cp2.CampId = c.Id
        LEFT JOIN CampOwners   co2 ON co2.CampId = c.Id
        WHERE (@Status     IS NULL OR c.Status = @Status)
          AND (@PartnerId  IS NULL OR cp2.PartnerId = @PartnerId)
          AND (@OwnerId    IS NULL OR co2.OwnerId   = @OwnerId)
          AND (@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%')
        ORDER BY c.Id DESC
        OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
    );

    -- Result Set 3: All owners for those camps
    SELECT co.CampId, co.Id AS CampOwnerId, co.OwnerId,
           o.Name AS OwnerName, co.ShareType AS OwnerShareType, co.ShareValue AS OwnerShareValue
    FROM CampOwners co
    LEFT JOIN Owners o ON o.Id = co.OwnerId
    WHERE co.CampId IN (
        SELECT DISTINCT c.Id
        FROM Camps c
        LEFT JOIN CampPartners cp2 ON cp2.CampId = c.Id
        LEFT JOIN CampOwners   co2 ON co2.CampId = c.Id
        WHERE (@Status     IS NULL OR c.Status = @Status)
          AND (@PartnerId  IS NULL OR cp2.PartnerId = @PartnerId)
          AND (@OwnerId    IS NULL OR co2.OwnerId   = @OwnerId)
          AND (@SearchText IS NULL OR c.Name LIKE '%'+@SearchText+'%' OR c.Code LIKE '%'+@SearchText+'%')
        ORDER BY c.Id DESC
        OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
    );
END
GO

PRINT '✅ sp_GetCamps fixed - 3 separate result sets, no cartesian product';
GO
