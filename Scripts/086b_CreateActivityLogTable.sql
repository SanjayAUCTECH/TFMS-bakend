-- 086b: Create ActivityLog table (was missing from DB)
USE TFMS_TestSoftwareDB;
GO
IF OBJECT_ID('ActivityLog') IS NULL
BEGIN
  CREATE TABLE ActivityLog (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    ActivityType NVARCHAR(50)  NOT NULL,
    Module       NVARCHAR(100) NOT NULL DEFAULT '',
    Action       NVARCHAR(MAX) NOT NULL DEFAULT '',
    EntityId     NVARCHAR(100) NULL,
    EntityType   NVARCHAR(100) NULL,
    OldValues    NVARCHAR(MAX) NULL,
    NewValues    NVARCHAR(MAX) NULL,
    UserId       INT           NULL,
    UserName     NVARCHAR(200) NULL,
    UserRole     NVARCHAR(100) NULL,
    IpAddress    NVARCHAR(50)  NULL,
    UserAgent    NVARCHAR(MAX) NULL,
    Status       NVARCHAR(50)  NULL DEFAULT 'Success',
    ErrorMessage NVARCHAR(MAX) NULL,
    CreatedAt    DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    AddedBy      INT           NULL,
    UpdatedBy    INT           NULL,
    DeletedBy    INT           NULL,
    IsDeleted    BIT           NOT NULL DEFAULT 0
  );
  PRINT 'ActivityLog table CREATED';
END
ELSE
  PRINT 'ActivityLog table already EXISTS';
GO
