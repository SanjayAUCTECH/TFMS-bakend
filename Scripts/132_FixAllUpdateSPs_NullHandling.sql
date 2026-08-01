-- ============================================================
-- 132: Fix ALL Update SPs — null aaye toh NULL save ho
--      value aaye toh woh save ho
-- Rule: koi bhi default = '' nahi, sab = NULL
-- Date: Aug 1, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ══════════════════════════════════════════════════════════════
-- 1. sp_UpdateTenant
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateTenant
  @Id                  INT,
  @Type                NVARCHAR(MAX) = NULL,
  @Name                NVARCHAR(MAX),
  @Passport            NVARCHAR(MAX) = NULL,
  @Nationality         NVARCHAR(MAX) = NULL,
  @EmiratesId          NVARCHAR(MAX) = NULL,
  @Contact             NVARCHAR(MAX) = NULL,
  @Whatsapp            NVARCHAR(MAX) = NULL,
  @Email               NVARCHAR(MAX) = NULL,
  @Address             NVARCHAR(MAX) = NULL,
  @Status              NVARCHAR(MAX) = 'Active',
  @Company             NVARCHAR(MAX) = NULL,
  @TradeLicense        NVARCHAR(MAX) = NULL,
  @LicensingAuthority  NVARCHAR(MAX) = NULL,
  @NumberOfCoOccupants NVARCHAR(MAX) = NULL,
  @PlotNo              NVARCHAR(MAX) = NULL,
  @MakaniNo            NVARCHAR(MAX) = NULL,
  @PropertyArea        NVARCHAR(MAX) = NULL,
  @PremisesNo          NVARCHAR(MAX) = NULL,
  @LessorName          NVARCHAR(MAX) = NULL,
  @LessorEid           NVARCHAR(MAX) = NULL,
  @LessorLicense       NVARCHAR(MAX) = NULL,
  @LessorLicAuthority  NVARCHAR(MAX) = NULL,
  @LessorEmail         NVARCHAR(MAX) = NULL,
  @LessorPhone         NVARCHAR(MAX) = NULL,
  @UpdatedBy           INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Tenants SET
    Type                = ISNULL(@Type, Type),
    Name                = @Name,
    Passport            = @Passport,
    Nationality         = @Nationality,
    EmiratesId          = @EmiratesId,
    Contact             = @Contact,
    Whatsapp            = @Whatsapp,
    Email               = @Email,
    Address             = @Address,
    Status              = @Status,
    Company             = @Company,
    TradeLicense        = @TradeLicense,
    LicensingAuthority  = @LicensingAuthority,
    NumberOfCoOccupants = @NumberOfCoOccupants,
    PlotNo              = @PlotNo,
    MakaniNo            = @MakaniNo,
    PropertyArea        = @PropertyArea,
    PremisesNo          = @PremisesNo,
    LessorName          = @LessorName,
    LessorEid           = @LessorEid,
    LessorLicense       = @LessorLicense,
    LessorLicAuthority  = @LessorLicAuthority,
    LessorEmail         = @LessorEmail,
    LessorPhone         = @LessorPhone,
    UpdatedBy           = @UpdatedBy,
    UpdatedAt           = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdateTenant fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 2. sp_UpdateOwner
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateOwner
  @Id        INT,
  @Name      NVARCHAR(MAX),
  @Contact   NVARCHAR(MAX) = NULL,
  @Email     NVARCHAR(MAX) = NULL,
  @Status    NVARCHAR(MAX) = 'Active',
  @UpdatedBy INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Owners SET
    Name      = @Name,
    Contact   = @Contact,
    Email     = @Email,
    Status    = @Status,
    UpdatedBy = @UpdatedBy,
    UpdatedAt = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdateOwner fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 3. sp_UpdatePartner
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdatePartner
  @Id        INT,
  @Name      NVARCHAR(MAX),
  @Contact   NVARCHAR(MAX) = NULL,
  @Mobile    NVARCHAR(MAX) = NULL,
  @Email     NVARCHAR(MAX) = NULL,
  @Status    NVARCHAR(MAX) = 'Active',
  @UpdatedBy INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE Partners SET
    Name      = @Name,
    Contact   = @Contact,
    Mobile    = @Mobile,
    Email     = @Email,
    Status    = @Status,
    UpdatedBy = @UpdatedBy,
    UpdatedAt = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdatePartner fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 4. sp_UpdateOtherPerson
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateOtherPerson
  @Id          INT,
  @Designation NVARCHAR(MAX) = NULL,
  @Name        NVARCHAR(MAX),
  @Mobile      NVARCHAR(MAX) = NULL,
  @Email       NVARCHAR(MAX) = NULL,
  @Address     NVARCHAR(MAX) = NULL,
  @City        NVARCHAR(MAX) = NULL,
  @State       NVARCHAR(MAX) = NULL,
  @Pincode     NVARCHAR(MAX) = NULL,
  @Remarks     NVARCHAR(MAX) = NULL,
  @Status      NVARCHAR(MAX) = 'Active',
  @UpdatedBy   INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE OtherPersons SET
    Designation = @Designation,
    Name        = @Name,
    Mobile      = @Mobile,
    Email       = @Email,
    Address     = @Address,
    City        = @City,
    State       = @State,
    Pincode     = @Pincode,
    Remarks     = @Remarks,
    Status      = @Status,
    UpdatedBy   = @UpdatedBy,
    UpdatedAt   = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdateOtherPerson fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 5. sp_UpdateRoom
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateRoom
  @Id           INT,
  @RoomNo       NVARCHAR(MAX),
  @CampId       INT,
  @FloorId      INT,
  @MonthlyPrice DECIMAL(18,2) = 0,
  @Status       NVARCHAR(MAX) = 'Vacant',
  @OtherDetails NVARCHAR(MAX) = NULL,
  @UpdatedBy    INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @OldCampId INT;
  SELECT @OldCampId = CampId FROM Rooms WHERE Id=@Id;
  UPDATE Rooms SET
    RoomNo       = @RoomNo,
    CampId       = @CampId,
    FloorId      = @FloorId,
    MonthlyPrice = @MonthlyPrice,
    Status       = @Status,
    Occupied     = CASE WHEN @Status='Occupied' THEN 1 ELSE 0 END,
    OtherDetails = @OtherDetails,
    UpdatedBy    = @UpdatedBy,
    UpdatedAt    = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
  UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@CampId AND IsDeleted=0) WHERE Id=@CampId;
  IF @OldCampId <> @CampId
    UPDATE Camps SET Rooms=(SELECT COUNT(*) FROM Rooms WHERE CampId=@OldCampId AND IsDeleted=0) WHERE Id=@OldCampId;
END
GO
PRINT '✅ sp_UpdateRoom fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 6. sp_UpdateUser
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateUser
  @Id          INT,
  @Name        NVARCHAR(MAX),
  @Role        NVARCHAR(MAX) = NULL,
  @Source      NVARCHAR(MAX) = NULL,
  @SourceId    INT           = NULL,
  @Contact     NVARCHAR(MAX) = NULL,
  @Email       NVARCHAR(MAX) = NULL,
  @IsAdmin     BIT           = 0,
  @LoginAccess NVARCHAR(MAX) = 'enabled',
  @Status      NVARCHAR(MAX) = 'Active',
  @MenuAccess  NVARCHAR(MAX) = '{}',
  @UpdatedBy   INT           = NULL
AS BEGIN
  SET NOCOUNT ON;
  UPDATE AppUsers SET
    Name        = @Name,
    Role        = @Role,
    Source      = @Source,
    SourceId    = @SourceId,
    Contact     = @Contact,
    Email       = @Email,
    IsAdmin     = @IsAdmin,
    LoginAccess = @LoginAccess,
    Status      = @Status,
    MenuAccess  = @MenuAccess,
    UpdatedBy   = @UpdatedBy,
    UpdatedAt   = GETUTCDATE()
  WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdateUser fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 7. sp_UpdateStaff (same as 131 but included here for completeness)
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateStaff
    @Id          INT,
    @Name        NVARCHAR(MAX),
    @Designation NVARCHAR(MAX) = NULL,
    @Contact     NVARCHAR(MAX) = NULL,
    @Email       NVARCHAR(MAX) = NULL,
    @Address     NVARCHAR(MAX) = NULL,
    @Username    NVARCHAR(MAX) = NULL,
    @Password    NVARCHAR(MAX) = NULL,
    @LoginAccess NVARCHAR(MAX) = 'enabled',
    @Status      NVARCHAR(MAX) = 'Active',
    @Remarks     NVARCHAR(MAX) = NULL,
    @EmiratesId  NVARCHAR(MAX) = NULL,
    @PassportNo  NVARCHAR(MAX) = NULL,
    @Nationality NVARCHAR(MAX) = NULL,
    @JobTitle    NVARCHAR(MAX) = NULL,
    @MoveInDate  DATETIME2     = NULL,
    @VisaExpiry  DATETIME2     = NULL,
    @LabourCardNo    NVARCHAR(MAX) = NULL,
    @DateOfBirth     DATETIME2     = NULL,
    @FitnessExpireDM DATETIME2     = NULL,
    @IloeNo          NVARCHAR(MAX) = NULL,
    @InsuranceNo     NVARCHAR(MAX) = NULL,
    @EmiratesIdIssueDate  DATETIME2     = NULL,
    @EmiratesIdExpiryDate DATETIME2     = NULL,
    @PassportIssueDate    DATETIME2     = NULL,
    @PassportExpiryDate   DATETIME2     = NULL,
    @LabourCardIssueDate  DATETIME2     = NULL,
    @LabourCardExpiryDate DATETIME2     = NULL,
    @IloeIssueDate        DATETIME2     = NULL,
    @IloeExpiryDate       DATETIME2     = NULL,
    @InsuranceIssueDate   DATETIME2     = NULL,
    @InsuranceExpiryDate  DATETIME2     = NULL,
    @EmiratesIdDocument   NVARCHAR(MAX) = NULL,
    @PassportDocument     NVARCHAR(MAX) = NULL,
    @LabourCardDocument   NVARCHAR(MAX) = NULL,
    @IloeDocument         NVARCHAR(MAX) = NULL,
    @InsuranceDocument    NVARCHAR(MAX) = NULL,
    @CompanyId            INT           = NULL,
    @UpdatedBy            INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Staff SET
        Name             = @Name,
        Designation      = @Designation,
        Contact          = @Contact,
        Email            = @Email,
        Address          = @Address,
        Username         = ISNULL(@Username, Username), -- username kabhi blank nahi hona chahiye
        LoginAccess      = @LoginAccess,
        Status           = @Status,
        Remarks          = @Remarks,
        EmiratesId       = @EmiratesId,
        PassportNo       = @PassportNo,
        Nationality      = @Nationality,
        JobTitle         = @JobTitle,
        MoveInDate       = @MoveInDate,
        VisaExpiry       = @VisaExpiry,
        LabourCardNo     = @LabourCardNo,
        DateOfBirth      = @DateOfBirth,
        FitnessExpireDM  = @FitnessExpireDM,
        IloeNo           = @IloeNo,
        InsuranceNo      = @InsuranceNo,
        EmiratesIdIssueDate  = @EmiratesIdIssueDate,
        EmiratesIdExpiryDate = @EmiratesIdExpiryDate,
        PassportIssueDate    = @PassportIssueDate,
        PassportExpiryDate   = @PassportExpiryDate,
        LabourCardIssueDate  = @LabourCardIssueDate,
        LabourCardExpiryDate = @LabourCardExpiryDate,
        IloeIssueDate        = @IloeIssueDate,
        IloeExpiryDate       = @IloeExpiryDate,
        InsuranceIssueDate   = @InsuranceIssueDate,
        InsuranceExpiryDate  = @InsuranceExpiryDate,
        EmiratesIdDocument   = @EmiratesIdDocument,
        PassportDocument     = @PassportDocument,
        LabourCardDocument   = @LabourCardDocument,
        IloeDocument         = @IloeDocument,
        InsuranceDocument    = @InsuranceDocument,
        CompanyId            = @CompanyId,
        UpdatedBy            = @UpdatedBy,
        UpdatedAt            = GETUTCDATE()
    WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE Staff SET Password=@Password WHERE Id=@Id;

    UPDATE AppUsers SET
        Name=@Name, Contact=@Contact, Email=@Email,
        LoginAccess=@LoginAccess, Status=@Status, UpdatedAt=GETUTCDATE()
    WHERE Source='Staff Master' AND SourceId=@Id;

    IF @Password IS NOT NULL AND LEN(@Password) > 0
        UPDATE AppUsers SET PasswordHash=@Password WHERE Source='Staff Master' AND SourceId=@Id;
END
GO
PRINT '✅ sp_UpdateStaff fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 8. sp_UpdateExpense
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateExpense
    @Id            INT,
    @Date          DATE,
    @Mode          NVARCHAR(MAX) = NULL,
    @Head          NVARCHAR(MAX) = NULL,
    @FundPool      NVARCHAR(MAX) = NULL,
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX) = NULL,
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(MAX) = NULL,
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = NULL,
    @Purpose       NVARCHAR(MAX) = NULL,
    @UpdatedBy     INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Expenses SET
        Date          = @Date,
        Mode          = @Mode,
        Head          = @Head,
        FundPool      = @FundPool,
        Amount        = @Amount,
        Nature        = @Nature,
        CampId        = @CampId,
        RecipientRole = @RecipientRole,
        RecipientId   = @RecipientId,
        RecipientName = @RecipientName,
        Purpose       = @Purpose,
        UpdatedBy     = @UpdatedBy,
        UpdatedAt     = GETUTCDATE()
    WHERE Id=@Id AND IsDeleted=0;
END
GO
PRINT '✅ sp_UpdateExpense fixed';
GO

-- ══════════════════════════════════════════════════════════════
-- 9. sp_UpdateIncome
-- ══════════════════════════════════════════════════════════════
CREATE OR ALTER PROCEDURE sp_UpdateIncome
    @Id          INT,
    @Date        DATE,
    @Mode        NVARCHAR(MAX) = NULL,
    @Head        NVARCHAR(MAX) = NULL,
    @FundPool    NVARCHAR(MAX) = NULL,
    @Amount      DECIMAL(18,2),
    @Purpose     NVARCHAR(MAX) = NULL,
    @Source      NVARCHAR(MAX) = NULL,
    @SourceRef   NVARCHAR(MAX) = NULL,
    @CampId      INT           = NULL,
    @CampName    NVARCHAR(MAX) = NULL,
    @PartnerId   INT           = NULL,
    @PartnerName NVARCHAR(MAX) = NULL,
    @UpdatedBy   INT           = NULL
AS BEGIN
    SET NOCOUNT ON;
    UPDATE Incomes SET
        Date        = @Date,
        Mode        = @Mode,
        Head        = @Head,
        FundPool    = @FundPool,
        Amount      = @Amount,
        Purpose     = @Purpose,
        Source      = @Source,
        SourceRef   = @SourceRef,
        CampId      = @CampId,
        CampName    = @CampName,
        PartnerId   = @PartnerId,
        PartnerName = @PartnerName,
        UpdatedBy   = @UpdatedBy,
        UpdatedAt   = GETUTCDATE()
    WHERE Id=@Id AND ISNULL(IsDeleted,0)=0;
END
GO
PRINT '✅ sp_UpdateIncome fixed';
GO

PRINT '';
PRINT '✅✅ 132 - Saare Update SPs fix ho gaye: null aaye = NULL save, value aaye = woh save';
GO
