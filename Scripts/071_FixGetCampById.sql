-- ============================================================
-- Fix sp_GetCampById — cartesian product bug
-- Problem: LEFT JOIN CampPartners × LEFT JOIN CampOwners
--          causes N×M rows (2 partners × 1 owner = owner shown 2x)
-- Solution: 3 separate SELECT statements (camp + partners + owners)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetCampById @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result Set 1: Camp details
    SELECT c.Id, c.Code, c.Name, c.Rooms, c.Floors, c.Status,
           c.StartDate, c.EndDate,
           c.CampPropertyUsage, c.CampBuildingName, c.CampPropertyType, c.CampLocation,
           c.CampPropertyNo, c.CampPropertyArea, c.CampPremisesNo, c.CampPlotNo, c.CampMakaniNo,
           c.CreatedAt, c.UpdatedAt
    FROM Camps c
    WHERE c.Id = @Id;

    -- Result Set 2: Partners
    SELECT cp.Id AS CampPartnerId, cp.PartnerId, p.Name AS PartnerName,
           cp.ShareType AS PartnerShareType, cp.ShareValue AS PartnerShareValue
    FROM CampPartners cp
    LEFT JOIN Partners p ON p.Id = cp.PartnerId
    WHERE cp.CampId = @Id;

    -- Result Set 3: Owners
    SELECT co.Id AS CampOwnerId, co.OwnerId, o.Name AS OwnerName,
           co.ShareType AS OwnerShareType, co.ShareValue AS OwnerShareValue
    FROM CampOwners co
    LEFT JOIN Owners o ON o.Id = co.OwnerId
    WHERE co.CampId = @Id;
END
GO

PRINT '✅ sp_GetCampById fixed - 3 separate result sets, no cartesian product';
GO
