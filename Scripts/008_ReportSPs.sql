USE TFMS_softwareDB;
GO

-- ── INVENTORY REPORT ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetInventoryReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @Status NVARCHAR(30)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Rooms r
    JOIN Camps ca ON ca.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId
    WHERE (@CampId IS NULL OR r.CampId=@CampId) AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%' OR ca.Name LIKE '%'+@SearchText+'%');

    SELECT r.Id RoomId, r.RoomNo, ca.Name CampName, f.Name FloorName,
           r.Status, r.Occupied, r.MonthlyPrice, r.OtherDetails,
           ISNULL(t.Name,'') TenantName,
           ISNULL(c.ContractId,'') ContractId,
           ISNULL(c.Status,'') ContractStatus
    FROM Rooms r
    JOIN Camps ca ON ca.Id=r.CampId JOIN Floors f ON f.Id=r.FloorId
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN Tenants t ON t.Id=c.TenantId
    WHERE (@CampId IS NULL OR r.CampId=@CampId) AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%' OR ca.Name LIKE '%'+@SearchText+'%')
    ORDER BY ca.Name, r.RoomNo
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── TENANT REPORT ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @Status NVARCHAR(20)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%');

    SELECT t.Id TenantId, t.Name TenantName, t.Contact, t.Email, t.EmiratesId, t.Nationality,
           t.Status, ISNULL(c.ContractId,'') ContractId, ISNULL(ca.Name,'') CampName,
           ISNULL(r.RoomNo,'') RoomNo, c.StartDate ContractStart, c.EndDate ContractEnd,
           ISNULL(c.Status,'') ContractStatus, ISNULL(c.MonthlyTotal,0) MonthlyRent,
           ISNULL((SELECT SUM(PaidAmount) FROM Payments WHERE ContractId=c.ContractId),0) TotalPaid,
           ISNULL((SELECT SUM(Amount)     FROM Payments WHERE ContractId=c.ContractId),0) TotalDue,
           ISNULL((SELECT SUM(Amount-PaidAmount) FROM Payments WHERE ContractId=c.ContractId AND Status IN('Pending','Partial')),0) Balance
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN Camps ca ON ca.Id=c.CampId
    LEFT JOIN ContractRooms cr ON cr.ContractId=c.ContractId
    LEFT JOIN Rooms r ON r.Id=cr.RoomId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
    ORDER BY t.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── PARTNER REPORT ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @Status NVARCHAR(20)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Partners p
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%');

    SELECT p.Id PartnerId, p.Code PartnerCode, p.Name PartnerName,
           p.Contact, p.Mobile, p.Status,
           COUNT(DISTINCT cp.CampId) TotalCamps,
           ISNULL(STRING_AGG(c.Name,', '),'') CampNames,
           ISNULL(AVG(cp.ShareValue),0) ShareValue,
           ISNULL(MAX(cp.ShareType),'') ShareType
    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id
    LEFT JOIN Camps c ON c.Id=cp.CampId
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
    GROUP BY p.Id,p.Code,p.Name,p.Contact,p.Mobile,p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── CAMP REPORT ───────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetCampReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @Status NVARCHAR(20)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Camps ca
    WHERE (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%' OR ca.Code LIKE '%'+@SearchText+'%');

    SELECT ca.Id CampId, ca.Code CampCode, ca.Name CampName, ca.Status,
           COUNT(DISTINCT r.Id) TotalRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Vacant'   THEN r.Id END) VacantRooms,
           COUNT(DISTINCT CASE WHEN c.Status='Active'   THEN c.Id END) ActiveContracts,
           ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN r.MonthlyPrice ELSE 0 END),0) TotalMonthlyRent,
           ISNULL((SELECT SUM(PaidAmount) FROM Payments p2 JOIN Contracts c2 ON c2.ContractId=p2.ContractId WHERE c2.CampId=ca.Id AND p2.Status='Paid'),0) TotalCollected,
           ISNULL((SELECT SUM(Amount)     FROM Payments p3 JOIN Contracts c3 ON c3.ContractId=p3.ContractId WHERE c3.CampId=ca.Id AND p3.Status='Pending'),0) TotalDue
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN Contracts c ON c.CampId=ca.Id
    WHERE (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%' OR ca.Code LIKE '%'+@SearchText+'%')
    GROUP BY ca.Id,ca.Code,ca.Name,ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── WAIVER REPORT ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetWaiverReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @TenantId INT=NULL, @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Waivers w JOIN Tenants t ON t.Id=w.TenantId
    WHERE (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR w.WaiverDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%');

    SELECT w.Id WaiverId, w.TenantId, t.Name TenantName, w.ContractId,
           w.InstallmentNo, w.OriginalAmount, w.WaiverAmount, w.BalanceAmount,
           w.Remark, w.WaiverDate
    FROM Waivers w JOIN Tenants t ON t.Id=w.TenantId
    WHERE (@TenantId IS NULL OR w.TenantId=@TenantId)
      AND (@DateFrom IS NULL OR w.WaiverDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR w.WaiverDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR w.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY w.WaiverDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── TENANT LEDGER ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantLedger
    @TenantId INT, @ContractId NVARCHAR(20)=NULL,
    @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Result set 1: Summary
    SELECT t.Name TenantName, t.Contact,
        ISNULL((SELECT SUM(Amount)     FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId WHERE c.TenantId=@TenantId AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) TotalDebit,
        ISNULL((SELECT SUM(PaidAmount) FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId WHERE c.TenantId=@TenantId AND p.Status='Paid' AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) TotalCredit,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId WHERE c.TenantId=@TenantId AND p.Status IN('Pending','Partial') AND (@ContractId IS NULL OR p.ContractId=@ContractId)),0) NetBalance
    FROM Tenants t WHERE t.Id=@TenantId;

    -- Result set 2: Ledger rows
    SELECT p.DueDate [Date],
           'Rent Due - Installment #'+CAST(p.InstallmentNo AS NVARCHAR) Description,
           'Debit' [Type], p.Amount Debit, 0 Credit, 0 Balance,
           p.ContractId, p.InstallmentNo, '' PaymentMode, '' Reference
    FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId
    WHERE c.TenantId=@TenantId
      AND (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.DueDate<=CAST(@DateTo   AS DATE))
    UNION ALL
    SELECT p.PaidDate [Date],
           'Payment Received - Installment #'+CAST(p.InstallmentNo AS NVARCHAR) Description,
           'Credit' [Type], 0 Debit, p.PaidAmount Credit, 0 Balance,
           p.ContractId, p.InstallmentNo, p.PaymentMode, p.ChequeNumber Reference
    FROM Payments p JOIN Contracts c ON c.ContractId=p.ContractId
    WHERE c.TenantId=@TenantId AND p.Status='Paid'
      AND (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@DateFrom IS NULL OR p.PaidDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.PaidDate<=CAST(@DateTo   AS DATE))
    ORDER BY [Date], InstallmentNo;
END
GO

-- ── TRANSACTION STATEMENT ─────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @ContractId NVARCHAR(20)=NULL, @TenantId INT=NULL, @CampId INT=NULL,
    @Status NVARCHAR(20)=NULL, @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL,
    @Month NVARCHAR(20)=NULL, @Year NVARCHAR(6)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId JOIN Tenants t ON t.Id=c.TenantId
    JOIN Camps ca ON ca.Id=c.CampId
    WHERE (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@TenantId   IS NULL OR c.TenantId=@TenantId)
      AND (@CampId     IS NULL OR c.CampId=@CampId)
      AND (@Status     IS NULL OR p.Status=@Status)
      AND (@Month IS NULL OR DATENAME(MONTH,p.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(p.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR p.ContractId LIKE '%'+@SearchText+'%');

    SELECT p.Id, ISNULL(p.PaidDate,p.DueDate) [Date], p.ContractId,
           t.Name TenantName, ca.Name CampName,
           ISNULL((SELECT TOP 1 r.RoomNo FROM ContractRooms cr JOIN Rooms r ON r.Id=cr.RoomId WHERE cr.ContractId=p.ContractId),'') RoomNo,
           p.InstallmentNo, p.Amount, p.PaidAmount,
           (p.Amount-p.PaidAmount) Balance,
           p.PaymentMode, p.Status, p.ReceivedBy, p.FundPoolName, p.ChequeNumber
    FROM Payments p
    JOIN Contracts c ON c.ContractId=p.ContractId JOIN Tenants t ON t.Id=c.TenantId
    JOIN Camps ca ON ca.Id=c.CampId
    WHERE (@ContractId IS NULL OR p.ContractId=@ContractId)
      AND (@TenantId   IS NULL OR c.TenantId=@TenantId)
      AND (@CampId     IS NULL OR c.CampId=@CampId)
      AND (@Status     IS NULL OR p.Status=@Status)
      AND (@Month IS NULL OR DATENAME(MONTH,p.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(p.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR p.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR p.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR p.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY p.DueDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── ROOM HISTORY ──────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetRoomHistory @RoomId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId, t.Name TenantName,
           c.StartDate, c.EndDate, c.MonthlyTotal MonthlyRent, c.Status
    FROM ContractRooms cr
    JOIN Contracts c ON c.ContractId=cr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    WHERE cr.RoomId=@RoomId
    ORDER BY c.StartDate DESC;
END
GO

-- ── MAKE PAYMENT (Outgoing) ───────────────────────────────────
-- Table for outgoing payments
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='OutgoingPayments')
CREATE TABLE OutgoingPayments (
    Id            INT IDENTITY(1,1) PRIMARY KEY,
    PaymentCode   NVARCHAR(20)  NOT NULL UNIQUE,
    PaymentType   NVARCHAR(30)  NOT NULL DEFAULT '',
    RecipientId   INT           NULL,
    RecipientName NVARCHAR(200) NOT NULL DEFAULT '',
    Amount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    PaymentDate   DATE          NOT NULL,
    PaymentModeId INT           NULL,
    PaymentMode   NVARCHAR(50)  NOT NULL DEFAULT '',
    Description   NVARCHAR(500) NOT NULL DEFAULT '',
    FundPoolId    INT           NULL,
    FundPoolName  NVARCHAR(200) NOT NULL DEFAULT '',
    Reference     NVARCHAR(100) NOT NULL DEFAULT '',
    CampId        INT           NULL,
    AccountHeadId NVARCHAR(20)  NOT NULL DEFAULT '',
    CreatedAt     DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt     DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);
GO

CREATE OR ALTER PROCEDURE sp_MakePayment
    @PaymentType NVARCHAR(30), @RecipientId INT=NULL, @RecipientName NVARCHAR(200),
    @Amount DECIMAL(18,2), @PaymentDate DATE,
    @PaymentModeId INT=NULL, @PaymentMode NVARCHAR(50),
    @Description NVARCHAR(500), @FundPoolId INT=NULL,
    @Reference NVARCHAR(100), @CampId INT=NULL, @AccountHeadId NVARCHAR(20)=NULL,
    @NewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PaymentCode NVARCHAR(20)='OUT-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OutgoingPayments) AS NVARCHAR),6);
    DECLARE @FundPoolName NVARCHAR(200)=ISNULL((SELECT Name FROM FundPools WHERE Id=@FundPoolId),'');
    INSERT INTO OutgoingPayments(PaymentCode,PaymentType,RecipientId,RecipientName,Amount,PaymentDate,PaymentModeId,PaymentMode,Description,FundPoolId,FundPoolName,Reference,CampId,AccountHeadId,CreatedAt,UpdatedAt)
    VALUES(@PaymentCode,@PaymentType,@RecipientId,@RecipientName,@Amount,@PaymentDate,@PaymentModeId,@PaymentMode,@Description,@FundPoolId,@FundPoolName,@Reference,@CampId,ISNULL(@AccountHeadId,''),GETUTCDATE(),GETUTCDATE());
    SET @NewId=SCOPE_IDENTITY();
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance=Balance-@Amount,UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;
END
GO

CREATE OR ALTER PROCEDURE sp_GetOutgoingPayments
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(200)=NULL,
    @DateFrom NVARCHAR(20)=NULL, @DateTo NVARCHAR(20)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OutgoingPayments
    WHERE (@DateFrom IS NULL OR PaymentDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR PaymentDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR RecipientName LIKE '%'+@SearchText+'%' OR PaymentCode LIKE '%'+@SearchText+'%');

    SELECT Id,PaymentCode,PaymentType,RecipientName,Amount,PaymentDate,
           PaymentMode,Description,FundPoolName,Reference,CreatedAt
    FROM OutgoingPayments
    WHERE (@DateFrom IS NULL OR PaymentDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR PaymentDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR RecipientName LIKE '%'+@SearchText+'%' OR PaymentCode LIKE '%'+@SearchText+'%')
    ORDER BY PaymentDate DESC, Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'Script 008 completed!';
GO
