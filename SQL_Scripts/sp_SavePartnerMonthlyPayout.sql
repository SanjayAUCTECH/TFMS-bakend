-- ================================================================
-- FILE   : sp_SavePartnerMonthlyPayout.sql
-- PURPOSE: Save partner-wise monthly payout totals into
--          PartnerMonthlyPayout table using TVP.
--          Also inserts a record into PartnerTrans for audit trail.
-- ================================================================

CREATE OR ALTER PROCEDURE sp_SavePartnerMonthlyPayout
    @FromDate  DATETIME,
    @ToDate    DATETIME,
    @Date      DATETIME,
    @AddedBy   INT = NULL,
    @Rows      dbo.PartnerMonthlyPayoutType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        -- ── Step 1: Soft-delete existing active records for same period + partner ──
        UPDATE pm
        SET    IsDeleted = 1,
               UpdatedAt = GETDATE()
        FROM   PartnerMonthlyPayout pm
        INNER JOIN @Rows r ON r.PartnerId = pm.PartnerId
        WHERE  CAST(pm.FromDate AS DATE) = CAST(@FromDate AS DATE)
          AND  CAST(pm.ToDate   AS DATE) = CAST(@ToDate   AS DATE)
          AND  pm.IsDeleted = 0;

        -- ── Step 2: Insert fresh rows into PartnerMonthlyPayout ──────────────────
        INSERT INTO PartnerMonthlyPayout (
            FromDate, ToDate, [Date],
            PartnerId,
            CampPartnerPercentage,
            TotalCampIncome, TotalCampExpense,
            TotalHOExpense,  TotalAllExpense,
            TotalBenefitAmount, PartnerShareAmount,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        SELECT
            @FromDate, @ToDate, @Date,
            r.PartnerId,
            r.CampPartnerPercentage,
            r.TotalCampIncome,  r.TotalCampExpense,
            r.TotalHOExpense,   r.TotalAllExpense,
            r.TotalBenefitAmount, r.PartnerShareAmount,
            @AddedBy, 0, GETDATE(), GETDATE()
        FROM @Rows r;

        -- ── Step 3: Insert into PartnerTrans for audit trail ─────────────────────
        --   Type        = 'Payout'
        --   AccountHead = 'Partner Monthly Payout'
        --   Amount      = PartnerShareAmount
        --   Remark      = Period label
        INSERT INTO PartnerTrans (
            PartnerId,
            PaymentMode,
            Type,
            AccountHead,
            Amount,
            AccountId,
            Remark,
            AddedBy,
            IsDeleted,
            CreatedAt,
            UpdatedAt
        )
        SELECT
            r.PartnerId,
            NULL,                          -- PaymentMode (not applicable)
            'Payout',                      -- Type
            'Partner Monthly Payout',      -- AccountHead
            r.PartnerShareAmount,          -- Amount = partner's share
            NULL,                          -- AccountId
            'Monthly Payout: ' +
                CONVERT(VARCHAR, CAST(@FromDate AS DATE), 105) +
                ' to ' +
                CONVERT(VARCHAR, CAST(@ToDate AS DATE), 105),   -- Remark: period
            @AddedBy,
            0,
            GETDATE(),
            GETDATE()
        FROM @Rows r;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_SavePartnerMonthlyPayout updated - now also saves to PartnerTrans.';
GO
