USE TFMS_softwareDB;
GO

-- Generate installment payments for all contracts
DECLARE @cid NVARCHAR(20), @months INT, @sd DATE, @monthly DECIMAL(18,2), @rn INT;

DECLARE cc CURSOR FOR
    SELECT ContractId, Months, StartDate, MonthlyTotal,
           ROW_NUMBER() OVER(ORDER BY Id) - 1  -- 0-indexed row number
    FROM Contracts ORDER BY Id;

OPEN cc;
FETCH NEXT FROM cc INTO @cid, @months, @sd, @monthly, @rn;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @inst INT = 1;
    WHILE @inst <= @months
    BEGIN
        DECLARE @dd     DATE          = DATEADD(MONTH, @inst - 1, @sd);
        -- UI logic: paid if (inst%2==0) OR (ci<8) OR (inst%3==1)
        DECLARE @paid   BIT           = CASE WHEN (@inst%2=0 OR @rn<8 OR @inst%3=1) THEN 1 ELSE 0 END;
        DECLARE @pmId   INT           = ((@inst - 1) % 6) + 1;
        DECLARE @pmName NVARCHAR(50)  = (SELECT Name FROM PaymentModes WHERE Id = @pmId);
        DECLARE @fpId   INT           = ((@inst - 1) % 3) + 1;
        DECLARE @fpName NVARCHAR(200) = (SELECT Name FROM FundPools WHERE Id = @fpId);

        INSERT INTO Payments(
            ContractId, InstallmentNo, Amount, DueDate,
            PaidAmount, PaidDate, Status,
            PaymentMode, PaymentModeId, ChequeNumber, ClearanceDate,
            Description, ReceivedBy, ReceivedContact,
            FundPoolId, FundPoolName, IssuedBy)
        VALUES(
            @cid, @inst, @monthly, @dd,
            CASE WHEN @paid=1 THEN @monthly ELSE 0 END,
            CASE WHEN @paid=1 THEN @dd      ELSE NULL END,
            CASE WHEN @paid=1 THEN 'Paid'   ELSE 'Pending' END,
            @pmName, @pmId,
            CASE WHEN @paid=1 AND @pmName='Cheque' THEN 'CHQ'+CAST(1000+@inst AS NVARCHAR) ELSE '' END,
            CASE WHEN @paid=1 THEN CAST(@dd AS NVARCHAR(20)) ELSE '' END,
            CASE WHEN @paid=1 THEN 'Monthly rent payment' ELSE 'Due rent' END,
            '', '',
            CASE WHEN @paid=1 THEN @fpId   ELSE NULL END,
            CASE WHEN @paid=1 THEN @fpName ELSE '' END,
            'admin');

        SET @inst += 1;
    END
    FETCH NEXT FROM cc INTO @cid, @months, @sd, @monthly, @rn;
END

CLOSE cc;
DEALLOCATE cc;
GO

-- Mark past-due pending as Overdue
UPDATE Payments
SET Status = 'Overdue'
WHERE Status = 'Pending' AND DueDate < CAST(GETUTCDATE() AS DATE);
GO

-- Insert 8 sample waivers on overdue/pending installments
DECLARE @wCursor CURSOR;
SET @wCursor = CURSOR FOR
    SELECT TOP 8 p.Id, p.ContractId, p.InstallmentNo, p.Amount, c.TenantId
    FROM Payments p
    JOIN Contracts c ON c.ContractId = p.ContractId
    WHERE p.Status IN ('Pending','Overdue')
    ORDER BY p.Id;

DECLARE @pid INT, @pcid NVARCHAR(20), @pinst INT, @pamt DECIMAL(18,2), @ptid INT;
OPEN @wCursor;
FETCH NEXT FROM @wCursor INTO @pid, @pcid, @pinst, @pamt, @ptid;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @wa DECIMAL(18,2) = ROUND(@pamt * 0.05, 2);
    INSERT INTO Waivers(TenantId, ContractId, InstallmentNo, OriginalAmount, WaiverAmount, BalanceAmount, Remark, WaiverDate)
    VALUES(@ptid, @pcid, @pinst, @pamt, @wa, @pamt - @wa, 'Early payment discount', '2026-03-15');
    UPDATE Payments SET Amount = @pamt - @wa WHERE Id = @pid;
    FETCH NEXT FROM @wCursor INTO @pid, @pcid, @pinst, @pamt, @ptid;
END
CLOSE @wCursor;
DEALLOCATE @wCursor;
GO

-- Final summary
PRINT '=== FINAL DATA SUMMARY ===';
SELECT 'Partners'      AS [Table], COUNT(*) AS [Rows] FROM Partners      UNION ALL
SELECT 'Owners',       COUNT(*) FROM Owners         UNION ALL
SELECT 'Floors',       COUNT(*) FROM Floors          UNION ALL
SELECT 'Designations', COUNT(*) FROM Designations    UNION ALL
SELECT 'AccountsHeads',COUNT(*) FROM AccountsHeads   UNION ALL
SELECT 'FundPools',    COUNT(*) FROM FundPools        UNION ALL
SELECT 'Roles',        COUNT(*) FROM Roles            UNION ALL
SELECT 'OtherPersons', COUNT(*) FROM OtherPersons     UNION ALL
SELECT 'Camps',        COUNT(*) FROM Camps            UNION ALL
SELECT 'Rooms',        COUNT(*) FROM Rooms            UNION ALL
SELECT 'Tenants',      COUNT(*) FROM Tenants          UNION ALL
SELECT 'Contracts',    COUNT(*) FROM Contracts        UNION ALL
SELECT 'Payments',     COUNT(*) FROM Payments         UNION ALL
SELECT 'Waivers',      COUNT(*) FROM Waivers;
GO
