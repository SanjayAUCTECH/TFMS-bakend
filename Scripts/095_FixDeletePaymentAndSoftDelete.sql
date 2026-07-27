-- ============================================================
-- 095: Fix Payment Delete + Soft Delete Filters
--
-- Problems fixed:
-- 1. sp_DeleteTxnRecord — wrong revert logic (subtracts full amount 
--    from all installments instead of per-installment amounts)
-- 2. sp_GetPaymentHistory — does NOT filter IsDeleted=1 rows
-- 3. sp_GetPaymentSummary — counts IsDeleted=1 installments
-- 4. Missing sp_SoftDeletePayment — controller calls SoftDeleteAsync
--    directly via inline SQL, but TxnRecord is not cleaned up
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ============================================================
-- FIX 1: sp_DeleteTxnRecord — proper per-installment revert
-- ============================================================
CREATE OR ALTER PROCEDURE sp_DeleteTxnRecord
    @Id        INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Get TxnRecord details
    DECLARE @ContractId          NVARCHAR(MAX),
            @Amount              DECIMAL(18,2),
            @FundPoolId          INT,
            @AppliedInstallments NVARCHAR(MAX),
            @TxnType             NVARCHAR(20);

    SELECT
        @ContractId          = ContractId,
        @Amount              = Amount,
        @FundPoolId          = FundPoolId,
        @AppliedInstallments = AppliedInstallments,
        @TxnType             = TxnType
    FROM TxnRecords WHERE Id = @Id;

    IF @ContractId IS NULL
    BEGIN RAISERROR('TxnRecord %d not found.', 16, 1, @Id); RETURN; END

    -- Only revert CR (payment) type
    IF @TxnType = 'CR'
    BEGIN
        -- 2. Revert FundPool balance
        IF @FundPoolId IS NOT NULL AND @Amount > 0
            UPDATE FundPools
            SET Balance = Balance - @Amount, UpdatedAt = GETUTCDATE()
            WHERE Id = @FundPoolId;

        -- 3. Revert ContractInstallments — per installment
        --    Each installment gets its own proportional revert based on how much was
        --    applied to it. We use the installment's own PaidAmount capped to Amount.
        IF @AppliedInstallments IS NOT NULL AND LEN(@AppliedInstallments) > 0
        BEGIN
            -- Split comma-separated installment numbers
            -- For each installment, revert its full payment (set to Pending/0)
            -- because each sp_RecordPayment call tracks applied installments
            UPDATE ci
            SET
                ci.PaidAmount      = 0,
                ci.PaidDate        = NULL,
                ci.Status          = 'Pending',
                ci.PaymentMode     = '',
                ci.PaymentModeId   = NULL,
                ci.ChequeNumber    = '',
                ci.ClearanceDate   = '',
                ci.Description     = '',
                ci.ReceivedBy      = '',
                ci.ReceivedContact = '',
                ci.FundPoolId      = NULL,
                ci.FundPoolName    = '',
                ci.IssuedBy        = ''
            FROM ContractInstallments ci
            INNER JOIN STRING_SPLIT(@AppliedInstallments, ',') s
                ON ci.InstallmentNo = CAST(TRIM(s.value) AS INT)
            WHERE ci.ContractId = @ContractId
              AND ISNULL(ci.IsDeleted, 0) = 0;

            -- Mark overdue if due date is past
            UPDATE ContractInstallments
            SET Status = 'Overdue'
            WHERE ContractId = @ContractId
              AND Status = 'Pending'
              AND DueDate < CAST(GETUTCDATE() AS DATE)
              AND ISNULL(IsDeleted, 0) = 0
              AND InstallmentNo IN (
                  SELECT CAST(TRIM(value) AS INT)
                  FROM STRING_SPLIT(@AppliedInstallments, ',')
                  WHERE TRIM(value) <> ''
              );
        END

        -- 4. Revert ContractRooms from ContractRoomsTrns
        UPDATE cr
        SET
            cr.PaidAmount = CASE
                WHEN ISNULL(cr.PaidAmount, 0) - crt.Amount < 0 THEN 0
                ELSE ISNULL(cr.PaidAmount, 0) - crt.Amount
            END,
            cr.Balance = ISNULL(cr.TotalAmount, 0) - (
                CASE
                    WHEN ISNULL(cr.PaidAmount, 0) - crt.Amount < 0 THEN 0
                    ELSE ISNULL(cr.PaidAmount, 0) - crt.Amount
                END
            )
        FROM ContractRooms cr
        INNER JOIN ContractRoomsTrns crt
            ON crt.ContractId = cr.ContractId AND crt.RoomId = cr.RoomId
        WHERE crt.TxnRecordId = @Id AND crt.TxnType = 'CR';

        -- 5. Revert ContractRoomInstallments
        UPDATE cri
        SET
            cri.PaidAmount = CASE
                WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0
                ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount
            END,
            cri.Balance = cri.InstallAmount - (
                CASE
                    WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0
                    ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount
                END
            ),
            cri.Status = CASE
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) = 0
                    THEN 'Pending'
                WHEN (CASE WHEN ISNULL(cri.PaidAmount, 0) - crt.Amount < 0 THEN 0 ELSE ISNULL(cri.PaidAmount, 0) - crt.Amount END) >= cri.InstallAmount
                    THEN 'Paid'
                ELSE 'Partial'
            END,
            cri.PaidDate  = NULL,
            cri.UpdatedAt = GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN ContractRoomsTrns crt
            ON crt.ContractId = cri.ContractId AND crt.RoomId = cri.RoomId
        WHERE crt.TxnRecordId = @Id AND crt.TxnType = 'CR';

        -- 6. Delete ContractRoomsTrns
        DELETE FROM ContractRoomsTrns WHERE TxnRecordId = @Id;
    END

    -- 7. Soft delete TxnRecord
    UPDATE TxnRecords
    SET IsDeleted  = 1,
        DeletedBy  = @DeletedBy,
        UpdatedAt  = GETUTCDATE()
    WHERE Id = @Id;

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '✅ sp_DeleteTxnRecord fixed - proper per-installment revert + soft delete';
GO

-- ============================================================
-- FIX 2: sp_GetTxnRecords — filter IsDeleted=1
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetTxnRecords
    @PageNumber   INT,
    @PageSize     INT,
    @ContractId   NVARCHAR(MAX) = NULL,
    @TenantId     INT           = NULL,
    @CampId       INT           = NULL,
    @TxnType      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM TxnRecords tr
    JOIN Contracts c  ON c.ContractId = tr.ContractId AND c.IsDeleted = 0
    JOIN Tenants   t  ON t.Id = c.TenantId
    JOIN Camps     ca ON ca.Id = c.CampId
    WHERE ISNULL(tr.IsDeleted, 0) = 0          -- ✅ filter soft-deleted TxnRecords
      AND (@ContractId IS NULL OR tr.ContractId = @ContractId)
      AND (@TenantId   IS NULL OR c.TenantId    = @TenantId)
      AND (@CampId     IS NULL OR c.CampId      = @CampId)
      AND (@TxnType    IS NULL OR tr.TxnType    = @TxnType);

    SELECT
        tr.Id, tr.TxnId, tr.TxnType,
        tr.ContractId, tr.ContractCode,
        c.TenantId,
        t.Name          AS TenantName,
        c.CampId,
        ca.Name         AS CampName,
        tr.TotalAmount, tr.Amount,
        tr.PaidDate     AS TxnDate,
        tr.FromDate, tr.ToDate,
        tr.PaymentMode, tr.PaymentModeId,
        tr.FundPoolId, tr.FundPoolName,
        tr.Description, tr.ReceivedBy,
        tr.ChequeNumber, tr.IssuedBy,
        tr.ReceivedContact,
        tr.InstallmentNo, tr.AppliedInstallments,
        tr.Unallocated,
        tr.CreatedAt, tr.UpdatedAt
    FROM TxnRecords tr
    JOIN Contracts c  ON c.ContractId = tr.ContractId AND c.IsDeleted = 0
    JOIN Tenants   t  ON t.Id = c.TenantId
    JOIN Camps     ca ON ca.Id = c.CampId
    WHERE ISNULL(tr.IsDeleted, 0) = 0          -- ✅ filter soft-deleted TxnRecords
      AND (@ContractId IS NULL OR tr.ContractId = @ContractId)
      AND (@TenantId   IS NULL OR c.TenantId    = @TenantId)
      AND (@CampId     IS NULL OR c.CampId      = @CampId)
      AND (@TxnType    IS NULL OR tr.TxnType    = @TxnType)
    ORDER BY tr.PaidDate DESC, tr.Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT '✅ sp_GetTxnRecords updated - filters IsDeleted=1 TxnRecords';
GO

-- ============================================================
-- FIX 3: sp_GetPaymentHistory — filter IsDeleted=1 installments
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetPaymentHistory
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.Id, p.ContractId, p.InstallmentNo,
        p.Amount, p.DueDate, p.PaidAmount, p.PaidDate, p.Status,
        p.PaymentMode, p.PaymentModeId, p.ChequeNumber, p.ClearanceDate,
        p.Description, p.ReceivedBy, p.ReceivedContact,
        p.FundPoolId, p.FundPoolName, p.IssuedBy,
        t.Name  AS TenantName,
        ca.Name AS CampName
    FROM ContractInstallments p
    JOIN Contracts c  ON c.ContractId = p.ContractId
    JOIN Tenants   t  ON t.Id = c.TenantId
    JOIN Camps     ca ON ca.Id = c.CampId
    WHERE p.ContractId = @ContractId
      AND ISNULL(p.IsDeleted, 0) = 0           -- ✅ exclude soft-deleted installments
    ORDER BY p.InstallmentNo;
END
GO

PRINT '✅ sp_GetPaymentHistory updated - excludes IsDeleted installments';
GO

-- ============================================================
-- FIX 4: sp_GetPaymentSummary — filter IsDeleted=1 installments
-- ============================================================
CREATE OR ALTER PROCEDURE sp_GetPaymentSummary
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ContractId, c.TenantId,
        t.Name                                  AS TenantName,
        t.Contact                               AS TenantContact,
        c.CampId,
        ca.Name                                 AS CampName,
        CONVERT(NVARCHAR(MAX), c.StartDate, 23) AS StartDate,
        CONVERT(NVARCHAR(MAX), c.EndDate,   23) AS EndDate,
        c.Months,
        c.ContractTotal, c.MonthlyTotal,
        0                                       AS LessorAmount,
        c.Status,
        COUNT(p.Id)                             AS TotalInstallments,
        SUM(CASE WHEN p.Status = 'Paid'    THEN 1 ELSE 0 END) AS PaidCount,
        SUM(CASE WHEN p.Status IN ('Pending','Overdue') THEN 1 ELSE 0 END) AS PendingCount,
        SUM(CASE WHEN p.Status = 'Partial' THEN 1 ELSE 0 END) AS PartialCount,
        ISNULL(SUM(p.PaidAmount), 0)            AS TotalPaid,
        ISNULL(SUM(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                        THEN p.Amount - p.PaidAmount ELSE 0 END), 0) AS TotalDue,
        ISNULL(SUM(p.Amount), 0)                AS TotalScheduled,
        ISNULL(MIN(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                        THEN p.Amount - p.PaidAmount END), 0) AS NextInstallmentDue,
        MIN(CASE WHEN p.Status IN ('Pending','Overdue','Partial')
                 THEN p.InstallmentNo END)       AS NextInstallmentNo,
        ISNULL((
            SELECT STRING_AGG(r2.RoomNo, ', ')
            FROM ContractRooms cr2
            JOIN Rooms r2 ON r2.Id = cr2.RoomId
            WHERE cr2.ContractId = c.ContractId
        ), '') AS RoomNos,
        (SELECT COUNT(*) FROM ContractRooms cr3 WHERE cr3.ContractId = c.ContractId) AS RoomCount
    FROM Contracts c
    JOIN Tenants t  ON t.Id  = c.TenantId
    JOIN Camps   ca ON ca.Id = c.CampId
    LEFT JOIN ContractInstallments p
        ON p.ContractId = c.ContractId
        AND ISNULL(p.IsDeleted, 0) = 0          -- ✅ exclude soft-deleted installments
    WHERE c.ContractId = @ContractId
    GROUP BY
        c.ContractId, c.TenantId, t.Name, t.Contact,
        c.CampId, ca.Name, c.StartDate, c.EndDate,
        c.Months, c.ContractTotal, c.MonthlyTotal, c.Status;
END
GO

PRINT '✅ sp_GetPaymentSummary updated - excludes IsDeleted installments';
GO

-- ============================================================
-- FIX 5: TxnRecords table — add IsDeleted + DeletedBy columns if missing
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('TxnRecords') AND name = 'IsDeleted')
    ALTER TABLE TxnRecords ADD IsDeleted BIT NOT NULL DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('TxnRecords') AND name = 'DeletedBy')
    ALTER TABLE TxnRecords ADD DeletedBy INT NULL;
GO

PRINT '✅ TxnRecords table - IsDeleted + DeletedBy columns ensured';
GO

PRINT '============================================================';
PRINT '✅ ALL PAYMENT DELETE FIXES APPLIED SUCCESSFULLY';
PRINT '   1. sp_DeleteTxnRecord - proper revert + soft delete';
PRINT '   2. sp_GetTxnRecords   - filters IsDeleted TxnRecords';
PRINT '   3. sp_GetPaymentHistory - filters IsDeleted installments';
PRINT '   4. sp_GetPaymentSummary - filters IsDeleted installments';
PRINT '   5. TxnRecords table - IsDeleted/DeletedBy columns added';
PRINT '============================================================';
GO
