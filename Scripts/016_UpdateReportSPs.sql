-- ============================================================
-- 016_UpdateReportSPs.sql — Update all report SPs for full UI column support
-- ============================================================

-- ── TENANT REPORT ──────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTenantReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @CampId INT=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(DISTINCT t.Id) FROM Tenants t
    LEFT JOIN Contracts c ON c.TenantId=t.Id AND c.Status='Active'
    WHERE (@Status IS NULL OR t.Status=@Status)
      AND (@CampId IS NULL OR c.CampId=@CampId)
      AND (@SearchText IS NULL OR t.Name LIKE '%'+@SearchText+'%' OR t.Contact LIKE '%'+@SearchText+'%');

    SELECT
        t.Id                                         TenantId,
        t.Name                                       TenantName,
        t.Contact, t.Email, t.EmiratesId, t.Nationality,
        t.Status,
        ISNULL(t.Type,'Individual')                  [Type],
        ISNULL(c.ContractId,'')                      ContractId,
        ISNULL(ca.Name,'')                           CampName,
        ISNULL(r.RoomNo,'')                          RoomNo,
        c.StartDate ContractStart, c.EndDate ContractEnd,
        ISNULL(c.Status,'')                          ContractStatus,
        ISNULL(c.MonthlyTotal,0)                     MonthlyRent,
        ISNULL(c.ContractTotal,0)                    TotalAmount,
        ISNULL((SELECT COUNT(*) FROM ContractRooms cr2 WHERE cr2.ContractId=c.ContractId),0) RoomsBooked,
        ISNULL((SELECT SUM(ci.PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId),0) TotalPaid,
        ISNULL((SELECT SUM(ci.Amount-ci.PaidAmount) FROM ContractInstallments ci WHERE ci.ContractId=c.ContractId AND ci.Status IN('Pending','Partial')),0) TotalDue,
        ISNULL(c.ContractTotal,0) - ISNULL((SELECT SUM(ci2.PaidAmount) FROM ContractInstallments ci2 WHERE ci2.ContractId=c.ContractId),0) Balance,
        ISNULL((SELECT SUM(w.WaiverAmount) FROM Waivers w WHERE w.ContractId=c.ContractId),0) WaiverAmount
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

-- ── PARTNER REPORT ─────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber INT, @PageSize INT, @SearchText NVARCHAR(MAX)=NULL,
    @Status NVARCHAR(MAX)=NULL, @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords=COUNT(*) FROM Partners p
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%');

    SELECT
        p.Id PartnerId, p.Code PartnerCode, p.Name PartnerName,
        p.Contact, p.Mobile, p.Email, p.Status,
        COUNT(DISTINCT cp.CampId)             TotalCamps,
        ISNULL(STRING_AGG(c.Name,', '),'')    CampNames,
        ISNULL(AVG(CAST(cp.ShareValue AS DECIMAL(18,4))),0) ShareValue,
        ISNULL(MAX(cp.ShareType),'')          ShareType,
        -- Total rent collected across all partner camps
        ISNULL((
            SELECT SUM(ci.PaidAmount)
            FROM ContractInstallments ci
            JOIN Contracts ct ON ct.ContractId=ci.ContractId
            JOIN CampPartners cp2 ON cp2.CampId=ct.CampId AND cp2.PartnerId=p.Id
            WHERE ci.Status='Paid'
        ),0) TotalCollected,
        -- Total paid to partner via Expenses (RecipientRole='Partner')
        ISNULL((
            SELECT SUM(e.Amount) FROM Expenses e
            WHERE e.RecipientRole='Partner' AND e.RecipientName=p.Name
        ),0) TotalPaid,
        -- Balance = Collected (share) - Paid
        0 ShareDue  -- computed client-side from share type/value
    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id
    LEFT JOIN Camps c ON c.Id=cp.CampId
    WHERE (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
    GROUP BY p.Id, p.Code, p.Name, p.Contact, p.Mobile, p.Email, p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── TRANSACTION STATEMENT ─────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetTransactionStatement
    @PageNumber INT, @PageSize INT,
    @SearchText NVARCHAR(MAX)=NULL, @ContractId NVARCHAR(MAX)=NULL,
    @TenantId INT=NULL, @CampId INT=NULL, @Status NVARCHAR(MAX)=NULL,
    @DateFrom DATE=NULL, @DateTo DATE=NULL,
    @Month NVARCHAR(MAX)=NULL, @Year NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- DR = paid installments | CR = expenses
    ;WITH AllTxns AS (
        -- DR rows (paid installments)
        SELECT
            ci.Id, ci.PaidDate [Date], 'Rent Income' AccountHead,
            ISNULL(t.Name,'—') Particular,
            ISNULL(ca.Name,'—') CampName, ca.Id CampId,
            ISNULL(ci.FundPoolName,'—') FundPoolName,
            'DR' TxnType,
            'Inst #'+CAST(ci.InstallmentNo AS NVARCHAR) [Source],
            ISNULL(ci.PaymentMode,'—') [Mode],
            ci.PaidAmount Amount, ci.Status, ct.ContractId,
            ISNULL(t.Name,'—') TenantName, ISNULL(ca.Name,'—') Camp
        FROM ContractInstallments ci
        JOIN Contracts ct ON ct.ContractId=ci.ContractId
        LEFT JOIN Tenants t ON t.Id=ct.TenantId
        LEFT JOIN Camps ca ON ca.Id=ct.CampId
        WHERE ci.Status='Paid'
        UNION ALL
        -- CR rows (expenses)
        SELECT
            e.Id, e.Date, e.Head AccountHead,
            ISNULL(e.RecipientName,'—') Particular,
            ISNULL(e.CampName,'—') CampName,
            e.CampId,
            ISNULL(e.FundPoolName,'—') FundPoolName,
            'CR' TxnType,
            ISNULL(e.ExpenseId,'—') [Source],
            ISNULL(e.Mode,'—') [Mode],
            e.Amount, 'Paid' Status, '—' ContractId,
            ISNULL(e.RecipientName,'—') TenantName,
            ISNULL(e.CampName, CASE WHEN e.Nature='HO' THEN 'HO' ELSE '—' END) Camp
        FROM Expenses e
    )
    SELECT @TotalRecords=COUNT(*) FROM AllTxns
    WHERE (@Status IS NULL OR (@Status='DR' AND TxnType='DR') OR (@Status='CR' AND TxnType='CR'))
      AND (@CampId IS NULL OR CampId=@CampId)
      AND (@ContractId IS NULL OR ContractId=@ContractId)
      AND (@DateFrom IS NULL OR [Date]>=@DateFrom)
      AND (@DateTo IS NULL OR [Date]<=@DateTo);

    SELECT TOP 5000
        Id, [Date], AccountHead, Particular, CampName, FundPoolName,
        TxnType, [Source], [Mode], Amount, Status, ContractId, TenantName, Camp
    FROM AllTxns
    WHERE (@Status IS NULL OR (@Status='DR' AND TxnType='DR') OR (@Status='CR' AND TxnType='CR'))
      AND (@CampId IS NULL OR CampId=@CampId)
      AND (@ContractId IS NULL OR ContractId=@ContractId)
      AND (@DateFrom IS NULL OR [Date]>=@DateFrom)
      AND (@DateTo IS NULL OR [Date]<=@DateTo)
    ORDER BY [Date] DESC;
END
GO

-- ── MONTHLY DUE REPORT ─────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetDueReport
    @PageNumber INT=1, @PageSize INT=2147483647,
    @TenantId INT=NULL, @CampId INT=NULL,
    @Month NVARCHAR(MAX)=NULL, @Status NVARCHAR(MAX)=NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords = COUNT(*)
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN Tenants t ON t.Id=ct.TenantId
    LEFT JOIN Camps ca ON ca.Id=ct.CampId
    WHERE ci.Status IN ('Pending','Partial')
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR ct.CampId=@CampId)
      AND (@Month IS NULL OR FORMAT(ci.DueDate,'yyyy-MM')=@Month);

    SELECT
        ci.Id, ci.ContractId, ci.InstallmentNo,
        ci.Amount, ci.PaidAmount,
        ci.Amount - ci.PaidAmount  BalanceAmount,
        ci.DueDate, ci.Status,
        ISNULL(ci.PaymentMode,'—') PaymentMode,
        ISNULL(t.Name,'—')         TenantName,
        ct.TenantId,
        ISNULL(ca.Name,'—')        CampName,
        CASE WHEN ci.DueDate < GETDATE() THEN 'Overdue' ELSE 'Pending' END DueStatus
    FROM ContractInstallments ci
    JOIN Contracts ct ON ct.ContractId=ci.ContractId
    LEFT JOIN Tenants t ON t.Id=ct.TenantId
    LEFT JOIN Camps ca ON ca.Id=ct.CampId
    WHERE ci.Status IN ('Pending','Partial')
      AND (@TenantId IS NULL OR ct.TenantId=@TenantId)
      AND (@CampId IS NULL OR ct.CampId=@CampId)
      AND (@Month IS NULL OR FORMAT(ci.DueDate,'yyyy-MM')=@Month)
    ORDER BY ci.DueDate
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
