SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE sp_GetPartnerReport
    @PageNumber  INT,
    @PageSize    INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalRecords = COUNT(*) FROM Partners p
    WHERE p.IsDeleted=0
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%');

    SELECT
        p.Id AS PartnerId, p.Code AS PartnerCode, p.Name AS PartnerName,
        ISNULL(p.Contact,'') AS Contact, ISNULL(p.Mobile,'') AS Mobile,
        ISNULL(p.Email,'') AS Email, p.Status,
        COUNT(DISTINCT cp.CampId) AS TotalCamps,
        ISNULL(STUFF((SELECT DISTINCT ', '+c2.Name FROM CampPartners cp2 JOIN Camps c2 ON c2.Id=cp2.CampId AND c2.IsDeleted=0 WHERE cp2.PartnerId=p.Id AND ISNULL(cp2.IsDeleted,0)=0 FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)'),1,2,''),'') AS CampNames,
        ISNULL(MAX(cp.ShareValue),0) AS ShareValue,
        ISNULL(MAX(cp.ShareType),'') AS ShareType,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0),0) AS TotalCollected,
        ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0),0) AS TotalPaid,
        ISNULL((SELECT SUM(i.Amount) FROM Incomes i WHERE i.PartnerId=p.Id AND ISNULL(i.IsDeleted,0)=0),0)
          - ISNULL((SELECT SUM(e.Amount) FROM Expenses e WHERE e.RecipientRole='Partner' AND e.RecipientId=p.Id AND ISNULL(e.IsDeleted,0)=0),0) AS ShareDue,
        ISNULL((SELECT SUM(pt.Amount) FROM PartnerTrans pt WHERE pt.PartnerId=p.Id AND pt.Type='Payout' AND ISNULL(pt.IsDeleted,0)=0),0) AS TotalPayoutGenerated,
        (SELECT MAX(CAST(pm.[Date] AS DATE)) FROM PartnerMonthlyPayout pm WHERE pm.PartnerId=p.Id AND ISNULL(pm.IsDeleted,0)=0) AS LastPayoutDate,
        ISNULL((SELECT SUM(pm.PartnerShareAmount) FROM PartnerMonthlyPayout pm WHERE pm.PartnerId=p.Id AND ISNULL(pm.IsDeleted,0)=0),0) AS TotalPartnerShareAmount
    FROM Partners p
    LEFT JOIN CampPartners cp ON cp.PartnerId=p.Id AND ISNULL(cp.IsDeleted,0)=0
    WHERE p.IsDeleted=0
      AND (@Status IS NULL OR p.Status=@Status)
      AND (@SearchText IS NULL OR p.Name LIKE '%'+@SearchText+'%' OR p.Code LIKE '%'+@SearchText+'%')
    GROUP BY p.Id,p.Code,p.Name,p.Contact,p.Mobile,p.Email,p.Status
    ORDER BY p.Name
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'sp_GetPartnerReport updated successfully.';
GO
