-- ============================================================================
-- Stored Procedure: sp_GetAccountMasters
-- Purpose: Fetch AccountMasters with pagination and filters
-- Created: 2026-10-05
-- ============================================================================

IF OBJECT_ID('dbo.sp_GetAccountMasters', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_GetAccountMasters;
GO

CREATE PROCEDURE dbo.sp_GetAccountMasters
(
    @PageNumber         INT = 1,
    @PageSize           INT = 10,
    @PaymentType        NVARCHAR(50)   = NULL,
    @Nature             NVARCHAR(50)   = NULL,
    @RecipientId        INT            = NULL,
    @FundPool           NVARCHAR(200)  = NULL,
    @Mode               NVARCHAR(100)  = NULL,
    @CampId             INT            = NULL,
    @AccountHead        NVARCHAR(200)  = NULL,
    @DateFrom           DATE           = NULL,
    @DateTo             DATE           = NULL,
    @PaymentDate        DATE           = NULL,
    @PaymentDateFrom    DATE           = NULL,
    @PaymentDateTo      DATE           = NULL,
    @SearchText         NVARCHAR(500)  = NULL,
    @TotalRecords       INT            = 0 OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Build WHERE clause dynamically
    DECLARE @Where NVARCHAR(MAX) = N'WHERE IsDeleted = 0';

    -- PaymentType filter
    IF @PaymentType IS NOT NULL AND @PaymentType <> ''
        SET @Where = @Where + N' AND PaymentType = @PaymentType';

    -- Nature filter
    IF @Nature IS NOT NULL AND @Nature <> ''
        SET @Where = @Where + N' AND Nature = @Nature';

    -- RecipientId filter
    IF @RecipientId IS NOT NULL
        SET @Where = @Where + N' AND RecipientId = @RecipientId';

    -- FundPool filter
    IF @FundPool IS NOT NULL AND @FundPool <> ''
        SET @Where = @Where + N' AND FundPool = @FundPool';

    -- Mode filter
    IF @Mode IS NOT NULL AND @Mode <> ''
        SET @Where = @Where + N' AND Mode = @Mode';

    -- CampId filter (check in Incomes and Expenses)
    IF @CampId IS NOT NULL
        SET @Where = @Where + N' AND (
            AccountId IN (SELECT AccountId FROM Incomes WHERE CampId = @CampId AND ISNULL(IsDeleted, 0) = 0)
            OR AccountId IN (SELECT AccountId FROM Expenses WHERE CampId = @CampId AND ISNULL(IsDeleted, 0) = 0)
        )';

    -- AccountHead filter (check in Incomes and Expenses)
    IF @AccountHead IS NOT NULL AND @AccountHead <> ''
        SET @Where = @Where + N' AND (
            AccountId IN (SELECT AccountId FROM Incomes WHERE Head = @AccountHead AND ISNULL(IsDeleted, 0) = 0)
            OR AccountId IN (SELECT AccountId FROM Expenses WHERE Head = @AccountHead AND ISNULL(IsDeleted, 0) = 0)
        )';

    -- TransDate range filter
    IF @DateFrom IS NOT NULL
        SET @Where = @Where + N' AND CAST(TransDate AS DATE) >= @DateFrom';

    IF @DateTo IS NOT NULL
        SET @Where = @Where + N' AND CAST(TransDate AS DATE) <= @DateTo';

    -- PaymentDate filters (exact date takes priority over range)
    -- If PaymentDate is NULL in DB, use TransDate for filtering
    IF @PaymentDate IS NOT NULL
        SET @Where = @Where + N' AND CAST(COALESCE(PaymentDate, TransDate) AS DATE) = @PaymentDate';
    ELSE
    BEGIN
        IF @PaymentDateFrom IS NOT NULL
            SET @Where = @Where + N' AND CAST(COALESCE(PaymentDate, TransDate) AS DATE) >= @PaymentDateFrom';

        IF @PaymentDateTo IS NOT NULL
            SET @Where = @Where + N' AND CAST(COALESCE(PaymentDate, TransDate) AS DATE) <= @PaymentDateTo';
    END;

    -- SearchText filter (search across multiple columns)
    IF @SearchText IS NOT NULL AND @SearchText <> ''
        SET @Where = @Where + N' AND (
            AccountId LIKE @SearchText 
            OR VoucherNo LIKE @SearchText 
            OR Purpose LIKE @SearchText 
            OR RecipientName LIKE @SearchText 
            OR Mode LIKE @SearchText 
            OR RecipientRole LIKE @SearchText
        )';

    -- Count total records
    DECLARE @CountSQL NVARCHAR(MAX) = N'
        SELECT @Total = COUNT(*) 
        FROM AccountMasters ' + @Where;

    DECLARE @CountParams NVARCHAR(MAX) = N'
        @PaymentType        NVARCHAR(50),
        @Nature             NVARCHAR(50),
        @RecipientId        INT,
        @FundPool           NVARCHAR(200),
        @Mode               NVARCHAR(100),
        @CampId             INT,
        @AccountHead        NVARCHAR(200),
        @DateFrom           DATE,
        @DateTo             DATE,
        @PaymentDate        DATE,
        @PaymentDateFrom    DATE,
        @PaymentDateTo      DATE,
        @SearchText         NVARCHAR(500),
        @Total              INT OUTPUT';

    EXEC sp_executesql 
        @CountSQL,
        @CountParams,
        @PaymentType        = @PaymentType,
        @Nature             = @Nature,
        @RecipientId        = @RecipientId,
        @FundPool           = @FundPool,
        @Mode               = @Mode,
        @CampId             = @CampId,
        @AccountHead        = @AccountHead,
        @DateFrom           = @DateFrom,
        @DateTo             = @DateTo,
        @PaymentDate        = @PaymentDate,
        @PaymentDateFrom    = @PaymentDateFrom,
        @PaymentDateTo      = @PaymentDateTo,
        @SearchText         = @SearchText,
        @Total              = @TotalRecords OUTPUT;

    -- Fetch paginated data
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    DECLARE @DataSQL NVARCHAR(MAX) = N'
        SELECT 
            Id,
            AccountId,
            VoucherNo,
            TransDate,
            COALESCE(PaymentDate, TransDate) AS PaymentDate,  -- If PaymentDate is NULL, use TransDate
            PaymentType,
            Mode,
            FundPool,
            FundPoolName,
            Amount,
            Nature,
            RecipientRole,
            RecipientName,
            Purpose,
            CreatedAt,
            UpdatedAt,
            RecipientId,
            AddedBy,
            UpdatedBy,
            DeletedBy,
            IsDeleted,
            CampId,
            CampName
        FROM AccountMasters ' + @Where + N'
        ORDER BY Id DESC
        OFFSET @Offset ROWS 
        FETCH NEXT @PageSize ROWS ONLY';

    DECLARE @DataParams NVARCHAR(MAX) = N'
        @PaymentType        NVARCHAR(50),
        @Nature             NVARCHAR(50),
        @RecipientId        INT,
        @FundPool           NVARCHAR(200),
        @Mode               NVARCHAR(100),
        @CampId             INT,
        @AccountHead        NVARCHAR(200),
        @DateFrom           DATE,
        @DateTo             DATE,
        @PaymentDate        DATE,
        @PaymentDateFrom    DATE,
        @PaymentDateTo      DATE,
        @SearchText         NVARCHAR(500),
        @Offset             INT,
        @PageSize           INT';

    EXEC sp_executesql 
        @DataSQL,
        @DataParams,
        @PaymentType        = @PaymentType,
        @Nature             = @Nature,
        @RecipientId        = @RecipientId,
        @FundPool           = @FundPool,
        @Mode               = @Mode,
        @CampId             = @CampId,
        @AccountHead        = @AccountHead,
        @DateFrom           = @DateFrom,
        @DateTo             = @DateTo,
        @PaymentDate        = @PaymentDate,
        @PaymentDateFrom    = @PaymentDateFrom,
        @PaymentDateTo      = @PaymentDateTo,
        @SearchText         = @SearchText,
        @Offset             = @Offset,
        @PageSize           = @PageSize;

END;
GO

PRINT 'Stored Procedure sp_GetAccountMasters created successfully';
GO
