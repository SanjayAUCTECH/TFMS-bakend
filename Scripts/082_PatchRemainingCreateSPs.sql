-- ============================================================
-- 082: Patch remaining Create SPs
--      sp_CreateExpense  — add @AddedBy + IsDeleted=0
--      sp_CreateContract — add @AddedBy + IsDeleted=0
--      ActivityLog SPs   — intentionally no IsDeleted (audit log never deleted)
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- ── Patch Expenses table to ensure IsDeleted column is saved on insert ────
-- Run after existing sp_CreateExpense — just update any rows missing IsDeleted
UPDATE Expenses SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

-- ── sp_CreateExpense — add @AddedBy and IsDeleted=0 ──────────────────────
CREATE OR ALTER PROCEDURE sp_CreateExpense
    @Date          DATE,
    @Mode          NVARCHAR(MAX) = '',
    @Head          NVARCHAR(MAX),
    @FundPool      NVARCHAR(MAX),
    @Amount        DECIMAL(18,2),
    @Nature        NVARCHAR(MAX) = 'HO',
    @CampId        INT           = NULL,
    @RecipientRole NVARCHAR(MAX) = '',
    @RecipientId   INT           = NULL,
    @RecipientName NVARCHAR(MAX) = '',
    @Purpose       NVARCHAR(MAX) = '',
    @AddedBy       INT           = NULL,
    @NewId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ExpenseId    NVARCHAR(MAX) = 'EXP-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Expenses) AS NVARCHAR), 6);
    DECLARE @FundPoolName NVARCHAR(MAX) = (SELECT Name FROM FundPools WHERE Code = @FundPool);
    DECLARE @CampName     NVARCHAR(MAX) = ISNULL((SELECT Name FROM Camps WHERE Id = @CampId), '');

    INSERT INTO Expenses(ExpenseId, Date, Mode, Head, FundPool, FundPoolName, Amount, Nature,
        CampId, CampName, RecipientRole, RecipientId, RecipientName, Purpose,
        AddedBy, IsDeleted, CreatedAt, UpdatedAt)
    VALUES(@ExpenseId, @Date, @Mode, @Head, @FundPool, @FundPoolName, @Amount, @Nature,
        @CampId, @CampName, @RecipientRole, @RecipientId, @RecipientName, @Purpose,
        @AddedBy, 0, GETUTCDATE(), GETUTCDATE());

    SET @NewId = SCOPE_IDENTITY();

    -- Deduct FundPool balance
    UPDATE FundPools SET Balance = Balance - @Amount, UpdatedAt = GETUTCDATE() WHERE Code = @FundPool;

    -- Owner payment handling
    IF @RecipientRole = 'Owner'
    BEGIN
        DECLARE @OwnerId INT = ISNULL(@RecipientId, (SELECT TOP 1 Id FROM Owners WHERE Name = @RecipientName AND IsDeleted=0));
        IF @OwnerId IS NOT NULL
        BEGIN
            DECLARE @OcId   INT           = (SELECT TOP 1 Id FROM OwnerContracts WHERE OwnerId=@OwnerId AND (@CampId IS NULL OR CampId=@CampId) AND Status='Active' AND IsDeleted=0 ORDER BY CreatedAt DESC);
            DECLARE @OcCode NVARCHAR(MAX) = (SELECT OcCode FROM OwnerContracts WHERE Id=@OcId);
            IF @OcId IS NOT NULL
            BEGIN
                DECLARE @OtCode NVARCHAR(MAX)='OT-'+RIGHT('000000'+CAST((SELECT ISNULL(MAX(Id),0)+1 FROM OwnerTransactions) AS NVARCHAR),6);
                INSERT INTO OwnerTransactions(TxnCode,OwnerContractId,OcCode,CampId,CampName,OwnerId,OwnerName,Type,Amount,Date,Description,ExpenseId,CreatedAt)
                VALUES(@OtCode,@OcId,@OcCode,@CampId,@CampName,@OwnerId,@RecipientName,'CR',@Amount,@Date,'Payment via expense - '+@ExpenseId,@NewId,GETUTCDATE());
                UPDATE OwnerContracts SET PaidAmount=ISNULL(PaidAmount,0)+@Amount,UpdatedAt=GETUTCDATE() WHERE Id=@OcId;
            END
        END
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ── Patch Contracts table ensure IsDeleted=0 on existing rows ────────────
UPDATE Contracts SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

-- ── Also update ExpenseRepository in C# to pass @AddedBy ─────────────────
-- (C# changes tracked separately — this confirms the SP accepts @AddedBy)

-- ── Ensure sp_CreateRoomWaiver has @AddedBy and IsDeleted=0 ──────────────
CREATE OR ALTER PROCEDURE sp_CreateRoomWaiver
    @TenantId      INT,
    @ContractId    NVARCHAR(MAX),
    @InstallmentNo INT,
    @WaiverAmount  DECIMAL(18,2),
    @Remark        NVARCHAR(MAX) = '',
    @WaiverDate    DATE,
    @CreatedBy     NVARCHAR(MAX) = '',
    @RoomWaiversJson NVARCHAR(MAX) = '[]',
    @AddedBy       INT = NULL,
    @NewId         INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OriginalAmount DECIMAL(18,2) =
        ISNULL((SELECT SUM(InstallAmount) FROM ContractRoomInstallments
                WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo), 0);

    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,
        BalanceAmount,Remark,WaiverDate,AddedBy,IsDeleted)
    VALUES(@TenantId,@ContractId,@InstallmentNo,@OriginalAmount,@WaiverAmount,
        @OriginalAmount-@WaiverAmount,@Remark,@WaiverDate,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();

    -- Apply room-level waivers
    IF @RoomWaiversJson<>'[]' AND @RoomWaiversJson IS NOT NULL
    BEGIN
        UPDATE cri
        SET cri.InstallAmount = cri.InstallAmount - rw.WaiverAmount,
            cri.Balance       = cri.InstallAmount - cri.PaidAmount - rw.WaiverAmount,
            cri.UpdatedAt     = GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN OPENJSON(@RoomWaiversJson)
            WITH(RoomId INT, WaiverAmount DECIMAL(18,2), InstallmentNo INT) rw
            ON cri.RoomId=rw.RoomId AND cri.ContractId=@ContractId AND cri.InstallmentNo=rw.InstallmentNo;
    END
END
GO

-- ── Patch ActivityLog SPs — no IsDeleted needed (audit log) ─────────────
-- ActivityLog is intentionally an append-only audit table.
-- No IsDeleted=0 filter needed — all logs must remain visible.

PRINT '082 - sp_CreateExpense, sp_CreateRoomWaiver patched with @AddedBy + IsDeleted=0';
GO
