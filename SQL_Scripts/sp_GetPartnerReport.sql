SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @PartnerId   INT           = NULL,
    @CampId      INT           = NULL,
    @DateFrom    DATE          = NULL,
    @DateTo      DATE          = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Get filtered partner IDs (by camp filter if needed)
    DECLARE @FilteredPartners TABLE (PartnerId INT);

    IF @CampId IS NOT NULL
    BEGIN
        INSERT INTO @FilteredPartners
        SELECT DISTINCT cp.PartnerId
        FROM CampPartners cp
        WHERE cp.CampId = @CampId AND ISNULL(cp.IsDeleted,0)=0;
    END

    SELECT @TotalRecords = COUNT(*) FROM Partners p
    WHERE p.IsDeleted=0
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@PartnerId IS NULL OR p.Id=@PartnerId)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR p.Id IN (SELECT PartnerId FROM @FilteredPartners));

    SELECT
        p.Id AS PartnerId, p.Code AS PartnerCode, p.Name AS PartnerName,
        ISNULL(p.Contact,'') AS Contact, ISNULL(p.Mobile,'') AS Mobile,
        ISNULL(p.Email,'') AS Email, p.Status,
        COUNT(DISTINCT cp.CampId) AS TotalCamps,
        ISNULL(STUFF((SELECT DISTINCT ', '+c2.Name FROM CampPartners cp2 JOIN Camps c2 ON c2.Id=cp2.CampId AND c2.IsDeleted=0 WHERE cp2.PartnerId=p.Id AND ISNULL(cp2.IsDeleted,0)=0 FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)'),1,2,''),'') AS CampNames,
        ISNULL(MAX(cp.ShareValue),0) AS ShareValue,
        ISNULL(MAX(cp.ShareType),'') AS ShareType,

        -- TotalCollected (with date filter)
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i
                WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0
                  AND (@DateFrom IS NULL OR CAST(i.[Date] AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(i.[Date] AS DATE) <= @DateTo)
        ),0) AS TotalCollected,

        -- TotalPaid (with date filter)
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e
                WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0
                  AND (@DateFrom IS NULL OR CAST(e.[Date] AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(e.[Date] AS DATE) <= @DateTo)
        ),0) AS TotalPaid,

        -- ShareDue
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i
                WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0
                  AND (@DateFrom IS NULL OR CAST(i.[Date] AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(i.[Date] AS DATE) <= @DateTo)
        ),0)
        - ISNULL((SELECT SUM(e.Amount) FROM Expenses e
                WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0
                  AND (@DateFrom IS NULL OR CAST(e.[Date] AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(e.[Date] AS DATE) <= @DateTo)
        ),0) AS ShareDue,

        -- TotalPayoutGenerated (with date filter)
        ISNULL((SELECT SUM(pt.Amount) FROM PartnerTrans pt
                WHERE pt.PartnerId=p.Id AND pt.Type='Payout' AND ISNULL(pt.IsDeleted,0)=0
                  AND (@DateFrom IS NULL OR CAST(pt.CreatedAt AS DATE) >= @DateFrom)
                  AND (@DateTo   IS NULL OR CAST(pt.CreatedAt AS DATE) <= @DateTo)
        ),0) AS TotalPayoutGenerated,

        -- LastPayoutDate
        (SELECT MAX(CAST(pm.[Date] AS DATE)) FROM PartnerMonthlyPayout pm WHERE pm.PartnerId=p.Id AND ISNULL(pm.IsDeleted,0)=0) AS LastPayoutDate,

        -- TotalPartnerShareAmount
        ISNULL((SELECT SUM(pm.PartnerShareAmount) FROM PartnerMonthlyPayout pm WHERE pm.PartnerId=p.Id AND ISNULL(pm.IsDeleted,0)=0),0) AS TotalPartnerShareAmount

    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id AND ISNULL(cp.IsDeleted,0)=0
    WHERE p.IsDeleted=0
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@PartnerId IS NULL OR p.Id=@PartnerId)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
      AND (@CampId IS NULL OR p.Id IN (SELECT PartnerId FROM @FilteredPartners))
    GROUP BY p.Id,p.Code,p.Name,p.Contact,p.Mobile,p.Email,p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'sp_GetPartnerReport updated with all filters.';
GO
