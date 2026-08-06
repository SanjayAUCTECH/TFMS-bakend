-- ══════════════════════════════════════════════════════════════════════════════
-- OWNER PAYMENT MODULE — Stored Procedures (FIXED)
-- Company pays Owner (Expense)
-- NOTE: OwnerContracts does NOT have PaidAmount/Balance columns
--       They are computed from OwnerInstallments SUM
-- ══════════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. sp_GetOwnerPaymentSummary
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetOwnerPaymentSummary') DROP PROCEDURE sp_GetOwnerPaymentSummary;
GO
CREATE PROCEDURE sp_GetOwnerPaymentSummary
    @OwnerContractId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        oc.Id AS OwnerContractId,
        oc.OcCode,
        oc.OwnerId,
        ISNULL(o.Name, '') AS OwnerName,
        oc.CampId,
        ISNULL(c.Name, '') AS CampName,
        CONVERT(VARCHAR(10), oc.StartDate, 120) AS StartDate,
        CASE WHEN oc.EndDate IS NOT NULL THEN CONVERT(VARCHAR(10), oc.EndDate, 120) ELSE '' END AS EndDate,
        oc.TotalAmount AS TotalPayable,
        ISNULL((SELECT SUM(ISNULL(oi.PaidAmount,0)) FROM OwnerInstallments oi WHERE oi.OwnerContractId=oc.Id AND ISNULL(oi.IsDeleted,0)=0), 0) AS TotalPaidToOwner,
        ISNULL(oc.MonthlyRent, 0) AS MonthlyRent,
        ISNULL(oc.NoOfMonths, 0) AS NoOfMonths,
        (SELECT COUNT(*) FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @OwnerContractId AND ISNULL(IsDeleted,0)=0) AS TotalInstallments,
        (SELECT COUNT(*) FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @OwnerContractId AND ISNULL(IsDeleted,0)=0 AND Status = 'Paid') AS PaidCount,
        (SELECT COUNT(*) FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @OwnerContractId AND ISNULL(IsDeleted,0)=0 AND Status = 'Pending') AS PendingCount,
        (SELECT COUNT(*) FROM OwnerMonthlyContractInstallments WHERE OwnerContractId = @OwnerContractId AND ISNULL(IsDeleted,0)=0 AND Status = 'Partial') AS PartialCount,
        ISNULL(oc.SecurityDeposit, 0) AS SecurityDeposit,
        ISNULL(oc.SecurityDepositPaid, 0) AS SecurityDepositPaid,
        ISNULL(oc.PaymentType, '') AS PaymentType,
        oc.Status
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId
    LEFT JOIN Camps c ON c.Id = oc.CampId
    WHERE oc.Id = @OwnerContractId AND ISNULL(oc.IsDeleted, 0) = 0;
END;
GO

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. sp_GetOwnerPaymentHistory
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_GetOwnerPaymentHistory') DROP PROCEDURE sp_GetOwnerPaymentHistory;
GO
CREATE PROCEDURE sp_GetOwnerPaymentHistory
    @OwnerContractId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.Id,
        ISNULL(t.TxnCode, '') AS TxnCode,
        ISNULL(t.OcCode, '') AS OcCode,
        t.Amount,
        CONVERT(VARCHAR(10), t.Date, 120) AS Date,
        ISNULL(t.Description, '') AS Description,
        ISNULL(t.InstallmentNos, '') AS InstallmentNos,
        ISNULL(t.PaymentMode, '') AS PaymentMode,
        ISNULL(t.ReferenceNo, '') AS ReferenceNo,
        ISNULL(t.Description, '') AS PaidBy,
        '' AS FundPoolName,
        t.ExpenseId,
        ISNULL(t.Type, 'CR') AS Type,
        t.CreatedAt
    FROM OwnerTransactions t
    WHERE t.OwnerContractId = @OwnerContractId
      AND t.Type IN ('CR', 'SD-PAY', 'SD-SETTLE')
    ORDER BY t.Date DESC, t.Id DESC;
END;
GO

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. sp_PayOwner — Record payment to owner (Company Expense)
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_PayOwner') DROP PROCEDURE sp_PayOwner;
GO
CREATE PROCEDURE sp_PayOwner
    @OwnerContractId INT,
    @InstallmentNos  NVARCHAR(200),
    @Amount          DECIMAL(18,2),
    @PaidDate        DATETIME,
    @PaymentModeId   INT = NULL,
    @PaymentMode     NVARCHAR(100) = 'Cash',
    @ChequeNumber    NVARCHAR(100) = '',
    @ReferenceNo     NVARCHAR(100) = '',
    @FundPoolId      INT = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @PaidBy          NVARCHAR(200) = '',
    @Notes           NVARCHAR(500) = '',
    @AddedBy         INT = NULL,
    @TxnCode         NVARCHAR(50) OUTPUT,
    @ExpenseId       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @OcCode NVARCHAR(50), @OwnerId INT, @CampId INT,
            @OwnerName NVARCHAR(200), @CampName NVARCHAR(200),
            @FundPoolCode NVARCHAR(50) = '';
    
    -- Get contract info
    SELECT @OcCode = oc.OcCode, @OwnerId = oc.OwnerId, @CampId = oc.CampId,
           @OwnerName = ISNULL(o.Name, ''), @CampName = ISNULL(c.Name, '')
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId
    LEFT JOIN Camps c ON c.Id = oc.CampId
    WHERE oc.Id = @OwnerContractId;

    -- Get FundPool Code
    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode = Code, @FundPoolName = Name FROM FundPools WHERE Id = @FundPoolId;

    -- Generate TxnCode
    DECLARE @NextId INT = (SELECT ISNULL(MAX(Id), 0) + 1 FROM OwnerTransactions);
    SET @TxnCode = 'OPY-' + RIGHT('000000' + CAST(@NextId AS VARCHAR), 6);

    -- 1. Insert OwnerTransaction (CR = Cash Released to owner)
    INSERT INTO OwnerTransactions (TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
                                   Type, Amount, Date, Description, InstallmentNos, PaymentMode, ReferenceNo, CreatedAt)
    VALUES (@TxnCode, @OwnerContractId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
            'CR', @Amount, @PaidDate, 
            CASE WHEN @Notes != '' THEN @Notes ELSE 'Payment to owner - ' + @PaymentMode END,
            @InstallmentNos, @PaymentMode, ISNULL(@ChequeNumber, @ReferenceNo), GETDATE());

    -- 2. Update OwnerContracts timestamp only (PaidAmount computed from OwnerInstallments)
    UPDATE OwnerContracts SET UpdatedAt = GETDATE() WHERE Id = @OwnerContractId;

    -- 3. Update OwnerMonthlyContractInstallments (if specific installments provided)
    IF @InstallmentNos IS NOT NULL AND @InstallmentNos != ''
    BEGIN
        DECLARE @RemainingAmount DECIMAL(18,2) = @Amount;
        DECLARE @InstNo INT;
        
        DECLARE installment_cursor CURSOR FOR
            SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstallmentNos, ',')
            WHERE ISNUMERIC(value) = 1 ORDER BY CAST(value AS INT);
        
        OPEN installment_cursor;
        FETCH NEXT FROM installment_cursor INTO @InstNo;
        
        WHILE @@FETCH_STATUS = 0 AND @RemainingAmount > 0
        BEGIN
            DECLARE @InstBalance DECIMAL(18,2);
            SELECT @InstBalance = Balance FROM OwnerMonthlyContractInstallments
            WHERE OwnerContractId = @OwnerContractId AND InstallmentNo = @InstNo AND ISNULL(IsDeleted,0)=0;
            
            IF @InstBalance IS NOT NULL AND @InstBalance > 0
            BEGIN
                DECLARE @PayThis DECIMAL(18,2) = CASE WHEN @RemainingAmount >= @InstBalance THEN @InstBalance ELSE @RemainingAmount END;
                
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount = ISNULL(PaidAmount, 0) + @PayThis,
                    Balance = Balance - @PayThis,
                    PaidDate = @PaidDate,
                    PaymentMode = @PaymentMode,
                    PaymentStatus = CASE WHEN (ISNULL(PaidAmount, 0) + @PayThis) >= Amount THEN 'Paid' ELSE 'Partial' END,
                    Status = CASE WHEN (ISNULL(PaidAmount, 0) + @PayThis) >= Amount THEN 'Paid' ELSE 'Partial' END,
                    ReferenceNo = ISNULL(@ChequeNumber, @ReferenceNo),
                    UpdatedAt = GETDATE()
                WHERE OwnerContractId = @OwnerContractId AND InstallmentNo = @InstNo AND ISNULL(IsDeleted,0)=0;
                
                SET @RemainingAmount = @RemainingAmount - @PayThis;
            END;
            
            FETCH NEXT FROM installment_cursor INTO @InstNo;
        END;
        
        CLOSE installment_cursor;
        DEALLOCATE installment_cursor;
    END;

    -- 4. Also update OwnerInstallments (main installment table)
    IF @InstallmentNos IS NOT NULL AND @InstallmentNos != ''
    BEGIN
        DECLARE @RemAmount2 DECIMAL(18,2) = @Amount;
        DECLARE @InstNo2 INT;
        
        DECLARE inst_cursor2 CURSOR FOR
            SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstallmentNos, ',')
            WHERE ISNUMERIC(value) = 1 ORDER BY CAST(value AS INT);
        
        OPEN inst_cursor2;
        FETCH NEXT FROM inst_cursor2 INTO @InstNo2;
        
        WHILE @@FETCH_STATUS = 0 AND @RemAmount2 > 0
        BEGIN
            DECLARE @OIBalance DECIMAL(18,2);
            SELECT @OIBalance = (Amount - ISNULL(PaidAmount,0)) FROM OwnerInstallments
            WHERE OwnerContractId = @OwnerContractId AND No = @InstNo2 AND ISNULL(IsDeleted,0)=0;
            
            IF @OIBalance IS NOT NULL AND @OIBalance > 0
            BEGIN
                DECLARE @PayThis2 DECIMAL(18,2) = CASE WHEN @RemAmount2 >= @OIBalance THEN @OIBalance ELSE @RemAmount2 END;
                
                UPDATE OwnerInstallments
                SET PaidAmount = ISNULL(PaidAmount, 0) + @PayThis2,
                    PaidDate = @PaidDate,
                    PaymentMode = @PaymentMode,
                    ReferenceNo = ISNULL(@ChequeNumber, @ReferenceNo),
                    Status = CASE WHEN (ISNULL(PaidAmount, 0) + @PayThis2) >= Amount THEN 'Paid' ELSE 'Partial' END
                WHERE OwnerContractId = @OwnerContractId AND No = @InstNo2 AND ISNULL(IsDeleted,0)=0;
                
                SET @RemAmount2 = @RemAmount2 - @PayThis2;
            END;
            
            FETCH NEXT FROM inst_cursor2 INTO @InstNo2;
        END;
        
        CLOSE inst_cursor2;
        DEALLOCATE inst_cursor2;
    END;

    -- 5. Insert Expense record (Company expense for paying owner)
    DECLARE @ExpId NVARCHAR(MAX) = 'EXP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);

    INSERT INTO Expenses(
        ExpenseId, Date, Mode, Head, FundPool, FundPoolName, Amount, Nature,
        CampId, CampName, RecipientRole, RecipientName, Purpose,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @ExpId, @PaidDate, @PaymentMode, 'Owner Payment', @FundPoolCode, @FundPoolName, @Amount, 'Camp',
        @CampId, @CampName, 'Owner', @OwnerName,
        'Owner Payment - ' + @OcCode + ' - Inst: ' + @InstallmentNos,
        @AddedBy, 0, GETDATE(), GETDATE()
    );
    SET @ExpenseId = SCOPE_IDENTITY();

    -- 6. Update OwnerTransaction with ExpenseId
    UPDATE OwnerTransactions SET ExpenseId = @ExpenseId WHERE TxnCode = @TxnCode;

    -- 7. Deduct from FundPool (money going out to owner)
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance = Balance - @Amount, UpdatedAt = GETDATE() WHERE Id = @FundPoolId;
END;
GO

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. sp_DeleteOwnerPayment — Reverse a payment
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_DeleteOwnerPayment') DROP PROCEDURE sp_DeleteOwnerPayment;
GO
CREATE PROCEDURE sp_DeleteOwnerPayment
    @TxnId     INT,
    @DeletedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OwnerContractId INT, @Amount DECIMAL(18,2), @InstallmentNos NVARCHAR(200),
            @ExpenseId INT, @FundPoolCode NVARCHAR(50), @FundPoolId INT;

    -- Get transaction details
    SELECT @OwnerContractId = OwnerContractId, @Amount = Amount,
           @InstallmentNos = InstallmentNos, @ExpenseId = ExpenseId
    FROM OwnerTransactions WHERE Id = @TxnId;

    IF @OwnerContractId IS NULL RETURN;

    -- Get FundPool info from Expense
    IF @ExpenseId IS NOT NULL
        SELECT @FundPoolCode = FundPool FROM Expenses WHERE Id = @ExpenseId;

    -- Get FundPoolId from Code
    IF @FundPoolCode IS NOT NULL AND LEN(@FundPoolCode) > 0
        SELECT @FundPoolId = Id FROM FundPools WHERE Code = @FundPoolCode;

    -- 1. Reverse OwnerMonthlyContractInstallments
    IF @InstallmentNos IS NOT NULL AND @InstallmentNos != ''
    BEGIN
        DECLARE @RemainingReverse DECIMAL(18,2) = @Amount;
        DECLARE @RevInstNo INT;
        
        DECLARE rev_cursor CURSOR FOR
            SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstallmentNos, ',')
            WHERE ISNUMERIC(value) = 1 ORDER BY CAST(value AS INT) DESC;
        
        OPEN rev_cursor;
        FETCH NEXT FROM rev_cursor INTO @RevInstNo;
        
        WHILE @@FETCH_STATUS = 0 AND @RemainingReverse > 0
        BEGIN
            DECLARE @InstPaid DECIMAL(18,2);
            SELECT @InstPaid = PaidAmount FROM OwnerMonthlyContractInstallments
            WHERE OwnerContractId = @OwnerContractId AND InstallmentNo = @RevInstNo AND ISNULL(IsDeleted,0)=0;
            
            IF @InstPaid IS NOT NULL AND @InstPaid > 0
            BEGIN
                DECLARE @ReverseThis DECIMAL(18,2) = CASE WHEN @RemainingReverse >= @InstPaid THEN @InstPaid ELSE @RemainingReverse END;
                
                UPDATE OwnerMonthlyContractInstallments
                SET PaidAmount = ISNULL(PaidAmount, 0) - @ReverseThis,
                    Balance = Balance + @ReverseThis,
                    Status = CASE WHEN (ISNULL(PaidAmount, 0) - @ReverseThis) <= 0 THEN 'Pending'
                                  WHEN (ISNULL(PaidAmount, 0) - @ReverseThis) < Amount THEN 'Partial'
                                  ELSE 'Paid' END,
                    PaymentStatus = CASE WHEN (ISNULL(PaidAmount, 0) - @ReverseThis) <= 0 THEN 'Pending'
                                         WHEN (ISNULL(PaidAmount, 0) - @ReverseThis) < Amount THEN 'Partial'
                                         ELSE 'Paid' END,
                    PaidDate = CASE WHEN (ISNULL(PaidAmount, 0) - @ReverseThis) <= 0 THEN NULL ELSE PaidDate END,
                    UpdatedAt = GETDATE()
                WHERE OwnerContractId = @OwnerContractId AND InstallmentNo = @RevInstNo AND ISNULL(IsDeleted,0)=0;
                
                SET @RemainingReverse = @RemainingReverse - @ReverseThis;
            END;
            
            FETCH NEXT FROM rev_cursor INTO @RevInstNo;
        END;
        
        CLOSE rev_cursor;
        DEALLOCATE rev_cursor;
    END;

    -- 2. Reverse OwnerInstallments
    IF @InstallmentNos IS NOT NULL AND @InstallmentNos != ''
    BEGIN
        DECLARE @RemRev2 DECIMAL(18,2) = @Amount;
        DECLARE @RevNo2 INT;
        
        DECLARE rev2_cursor CURSOR FOR
            SELECT CAST(value AS INT) FROM STRING_SPLIT(@InstallmentNos, ',')
            WHERE ISNUMERIC(value) = 1 ORDER BY CAST(value AS INT) DESC;
        
        OPEN rev2_cursor;
        FETCH NEXT FROM rev2_cursor INTO @RevNo2;
        
        WHILE @@FETCH_STATUS = 0 AND @RemRev2 > 0
        BEGIN
            DECLARE @OIPaid DECIMAL(18,2);
            SELECT @OIPaid = PaidAmount FROM OwnerInstallments
            WHERE OwnerContractId = @OwnerContractId AND No = @RevNo2 AND ISNULL(IsDeleted,0)=0;
            
            IF @OIPaid IS NOT NULL AND @OIPaid > 0
            BEGIN
                DECLARE @RevThis2 DECIMAL(18,2) = CASE WHEN @RemRev2 >= @OIPaid THEN @OIPaid ELSE @RemRev2 END;
                
                UPDATE OwnerInstallments
                SET PaidAmount = ISNULL(PaidAmount, 0) - @RevThis2,
                    Status = CASE WHEN (ISNULL(PaidAmount, 0) - @RevThis2) <= 0 THEN 'Pending'
                                  WHEN (ISNULL(PaidAmount, 0) - @RevThis2) < Amount THEN 'Partial'
                                  ELSE 'Paid' END,
                    PaidDate = CASE WHEN (ISNULL(PaidAmount, 0) - @RevThis2) <= 0 THEN NULL ELSE PaidDate END
                WHERE OwnerContractId = @OwnerContractId AND No = @RevNo2 AND ISNULL(IsDeleted,0)=0;
                
                SET @RemRev2 = @RemRev2 - @RevThis2;
            END;
            
            FETCH NEXT FROM rev2_cursor INTO @RevNo2;
        END;
        
        CLOSE rev2_cursor;
        DEALLOCATE rev2_cursor;
    END;

    -- 3. Delete OwnerTransaction
    DELETE FROM OwnerTransactions WHERE Id = @TxnId;

    -- 4. Soft-delete Expense
    IF @ExpenseId IS NOT NULL
        UPDATE Expenses SET IsDeleted = 1, UpdatedAt = GETDATE() WHERE Id = @ExpenseId;

    -- 5. Restore FundPool balance (money comes back)
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETDATE() WHERE Id = @FundPoolId;

    -- 6. Update contract timestamp
    UPDATE OwnerContracts SET UpdatedAt = GETDATE() WHERE Id = @OwnerContractId;
END;
GO

-- ──────────────────────────────────────────────────────────────────────────────
-- 5. sp_PayOwnerSecurityDeposit — Pay SD to owner
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_PayOwnerSecurityDeposit') DROP PROCEDURE sp_PayOwnerSecurityDeposit;
GO
CREATE PROCEDURE sp_PayOwnerSecurityDeposit
    @OwnerContractId INT,
    @Amount          DECIMAL(18,2),
    @PaidDate        DATETIME,
    @PaymentMode     NVARCHAR(100) = 'Cash',
    @PaymentModeId   INT = NULL,
    @ChequeNumber    NVARCHAR(100) = '',
    @FundPoolId      INT = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @PaidBy          NVARCHAR(200) = 'Admin',
    @Notes           NVARCHAR(500) = '',
    @NewPaid         DECIMAL(18,2) OUTPUT,
    @NewStatus       NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OcCode NVARCHAR(50), @OwnerId INT, @CampId INT,
            @OwnerName NVARCHAR(200), @CampName NVARCHAR(200),
            @SDAmount DECIMAL(18,2), @SDPaid DECIMAL(18,2),
            @FundPoolCode NVARCHAR(50) = '';

    SELECT @OcCode = oc.OcCode, @OwnerId = oc.OwnerId, @CampId = oc.CampId,
           @OwnerName = ISNULL(o.Name, ''), @CampName = ISNULL(c.Name, ''),
           @SDAmount = ISNULL(oc.SecurityDeposit, 0), @SDPaid = ISNULL(oc.SecurityDepositPaid, 0)
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId
    LEFT JOIN Camps c ON c.Id = oc.CampId
    WHERE oc.Id = @OwnerContractId;

    -- Get FundPool Code
    IF @FundPoolId IS NOT NULL
        SELECT @FundPoolCode = Code, @FundPoolName = Name FROM FundPools WHERE Id = @FundPoolId;

    -- Update SecurityDepositPaid
    SET @NewPaid = @SDPaid + @Amount;
    SET @NewStatus = CASE WHEN @NewPaid >= @SDAmount THEN 'Paid'
                         WHEN @NewPaid > 0 THEN 'Partially Paid'
                         ELSE 'Pending' END;

    UPDATE OwnerContracts
    SET SecurityDepositPaid = @NewPaid,
        SecurityDepositPaidDate = @PaidDate,
        UpdatedAt = GETDATE()
    WHERE Id = @OwnerContractId;

    -- Insert OwnerTransaction (SD-PAY)
    DECLARE @TxnCode NVARCHAR(50) = 'OSD-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS VARCHAR), 6);

    INSERT INTO OwnerTransactions (TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
                                   Type, Amount, Date, Description, PaymentMode, ReferenceNo, CreatedAt)
    VALUES (@TxnCode, @OwnerContractId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
            'SD-PAY', @Amount, @PaidDate,
            CASE WHEN @Notes != '' THEN @Notes ELSE 'Security deposit paid to owner - ' + @PaymentMode END,
            @PaymentMode, @ChequeNumber, GETDATE());

    -- Deduct from FundPool
    IF @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance = Balance - @Amount, UpdatedAt = GETDATE() WHERE Id = @FundPoolId;

    -- Insert Expense (using correct column names)
    DECLARE @ExpId2 NVARCHAR(MAX) = 'EXP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);

    INSERT INTO Expenses(
        ExpenseId, Date, Mode, Head, FundPool, FundPoolName, Amount, Nature,
        CampId, CampName, RecipientRole, RecipientName, Purpose,
        IsDeleted, CreatedAt, UpdatedAt
    )
    VALUES(
        @ExpId2, @PaidDate, @PaymentMode, 'Owner SD Payment', @FundPoolCode, @FundPoolName, @Amount, 'Camp',
        @CampId, @CampName, 'Owner', @OwnerName,
        'Owner SD Payment - ' + @OcCode + ' - ' + @OwnerName,
        0, GETDATE(), GETDATE()
    );
END;
GO

-- ──────────────────────────────────────────────────────────────────────────────
-- 6. sp_SettleOwnerSecurityDeposit — Recover/adjust SD from owner
-- ──────────────────────────────────────────────────────────────────────────────
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_SettleOwnerSecurityDeposit') DROP PROCEDURE sp_SettleOwnerSecurityDeposit;
GO
CREATE PROCEDURE sp_SettleOwnerSecurityDeposit
    @OwnerContractId INT,
    @RecoverAmount   DECIMAL(18,2) = 0,
    @AdjustAmount    DECIMAL(18,2) = 0,
    @ForfeitAmount   DECIMAL(18,2) = 0,
    @FundPoolId      INT = NULL,
    @FundPoolName    NVARCHAR(200) = '',
    @Notes           NVARCHAR(500) = '',
    @SettledBy       NVARCHAR(200) = 'Admin',
    @NewStatus       NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OcCode NVARCHAR(50), @OwnerId INT, @CampId INT,
            @OwnerName NVARCHAR(200), @CampName NVARCHAR(200);

    SELECT @OcCode = oc.OcCode, @OwnerId = oc.OwnerId, @CampId = oc.CampId,
           @OwnerName = ISNULL(o.Name, ''), @CampName = ISNULL(c.Name, '')
    FROM OwnerContracts oc
    LEFT JOIN Owners o ON o.Id = oc.OwnerId
    LEFT JOIN Camps c ON c.Id = oc.CampId
    WHERE oc.Id = @OwnerContractId;

    -- Determine status
    SET @NewStatus = CASE
        WHEN @RecoverAmount > 0 THEN 'Recovered'
        WHEN @ForfeitAmount > 0 THEN 'Forfeited'
        WHEN @AdjustAmount > 0 THEN 'Adjusted'
        ELSE 'Settled' END;

    -- Insert OwnerTransaction (SD-SETTLE)
    DECLARE @TxnCode NVARCHAR(50) = 'OSS-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS VARCHAR), 6);
    DECLARE @TotalSettled DECIMAL(18,2) = @RecoverAmount + @AdjustAmount + @ForfeitAmount;

    INSERT INTO OwnerTransactions (TxnCode, OwnerContractId, OcCode, CampId, CampName, OwnerId, OwnerName,
                                   Type, Amount, Date, Description, PaymentMode, CreatedAt)
    VALUES (@TxnCode, @OwnerContractId, @OcCode, @CampId, @CampName, @OwnerId, @OwnerName,
            'SD-SETTLE', @TotalSettled, GETDATE(),
            'SD Settlement - Recover:' + CAST(@RecoverAmount AS VARCHAR) + ' Adjust:' + CAST(@AdjustAmount AS VARCHAR) + ' Forfeit:' + CAST(@ForfeitAmount AS VARCHAR) + ' ' + @Notes,
            '', GETDATE());

    -- If recovering, add back to FundPool (money coming back from owner)
    IF @RecoverAmount > 0 AND @FundPoolId IS NOT NULL
        UPDATE FundPools SET Balance = Balance + @RecoverAmount, UpdatedAt = GETDATE() WHERE Id = @FundPoolId;

    -- Update contract timestamp
    UPDATE OwnerContracts SET UpdatedAt = GETDATE() WHERE Id = @OwnerContractId;
END;
GO

PRINT '✅ 149 - All Owner Payment SPs created successfully';
GO
