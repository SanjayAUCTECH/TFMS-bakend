-- ============================================================
-- 081: Final Complete Fix
--      Fix all remaining sp_Create* missing IsDeleted=0/@AddedBy
--      Fix sp_DeleteTxnRecord (was physical, make soft)
--      Fix Report SPs missing IsDeleted=0
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── sp_CreateCamp — add IsDeleted=0 ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateCamp
    @Name NVARCHAR(MAX),@Status NVARCHAR(MAX)='Active',
    @StartDate DATE=NULL,@EndDate DATE=NULL,
    @CampPropertyUsage NVARCHAR(MAX)='',@CampBuildingName NVARCHAR(MAX)='',
    @CampPropertyType NVARCHAR(MAX)='',@CampLocation NVARCHAR(MAX)='',
    @CampPropertyNo NVARCHAR(MAX)='',@CampPropertyArea NVARCHAR(MAX)='',
    @CampPremisesNo NVARCHAR(MAX)='',@CampPlotNo NVARCHAR(MAX)='',
    @CampMakaniNo NVARCHAR(MAX)='',
    @PartnersJson NVARCHAR(MAX)='[]',@OwnersJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX)='CAMP-'+RIGHT('0000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Camps) AS NVARCHAR),4);
    INSERT INTO Camps(Code,Name,Status,StartDate,EndDate,
        CampPropertyUsage,CampBuildingName,CampPropertyType,CampLocation,
        CampPropertyNo,CampPropertyArea,CampPremisesNo,CampPlotNo,CampMakaniNo,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Status,@StartDate,@EndDate,
        @CampPropertyUsage,@CampBuildingName,@CampPropertyType,@CampLocation,
        @CampPropertyNo,@CampPropertyArea,@CampPremisesNo,@CampPlotNo,@CampMakaniNo,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    IF @PartnersJson<>'[]' AND @PartnersJson IS NOT NULL
        INSERT INTO CampPartners(CampId,PartnerId,ShareType,ShareValue)
        SELECT @NewId,p.PartnerId,p.ShareType,p.ShareValue
        FROM OPENJSON(@PartnersJson) WITH(PartnerId INT,ShareType NVARCHAR(50),ShareValue DECIMAL(18,4)) p;
    IF @OwnersJson<>'[]' AND @OwnersJson IS NOT NULL
        INSERT INTO CampOwners(CampId,OwnerId,ShareType,ShareValue)
        SELECT @NewId,o.OwnerId,o.ShareType,o.ShareValue
        FROM OPENJSON(@OwnersJson) WITH(OwnerId INT,ShareType NVARCHAR(50),ShareValue DECIMAL(18,4)) o;
END
GO

-- ── sp_CreatePartner — add IsDeleted=0 ───────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreatePartner
    @Name NVARCHAR(MAX),@Contact NVARCHAR(MAX)='',@Mobile NVARCHAR(MAX)='',
    @Email NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX)='PTR-'+RIGHT('0000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Partners) AS NVARCHAR),4);
    INSERT INTO Partners(Code,Name,Contact,Mobile,Email,Status,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@Name,@Contact,@Mobile,@Email,@Status,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateRoom — add IsDeleted=0 ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateRoom
    @RoomNo NVARCHAR(MAX),@CampId INT,@FloorId INT,
    @MonthlyPrice DECIMAL(18,2)=0,@Status NVARCHAR(MAX)='Vacant',
    @OtherDetails NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Rooms(RoomNo,CampId,FloorId,MonthlyPrice,Status,OtherDetails,
        AddedBy,IsDeleted,Occupied,CreatedAt,UpdatedAt)
    VALUES(@RoomNo,@CampId,@FloorId,@MonthlyPrice,@Status,@OtherDetails,
        @AddedBy,0,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateIncome — add IsDeleted=0 ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateIncome
    @Date DATE,@Mode NVARCHAR(MAX),@Head NVARCHAR(MAX),@FundPool NVARCHAR(MAX),
    @Amount DECIMAL(18,2),@Purpose NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',
    @SourceRef NVARCHAR(MAX)='',@CampId INT=NULL,@CampName NVARCHAR(MAX)='',
    @PartnerId INT=NULL,@PartnerName NVARCHAR(MAX)='',
    @ContractId NVARCHAR(MAX)='',@ContractCode NVARCHAR(MAX)='',
    @TenantId INT=NULL,@TenantName NVARCHAR(MAX)='',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @IncomeId NVARCHAR(MAX)='INC-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),6);
    INSERT INTO Incomes(IncomeId,Date,Mode,Head,FundPool,FundPoolName,Amount,Purpose,Source,SourceRef,
        CampId,CampName,PartnerId,PartnerName,ContractId,ContractCode,TenantId,TenantName,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    SELECT @IncomeId,@Date,@Mode,@Head,@FundPool,fp.Name,@Amount,@Purpose,@Source,@SourceRef,
        @CampId,ISNULL(@CampName,''),@PartnerId,ISNULL(@PartnerName,''),@ContractId,@ContractCode,
        @TenantId,@TenantName,@AddedBy,0,GETUTCDATE(),GETUTCDATE()
    FROM FundPools fp WHERE fp.Code=@FundPool;
    SET @NewId=SCOPE_IDENTITY();
    UPDATE FundPools SET Balance=Balance+@Amount,UpdatedAt=GETUTCDATE() WHERE Code=@FundPool;
END
GO

-- ── sp_CreateStaff — add IsDeleted=0 ─────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateStaff
    @Name NVARCHAR(MAX),@Designation NVARCHAR(MAX)='',@Contact NVARCHAR(MAX)='',
    @Email NVARCHAR(MAX)='',@Address NVARCHAR(MAX)='',
    @Username NVARCHAR(MAX)=NULL,@Password NVARCHAR(MAX)=NULL,
    @LoginAccess NVARCHAR(MAX)='enabled',@Status NVARCHAR(MAX)='Active',
    @Remarks NVARCHAR(MAX)='',@EmiratesId NVARCHAR(MAX)='',
    @PassportNo NVARCHAR(MAX)='',@Nationality NVARCHAR(MAX)='',@JobTitle NVARCHAR(MAX)='',
    @MoveInDate DATE=NULL,@VisaExpiry DATE=NULL,
    @EmiratesIdIssueDate DATE=NULL,@EmiratesIdExpiryDate DATE=NULL,
    @PassportIssueDate DATE=NULL,@PassportExpiryDate DATE=NULL,
    @LabourCardIssueDate DATE=NULL,@LabourCardExpiryDate DATE=NULL,
    @IloeIssueDate DATE=NULL,@IloeExpiryDate DATE=NULL,
    @InsuranceIssueDate DATE=NULL,@InsuranceExpiryDate DATE=NULL,
    @EmiratesIdDocument NVARCHAR(MAX)=NULL,@PassportDocument NVARCHAR(MAX)=NULL,
    @LabourCardDocument NVARCHAR(MAX)=NULL,@IloeDocument NVARCHAR(MAX)=NULL,
    @InsuranceDocument NVARCHAR(MAX)=NULL,
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @StaffId NVARCHAR(MAX)='STF-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Staff) AS NVARCHAR),6);
    INSERT INTO Staff(StaffId,Name,Designation,Contact,Email,Address,Username,Password,
        LoginAccess,Status,Remarks,EmiratesId,PassportNo,Nationality,JobTitle,
        MoveInDate,VisaExpiry,EmiratesIdIssueDate,EmiratesIdExpiryDate,PassportIssueDate,
        PassportExpiryDate,LabourCardIssueDate,LabourCardExpiryDate,IloeIssueDate,IloeExpiryDate,
        InsuranceIssueDate,InsuranceExpiryDate,EmiratesIdDocument,PassportDocument,
        LabourCardDocument,IloeDocument,InsuranceDocument,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@StaffId,@Name,@Designation,@Contact,@Email,@Address,@Username,@Password,
        @LoginAccess,@Status,@Remarks,@EmiratesId,@PassportNo,@Nationality,@JobTitle,
        @MoveInDate,@VisaExpiry,@EmiratesIdIssueDate,@EmiratesIdExpiryDate,@PassportIssueDate,
        @PassportExpiryDate,@LabourCardIssueDate,@LabourCardExpiryDate,@IloeIssueDate,@IloeExpiryDate,
        @InsuranceIssueDate,@InsuranceExpiryDate,@EmiratesIdDocument,@PassportDocument,
        @LabourCardDocument,@IloeDocument,@InsuranceDocument,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateTenant — add IsDeleted=0 ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateTenant
    @Type NVARCHAR(MAX)='Individual',@Name NVARCHAR(MAX),
    @Passport NVARCHAR(MAX)='',@Nationality NVARCHAR(MAX)='',
    @EmiratesId NVARCHAR(MAX)='',@Contact NVARCHAR(MAX)='',
    @Whatsapp NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @Address NVARCHAR(MAX)='',@Status NVARCHAR(MAX)='Active',
    @Company NVARCHAR(MAX)='',@TradeLicense NVARCHAR(MAX)='',
    @LicensingAuthority NVARCHAR(MAX)='',@NumberOfCoOccupants NVARCHAR(MAX)='',
    @PlotNo NVARCHAR(MAX)='',@MakaniNo NVARCHAR(MAX)='',
    @PropertyArea NVARCHAR(MAX)='',@PremisesNo NVARCHAR(MAX)='',
    @LessorName NVARCHAR(MAX)='',@LessorEid NVARCHAR(MAX)='',
    @LessorLicense NVARCHAR(MAX)='',@LessorLicAuthority NVARCHAR(MAX)='',
    @LessorEmail NVARCHAR(MAX)='',@LessorPhone NVARCHAR(MAX)='',
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Tenants(Type,Name,Passport,Nationality,EmiratesId,Contact,Whatsapp,Email,
        Address,Status,Company,TradeLicense,LicensingAuthority,NumberOfCoOccupants,
        PlotNo,MakaniNo,PropertyArea,PremisesNo,LessorName,LessorEid,LessorLicense,
        LessorLicAuthority,LessorEmail,LessorPhone,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Type,@Name,@Passport,@Nationality,@EmiratesId,@Contact,@Whatsapp,@Email,
        @Address,@Status,@Company,@TradeLicense,@LicensingAuthority,@NumberOfCoOccupants,
        @PlotNo,@MakaniNo,@PropertyArea,@PremisesNo,@LessorName,@LessorEid,@LessorLicense,
        @LessorLicAuthority,@LessorEmail,@LessorPhone,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateUser — add IsDeleted=0 ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateUser
    @Name NVARCHAR(MAX),@Username NVARCHAR(MAX),@PasswordHash NVARCHAR(MAX),
    @Role NVARCHAR(MAX)='',@Source NVARCHAR(MAX)='',@SourceId INT=NULL,
    @Contact NVARCHAR(MAX)='',@Email NVARCHAR(MAX)='',
    @IsAdmin BIT=0,@LoginAccess NVARCHAR(MAX)='enabled',@Status NVARCHAR(MAX)='Active',
    @MenuAccess NVARCHAR(MAX)='{}',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @UserId NVARCHAR(MAX)='USR-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM AppUsers) AS NVARCHAR),6);
    INSERT INTO AppUsers(UserId,Name,Username,Password,Role,Source,SourceId,Contact,Email,
        IsAdmin,LoginAccess,Status,MenuAccess,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@UserId,@Name,@Username,@PasswordHash,@Role,@Source,@SourceId,@Contact,@Email,
        @IsAdmin,@LoginAccess,@Status,@MenuAccess,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateWaiver — add IsDeleted=0 ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateWaiver
    @TenantId INT,@ContractId NVARCHAR(MAX),@InstallmentNo INT,
    @OriginalAmount DECIMAL(18,2)=0,@WaiverAmount DECIMAL(18,2),
    @Remark NVARCHAR(MAX)='',@WaiverDate DATE,@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,
        BalanceAmount,Remark,WaiverDate,AddedBy,IsDeleted)
    VALUES(@TenantId,@ContractId,@InstallmentNo,@OriginalAmount,@WaiverAmount,
        @OriginalAmount-@WaiverAmount,@Remark,@WaiverDate,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateTxnRecord — add IsDeleted=0 ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateTxnRecord
    @TxnType NVARCHAR(MAX)='DR',@ContractId NVARCHAR(MAX),@ContractCode NVARCHAR(MAX)='',
    @TenantId INT,@CampId INT,@TotalAmount DECIMAL(18,2),@Amount DECIMAL(18,2),
    @TxnDate DATE,@FromDate DATE=NULL,@ToDate DATE=NULL,
    @PaymentMode NVARCHAR(MAX)='',@PaymentModeId INT=NULL,
    @FundPoolId INT=NULL,@FundPoolName NVARCHAR(MAX)='',
    @Description NVARCHAR(MAX)='',@ReceivedBy NVARCHAR(MAX)='',
    @ChequeNumber NVARCHAR(MAX)='',@InstallmentNo INT=NULL,
    @AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @TxnId NVARCHAR(MAX)='TXN-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),6);
    INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
        TotalAmount,Amount,TxnDate,FromDate,ToDate,PaymentMode,PaymentModeId,
        FundPoolId,FundPoolName,Description,ReceivedBy,ChequeNumber,InstallmentNo,
        AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@TxnId,@TxnType,@ContractId,@ContractCode,@TenantId,@CampId,
        @TotalAmount,@Amount,@TxnDate,@FromDate,@ToDate,@PaymentMode,@PaymentModeId,
        @FundPoolId,@FundPoolName,@Description,@ReceivedBy,@ChequeNumber,@InstallmentNo,
        @AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_CreateCompanyAsset — add IsDeleted=0 ──────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateCompanyAsset
    @AssetType NVARCHAR(MAX)='',@DocumentName NVARCHAR(MAX)='',
    @CompanyName NVARCHAR(MAX)='',@IssueDate DATE=NULL,@ExpiryDate DATE=NULL,
    @Status NVARCHAR(MAX)='Active',@DocumentUrl NVARCHAR(MAX)=NULL,
    @Remarks NVARCHAR(MAX)='',@AddedBy INT=NULL,@NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @Code NVARCHAR(MAX)='AST-'+RIGHT('0000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM CompanyAssets) AS NVARCHAR),4);
    INSERT INTO CompanyAssets(AssetCode,AssetType,DocumentName,CompanyName,IssueDate,ExpiryDate,
        Status,DocumentUrl,Remarks,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@Code,@AssetType,@DocumentName,@CompanyName,@IssueDate,@ExpiryDate,
        @Status,@DocumentUrl,@Remarks,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
END
GO

-- ── sp_DeleteTxnRecord — proper soft delete ──────────────────────────────
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord @Id INT, @DeletedBy INT=NULL AS BEGIN
    SET NOCOUNT ON;
    -- Reverse payment amounts on ContractRooms
    UPDATE cr
    SET cr.PaidAmount=CASE WHEN ISNULL(cr.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-crt.Amount END,
        cr.Balance=ISNULL(cr.TotalAmount,0)-(CASE WHEN ISNULL(cr.PaidAmount,0)-crt.Amount<0 THEN 0 ELSE ISNULL(cr.PaidAmount,0)-crt.Amount END)
    FROM ContractRooms cr
    INNER JOIN ContractRoomsTrns crt ON crt.ContractId=cr.ContractId AND crt.RoomId=cr.RoomId
    WHERE crt.TxnType='CR' AND crt.TxnRecordId=@Id;
    -- Delete ContractRoomsTrns entries for this txn
    DELETE FROM ContractRoomsTrns WHERE TxnType='CR' AND TxnRecordId=@Id;
    -- SOFT delete only
    UPDATE TxnRecords SET IsDeleted=1,DeletedBy=@DeletedBy,UpdatedAt=GETUTCDATE() WHERE Id=@Id;
END
GO

-- ── Report SPs — add IsDeleted=0 filters ─────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDashboardStats
    @CampId INT=NULL,@TenantId INT=NULL,@Month NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM Tenants WHERE IsDeleted=0)                          AS totalTenants,
        (SELECT COUNT(*) FROM Contracts WHERE Status='Active' AND IsDeleted=0)    AS activeContracts,
        (SELECT COUNT(*) FROM Rooms WHERE IsDeleted=0)                            AS totalRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Occupied=1 AND IsDeleted=0)             AS occupiedRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Occupied=0 AND IsDeleted=0)             AS vacantRooms,
        (SELECT ISNULL(SUM(Amount),0) FROM Incomes WHERE IsDeleted=0)             AS totalIncome,
        (SELECT ISNULL(SUM(Amount),0) FROM Expenses WHERE IsDeleted=0)            AS totalExpense;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @Month NVARCHAR(MAX)=NULL,@Year INT=NULL,@CampId INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT t.*,tn.Name TenantName,c.Name CampName
    FROM TxnRecords t
    LEFT JOIN Tenants tn ON tn.Id=t.TenantId AND tn.IsDeleted=0
    LEFT JOIN Camps c ON c.Id=t.CampId AND c.IsDeleted=0
    WHERE t.IsDeleted=0
        AND (@CampId IS NULL OR t.CampId=@CampId)
        AND (@Year IS NULL OR YEAR(t.TxnDate)=@Year)
        AND (@Month IS NULL OR MONTH(t.TxnDate)=CAST(@Month AS INT))
    ORDER BY t.TxnDate DESC,t.Id DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetMisStats
    @CampId INT=NULL,@Month NVARCHAR(MAX)=NULL,@PartnerId INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM Contracts WHERE Status='Active' AND IsDeleted=0 AND (@CampId IS NULL OR CampId=@CampId)) AS activeContracts,
        (SELECT COUNT(*) FROM Rooms WHERE IsDeleted=0 AND (@CampId IS NULL OR CampId=@CampId)) AS totalRooms,
        (SELECT COUNT(*) FROM Rooms WHERE Occupied=1 AND IsDeleted=0 AND (@CampId IS NULL OR CampId=@CampId)) AS occupied,
        (SELECT ISNULL(SUM(Amount),0) FROM Incomes WHERE IsDeleted=0 AND (@CampId IS NULL OR CampId=@CampId)) AS totalIncome,
        (SELECT ISNULL(SUM(Amount),0) FROM Expenses WHERE IsDeleted=0 AND (@CampId IS NULL OR CampId=@CampId)) AS totalExpense;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTransactionReport
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,
    @Type NVARCHAR(MAX)=NULL,@AccountHead NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT 'Income' AS TxnType,i.IncomeId AS TxnId,i.Date,i.Head,i.Amount,i.Mode,i.Purpose,i.FundPool
    FROM Incomes i WHERE i.IsDeleted=0
        AND (@AccountHead IS NULL OR i.Head=@AccountHead)
        AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR i.Date<=CAST(@DateTo AS DATE))
        AND (@Type IS NULL OR @Type='Income')
    UNION ALL
    SELECT 'Expense' AS TxnType,e.ExpenseId AS TxnId,e.Date,e.Head,e.Amount,e.Mode,e.Purpose,e.FundPool
    FROM Expenses e WHERE e.IsDeleted=0
        AND (@AccountHead IS NULL OR e.Head=@AccountHead)
        AND (@DateFrom IS NULL OR e.Date>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR e.Date<=CAST(@DateTo AS DATE))
        AND (@Type IS NULL OR @Type='Expense')
    ORDER BY Date DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetDueReport
    @TenantId INT=NULL,@CampId INT=NULL,@Month NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId,c.Status,t.Name TenantName,
        p.InstallmentNo,p.Amount,p.PaidAmount,p.DueDate,p.Status PaymentStatus
    FROM Contracts c
    JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    JOIN Payments p ON p.ContractId=c.ContractId AND p.Status<>'Paid'
    WHERE c.IsDeleted=0
        AND (@TenantId IS NULL OR c.TenantId=@TenantId)
        AND (@CampId IS NULL OR c.CampId=@CampId)
    ORDER BY p.DueDate;
END
GO

CREATE OR ALTER PROCEDURE sp_GetWaiverReport
    @TenantId INT=NULL,@DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT w.*,t.Name TenantName
    FROM Waivers w
    LEFT JOIN Tenants t ON t.Id=w.TenantId AND t.IsDeleted=0
    WHERE w.IsDeleted=0
        AND (@TenantId IS NULL OR w.TenantId=@TenantId)
        AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR w.WaiverDate<=CAST(@DateTo AS DATE))
    ORDER BY w.WaiverDate DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomHistory @RoomId INT AS BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId,c.StartDate,c.EndDate,c.Status,
           t.Name TenantName,t.Contact,r.RoomNo
    FROM ContractRooms cr
    JOIN Contracts c ON c.ContractId=cr.ContractId AND c.IsDeleted=0
    JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    JOIN Rooms r ON r.Id=cr.RoomId AND r.IsDeleted=0
    WHERE cr.RoomId=@RoomId
    ORDER BY c.StartDate DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomTransactions
    @ContractId NVARCHAR(MAX)=NULL,@RoomId INT=NULL,
    @TxnDate NVARCHAR(MAX)=NULL,@TxnRecordId INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT crt.*,r.RoomNo,c.Name CampName
    FROM ContractRoomsTrns crt
    JOIN Rooms r ON r.Id=crt.RoomId AND r.IsDeleted=0
    LEFT JOIN Camps c ON c.Id=crt.CampId AND c.IsDeleted=0
    WHERE (@ContractId IS NULL OR crt.ContractId=@ContractId)
        AND (@RoomId IS NULL OR crt.RoomId=@RoomId)
        AND (@TxnRecordId IS NULL OR crt.TxnRecordId=@TxnRecordId)
        AND (@TxnDate IS NULL OR CONVERT(NVARCHAR(10),crt.TxnDate,23)=@TxnDate)
    ORDER BY crt.TxnDate DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTenantLedger
    @TenantId INT,@ContractId NVARCHAR(MAX)=NULL,
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT t.Name TenantName,
        p.InstallmentNo,p.Amount,p.PaidAmount,p.DueDate,p.Status,p.PaidDate,
        c.ContractId,c.StartDate,c.EndDate
    FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId AND c.IsDeleted=0
    JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    WHERE c.TenantId=@TenantId
        AND (@ContractId IS NULL OR p.ContractId=@ContractId)
        AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR p.DueDate<=CAST(@DateTo AS DATE))
    ORDER BY p.DueDate;
END
GO

CREATE OR ALTER PROCEDURE sp_GetCampCollectionReport
    @CampId INT=NULL,@PartnerId INT=NULL,
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT c.Name CampName,i.Amount,i.Date,i.Head,i.Purpose,i.Mode,i.PartnerName
    FROM Incomes i
    LEFT JOIN Camps c ON c.Id=i.CampId AND c.IsDeleted=0
    WHERE i.IsDeleted=0
        AND (@CampId IS NULL OR i.CampId=@CampId)
        AND (@PartnerId IS NULL OR i.PartnerId=@PartnerId)
        AND (@DateFrom IS NULL OR i.Date>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR i.Date<=CAST(@DateTo AS DATE))
    ORDER BY i.Date DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_GetRoomWiseCollectionReport
    @CampId INT=NULL,@DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT r.RoomNo,c.Name CampName,
        ISNULL(SUM(crt.Amount),0) Collected
    FROM Rooms r
    LEFT JOIN Camps c ON c.Id=r.CampId AND c.IsDeleted=0
    LEFT JOIN ContractRoomsTrns crt ON crt.RoomId=r.Id AND crt.TxnType='CR'
        AND (@DateFrom IS NULL OR crt.TxnDate>=CAST(@DateFrom AS DATE))
        AND (@DateTo IS NULL OR crt.TxnDate<=CAST(@DateTo AS DATE))
    WHERE r.IsDeleted=0
        AND (@CampId IS NULL OR r.CampId=@CampId)
    GROUP BY r.RoomNo,c.Name
    ORDER BY c.Name,r.RoomNo;
END
GO

CREATE OR ALTER PROCEDURE sp_GetTenantReportSummary
    @Status NVARCHAR(MAX)=NULL,@CampId INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT t.Id,t.Name,t.Contact,t.Status,t.Type,
        COUNT(c.Id) AS ContractCount,
        ISNULL(SUM(c.ContractTotal),0) AS TotalContractValue
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.IsDeleted=0
    WHERE t.IsDeleted=0
        AND (@Status IS NULL OR t.Status=@Status)
        AND (@CampId IS NULL OR c.CampId=@CampId)
    GROUP BY t.Id,t.Name,t.Contact,t.Status,t.Type
    ORDER BY t.Name;
END
GO

CREATE OR ALTER PROCEDURE sp_GetOwnerReport @Status NVARCHAR(MAX)=NULL AS BEGIN
    SET NOCOUNT ON;
    SELECT o.*,
        ISNULL((SELECT SUM(TotalAmount) FROM OwnerContracts WHERE OwnerId=o.Id AND IsDeleted=0),0) TotalContracted,
        ISNULL((SELECT SUM(PaidAmount)  FROM OwnerContracts WHERE OwnerId=o.Id AND IsDeleted=0),0) TotalPaid
    FROM Owners o WHERE o.IsDeleted=0
        AND (@Status IS NULL OR o.Status=@Status)
    ORDER BY o.Name;
END
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerReport @Status NVARCHAR(MAX)=NULL AS BEGIN
    SET NOCOUNT ON;
    SELECT p.*,
        ISNULL((SELECT COUNT(DISTINCT CampId) FROM CampPartners WHERE PartnerId=p.Id),0) CampsAssigned
    FROM Partners p WHERE p.IsDeleted=0
        AND (@Status IS NULL OR p.Status=@Status)
    ORDER BY p.Name;
END
GO

PRINT '081 - All Create SPs fixed with IsDeleted=0, sp_DeleteTxnRecord soft delete, Report SPs IsDeleted=0';
GO
