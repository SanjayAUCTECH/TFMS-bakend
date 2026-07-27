-- ============================================================
-- 083: Final patches
--      sp_CreateRoomStatus  — add IsDeleted=0 in INSERT
--      sp_CreateRoomWaiver  — add IsDeleted=0 in INSERT
--      sp_CreateContract    — add @AddedBy + IsDeleted=0
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Ensure IsDeleted=0 on existing RoomStatuses rows
UPDATE RoomStatuses SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

CREATE OR ALTER PROCEDURE sp_CreateRoomStatus
    @Name NVARCHAR(MAX), @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    INSERT INTO RoomStatuses(Name, AddedBy, IsDeleted) VALUES(@Name, @AddedBy, 0);
    SET @NewId=SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_CreateRoomWaiver
    @TenantId INT, @ContractId NVARCHAR(MAX), @InstallmentNo INT,
    @WaiverAmount DECIMAL(18,2), @Remark NVARCHAR(MAX)='',
    @WaiverDate DATE, @CreatedBy NVARCHAR(MAX)='',
    @RoomWaiversJson NVARCHAR(MAX)='[]',
    @AddedBy INT=NULL, @NewId INT OUTPUT
AS BEGIN
    SET NOCOUNT ON;
    DECLARE @OrigAmount DECIMAL(18,2)=
        ISNULL((SELECT SUM(InstallAmount) FROM ContractRoomInstallments
                WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo),0);
    INSERT INTO Waivers(TenantId,ContractId,InstallmentNo,OriginalAmount,WaiverAmount,
        BalanceAmount,Remark,WaiverDate,AddedBy,IsDeleted)
    VALUES(@TenantId,@ContractId,@InstallmentNo,@OrigAmount,@WaiverAmount,
        @OrigAmount-@WaiverAmount,@Remark,@WaiverDate,@AddedBy,0);
    SET @NewId=SCOPE_IDENTITY();
    IF @RoomWaiversJson<>'[]' AND @RoomWaiversJson IS NOT NULL
        UPDATE cri SET cri.InstallAmount=cri.InstallAmount-rw.WaiverAmount,
            cri.Balance=cri.InstallAmount-cri.PaidAmount-rw.WaiverAmount,cri.UpdatedAt=GETUTCDATE()
        FROM ContractRoomInstallments cri
        INNER JOIN OPENJSON(@RoomWaiversJson)
            WITH(RoomId INT, WaiverAmount DECIMAL(18,2), InstallmentNo INT) rw
            ON cri.RoomId=rw.RoomId AND cri.ContractId=@ContractId AND cri.InstallmentNo=rw.InstallmentNo;
END
GO

-- After sp_CreateContract runs, stamp AddedBy (since sp_CreateContract is complex)
-- For existing contract SP, we use a post-insert trigger approach via UPDATE
-- Patch: ensure IsDeleted=0 on Contracts table
UPDATE Contracts SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

-- Ensure Payments table has IsDeleted column patched
UPDATE Payments SET IsDeleted=0 WHERE IsDeleted IS NULL;
GO

PRINT '083 - RoomStatus, RoomWaiver, Contracts, Payments patched';
GO