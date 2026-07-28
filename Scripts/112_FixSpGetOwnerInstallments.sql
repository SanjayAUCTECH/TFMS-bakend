USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_GetOwnerInstallments
    @OcId        INT,
    @PageNumber  INT           = 1,
    @PageSize    INT           = 500,
    @Status      NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId
      AND ISNULL(IsDeleted,0)=0
      AND (@Status IS NULL OR Status=@Status);

    SELECT
        Id,
        OwnerContractId,
        No               AS InstallmentNo,
        Amount,                              -- ✅ 'Amount' (MapInstallment reads 'Amount')
        ISNULL(PaidAmount,0) AS PaidAmount,
        Amount - ISNULL(PaidAmount,0) AS Balance,
        DueDate,
        PaidDate,
        ISNULL(Status,'Pending') AS Status,
        ExpenseId
    FROM OwnerInstallments
    WHERE OwnerContractId=@OcId
      AND ISNULL(IsDeleted,0)=0
      AND (@Status IS NULL OR Status=@Status)
    ORDER BY No
    OFFSET (@PageNumber-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO

PRINT 'sp_GetOwnerInstallments fixed - Amount column name corrected';
GO
