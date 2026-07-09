-- ============================================================
-- TFMS â€” Payment + TxnRecords Stored Procedures
-- Script 017: sp_RecordPayment (with TxnRecord), sp_GetPaymentSummary,
--             sp_GetPaymentHistory, sp_GetTxnRecords, sp_CreateTxnRecord,
--             sp_UpdateTxnRecord, sp_DeleteTxnRecord
-- Run on: TFMS_softwareDB
-- ============================================================
USE TFMS_softwareDB;
GO

-- â”€â”€ 1. Fix TxnRecords table â€” ensure all needed columns exist â”€â”€
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='TxnType')
    ALTER TABLE TxnRecords ADD TxnType NVARCHAR(5) NOT NULL DEFAULT 'CR';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='TenantId')
    ALTER TABLE TxnRecords ADD TenantId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='CampId')
    ALTER TABLE TxnRecords ADD CampId INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='TotalAmount')
    ALTER TABLE TxnRecords ADD TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='ContractCode')
    ALTER TABLE TxnRecords ADD ContractCode NVARCHAR(20) NOT NULL DEFAULT '';
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='FromDate')
    ALTER TABLE TxnRecords ADD FromDate DATE NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='ToDate')
    ALTER TABLE TxnRecords ADD ToDate DATE NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='InstallmentNo')
    ALTER TABLE TxnRecords ADD InstallmentNo INT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('TxnRecords') AND name='UpdatedAt')
    ALTER TABLE TxnRecords ADD UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE();
GO

-- â”€â”€ 2. sp_RecordPayment â€” Updates ContractInstallments + creates TxnRecord â”€
CREATE OR ALTER PROCEDURE sp_RecordPayment
    @ContractId     NVARCHAR(20),
    @InstallmentNo  INT,
    @PaidAmount     DECIMAL(18,2),
    @PaidDate       DATE,
    @PaymentModeId  INT          = NULL,
    @PaymentMode    NVARCHAR(50) = '',
    @ChequeNumber   NVARCHAR(50) = '',
    @ClearanceDate  NVARCHAR(50) = '',
    @Description    NVARCHAR(500)= '',
    @ReceivedBy     NVARCHAR(200)= '',
    @ReceivedContact NVARCHAR(20)= '',
    @FundPoolId     INT          = NULL,
    @FundPoolName   NVARCHAR(200)= '',
    @IssuedBy       NVARCHAR(100)= ''
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- â”€â”€ A. Validate installment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        DECLARE @Amount DECIMAL(18,2);
        SELECT @Amount = Amount
        FROM ContractInstallments
        WHERE ContractId = @ContractId AND InstallmentNo = @InstallmentNo;

        IF @Amount IS NULL
        BEGIN
            RAISERROR('Installment not found for contract %s, installment %d.', 16, 1, @ContractId, @InstallmentNo);
            RETURN;
        END

        -- â”€â”€ B. Determine new status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        DECLARE @NewStatus NVARCHAR(20) =
            CASE
                WHEN @PaidAmount >= @Amount THEN 'Paid'
                WHEN @PaidAmount  > 0       THEN 'Partial'
                ELSE 'Pending'
            END;

        -- â”€â”€ C. Update ContractInstallments (ContractInstallments) row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        UPDATE ContractInstallments
        SET PaidAmount      = @PaidAmount,
            PaidDate        = @PaidDate,
            Status          = @NewStatus,
            PaymentModeId   = @PaymentModeId,
            PaymentMode     = @PaymentMode,
            ChequeNumber    = @ChequeNumber,
            ClearanceDate   = @ClearanceDate,
            Description     = @Description,
            ReceivedBy      = @ReceivedBy,
            ReceivedContact = @ReceivedContact,
            FundPoolId      = @FundPoolId,
            FundPoolName    = @FundPoolName,
            IssuedBy        = @IssuedBy
        WHERE ContractId = @ContractId AND InstallmentNo = @InstallmentNo;

        -- â”€â”€ D. Update FundPool balance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        IF @FundPoolId IS NOT NULL AND @PaidAmount > 0
            UPDATE FundPools
            SET Balance   = Balance + @PaidAmount,
                UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- â”€â”€ E. Create TxnRecord entry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        -- Generate TxnId: TXN-YYYYMMDD-XXXXXX
        DECLARE @TxnId NVARCHAR(20) =
            'TXN-' + CONVERT(NVARCHAR(8), @PaidDate, 112) + '-' +
            RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6);

        -- Get TenantId, CampId from Contract
        DECLARE @TenantId INT, @CampId INT;
        SELECT @TenantId = TenantId, @CampId = CampId
        FROM Contracts WHERE ContractId = @ContractId;

        -- AppliedInstallments = the installment number(s) this txn covers
        DECLARE @AppliedInstallments NVARCHAR(200) = CAST(@InstallmentNo AS NVARCHAR);

        INSERT INTO TxnRecords (
            TxnId, TxnType, ContractId, ContractCode,
            TenantId, CampId,
            TotalAmount, Amount,
            PaidDate,
            PaymentMode, PaymentModeId,
            ChequeNumber, Description,
            IssuedBy, ReceivedBy, ReceivedContact,
            FundPoolId, FundPoolName,
            AppliedInstallments, Unallocated,
            InstallmentNo,
            CreatedAt, UpdatedAt
        )
        VALUES (
            @TxnId, 'CR', @ContractId, @ContractId,
            @TenantId, @CampId,
            @Amount, @PaidAmount,
            @PaidDate,
            @PaymentMode, @PaymentModeId,
            @ChequeNumber, @Description,
            @IssuedBy, @ReceivedBy, @ReceivedContact,
            @FundPoolId, @FundPoolName,
            @AppliedInstallments, CASE WHEN @PaidAmount > @Amount THEN @PaidAmount - @Amount ELSE 0 END,
            @InstallmentNo,
            GETUTCDATE(), GETUTCDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- â”€â”€ 3. sp_GetPaymentSummary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary
    @ContractId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ContractId,
        c.TenantId,
        t.Name                                              AS TenantName,
        t.Contact                                           AS TenantContact,
        c.CampId,
        ca.Name                                             AS CampName,
        CONVERT(NVARCHAR(10), c.StartDate, 23)             AS StartDate,
        CONVERT(NVARCHAR(10), c.EndDate,   23)             AS EndDate,
        c.Months,
        c.ContractTotal,
        c.MonthlyTotal,
        ISNULL((SELECT 0), 0)                          AS LessorAmount,
        c.Status,
        COUNT(p.Id)                                        AS TotalInstallments,
        SUM(CASE WHEN p.Status='Paid'    THEN 1 ELSE 0 END) AS PaidCount,
        SUM(CASE WHEN p.Status='Pending' OR p.Status='Overdue' THEN 1 ELSE 0 END) AS PendingCount,
        SUM(CASE WHEN p.Status='Partial' THEN 1 ELSE 0 END) AS PartialCount,
        ISNULL(SUM(p.PaidAmount), 0)                       AS TotalPaid,
        ISNULL(SUM(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                        THEN p.Amount - p.PaidAmount ELSE 0 END), 0) AS TotalDue,
        ISNULL(SUM(p.Amount), 0)                           AS TotalScheduled,
        ISNULL(MIN(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                        THEN p.Amount - p.PaidAmount END), 0) AS NextInstallmentDue,
        MIN(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                 THEN p.InstallmentNo END)                 AS NextInstallmentNo,
        ISNULL((SELECT STRING_AGG(r2.RoomNo, ', ')
                FROM ContractRooms cr2
                JOIN Rooms r2 ON r2.Id = cr2.RoomId
                WHERE cr2.ContractId = c.ContractId), '') AS RoomNos,
        (SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId = c.ContractId) AS RoomCount
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    LEFT JOIN ContractInstallments p ON p.ContractId = c.ContractId
    WHERE c.ContractId = @ContractId
    GROUP BY c.ContractId, c.TenantId, t.Name, t.Contact,
             c.CampId, ca.Name, c.StartDate, c.EndDate,
             c.Months, c.ContractTotal, c.MonthlyTotal,
             c.Status;
END
GO

-- â”€â”€ 4. sp_GetPaymentHistory â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory
    @ContractId NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.Id,
        p.ContractId,
        p.InstallmentNo,
        p.Amount,
        p.DueDate,
        p.PaidAmount,
        p.PaidDate,
        p.Status,
        p.PaymentMode,
        p.PaymentModeId,
        p.ChequeNumber,
        p.ClearanceDate,
        p.Description,
        p.ReceivedBy,
        p.ReceivedContact,
        p.FundPoolId,
        p.FundPoolName,
        p.IssuedBy,
        t.Name  AS TenantName,
        ca.Name AS CampName
    FROM ContractInstallments p
    JOIN Contracts c  ON c.ContractId = p.ContractId
    JOIN Tenants   t  ON t.Id         = c.TenantId
    JOIN Camps     ca ON ca.Id        = c.CampId
    WHERE p.ContractId = @ContractId
    ORDER BY p.InstallmentNo;
END
GO

-- â”€â”€ 5. sp_GetTxnRecords â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber  INT,
    @PageSize    INT,
    @ContractId  NVARCHAR(20) = NULL,
    @TenantId    INT          = NULL,
    @CampId      INT          = NULL,
    @TxnType     NVARCHAR(5)  = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c  ON c.ContractId = tr.ContractId
    JOIN Tenants   t  ON t.Id         = c.TenantId
    JOIN Camps     ca ON ca.Id        = c.CampId
    WHERE (@ContractId IS NULL OR tr.ContractId = @ContractId)
      AND (@TenantId   IS NULL OR c.TenantId    = @TenantId)
      AND (@CampId     IS NULL OR c.CampId      = @CampId)
      AND (@TxnType    IS NULL OR tr.TxnType    = @TxnType);

    SELECT
        tr.Id,
        tr.TxnId,
        tr.TxnType,
        tr.ContractId,
        tr.ContractCode,
        c.TenantId,
        t.Name          AS TenantName,
        c.CampId,
        ca.Name         AS CampName,
        tr.TotalAmount,
        tr.Amount,
        tr.PaidDate     AS TxnDate,
        tr.FromDate,
        tr.ToDate,
        tr.PaymentMode,
        tr.PaymentModeId,
        tr.FundPoolId,
        tr.FundPoolName,
        tr.Description,
        tr.ReceivedBy,
        tr.InstallmentNo,
        tr.AppliedInstallments,
        tr.Unallocated,
        tr.CreatedAt,
        tr.UpdatedAt
    FROM TxnRecords tr
    JOIN Contracts c  ON c.ContractId = tr.ContractId
    JOIN Tenants   t  ON t.Id         = c.TenantId
    JOIN Camps     ca ON ca.Id        = c.CampId
    WHERE (@ContractId IS NULL OR tr.ContractId = @ContractId)
      AND (@TenantId   IS NULL OR c.TenantId    = @TenantId)
      AND (@CampId     IS NULL OR c.CampId      = @CampId)
      AND (@TxnType    IS NULL OR tr.TxnType    = @TxnType)
    ORDER BY tr.PaidDate DESC, tr.Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- â”€â”€ 6. sp_CreateTxnRecord â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_CreateTxnRecord
    @TxnType        NVARCHAR(5)   = 'CR',
    @ContractId     NVARCHAR(20),
    @ContractCode   NVARCHAR(20)  = '',
    @TenantId       INT           = 0,
    @CampId         INT           = 0,
    @TotalAmount    DECIMAL(18,2) = 0,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @FromDate       DATE          = NULL,
    @ToDate         DATE          = NULL,
    @PaymentMode    NVARCHAR(50)  = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(200) = '',
    @Description    NVARCHAR(500) = '',
    @ReceivedBy     NVARCHAR(200) = '',
    @InstallmentNo  INT           = NULL,
    @NewId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TxnId NVARCHAR(20) =
        'TXN-' + CONVERT(NVARCHAR(8), @TxnDate, 112) + '-' +
        RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM TxnRecords) AS NVARCHAR), 6);

    INSERT INTO TxnRecords (
        TxnId, TxnType, ContractId, ContractCode,
        TenantId, CampId,
        TotalAmount, Amount,
        PaidDate, FromDate, ToDate,
        PaymentMode, PaymentModeId,
        FundPoolId, FundPoolName,
        Description, ReceivedBy,
        AppliedInstallments,
        InstallmentNo, Unallocated,
        CreatedAt, UpdatedAt
    )
    VALUES (
        @TxnId, @TxnType, @ContractId, @ContractCode,
        @TenantId, @CampId,
        @TotalAmount, @Amount,
        @TxnDate, @FromDate, @ToDate,
        @PaymentMode, @PaymentModeId,
        @FundPoolId, @FundPoolName,
        @Description, @ReceivedBy,
        ISNULL(CAST(@InstallmentNo AS NVARCHAR), ''),
        @InstallmentNo, 0,
        GETUTCDATE(), GETUTCDATE()
    );
    SET @NewId = SCOPE_IDENTITY();
END
GO

-- â”€â”€ 7. sp_UpdateTxnRecord â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_UpdateTxnRecord
    @Id             INT,
    @Amount         DECIMAL(18,2),
    @TxnDate        DATE,
    @PaymentMode    NVARCHAR(50)  = '',
    @PaymentModeId  INT           = NULL,
    @FundPoolId     INT           = NULL,
    @FundPoolName   NVARCHAR(200) = '',
    @Description    NVARCHAR(500) = '',
    @ReceivedBy     NVARCHAR(200) = ''
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TxnRecords
    SET Amount        = @Amount,
        PaidDate      = @TxnDate,
        PaymentMode   = @PaymentMode,
        PaymentModeId = @PaymentModeId,
        FundPoolId    = @FundPoolId,
        FundPoolName  = @FundPoolName,
        Description   = @Description,
        ReceivedBy    = @ReceivedBy,
        UpdatedAt     = GETUTCDATE()
    WHERE Id = @Id;
END
GO

-- â”€â”€ 8. sp_DeleteTxnRecord â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM TxnRecords WHERE Id = @Id;
END
GO

PRINT 'Script 017 â€” Payment + TxnRecord SPs applied successfully!';
GO

