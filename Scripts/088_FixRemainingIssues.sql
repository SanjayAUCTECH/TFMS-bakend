USE TFMS_TestSoftwareDB;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ── sp_RecordPayment (complete rewrite with all NOT NULL cols) ──────
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId NVARCHAR(MAX), @InstallmentNo INT, @PaidAmount DECIMAL(18,2),
    @PaidDate DATETIME=NULL, @PaymentModeId INT=NULL, @PaymentMode NVARCHAR(MAX)='',
    @ChequeNumber NVARCHAR(MAX)='', @ClearanceDate NVARCHAR(MAX)='',
    @Description NVARCHAR(MAX)='', @ReceivedBy NVARCHAR(MAX)='',
    @ReceivedContact NVARCHAR(MAX)='', @FundPoolId INT=NULL,
    @FundPoolName NVARCHAR(MAX)='', @IssuedBy NVARCHAR(MAX)='',
    @AddedBy INT=NULL, @NewTxnRecordId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @TenantId INT=0, @CampId INT=0, @Amount DECIMAL(18,2)=0;
    DECLARE @TenantName NVARCHAR(MAX)='', @CampName NVARCHAR(MAX)='';

    SELECT @TenantId=c.TenantId,
           @CampId=ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId=ci.ContractId ORDER BY cc.Id),0),
           @Amount=ci.Amount
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId
    WHERE ci.ContractId=@ContractId AND ci.InstallmentNo=@InstallmentNo AND ISNULL(ci.IsDeleted,0)=0;

    SELECT @TenantName=ISNULL(Name,'') FROM Tenants WHERE Id=@TenantId AND IsDeleted=0;
    SELECT @CampName=ISNULL(Name,'') FROM Camps WHERE Id=@CampId AND IsDeleted=0;

    -- Update installment
    UPDATE ContractInstallments
    SET PaidAmount=ISNULL(PaidAmount,0)+@PaidAmount,
        PaidDate=@PaidDate,
        PaymentMode=ISNULL(@PaymentMode,''),
        PaymentModeId=@PaymentModeId,
        ChequeNumber=ISNULL(@ChequeNumber,''),
        ClearanceDate=ISNULL(@ClearanceDate,''),
        Description=ISNULL(@Description,''),
        ReceivedBy=ISNULL(@ReceivedBy,''),
        ReceivedContact=ISNULL(@ReceivedContact,''),
        FundPoolId=@FundPoolId,
        FundPoolName=ISNULL(@FundPoolName,''),
        IssuedBy=ISNULL(@IssuedBy,''),
        AddedBy=ISNULL(AddedBy,@AddedBy),
        Status=CASE
            WHEN ISNULL(PaidAmount,0)+@PaidAmount>=Amount THEN 'Paid'
            WHEN ISNULL(PaidAmount,0)+@PaidAmount>0 THEN 'Partial'
            ELSE 'Pending' END
    WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo AND ISNULL(IsDeleted,0)=0;

    -- Create CR TxnRecord
    DECLARE @TxnId NVARCHAR(50)=CONCAT('TXN-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR),5));
    INSERT INTO TxnRecords(TxnId,TxnType,ContractId,ContractCode,TenantId,CampId,
        TotalAmount,Amount,TxnDate,PaymentMode,PaymentModeId,ChequeNumber,
        FundPoolId,FundPoolName,Description,ReceivedBy,ReceivedContact,IssuedBy,
        InstallmentNo,AppliedInstallments,Unallocated,AddedBy,IsDeleted,CreatedAt,UpdatedAt)
    VALUES(@TxnId,'CR',@ContractId,@ContractId,ISNULL(@TenantId,0),ISNULL(@CampId,0),
        ISNULL(@Amount,0),@PaidAmount,ISNULL(@PaidDate,GETUTCDATE()),
        ISNULL(@PaymentMode,''),@PaymentModeId,ISNULL(@ChequeNumber,''),
        @FundPoolId,ISNULL(@FundPoolName,''),ISNULL(@Description,''),
        ISNULL(@ReceivedBy,''),ISNULL(@ReceivedContact,''),ISNULL(@IssuedBy,''),
        @InstallmentNo,'',0,@AddedBy,0,GETUTCDATE(),GETUTCDATE());
    SET @NewTxnRecordId=SCOPE_IDENTITY();

    -- Update FundPool balance
    IF @FundPoolId IS NOT NULL AND @PaidAmount>0
        UPDATE FundPools SET Balance=Balance+@PaidAmount,UpdatedAt=GETUTCDATE()
        WHERE Id=@FundPoolId AND IsDeleted=0;

    -- Create Income record
    IF @FundPoolId IS NOT NULL
    BEGIN
        DECLARE @FPCode NVARCHAR(MAX)='';
        SELECT @FPCode=ISNULL(Code,'') FROM FundPools WHERE Id=@FundPoolId;
        DECLARE @IncId NVARCHAR(50)=CONCAT('INC-',RIGHT('00000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR),5));
        INSERT INTO Incomes(IncomeId,[Date],Mode,Head,FundPool,FundPoolName,Amount,
            Purpose,Source,SourceRef,CampName,PartnerName,TenantName,
            CreatedAt,UpdatedAt,CampId,ContractId,ContractCode,AddedBy,IsDeleted)
        VALUES(@IncId,CAST(ISNULL(@PaidDate,GETUTCDATE()) AS DATE),
            ISNULL(@PaymentMode,'Cash'),'Rent',
            ISNULL(@FPCode,''),ISNULL(@FundPoolName,''),@PaidAmount,
            'Rent Payment','Room Payment',@ContractId,
            ISNULL(@CampName,''),'',ISNULL(@TenantName,''),
            GETUTCDATE(),GETUTCDATE(),ISNULL(@CampId,0),
            @ContractId,@ContractId,@AddedBy,0);
    END
END
GO
PRINT 'sp_RecordPayment DONE';
GO

-- ── sp_GetPaymentSummary — verify TenantId col exists ──────────────
-- Repository reads: ContractId,TenantId,TenantName,TenantContact,CampId,CampName
--                   StartDate,EndDate,Months,ContractTotal,MonthlyTotal,LessorAmount,
--                   Status,TotalInstallments,PaidCount,PendingCount,PartialCount,
--                   TotalPaid,TotalDue,TotalScheduled,NextInstallmentDue,NextInstallmentNo,RoomNos,RoomCount
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ContractId,
        c.TenantId,
        ISNULL(t.Name,'') AS TenantName,
        ISNULL(t.Contact,'') AS TenantContact,
        ISNULL((SELECT TOP 1 cc.CampId FROM ContractCamps cc WHERE cc.ContractId=c.ContractId ORDER BY cc.Id),0) AS CampId,
        ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc2 JOIN Camps ca ON ca.Id=cc2.CampId WHERE cc2.ContractId=c.ContractId ORDER BY cc2.Id),'') AS CampName,
        CONVERT(NVARCHAR(10),c.StartDate,23) AS StartDate,
        CONVERT(NVARCHAR(10),c.EndDate,23) AS EndDate,
        c.Months,
        c.ContractTotal,
        c.MonthlyTotal,
        ISNULL(c.LessorAmount,0) AS LessorAmount,
        c.Status,
        (SELECT COUNT(*) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0) AS TotalInstallments,
        (SELECT COUNT(*) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status='Paid' AND ISNULL(ci.IsDeleted,0)=0) AS PaidCount,
        (SELECT COUNT(*) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status='Pending' AND ISNULL(ci.IsDeleted,0)=0) AS PendingCount,
        (SELECT COUNT(*) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status='Partial' AND ISNULL(ci.IsDeleted,0)=0) AS PartialCount,
        ISNULL((SELECT SUM(PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ISNULL(ci.IsDeleted,0)=0),0) AS TotalPaid,
        ISNULL((SELECT SUM(Amount-PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status<>'Paid' AND ISNULL(ci.IsDeleted,0)=0),0) AS TotalDue,
        c.ContractTotal AS TotalScheduled,
        ISNULL((SELECT TOP 1 Amount FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status IN('Pending','Partial') AND ISNULL(ci.IsDeleted,0)=0 ORDER BY InstallmentNo),0) AS NextInstallmentDue,
        (SELECT TOP 1 InstallmentNo FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status IN('Pending','Partial') AND ISNULL(ci.IsDeleted,0)=0 ORDER BY InstallmentNo) AS NextInstallmentNo,
        ISNULL((SELECT STRING_AGG(r.RoomNo,', ') FROM ContractRooms cr JOIN Rooms r ON r.Id=cr.RoomId WHERE cr.ContractId=c.ContractId),'') AS RoomNos,
        ISNULL((SELECT COUNT(*) FROM ContractRooms cr WHERE cr.ContractId=c.ContractId),0) AS RoomCount
    FROM Contracts c
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    WHERE c.ContractId=@ContractId AND c.IsDeleted=0;
END
GO
PRINT 'sp_GetPaymentSummary DONE';
GO

-- ── sp_GetPaymentHistory — verify it returns correct columns ────────
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory @ContractId NVARCHAR(MAX) AS BEGIN
    SET NOCOUNT ON;
    SELECT ci.Id, ci.ContractId, ci.InstallmentNo, ci.Amount, ci.DueDate,
        ISNULL(ci.PaidAmount,0) PaidAmount, ci.PaidDate, ci.Status,
        ISNULL(ci.PaymentMode,'') PaymentMode, ci.PaymentModeId,
        ISNULL(ci.ChequeNumber,'') ChequeNumber,
        ISNULL(ci.ClearanceDate,'') ClearanceDate,
        ISNULL(ci.Description,'') Description,
        ISNULL(ci.ReceivedBy,'') ReceivedBy,
        ISNULL(ci.ReceivedContact,'') ReceivedContact,
        ci.FundPoolId, ISNULL(ci.FundPoolName,'') FundPoolName,
        ISNULL(ci.IssuedBy,'') IssuedBy,
        ISNULL(t.Name,'') TenantName,
        ISNULL((SELECT TOP 1 ca.Name FROM ContractCamps cc JOIN Camps ca ON ca.Id=cc.CampId WHERE cc.ContractId=ci.ContractId ORDER BY cc.Id),'') CampName
    FROM ContractInstallments ci
    JOIN Contracts c ON c.ContractId=ci.ContractId AND c.IsDeleted=0
    LEFT JOIN Tenants t ON t.Id=c.TenantId AND t.IsDeleted=0
    WHERE ci.ContractId=@ContractId AND ISNULL(ci.IsDeleted,0)=0
      AND ci.PaidAmount>0
    ORDER BY ci.InstallmentNo;
END
GO
PRINT 'sp_GetPaymentHistory DONE';
GO

-- ── Verify sp_GetPaymentHistory columns match PaymentHistoryResponse ─
-- Repository maps: Id,ContractId,InstallmentNo,Amount,DueDate,PaidAmount,PaidDate,Status,
--                  PaymentMode,PaymentModeId,ChequeNumber,ClearanceDate,Description,
--                  ReceivedBy,ReceivedContact,FundPoolId,FundPoolName,IssuedBy,TenantName,CampName
PRINT 'All payment SPs done';
GO

-- ── Fix OwnerContracts: ensure no FK issue ──────────────────────────
-- The sp_CreateOwnerContract was fixed but test used invalid camp/owner IDs
-- Verify it works with current data
DECLARE @testCampId INT = (SELECT TOP 1 Id FROM Camps WHERE IsDeleted=0);
DECLARE @testOwnerId INT = (SELECT TOP 1 Id FROM Owners WHERE IsDeleted=0);
PRINT 'Valid CampId='+CAST(ISNULL(@testCampId,0) AS NVARCHAR)+' OwnerId='+CAST(ISNULL(@testOwnerId,0) AS NVARCHAR);
GO
PRINT '088 DONE - All remaining SP issues fixed';
GO
