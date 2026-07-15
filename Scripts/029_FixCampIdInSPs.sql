-- ============================================================
-- Script 029: Fix ALL SPs referencing Contracts.CampId
-- CampId removed from Contracts (Script 027).
-- Now: JOIN ContractCamps cc ON cc.ContractId = c.ContractId
--      and use cc.CampId instead of c.CampId
-- ============================================================

-- ── sp_GetDashboardStats ─────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDashboardStats
    @CampId   INT = NULL,
    @TenantId INT = NULL,
    @Year     INT = NULL,
    @Month    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ThisMonth INT = ISNULL(@Month, MONTH(GETUTCDATE()));
    DECLARE @ThisYear  INT = ISNULL(@Year,  YEAR(GETUTCDATE()));

    SELECT
        (SELECT COUNT(*) FROM Camps  WHERE Status='Active' AND (@CampId IS NULL OR Id=@CampId))                     AS TotalCamps,
        (SELECT COUNT(*) FROM Rooms  WHERE (@CampId IS NULL OR CampId=@CampId))                                      AS TotalRooms,
        (SELECT COUNT(*) FROM Rooms  WHERE Status='Occupied' AND (@CampId IS NULL OR CampId=@CampId))                AS OccupiedRooms,
        (SELECT COUNT(*) FROM Rooms  WHERE Status='Vacant'   AND (@CampId IS NULL OR CampId=@CampId))                AS VacantRooms,
        (SELECT COUNT(*) FROM Tenants WHERE Status='Active')                                                          AS TotalTenants,
        -- Active contracts filtered via ContractCamps
        (SELECT COUNT(DISTINCT c.Id) FROM Contracts c
         LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
         WHERE c.Status='Active'
           AND (@CampId IS NULL OR cc.CampId=@CampId)
           AND (@TenantId IS NULL OR c.TenantId=@TenantId))                                                          AS ActiveContracts,
        -- Monthly revenue from paid installments
        ISNULL((SELECT SUM(ci.PaidAmount)
                FROM ContractInstallments ci
                JOIN Contracts c ON c.ContractId=ci.ContractId
                LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
                WHERE ci.Status='Paid'
                  AND MONTH(ci.PaidDate)=@ThisMonth AND YEAR(ci.PaidDate)=@ThisYear
                  AND (@CampId IS NULL OR cc.CampId=@CampId)),0)                                                     AS MonthlyRevenue,
        ISNULL((SELECT SUM(ci2.Amount)
                FROM ContractInstallments ci2
                JOIN Contracts c2 ON c2.ContractId=ci2.ContractId
                LEFT JOIN ContractCamps cc2 ON cc2.ContractId=c2.ContractId
                WHERE ci2.Status IN('Pending','Partial','Overdue')
                  AND (@CampId IS NULL OR cc2.CampId=@CampId)),0)                                                    AS TotalOutstanding;

    -- Camp occupancy breakdown
    SELECT ca.Id CampId, ca.Name CampName,
           COUNT(r.Id) TotalRooms,
           SUM(CASE WHEN r.Status='Occupied' THEN 1 ELSE 0 END) OccupiedRooms,
           SUM(CASE WHEN r.Status='Vacant'   THEN 1 ELSE 0 END) VacantRooms
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id, ca.Name ORDER BY ca.Name;

    -- Monthly collections (last 6 months)
    SELECT FORMAT(ci.PaidDate,'MMM yyyy') [Month],
           SUM(ci.PaidAmount) Collected,
           SUM(ci.Amount) Due
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@CampId IS NULL OR cc.CampId=@CampId)
      AND ci.PaidDate >= DATEADD(MONTH,-5,DATEFROMPARTS(@ThisYear,@ThisMonth,1))
    GROUP BY FORMAT(ci.PaidDate,'MMM yyyy'), YEAR(ci.PaidDate), MONTH(ci.PaidDate)
    ORDER BY YEAR(ci.PaidDate), MONTH(ci.PaidDate);

    -- Camp revenue
    SELECT ca.Id CampId, ca.Name CampName,
           ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) Revenue
    FROM Camps ca
    LEFT JOIN ContractCamps cc ON cc.CampId=ca.Id
    LEFT JOIN Contracts c ON c.ContractId=cc.ContractId AND c.Status='Active'
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
        AND MONTH(ci.DueDate)=@ThisMonth AND YEAR(ci.DueDate)=@ThisYear
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id, ca.Name ORDER BY Revenue DESC;
END
GO

-- ── sp_GetTenants ─────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenants
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @SortBy NVARCHAR(MAX)=NULL,
    @SortDirection NVARCHAR(MAX)='ASC', @Status NVARCHAR(MAX)=NULL,
    @CampId INT=NULL, @TenantType NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status     IS NULL OR t.Status=@Status)
      AND (@TenantType IS NULL OR t.Type=@TenantType)
      AND (@CampId     IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.EmiratesId LIKE '%'+@SearchText+'%');
    SELECT DISTINCT t.Id,t.Name,t.Type,t.Contact,t.Email,t.Whatsapp,
           t.EmiratesId,t.Passport,t.Nationality,t.Address,
           t.Company,t.TradeLicense,t.LicensingAuthority,t.NumberOfCoOccupants,
           t.PlotNo,t.MakaniNo,t.PropertyArea,t.PremisesNo,
           t.LessorName,t.LessorEid,t.LessorLicense,t.LessorLicAuthority,t.LessorEmail,t.LessorPhone,
           t.Status,t.CreatedAt,t.UpdatedAt
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status     IS NULL OR t.Status=@Status)
      AND (@TenantType IS NULL OR t.Type=@TenantType)
      AND (@CampId     IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%'
                               OR t.Contact LIKE '%'+@SearchText+'%'
                               OR t.EmiratesId LIKE '%'+@SearchText+'%')
    ORDER BY t.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetTenantReport ───────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%');
    SELECT t.Id TenantId, t.Name TenantName, t.Contact, t.Email, t.EmiratesId, t.Nationality,
           t.Status, ISNULL(t.Type,'Individual') [Type],
           ISNULL(c.ContractId,'') ContractId,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id),'') CampName,
           ISNULL((SELECT STRING_AGG(r2.RoomNo,', ') FROM ContractRooms cr2 JOIN Rooms r2 ON r2.Id=cr2.RoomId WHERE cr2.ContractId=c.ContractId),'') RoomNo,
           c.StartDate ContractStart, c.EndDate ContractEnd,
           ISNULL(c.Status,'') ContractStatus, ISNULL(c.MonthlyTotal,0) MonthlyRent,
           ISNULL(c.ContractTotal,0) TotalAmount,
           ISNULL((SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId=c.ContractId),0) RoomsBooked,
           ISNULL((SELECT SUM(ci.PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId),0) TotalPaid,
           ISNULL((SELECT SUM(ci.Amount-ci.PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status IN('Pending','Partial')),0) TotalDue,
           ISNULL(c.ContractTotal,0)-ISNULL((SELECT SUM(ci2.PaidAmount) FROM ContractInstallments ci2 WHERE ci2.ContractId=c.ContractId),0) Balance,
           ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w WHERE w.ContractId=c.ContractId),0) WaiverAmount
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
    ORDER BY t.Name, c.ContractId
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetPayments ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPayments
    @PageNumber INT,@PageSize INT,@SearchText NVARCHAR(MAX)=NULL,
    @SortBy NVARCHAR(MAX)=NULL,@SortDirection NVARCHAR(MAX)='ASC',
    @ContractId NVARCHAR(MAX)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
    @Month NVARCHAR(MAX)=NULL,@Year NVARCHAR(MAX)=NULL,
    @PaymentStatus NVARCHAR(MAX)=NULL,@PaymentModeId INT=NULL,
    @DateFrom NVARCHAR(MAX)=NULL,@DateTo NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT ci.Id)
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    LEFT JOIN ContractRooms cr ON cr.ContractId=ci.ContractId
    LEFT JOIN Rooms r ON r.Id=cr.RoomId
    LEFT JOIN Floors f ON f.Id=r.FloorId
    WHERE (@ContractId    IS NULL OR ci.ContractId=@ContractId)
      AND (@TenantId      IS NULL OR c.TenantId=@TenantId)
      AND (@CampId        IS NULL OR cc.CampId=@CampId)
      AND (@PaymentStatus IS NULL OR ci.Status=@PaymentStatus)
      AND (@PaymentModeId IS NULL OR ci.PaymentModeId=@PaymentModeId)
      AND (@Month IS NULL OR DATENAME(MONTH,ci.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(ci.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR ci.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR ci.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR ci.ContractId LIKE '%'+@SearchText+'%');
    SELECT DISTINCT ci.Id,ci.ContractId,t.Name TenantName,'' TenantCode,
           ISNULL(r.RoomNo,'') RoomNo,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=ci.ContractId ORDER BY cc2.Id),'') CampName,
           ISNULL(f.Name,'') FloorName,
           ci.InstallmentNo,ci.Amount,ci.DueDate,ci.PaidAmount,(ci.Amount-ci.PaidAmount) BalanceAmount,
           ci.PaidDate,ci.Status,ci.PaymentMode,ci.PaymentModeId,ci.ChequeNumber,ci.ClearanceDate,
           ci.Description,ci.ReceivedBy,ci.ReceivedContact,ci.FundPoolId,ci.FundPoolName,ci.IssuedBy
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    LEFT JOIN ContractRooms cr ON cr.ContractId=ci.ContractId
    LEFT JOIN Rooms r ON r.Id=cr.RoomId
    LEFT JOIN Floors f ON f.Id=r.FloorId
    WHERE (@ContractId    IS NULL OR ci.ContractId=@ContractId)
      AND (@TenantId      IS NULL OR c.TenantId=@TenantId)
      AND (@CampId        IS NULL OR cc.CampId=@CampId)
      AND (@PaymentStatus IS NULL OR ci.Status=@PaymentStatus)
      AND (@PaymentModeId IS NULL OR ci.PaymentModeId=@PaymentModeId)
      AND (@Month IS NULL OR DATENAME(MONTH,ci.DueDate)=@Month)
      AND (@Year  IS NULL OR CAST(YEAR(ci.DueDate) AS NVARCHAR)=@Year)
      AND (@DateFrom IS NULL OR ci.DueDate>=CAST(@DateFrom AS DATE))
      AND (@DateTo   IS NULL OR ci.DueDate<=CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR ci.ContractId LIKE '%'+@SearchText+'%')
    ORDER BY ci.DueDate ASC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetPaymentById ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPaymentById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT ci.Id,ci.ContractId,t.Name TenantName,'' TenantCode,
           ISNULL(r.RoomNo,'') RoomNo,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=ci.ContractId ORDER BY cc2.Id),'') CampName,
           ISNULL(f.Name,'') FloorName,
           ci.InstallmentNo,ci.Amount,ci.DueDate,ci.PaidAmount,(ci.Amount-ci.PaidAmount) BalanceAmount,
           ci.PaidDate,ci.Status,ci.PaymentMode,ci.PaymentModeId,ci.ChequeNumber,ci.ClearanceDate,
           ci.Description,ci.ReceivedBy,ci.ReceivedContact,ci.FundPoolId,ci.FundPoolName,ci.IssuedBy
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractRooms cr ON cr.ContractId=ci.ContractId
    LEFT JOIN Rooms r ON r.Id=cr.RoomId
    LEFT JOIN Floors f ON f.Id=r.FloorId
    WHERE ci.Id=@Id;
END
GO

-- ── sp_GetPaymentSummary ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary @ContractId NVARCHAR(MAX) AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId, c.TenantId, t.Name TenantName, t.Contact TenantContact,
           ISNULL((SELECT TOP 1 cc2.CampId FROM ContractCamps cc2 WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id),0) CampId,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id),'') CampName,
           CONVERT(NVARCHAR(MAX),c.StartDate,23) StartDate, CONVERT(NVARCHAR(MAX),c.EndDate,23) EndDate,
           c.Months, c.ContractTotal, c.MonthlyTotal, ISNULL(c.LessorAmount,0) LessorAmount, c.Status,
           COUNT(ci.Id) TotalInstallments,
           SUM(CASE WHEN ci.Status='Paid'    THEN 1 ELSE 0 END) PaidCount,
           SUM(CASE WHEN ci.Status IN('Pending','Overdue') THEN 1 ELSE 0 END) PendingCount,
           SUM(CASE WHEN ci.Status='Partial' THEN 1 ELSE 0 END) PartialCount,
           ISNULL(SUM(ci.PaidAmount),0) TotalPaid,
           ISNULL(SUM(CASE WHEN ci.Status IN('Pending','Overdue','Partial') THEN ci.Amount-ci.PaidAmount ELSE 0 END),0) TotalDue,
           ISNULL(SUM(ci.Amount),0) TotalScheduled,
           ISNULL(MIN(CASE WHEN ci.Status IN('Pending','Overdue','Partial') THEN ci.Amount-ci.PaidAmount END),0) NextInstallmentDue,
           MIN(CASE WHEN ci.Status IN('Pending','Overdue','Partial') THEN ci.InstallmentNo END) NextInstallmentNo,
           ISNULL((SELECT STRING_AGG(r2.RoomNo,', ') FROM ContractRooms cr2 JOIN Rooms r2 ON r2.Id=cr2.RoomId WHERE cr2.ContractId=c.ContractId),'') RoomNos,
           (SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId=c.ContractId) RoomCount
    FROM Contracts c
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
    WHERE c.ContractId=@ContractId
    GROUP BY c.ContractId,c.TenantId,t.Name,t.Contact,c.StartDate,c.EndDate,c.Months,c.ContractTotal,c.MonthlyTotal,c.LessorAmount,c.Status;
END
GO

-- ── sp_GetPaymentHistory ──────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory @ContractId NVARCHAR(MAX) AS
BEGIN
    SET NOCOUNT ON;
    SELECT ci.Id,ci.ContractId,ci.InstallmentNo,ci.Amount,ci.DueDate,ci.PaidAmount,ci.PaidDate,
           ci.Status,ci.PaymentMode,ci.PaymentModeId,ci.ChequeNumber,ci.ClearanceDate,
           ci.Description,ci.ReceivedBy,ci.ReceivedContact,ci.FundPoolId,ci.FundPoolName,ci.IssuedBy,
           t.Name TenantName,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=ci.ContractId ORDER BY cc2.Id),'') CampName
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    WHERE ci.ContractId=@ContractId
    ORDER BY ci.InstallmentNo;
END
GO

-- ── sp_RecordPayment — fix CampId read ───────────────────────
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId      NVARCHAR(MAX),
    @InstallmentNo   INT           = 0,
    @PaidAmount      DECIMAL(18,2),
    @PaidDate        DATE,
    @PaymentModeId   INT           = NULL,
    @PaymentMode     NVARCHAR(MAX) = '',
    @ChequeNumber    NVARCHAR(MAX) = '',
    @ClearanceDate   NVARCHAR(MAX) = '',
    @Description     NVARCHAR(MAX) = '',
    @ReceivedBy      NVARCHAR(MAX) = '',
    @ReceivedContact NVARCHAR(MAX) = '',
    @FundPoolId      INT           = NULL,
    @FundPoolName    NVARCHAR(MAX) = '',
    @IssuedBy        NVARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Contracts WHERE ContractId=@ContractId)
        BEGIN RAISERROR('Contract %s not found.',16,1,@ContractId); RETURN; END

        -- Get TenantId, CampId from ContractCamps
        DECLARE @TenantId INT, @CampId INT;
        SELECT @TenantId=TenantId FROM Contracts WHERE ContractId=@ContractId;
        SELECT TOP 1 @CampId=CampId FROM ContractCamps WHERE ContractId=@ContractId ORDER BY Id;

        CREATE TABLE #Pending (InstallmentNo INT, Amount DECIMAL(18,2), PaidAmount DECIMAL(18,2), Due DECIMAL(18,2));
        INSERT INTO #Pending
        SELECT InstallmentNo,Amount,PaidAmount,Amount-PaidAmount
        FROM ContractInstallments
        WHERE ContractId=@ContractId AND Status IN('Pending','Partial','Overdue') AND (Amount-PaidAmount)>0
          AND (@InstallmentNo=0 OR InstallmentNo>=@InstallmentNo)
        ORDER BY InstallmentNo;

        IF NOT EXISTS (SELECT 1 FROM #Pending)
        BEGIN DROP TABLE #Pending; RAISERROR('No pending installments found for contract %s.',16,1,@ContractId); RETURN; END

        DECLARE @Remaining DECIMAL(18,2)=@PaidAmount, @AppliedList NVARCHAR(MAX)='';
        DECLARE @CurNo INT,@CurAmt DECIMAL(18,2),@CurPaid DECIMAL(18,2),@CurDue DECIMAL(18,2);
        DECLARE @ToApply DECIMAL(18,2),@NewPaid DECIMAL(18,2),@NewStatus NVARCHAR(MAX);

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT InstallmentNo,Amount,PaidAmount,Due FROM #Pending ORDER BY InstallmentNo;
        OPEN cur; FETCH NEXT FROM cur INTO @CurNo,@CurAmt,@CurPaid,@CurDue;

        WHILE @@FETCH_STATUS=0 AND @Remaining>0
        BEGIN
            SET @ToApply=CASE WHEN @Remaining>=@CurDue THEN @CurDue ELSE @Remaining END;
            SET @NewPaid=@CurPaid+@ToApply;
            SET @NewStatus=CASE WHEN @NewPaid>=@CurAmt THEN 'Paid' WHEN @NewPaid>0 THEN 'Partial' ELSE 'Pending' END;
            UPDATE ContractInstallments
            SET PaidAmount=@NewPaid,PaidDate=@PaidDate,Status=@NewStatus,
                PaymentModeId=@PaymentModeId,PaymentMode=@PaymentMode,ChequeNumber=@ChequeNumber,
                ClearanceDate=@ClearanceDate,Description=@Description,ReceivedBy=@ReceivedBy,
                ReceivedContact=@ReceivedContact,FundPoolId=@FundPoolId,FundPoolName=@FundPoolName,IssuedBy=@IssuedBy
            WHERE ContractId=@ContractId AND InstallmentNo=@CurNo;
            SET @AppliedList=CASE WHEN @AppliedList='' THEN CAST(@CurNo AS NVARCHAR) ELSE @AppliedList+','+CAST(@CurNo AS NVARCHAR) END;
            SET @Remaining=@Remaining-@ToApply;
            FETCH NEXT FROM cur INTO @CurNo,@CurAmt,@CurPaid,@CurDue;
        END;
        CLOSE cur; DEALLOCATE cur; DROP TABLE #Pending;

        IF @FundPoolId IS NOT NULL AND @PaidAmount>0
            UPDATE FundPools SET Balance=Balance+@PaidAmount,UpdatedAt=GETUTCDATE() WHERE Id=@FundPoolId;

        DECLARE @TxnId NVARCHAR(MAX)='TXN-'+CONVERT(NVARCHAR(MAX),@PaidDate,112)+'-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),6);
        DECLARE @Unallocated DECIMAL(18,2)=CASE WHEN @Remaining>0 THEN @Remaining ELSE 0 END;

        INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
            TotalAmount,Amount,PaidDate,PaymentMode,PaymentModeId,ChequeNumber,Description,
            IssuedBy,ReceivedBy,ReceivedContact,FundPoolId,FundPoolName,AppliedInstallments,Unallocated,InstallmentNo,CreatedAt,UpdatedAt)
        VALUES(@TxnId,'CR',@ContractId,@ContractId,@TenantId,ISNULL(@CampId,0),
            @PaidAmount,@PaidAmount,@PaidDate,@PaymentMode,@PaymentModeId,@ChequeNumber,@Description,
            @IssuedBy,@ReceivedBy,@ReceivedContact,@FundPoolId,@FundPoolName,@AppliedList,@Unallocated,
            CASE WHEN CHARINDEX(',',@AppliedList)>0 THEN CAST(LEFT(@AppliedList,CHARINDEX(',',@AppliedList)-1) AS INT)
                 WHEN @AppliedList<>'' THEN CAST(@AppliedList AS INT) ELSE NULL END,
            GETUTCDATE(),GETUTCDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#Pending') IS NOT NULL DROP TABLE #Pending;
        THROW;
    END CATCH
END
GO

-- ── sp_GetTxnRecords — fix c.CampId → ContractCamps join ─────
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber INT, @PageSize INT,
    @ContractId NVARCHAR(MAX)=NULL,@TenantId INT=NULL,@CampId INT=NULL,
    @TxnType NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId   IS NULL OR c.TenantId=@TenantId)
      AND (@CampId     IS NULL OR cc.CampId=@CampId)
      AND (@TxnType    IS NULL OR tr.TxnType=@TxnType);
    SELECT tr.Id,tr.TxnId,tr.TxnType,tr.ContractId,tr.ContractCode,
           c.TenantId, t.Name TenantName,
           ISNULL(tr.CampId,ISNULL((SELECT TOP 1 cc2.CampId FROM ContractCamps cc2 WHERE cc2.ContractId=tr.ContractId ORDER BY cc2.Id),0)) CampId,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc3 JOIN Camps ca2 ON ca2.Id=cc3.CampId WHERE cc3.ContractId=tr.ContractId ORDER BY cc3.Id),'') CampName,
           tr.TotalAmount,tr.Amount,tr.PaidDate TxnDate,tr.FromDate,tr.ToDate,
           tr.PaymentMode,tr.PaymentModeId,tr.FundPoolId,tr.FundPoolName,
           tr.Description,tr.ReceivedBy,tr.InstallmentNo,tr.AppliedInstallments,tr.Unallocated,
           tr.CreatedAt,tr.UpdatedAt
    FROM TxnRecords tr
    JOIN Contracts c ON c.ContractId=tr.ContractId
    JOIN Tenants t ON t.Id=c.TenantId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@ContractId IS NULL OR tr.ContractId=@ContractId)
      AND (@TenantId   IS NULL OR c.TenantId=@TenantId)
      AND (@CampId     IS NULL OR cc.CampId=@CampId)
      AND (@TxnType    IS NULL OR tr.TxnType=@TxnType)
    ORDER BY tr.PaidDate DESC, tr.Id DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetMisStats ────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetMisStats
    @CampId INT=NULL, @Month NVARCHAR(MAX)=NULL, @PartnerId INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL(SUM(ci.Amount),0) TotalRental,
        ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) TotalCollected,
        ISNULL(SUM(CASE WHEN ci.Status='Pending' THEN ci.Amount ELSE 0 END),0) TotalOutstanding,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO') AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0) TotalExpenses,
        ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) - ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE (@CampId IS NULL OR (e.Nature='Camp' AND e.CampId=@CampId) OR e.Nature='HO') AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)),0) NetProfit,
        COUNT(DISTINCT r.Id) TotalUnits,
        COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedUnits,
        COUNT(DISTINCT CASE WHEN r.Status='Vacant'   THEN r.Id END) VacantUnits,
        CASE WHEN COUNT(r.Id)>0 THEN CAST(COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END)*100.0/COUNT(r.Id) AS DECIMAL(5,1)) ELSE 0 END OccupancyPct
    FROM Rooms r
    JOIN Camps ca ON ca.Id=r.CampId
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
        AND (@Month IS NULL OR LEFT(CAST(ci.DueDate AS NVARCHAR),7)=@Month)
    WHERE (@CampId IS NULL OR r.CampId=@CampId)
      AND (@PartnerId IS NULL OR r.CampId IN (SELECT CampId FROM CampPartners WHERE PartnerId=@PartnerId));

    SELECT ca.Id CampId, ca.Name CampName,
           COUNT(DISTINCT r.Id) TotalRooms,
           COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
           ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN r.MonthlyPrice ELSE 0 END),0) MonthlyRevenue,
           ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) TotalCollected,
           ISNULL(SUM(CASE WHEN ci.Status='Pending' THEN ci.Amount ELSE 0 END),0) TotalOutstanding
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active'
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId AND (@Month IS NULL OR LEFT(CAST(ci.DueDate AS NVARCHAR),7)=@Month)
    WHERE ca.Status='Active' AND (@CampId IS NULL OR ca.Id=@CampId)
    GROUP BY ca.Id,ca.Name ORDER BY ca.Name;

    SELECT FORMAT(ci.DueDate,'MMM yyyy') [Month],
           ISNULL(SUM(CASE WHEN ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) Collected,
           ISNULL(SUM(ci.Amount),0) Due, 0 Expenses, 0 NetProfit
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
    WHERE (@CampId IS NULL OR cc.CampId=@CampId)
      AND ci.DueDate >= DATEADD(MONTH,-11,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))
    GROUP BY FORMAT(ci.DueDate,'MMM yyyy'),YEAR(ci.DueDate),MONTH(ci.DueDate)
    ORDER BY YEAR(ci.DueDate),MONTH(ci.DueDate);

    SELECT e.Head, SUM(e.Amount) Amount
    FROM Expenses e
    WHERE (@CampId IS NULL OR e.Nature='HO' OR (e.Nature='Camp' AND e.CampId=@CampId))
      AND (@Month IS NULL OR LEFT(CAST(e.Date AS NVARCHAR),7)=@Month)
    GROUP BY e.Head ORDER BY Amount DESC;
END
GO

-- ── sp_GetCampReport — fix c.CampId references ───────────────
CREATE OR ALTER PROCEDURE sp_GetCampReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
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
           ISNULL((SELECT SUM(ci2.PaidAmount) FROM ContractInstallments ci2 JOIN ContractCamps cc2 ON cc2.ContractId=ci2.ContractId WHERE cc2.CampId=ca.Id AND ci2.Status='Paid'),0) TotalCollected,
           ISNULL((SELECT SUM(ci3.Amount)     FROM ContractInstallments ci3 JOIN ContractCamps cc3 ON cc3.ContractId=ci3.ContractId WHERE cc3.CampId=ca.Id AND ci3.Status='Pending'),0) TotalDue
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id
    LEFT JOIN ContractCamps cc ON cc.CampId=ca.Id
    LEFT JOIN Contracts c ON c.ContractId=cc.ContractId
    WHERE (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%' OR ca.Code LIKE '%'+@SearchText+'%')
    GROUP BY ca.Id,ca.Code,ca.Name,ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetDueReport — fix ct.CampId ──────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDueReport
    @PageNumber INT=1, @PageSize INT=2147483647,
    @TenantId INT=NULL, @CampId INT=NULL,
    @Month NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*)
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=ct.ContractId
    LEFT JOIN Tenants t ON t.Id=ct.TenantId
    LEFT JOIN Camps ca ON ca.Id=cc.CampId
    WHERE ci.Status IN('Pending','Partial')
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@Month IS NULL OR FORMAT(ci.DueDate,'yyyy-MM')=@Month);
    SELECT ci.Id, ci.ContractId, ci.InstallmentNo, ci.Amount, ci.PaidAmount,
           ci.Amount-ci.PaidAmount BalanceAmount, ci.DueDate, ci.Status,
           ISNULL(ci.PaymentMode,'') PaymentMode,
           ISNULL(t.Name,'') TenantName, ct.TenantId,
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=ct.ContractId ORDER BY cc2.Id),'') CampName,
           CASE WHEN ci.DueDate<GETDATE() THEN 'Overdue' ELSE 'Pending' END DueStatus
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN ContractCamps cc ON cc.ContractId=ct.ContractId
    LEFT JOIN Tenants t ON t.Id=ct.TenantId
    WHERE ci.Status IN('Pending','Partial')
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR cc.CampId=@CampId)
      AND (@Month IS NULL OR FORMAT(ci.DueDate,'yyyy-MM')=@Month)
    ORDER BY ci.DueDate
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetPartnerReport — fix c.CampId ───────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Partners p
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%');
    SELECT p.Id PartnerId, p.Code PartnerCode, p.Name PartnerName, p.Contact, p.Mobile, p.Email, p.Status,
           COUNT(DISTINCT cp.CampId) TotalCamps,
           ISNULL(STRING_AGG(c.Name,', '),'') CampNames,
           ISNULL(AVG(CAST(cp.ShareValue AS DECIMAL(18,4))),0) ShareValue,
           ISNULL(MAX(cp.ShareType),'') ShareType,
           ISNULL((SELECT SUM(ci.PaidAmount) FROM ContractInstallments ci
                   JOIN ContractCamps cc ON cc.ContractId=ci.ContractId
                   JOIN CampPartners cp2 ON cp2.CampId=cc.CampId AND cp2.PartnerId=p.Id
                   WHERE ci.Status='Paid'),0) TotalCollected,
           ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.RecipientRole='Partner' AND e.RecipientName=p.Name),0) TotalPaid,
           0 ShareDue
    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id
    LEFT JOIN Camps c ON c.Id=cp.CampId
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
    GROUP BY p.Id,p.Code,p.Name,p.Contact,p.Mobile,p.Email,p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── sp_GetTransactionStatement — already uses ContractCamps (016/020) ─
-- Recreate to ensure clean version without c.CampId
CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @ContractId NVARCHAR(MAX)=NULL,
    @TenantId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL,
    @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @Year NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..#AllTxns') IS NOT NULL DROP TABLE #AllTxns;
    CREATE TABLE #AllTxns (Id INT,TxnDate DATE,AccountHead NVARCHAR(MAX),Particular NVARCHAR(MAX),
        CampName NVARCHAR(MAX),CampId INT,FundPoolName NVARCHAR(MAX),TxnType NVARCHAR(MAX),
        Source NVARCHAR(MAX),Mode NVARCHAR(MAX),Amount DECIMAL(18,2),Status NVARCHAR(MAX),
        ContractId NVARCHAR(MAX),TenantName NVARCHAR(MAX));
    INSERT INTO #AllTxns
    SELECT ci.Id, ci.PaidDate,'Rent Income',ISNULL(t.Name,''),
           ISNULL((SELECT TOP 1 ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=ct.ContractId ORDER BY cc2.Id),'') CampName,
           ISNULL((SELECT TOP 1 cc3.CampId FROM ContractCamps cc3 WHERE cc3.ContractId=ct.ContractId ORDER BY cc3.Id),0) CampId,
           ISNULL(ci.FundPoolName,''),'DR','Inst #'+CAST(ci.InstallmentNo AS NVARCHAR),
           ISNULL(ci.PaymentMode,''),ci.PaidAmount,ci.Status,ct.ContractId,ISNULL(t.Name,'')
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN Tenants t ON t.Id=ct.TenantId
    WHERE ci.Status='Paid' AND ci.PaidDate IS NOT NULL
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR (SELECT TOP 1 cc4.CampId FROM ContractCamps cc4 WHERE cc4.ContractId=ct.ContractId ORDER BY cc4.Id)=@CampId)
      AND (@ContractId IS NULL OR ct.ContractId=@ContractId);
    INSERT INTO #AllTxns
    SELECT e.Id,e.Date,e.Head,ISNULL(e.RecipientName,''),
           ISNULL(e.CampName,CASE WHEN e.Nature='HO' THEN 'HO' ELSE '' END),ISNULL(e.CampId,0),
           ISNULL(e.FundPoolName,''),'CR',ISNULL(e.ExpenseId,''),ISNULL(e.Mode,''),
           e.Amount,'Paid','',ISNULL(e.RecipientName,'')
    FROM Expenses e WHERE (@CampId IS NULL OR e.CampId=@CampId);
    SELECT @TotalRecords=COUNT(*) FROM #AllTxns
    WHERE (@Status IS NULL OR TxnType=@Status)
      AND (@DateFrom IS NULL OR TxnDate>=@DateFrom) AND (@DateTo IS NULL OR TxnDate<=@DateTo)
      AND (@Month IS NULL OR FORMAT(TxnDate,'yyyy-MM')=@Month)
      AND (@Year IS NULL OR YEAR(TxnDate)=CAST(@Year AS INT))
      AND (@SearchText IS NULL OR Particular LIKE '%'+@SearchText+'%' OR TenantName LIKE '%'+@SearchText+'%' OR ContractId LIKE '%'+@SearchText+'%');
    SELECT Id,[TxnDate] [Date],AccountHead,Particular,CampName,FundPoolName,TxnType,Source,Mode,Amount,Status,ContractId,TenantName
    FROM #AllTxns
    WHERE (@Status IS NULL OR TxnType=@Status)
      AND (@DateFrom IS NULL OR TxnDate>=@DateFrom) AND (@DateTo IS NULL OR TxnDate<=@DateTo)
      AND (@Month IS NULL OR FORMAT(TxnDate,'yyyy-MM')=@Month)
      AND (@Year IS NULL OR YEAR(TxnDate)=CAST(@Year AS INT))
      AND (@SearchText IS NULL OR Particular LIKE '%'+@SearchText+'%' OR TenantName LIKE '%'+@SearchText+'%' OR ContractId LIKE '%'+@SearchText+'%')
    ORDER BY TxnDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
    DROP TABLE #AllTxns;
END
GO

PRINT '=== Script 029 complete: All Contracts.CampId references fixed ===';
