-- ============================================================================
-- 032: ContractTerms Table — Terms & Conditions for contract Page 2 and Page 3
-- ============================================================================

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ContractTerms')
BEGIN
    CREATE TABLE ContractTerms (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        ContractId  NVARCHAR(MAX) NOT NULL,          -- e.g., 'CNT-000106'
        PageNo      INT NOT NULL,                     -- 2 or 3
        TermNo      INT NOT NULL,                     -- 1,2,3,4,5...
        TermText    NVARCHAR(MAX) NULL,               -- The term content (no size limit)
        CreatedAt   DATETIME2 DEFAULT GETDATE(),
        UpdatedAt   DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- ============================================================================
-- sp_GetContractTerms — Get all terms for a contract
-- ============================================================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetContractTerms')
    DROP PROCEDURE sp_GetContractTerms;
GO

CREATE PROCEDURE sp_GetContractTerms
    @ContractId NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, ContractId, PageNo, TermNo, TermText, CreatedAt, UpdatedAt
    FROM ContractTerms
    WHERE ContractId = @ContractId
    ORDER BY PageNo, TermNo;
END
GO

-- ============================================================================
-- sp_SaveContractTerms — Upsert (delete + re-insert) all terms for a contract
-- ============================================================================
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_SaveContractTerms')
    DROP PROCEDURE sp_SaveContractTerms;
GO

CREATE PROCEDURE sp_SaveContractTerms
    @ContractId NVARCHAR(MAX),
    @TermsJson  NVARCHAR(MAX)  -- JSON array: [{"pageNo":2,"termNo":1,"termText":"..."},...]
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete existing terms for this contract
    DELETE FROM ContractTerms WHERE ContractId = @ContractId;

    -- Insert new terms from JSON
    INSERT INTO ContractTerms (ContractId, PageNo, TermNo, TermText)
    SELECT @ContractId, PageNo, TermNo, TermText
    FROM OPENJSON(@TermsJson)
    WITH (
        PageNo   INT            '$.pageNo',
        TermNo   INT            '$.termNo',
        TermText NVARCHAR(MAX)  '$.termText'
    )
    WHERE TermText IS NOT NULL AND LEN(LTRIM(RTRIM(TermText))) > 0;

    -- Return the saved terms
    SELECT Id, ContractId, PageNo, TermNo, TermText, CreatedAt, UpdatedAt
    FROM ContractTerms
    WHERE ContractId = @ContractId
    ORDER BY PageNo, TermNo;
END
GO
