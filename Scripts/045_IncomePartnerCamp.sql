-- ============================================================
-- 045: Income module — Add PartnerId, PartnerName columns
--      Update sp_CreateIncome, sp_UpdateIncome, sp_GetIncomes,
--      sp_GetIncomeById to include Camp & Partner
-- Date: July 20, 2026
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── 1. Add PartnerId, PartnerName columns to Incomes ─────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='PartnerId')
    ALTER TABLE Incomes ADD PartnerId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Incomes') AND name='PartnerName')
    ALTER TABLE Incomes ADD PartnerName NVARCHAR(MAX) NOT NULL DEFAULT '';
GO

-- ── 2. sp_CreateIncome ────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_CreateIncome
    @Date        DATE,
    @Mode        NVARCHAR(MAX),
    @Head        NVARCHAR(MAX),
    @FundPool    NVARCHAR(MAX),
    @Amount      DECIMAL(18,2),
    @Purpose     NVARCHAR(MAX),
    @Source      NVARCHAR(MAX)  = '',
    @SourceRef   NVARCHAR(MAX)  = '',
    @CampId      INT            = NULL,
    @CampName    NVARCHAR(MAX)  = '',
    @PartnerId   INT            = NULL,
    @PartnerName NVARCHAR(MAX)  = '',
    @NewId       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IncomeId NVARCHAR(MAX) = 'INC-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Incomes) AS NVARCHAR), 6);

    INSERT INTO Incomes (
        IncomeId, Date, Mode, Head, FundPool, FundPoolName,
        Amount, Purpose, Source, SourceRef,
        CampId, CampName, PartnerId, PartnerName,
        CreatedAt, UpdatedAt
    )
    SELECT
        @IncomeId, @Date, @Mode, @Head, @FundPool, fp.Name,
        @Amount, @Purpose, @Source, @SourceRef,
        @CampId, ISNULL(@CampName, ''), @PartnerId, ISNULL(@PartnerName, ''),
        GETUTCDATE(), GETUTCDATE()
    FROM FundPools fp WHERE fp.Code = @FundPool;

    SET @NewId = SCOPE_IDENTITY();

    -- Update Fund Pool balance
    UPDATE FundPools SET Balance = Balance + @Amount, UpdatedAt = GETUTCDATE()
    WHERE Code = @FundPool;
END
GO

-- ── 3. sp_UpdateIncome ────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdateIncome
    @Id          INT,
    @Date        DATE,
    @Mode        NVARCHAR(MAX),
    @Head        NVARCHAR(MAX),
    @FundPool    NVARCHAR(MAX),
    @Amount      DECIMAL(18,2),
    @Purpose     NVARCHAR(MAX),
    @Source      NVARCHAR(MAX)  = '',
    @SourceRef   NVARCHAR(MAX)  = '',
    @CampId      INT            = NULL,
    @CampName    NVARCHAR(MAX)  = '',
    @PartnerId   INT            = NULL,
    @PartnerName NVARCHAR(MAX)  = ''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldAmount DECIMAL(18,2), @OldPool NVARCHAR(MAX);
    SELECT @OldAmount = Amount, @OldPool = FundPool FROM Incomes WHERE Id = @Id;

    UPDATE Incomes SET
        Date        = @Date,
        Mode        = @Mode,
        Head        = @Head,
        FundPool    = @FundPool,
        FundPoolName= (SELECT Name FROM FundPools WHERE Code = @FundPool),
        Amount      = @Amount,
        Purpose     = @Purpose,
        Source      = @Source,
        SourceRef   = @SourceRef,
        CampId      = @CampId,
        CampName    = ISNULL(@CampName, ''),
        PartnerId   = @PartnerId,
        PartnerName = ISNULL(@PartnerName, ''),
        UpdatedAt   = GETUTCDATE()
    WHERE Id = @Id;

    -- Reverse old pool, apply new pool
    UPDATE FundPools SET Balance = Balance - @OldAmount, UpdatedAt = GETUTCDATE() WHERE Code = @OldPool;
    UPDATE FundPools SET Balance = Balance + @Amount,    UpdatedAt = GETUTCDATE() WHERE Code = @FundPool;
END
GO

-- ── 4. sp_GetIncomes ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetIncomes
    @PageNumber  INT, @PageSize INT,
    @SearchText  NVARCHAR(MAX) = NULL,
    @DateFrom    NVARCHAR(MAX) = NULL,
    @DateTo      NVARCHAR(MAX) = NULL,
    @Head        NVARCHAR(MAX) = NULL,
    @FundPool    NVARCHAR(MAX) = NULL,
    @TotalRecords INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @TotalRecords = COUNT(*)
    FROM Incomes i
    WHERE (@Head      IS NULL OR i.Head     = @Head)
      AND (@FundPool  IS NULL OR i.FundPool = @FundPool)
      AND (@DateFrom  IS NULL OR i.Date    >= CAST(@DateFrom AS DATE))
      AND (@DateTo    IS NULL OR i.Date    <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL
           OR i.IncomeId  LIKE '%' + @SearchText + '%'
           OR i.Head      LIKE '%' + @SearchText + '%'
           OR i.Purpose   LIKE '%' + @SearchText + '%'
           OR i.CampName  LIKE '%' + @SearchText + '%'
           OR i.PartnerName LIKE '%' + @SearchText + '%');

    SELECT
        i.Id, i.IncomeId, i.Date, i.Mode, i.Head,
        i.FundPool, i.FundPoolName,
        i.Amount, i.Purpose, i.Source, i.SourceRef,
        ISNULL(i.CampId,   0)  CampId,
        ISNULL(i.CampName, '') CampName,
        ISNULL(i.PartnerId, 0) PartnerId,
        ISNULL(i.PartnerName,'') PartnerName,
        ISNULL(i.ContractId,'')  ContractId,
        ISNULL(i.ContractCode,'') ContractCode,
        i.CreatedAt, i.UpdatedAt
    FROM Incomes i
    WHERE (@Head      IS NULL OR i.Head     = @Head)
      AND (@FundPool  IS NULL OR i.FundPool = @FundPool)
      AND (@DateFrom  IS NULL OR i.Date    >= CAST(@DateFrom AS DATE))
      AND (@DateTo    IS NULL OR i.Date    <= CAST(@DateTo   AS DATE))
      AND (@SearchText IS NULL
           OR i.IncomeId  LIKE '%' + @SearchText + '%'
           OR i.Head      LIKE '%' + @SearchText + '%'
           OR i.Purpose   LIKE '%' + @SearchText + '%'
           OR i.CampName  LIKE '%' + @SearchText + '%'
           OR i.PartnerName LIKE '%' + @SearchText + '%')
    ORDER BY i.Date DESC, i.Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO

-- ── 5. sp_GetIncomeById ───────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetIncomeById @Id INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        i.Id, i.IncomeId, i.Date, i.Mode, i.Head,
        i.FundPool, i.FundPoolName,
        i.Amount, i.Purpose, i.Source, i.SourceRef,
        ISNULL(i.CampId,    0)  CampId,
        ISNULL(i.CampName,  '') CampName,
        ISNULL(i.PartnerId, 0)  PartnerId,
        ISNULL(i.PartnerName,'') PartnerName,
        ISNULL(i.ContractId,'')  ContractId,
        ISNULL(i.ContractCode,'') ContractCode,
        i.CreatedAt, i.UpdatedAt
    FROM Incomes i
    WHERE i.Id = @Id;
END
GO

PRINT '045 - Incomes: PartnerId/PartnerName added, SPs updated (Create/Update/GetAll/GetById)';
GO
