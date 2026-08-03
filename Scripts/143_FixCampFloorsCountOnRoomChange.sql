-- ============================================================
-- 143: Fix Camps.Floors count — Room add/update/delete pe
--      Floors = distinct FloorId count jitne us camp mein use hain
-- Date: Aug 3, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateRoom
  @RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2)=0,
  @Status NVARCHAR(MAX)='Vacant',@OtherDetails NVARCHAR(MAX)=NULL,@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
  VALUES(@RoomNo,@CampId,@FloorId,0,@MonthlyPrice,@Status,@OtherDetails,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
  SET @NewId=SCOPE_IDENTITY();
  UPDATE Camps SET
    Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0),
    Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0)
  WHERE Id=@CampId;
END
GO
PRINT '✅ sp_CreateRoom — Rooms + Floors count update';
GO

CREATE OR ALTER PROCEDURE sp_UpdateRoom
  @Id INT,@RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT,@MonthlyPrice DECIMAL(18,2)=0,
  @Status NVARCHAR(MAX)='Vacant',@OtherDetails NVARCHAR(MAX)=NULL,@UpdatedBy INT=NULL
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @OldCampId INT; SELECT @OldCampId=CampId FROM Rooms WHERE Id=@Id;
  UPDATE Rooms SET RoomNo=@RoomNo,CampId=@CampId,FloorId=@FloorId,MonthlyPrice=@MonthlyPrice,
    Status=@Status,Occupied=CASE WHEN @Status='Occupied' THEN 1 ELSE 0 END,
    OtherDetails=@OtherDetails,UpdatedBy=@UpdatedBy,UpdatedAt=GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
  UPDATE Camps SET
    Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0),
    Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0)
  WHERE Id=@CampId;
  IF @OldCampId<>@CampId
    UPDATE Camps SET
      Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@OldCampId AND IsDeleted=0),
      Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@OldCampId AND IsDeleted=0)
    WHERE Id=@OldCampId;
END
GO
PRINT '✅ sp_UpdateRoom — Rooms + Floors count update';
GO

CREATE OR ALTER PROCEDURE sp_DeleteRoom @Id INT,@DeletedBy INT=NULL AS BEGIN
  SET NOCOUNT ON;
  DECLARE @CampId INT; SELECT @CampId=CampId FROM Rooms WHERE Id=@Id;
  UPDATE Rooms SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
  IF @CampId IS NOT NULL
    UPDATE Camps SET
      Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0),
      Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0)
    WHERE Id=@CampId;
END
GO
PRINT '✅ sp_DeleteRoom — Rooms + Floors count update';
GO

CREATE OR ALTER PROCEDURE sp_BulkCreateRooms
  @CampId INT,@FloorId INT,@RoomsJson NVARCHAR(MAX),@Status NVARCHAR(MAX)='Vacant',
  @Price DECIMAL(18,2)=0,@OtherDetails NVARCHAR(MAX)=''
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @t TABLE(RoomNo NVARCHAR(MAX));
  INSERT INTO @t SELECT value FROM OPENJSON(@RoomsJson);
  DECLARE @created INT=0;
  INSERT INTO Rooms(RoomNo,CampId,FloorId,Occupied,MonthlyPrice,Status,OtherDetails,IsDeleted,CreatedAt,UpdatedAt)
  SELECT RoomNo,@CampId,@FloorId,0,@Price,@Status,@OtherDetails,0,GETUTCDATE(),GETUTCDATE()
  FROM @t WHERE NOT EXISTS(SELECT 1 FROM Rooms r2 WHERE r2.RoomNo=[@t].RoomNo AND r2.CampId=@CampId AND r2.IsDeleted=0);
  SET @created=@@ROWCOUNT;
  UPDATE Camps SET
    Rooms  = (SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0),
    Floors = (SELECT COUNT(DISTINCT FloorId) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0)
  WHERE Id=@CampId;
  SELECT @created AS Created;
END
GO
PRINT '✅ sp_BulkCreateRooms — Rooms + Floors count update';
GO

PRINT '';
PRINT '✅✅ 143 - Camps.Floors count ab properly update hoga jab rooms add/edit/delete honge';
GO
