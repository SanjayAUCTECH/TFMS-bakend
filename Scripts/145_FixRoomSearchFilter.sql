-- ============================================================
-- 145: Fix sp_GetRooms SearchText filter
--      Problem: sirf RoomNo pe search tha
--      Fix: RoomNo + CampName + FloorName + Status pe search
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetRooms
  @PageNumber  INT           = 1,
  @PageSize    INT           = 2147483647,
  @SearchText  NVARCHAR(MAX) = NULL,
  @SortBy      NVARCHAR(MAX) = NULL,
  @SortDirection NVARCHAR(MAX) = 'ASC',
  @Status      NVARCHAR(MAX) = NULL,
  @CampId      INT           = NULL,
  @FloorId     INT           = NULL,
  @RoomStatus  NVARCHAR(MAX) = NULL,
  @TotalRecords INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;

  SELECT @TotalRecords = COUNT(*)
  FROM Rooms r
  LEFT JOIN Camps c ON c.Id=r.CampId AND c.IsDeleted=0
  LEFT JOIN Floors f ON f.Id=r.FloorId AND f.IsDeleted=0
  WHERE r.IsDeleted=0
    AND (@Status IS NULL OR r.Status=@Status)
    AND (@CampId IS NULL OR r.CampId=@CampId)
    AND (@FloorId IS NULL OR r.FloorId=@FloorId)
    AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
    AND (@SearchText IS NULL
         OR r.RoomNo       LIKE '%'+@SearchText+'%'
         OR c.Name         LIKE '%'+@SearchText+'%'
         OR f.Name         LIKE '%'+@SearchText+'%'
         OR r.Status       LIKE '%'+@SearchText+'%'
         OR r.OtherDetails LIKE '%'+@SearchText+'%');

  SELECT r.Id, r.RoomNo, r.CampId, ISNULL(c.Name,'') CampName,
    r.FloorId, ISNULL(f.Name,'') FloorName,
    r.Occupied, r.MonthlyPrice, r.Status, ISNULL(r.OtherDetails,'') OtherDetails,
    r.CreatedAt, r.UpdatedAt, r.AddedBy, r.UpdatedBy
  FROM Rooms r
  LEFT JOIN Camps c ON c.Id=r.CampId AND c.IsDeleted=0
  LEFT JOIN Floors f ON f.Id=r.FloorId AND f.IsDeleted=0
  WHERE r.IsDeleted=0
    AND (@Status IS NULL OR r.Status=@Status)
    AND (@CampId IS NULL OR r.CampId=@CampId)
    AND (@FloorId IS NULL OR r.FloorId=@FloorId)
    AND (@RoomStatus IS NULL OR r.Status=@RoomStatus)
    AND (@SearchText IS NULL
         OR r.RoomNo       LIKE '%'+@SearchText+'%'
         OR c.Name         LIKE '%'+@SearchText+'%'
         OR f.Name         LIKE '%'+@SearchText+'%'
         OR r.Status       LIKE '%'+@SearchText+'%'
         OR r.OtherDetails LIKE '%'+@SearchText+'%')
  ORDER BY c.Name, r.RoomNo
  OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ 145 - sp_GetRooms SearchText fix: ab RoomNo + CampName + FloorName + Status pe search hoga';
GO
