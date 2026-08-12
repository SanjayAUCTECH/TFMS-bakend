-- ================================================================
-- FILE   : sp_SavePartnerReleasePayout.sql
-- PURPOSE: Save release payout for a partner
-- ================================================================

CREATE OR ALTER PROCEDURE sp_SavePartnerReleasePayout
    @Date                 DATETIME,
    @ReleaseDate          DATETIME,
    @PartnerId            INT,
    @CampPartnerPercentage DECIMAL(10,4),
    @TotalCampIncome      DECIMAL(18,2),
    @TotalCampExpense     DECIMAL(18,2),
    @TotalHOExpense       DECIMAL(18,2),
    @TotalAllExpense      DECIMAL(18,2),
    @TotalBenefitAmount   DECIMAL(18,2),
    @PartnerShareAmount   DECIMAL(18,2),
    @ReleaseAmount        DECIMAL(18,2),
    @BalanceAmount        DECIMAL(18,2),
    @AddedBy              INT = NULL,
    @NewId                INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY

        INSERT INTO PartnerReleasePayout (
            [Date], ReleaseDate,
            PartnerId,
            CampPartnerPercentage,
            TotalCampIncome, TotalCampExpense,
            TotalHOExpense,  TotalAllExpense,
            TotalBenefitAmount, PartnerShareAmount,
            ReleaseAmount, BalanceAmount,
            AddedBy, IsDeleted, CreatedAt, UpdatedAt
        )
        VALUES (
            @Date, @ReleaseDate,
            @PartnerId,
            @CampPartnerPercentage,
            @TotalCampIncome, @TotalCampExpense,
            @TotalHOExpense,  @TotalAllExpense,
            @TotalBenefitAmount, @PartnerShareAmount,
            @ReleaseAmount, @BalanceAmount,
            @AddedBy, 0, GETDATE(), GETDATE()
        );

        SET @NewId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'sp_SavePartnerReleasePayout created successfully.';
GO
