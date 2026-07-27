-- ============================================================
-- 077: Fix ALL remaining GET SPs - Add IsDeleted=0 filter
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- CompanyAssets
CREATE OR ALTER PROCEDURE sp_GetCompanyAssetById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM CompanyAssets WHERE Id=@Id AND IsDeleted=0;
END
GO

-- ContractRoomInstallments
CREATE OR ALTER PROCEDURE sp_GetContractRoomInstallments
    @ContractId NVARCHAR(MAX)=NULL,@CampId INT=NULL,@RoomId INT=NULL,
    @Status NVARCHAR(MAX)=NULL,@Month NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT cri.* FROM ContractRoomInstallments cri
    WHERE cri.IsDeleted=0
      AND (@ContractId IS NULL OR cri.ContractId=@ContractId)
      AND (@CampId IS NULL OR cri.CampId=@CampId)
      AND (@RoomId IS NULL OR cri.RoomId=@RoomId)
      AND (@Status IS NULL OR cri.Status=@Status)
      AND (@Month IS NULL OR cri.Month=@Month)
    ORDER BY cri.ContractId,cri.InstallmentNo;
END
GO

-- PaymentById
CREATE OR ALTER PROCEDURE sp_GetPaymentById @Id INT AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM ContractInstallments WHERE Id=@Id AND IsDeleted=0;
END
GO

-- PaymentHistory
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT t.*,ten.Name TenantName FROM TxnRecords t
    LEFT JOIN Tenants ten ON ten.Id=t.TenantId
    WHERE t.ContractId=@ContractId AND t.IsDeleted=0
    ORDER BY t.PaidDate DESC;
END
GO

-- PaymentSummary
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId,c.ContractTotal,c.SecurityDeposit,c.MonthlyTotal,
        ISNULL(SUM(CASE WHEN ci.IsDeleted=0 AND ci.Status='Paid' THEN ci.PaidAmount ELSE 0 END),0) TotalPaid,
        ISNULL(SUM(CASE WHEN ci.IsDeleted=0 AND ci.Status IN ('Pending','Partial') THEN ci.Amount-ci.PaidAmount ELSE 0 END),0) TotalDue
    FROM Contracts c
    LEFT JOIN ContractInstallments ci ON ci.ContractId=c.ContractId
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0
    GROUP BY c.ContractId,c.ContractTotal,c.SecurityDeposit,c.MonthlyTotal;
END
GO

-- OwnerContracts
CREATE OR ALTER PROCEDURE sp_GetOwnerContracts
    @OwnerId INT=NULL,@CampId INT=NULL,@Status NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT oc.*,o.Name OwnerName,c.Name CampName FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id=oc.OwnerId
    LEFT JOIN Camps c ON c.Id=oc.CampId
    WHERE oc.IsDeleted=0
      AND (@OwnerId IS NULL OR oc.OwnerId=@OwnerId)
      AND (@CampId IS NULL OR oc.CampId=@CampId)
      AND (@Status IS NULL OR oc.Status=@Status)
    ORDER BY oc.Id DESC;
END
GO

-- OwnerInstallments
CREATE OR ALTER PROCEDURE sp_GetOwnerInstallments
    @OwnerId INT=NULL,@OcId INT=NULL,@Status NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT oi.*,o.Name OwnerName FROM OwnerInstallments oi
    LEFT JOIN Owners o ON o.Id=oi.OwnerId
    WHERE oi.IsDeleted=0
      AND (@OwnerId IS NULL OR oi.OwnerId=@OwnerId)
      AND (@OcId IS NULL OR oi.OcId=@OcId)
      AND (@Status IS NULL OR oi.Status=@Status)
    ORDER BY oi.InstallmentNo;
END
GO

-- OwnerTransactions
CREATE OR ALTER PROCEDURE sp_GetOwnerTransactions
    @OwnerId INT=NULL,@CampId INT=NULL,@OcId INT=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT ot.*,o.Name OwnerName FROM OwnerTransactions ot
    LEFT JOIN Owners o ON o.Id=ot.OwnerId
    WHERE ot.IsDeleted=0
      AND (@OwnerId IS NULL OR ot.OwnerId=@OwnerId)
      AND (@CampId IS NULL OR ot.CampId=@CampId)
      AND (@OcId IS NULL OR ot.OcId=@OcId)
    ORDER BY ot.Id DESC;
END
GO

-- ContractCancellations
CREATE OR ALTER PROCEDURE sp_GetContractCancellations
    @ContractId NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT cc.*,c.Status ContractCurrentStatus FROM ContractCancellations cc
    LEFT JOIN Contracts c ON c.ContractId=cc.ContractId
    WHERE cc.IsDeleted=0
      AND (@ContractId IS NULL OR cc.ContractId=@ContractId)
    ORDER BY cc.Id DESC;
END
GO

-- ContractRenewals
CREATE OR ALTER PROCEDURE sp_GetContractRenewals
    @ContractId NVARCHAR(MAX)=NULL
AS BEGIN
    SET NOCOUNT ON;
    SELECT * FROM ContractRenewals
    WHERE IsDeleted=0
      AND (@ContractId IS NULL OR OriginalContractId=@ContractId OR NewContractId=@ContractId)
    ORDER BY Id DESC;
END
GO

-- OutgoingPayments
CREATE OR ALTER PROCEDURE sp_GetOutgoingPayments
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@DateFrom DATE=NULL,@DateTo DATE=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM OutgoingPayments WHERE IsDeleted=0
      AND (@DateFrom IS NULL OR PaymentDate>=@DateFrom)
      AND (@DateTo IS NULL OR PaymentDate<=@DateTo)
      AND (@SearchText IS NULL OR RecipientName LIKE '%'+@SearchText+'%');
    SELECT * FROM OutgoingPayments WHERE IsDeleted=0
      AND (@DateFrom IS NULL OR PaymentDate>=@DateFrom)
      AND (@DateTo IS NULL OR PaymentDate<=@DateTo)
      AND (@SearchText IS NULL OR RecipientName LIKE '%'+@SearchText+'%')
    ORDER BY PaymentDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- CampReport
CREATE OR ALTER PROCEDURE sp_GetCampReport
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Camps ca WHERE ca.IsDeleted=0
      AND (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%');
    SELECT ca.Id CampId,ca.Code CampCode,ca.Name CampName,ca.Status,
        COUNT(DISTINCT r.Id) TotalRooms,
        COUNT(DISTINCT CASE WHEN r.Status='Occupied' THEN r.Id END) OccupiedRooms,
        COUNT(DISTINCT CASE WHEN r.Status='Vacant' THEN r.Id END) VacantRooms,
        COUNT(DISTINCT CASE WHEN c.Status='Active' THEN c.Id END) ActiveContracts,
        ISNULL(SUM(CASE WHEN r.Status='Occupied' THEN r.MonthlyPrice ELSE 0 END),0) TotalMonthlyRent,
        ISNULL((SELECT SUM(cr.PaidAmount) FROM ContractRooms cr WHERE cr.CampId=ca.Id AND cr.IsDeleted=0),0) TotalCollected,
        ISNULL((SELECT SUM(cr.Balance) FROM ContractRooms cr WHERE cr.CampId=ca.Id AND cr.Balance>0 AND cr.IsDeleted=0),0) TotalDue,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.Nature='Camp' AND e.CampId=ca.Id AND e.IsDeleted=0),0) CampExpense,
        ISNULL((SELECT SUM(e2.Amount)*0.1 FROM Expenses e2 WHERE e2.Nature='HO' AND e2.IsDeleted=0),0) HOAllocated,
        ISNULL((SELECT SUM(cr2.PaidAmount) FROM ContractRooms cr2 WHERE cr2.CampId=ca.Id AND cr2.IsDeleted=0),0)-
        ISNULL((SELECT SUM(e3.Amount) FROM Expenses e3 WHERE e3.Nature='Camp' AND e3.CampId=ca.Id AND e3.IsDeleted=0),0) Profit,
        ISNULL((SELECT SUM(e4.Amount) FROM Expenses e4 WHERE (e4.CampId=ca.Id OR e4.Nature='HO') AND e4.IsDeleted=0),0) TotalExpense
    FROM Camps ca
    LEFT JOIN Rooms r ON r.CampId=ca.Id AND r.IsDeleted=0
    LEFT JOIN ContractCamps cc ON cc.CampId=ca.Id
    LEFT JOIN Contracts c ON c.ContractId=cc.ContractId AND c.IsDeleted=0
    WHERE ca.IsDeleted=0
      AND (@Status IS NULL OR ca.Status=@Status)
      AND (@SearchText IS NULL OR ca.Name LIKE '%'+@SearchText+'%')
    GROUP BY ca.Id,ca.Code,ca.Name,ca.Status
    ORDER BY ca.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- InventoryReport
CREATE OR ALTER PROCEDURE sp_GetInventoryReport
    @PageNumber INT=1,@PageSize INT=2147483647,
    @SearchText NVARCHAR(MAX)=NULL,@Status NVARCHAR(MAX)=NULL,@CampId INT=NULL,
    @TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Rooms r WHERE r.IsDeleted=0
      AND (@CampId IS NULL OR r.CampId=@CampId)
      AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%');
    SELECT r.Id RoomId,r.RoomNo,ISNULL(ca.Name,'') CampName,ISNULL(f.Name,'') FloorName,
        r.Status,r.Occupied,r.MonthlyPrice,ISNULL(r.OtherDetails,'') OtherDetails,
        ISNULL(t.Name,'') TenantName,ISNULL(c.ContractId,'') ContractId,ISNULL(c.Status,'') ContractStatus
    FROM Rooms r
    LEFT JOIN Camps ca ON ca.Id=r.CampId AND ca.IsDeleted=0
    LEFT JOIN Floors f ON f.Id=r.FloorId AND f.IsDeleted=0
    LEFT JOIN ContractRooms cr ON cr.RoomId=r.Id AND cr.IsDeleted=0
    LEFT JOIN Contracts c ON c.ContractId=cr.ContractId AND c.Status='Active' AND c.IsDeleted=0
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    WHERE r.IsDeleted=0
      AND (@CampId IS NULL OR r.CampId=@CampId)
      AND (@Status IS NULL OR r.Status=@Status)
      AND (@SearchText IS NULL OR r.RoomNo LIKE '%'+@SearchText+'%')
    ORDER BY ca.Name,r.RoomNo
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- SecurityDepositStatus
CREATE OR ALTER PROCEDURE sp_GetSecurityDepositStatus @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT c.ContractId,c.SecurityDeposit,c.SecurityDepositStatus,c.SecurityDepositPaid,
        ISNULL(SUM(CASE WHEN tr.TxnType='SD-CR' THEN tr.Amount ELSE 0 END),0) PaidAmount
    FROM Contracts c
    LEFT JOIN TxnRecords tr ON tr.ContractId=c.ContractId AND tr.TxnType='SD-CR' AND tr.IsDeleted=0
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0
    GROUP BY c.ContractId,c.SecurityDeposit,c.SecurityDepositStatus,c.SecurityDepositPaid;
END
GO

-- TenantReport
CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT=1,@PageSize INT=100,@SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL,@CampId INT=NULL,@TenantId INT=NULL,@TotalRecords INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*)
    FROM (
        SELECT c.ContractId FROM Tenants t
        JOIN Contracts c ON c.TenantId=t.Id AND c.IsDeleted=0
        LEFT JOIN ContractCamps cc ON cc.ContractId=c.ContractId
        WHERE t.IsDeleted=0
          AND (@Status IS NULL OR t.Status=@Status) AND (@TenantId IS NULL OR t.Id=@TenantId)
          AND (@CampId IS NULL OR cc.CampId=@CampId)
          AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
        UNION ALL
        SELECT NULL FROM Tenants t WHERE t.IsDeleted=0
          AND NOT EXISTS(SELECT 1 FROM Contracts c2 WHERE c2.TenantId=t.Id AND c2.IsDeleted=0)
          AND (@TenantId IS NULL OR t.Id=@TenantId) AND (@Status IS NULL OR t.Status=@Status)
          AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%')
    ) x;
    SELECT t.Id TenantId,t.Name TenantName,ISNULL(t.Contact,'') Contact,ISNULL(t.Email,'') Email,
        ISNULL(t.EmiratesId,'') EmiratesId,ISNULL(t.Nationality,'') Nationality,t.Status,ISNULL(t.Type,'Individual') [Type],
        ISNULL(c.ContractId,'') ContractId,c.StartDate ContractStart,c.EndDate ContractEnd,ISNULL(c.Status,'') ContractStatus,
        ISNULL(c.SecurityDeposit,0) SecurityDeposit,ISNULL(c.SecurityDepositStatus,'Pending') SecurityDepositStatus,
        ISNULL(c.SecurityDepositPaid,0) SecurityDepositPaid,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-REF' AND tr.IsDeleted=0),0) SdRefundAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-FRF' AND tr.IsDeleted=0),0) SdForfeitAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-ADJ' AND tr.IsDeleted=0),0) SdAdjustAmount,
        ISNULL(STUFF((SELECT DISTINCT ', '+ca2.Name FROM ContractCamps cc2 JOIN Camps ca2 ON ca2.Id=cc2.CampId WHERE cc2.ContractId=c.ContractId FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)'),1,2,''),'') CampName,
        ISNULL((SELECT COUNT(DISTINCT cc3.CampId) FROM ContractCamps cc3 WHERE cc3.ContractId=c.ContractId),0) CampsCount,
        ISNULL(STUFF((SELECT ', '+r2.RoomNo FROM ContractRooms cr2 JOIN Rooms r2 ON r2.Id=cr2.RoomId WHERE cr2.ContractId=c.ContractId AND r2.IsDeleted=0 FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)'),1,2,''),'') RoomNo,
        ISNULL((SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId=c.ContractId AND cr3.IsDeleted=0),0) RoomsBooked,
        ISNULL(c.MonthlyTotal,0) MonthlyRent,ISNULL(c.ContractTotal,0) ContractRentTotal,
        ISNULL(c.ContractTotal,0)+ISNULL(c.SecurityDeposit,0) TotalAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType='CR' AND tr.IsDeleted=0),0) RentPaid,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType='SD-CR' AND tr.IsDeleted=0),0) SecurityDepositPaidAmount,
        ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType IN('CR','SD-CR') AND tr.IsDeleted=0),0) TotalPaid,
        (ISNULL(c.ContractTotal,0)+ISNULL(c.SecurityDeposit,0))-ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType IN('CR','SD-CR') AND tr.IsDeleted=0),0) TotalDue,
        ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w WHERE w.ContractId=c.ContractId AND w.IsDeleted=0),0) WaiverAmount,
        (ISNULL(c.ContractTotal,0)+ISNULL(c.SecurityDeposit,0))-ISNULL((SELECT SUM(tr.Amount) FROM TxnRecords tr WHERE tr.ContractId=c.ContractId AND tr.TxnType IN('CR','SD-CR') AND tr.IsDeleted=0),0)-ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w WHERE w.ContractId=c.ContractId AND w.IsDeleted=0),0) Balance
    FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.IsDeleted=0
    LEFT JOIN ContractCamps ccf ON ccf.ContractId=c.ContractId
    WHERE t.IsDeleted=0
      AND (@Status IS NULL OR t.Status=@Status) AND (@TenantId IS NULL OR t.Id=@TenantId)
      AND (@CampId IS NULL OR ccf.CampId=@CampId OR c.ContractId IS NULL)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%')
    GROUP BY t.Id,t.Name,t.Contact,t.Email,t.EmiratesId,t.Nationality,t.Status,t.Type,
        c.ContractId,c.StartDate,c.EndDate,c.Status,c.SecurityDeposit,c.SecurityDepositStatus,
        c.SecurityDepositPaid,c.MonthlyTotal,c.ContractTotal
    ORDER BY t.Name,c.StartDate DESC
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '077 - All GET SPs fixed with IsDeleted=0 filter';
GO
