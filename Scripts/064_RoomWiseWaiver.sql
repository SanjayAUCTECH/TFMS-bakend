-- ============================================================
-- 064: Room-wise Waiver
--      sp_CreateRoomWaiver — waiver + update CRI + ContractRooms
--      RoomWaiversJson: [{criId, roomId, campId, amount}]
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateRoomWaiver
    @TenantId         INT,
    @ContractId       NVARCHAR(MAX),
    @InstallmentNo    INT,
    @WaiverAmount     DECIMAL(18,2),
    @Remark           NVARCHAR(MAX) = '',
    @WaiverDate       DATE,
    @CreatedBy        NVARCHAR(MAX) = 'Admin',
    @RoomWaiversJson  NVARCHAR(MAX) = NULL,   -- [{criId,roomId,campId,amount}]
    @NewId            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
    BEGIN TRANSACTION;

    -- Generate WaiverCode
    DECLARE @WaiverCode NVARCHAR(MAX) = 'WAI-' + RIGHT('000000' + CAST((SELECT ISNULL(MAX(Id),0)+1 FROM Waivers) AS NVARCHAR), 6);

    -- Get installment original amount
    DECLARE @OriginalAmount DECIMAL(18,2);
    SELECT @OriginalAmount = Amount FROM ContractInstallments WHERE ContractId=@ContractId AND InstallmentNo=@InstallmentNo;

    -- Insert Waiver
    INSERT INTO Waivers(WaiverCode, TenantId, ContractId, InstallmentNo, OriginalAmount, WaiverAmount, BalanceAmount, Remark, WaiverDate, CreatedBy)
    VALUES(@WaiverCode, @TenantId, @ContractId, @InstallmentNo, ISNULL(@OriginalAmount,0), @WaiverAmount,
           ISNULL(@OriginalAmount,0) - @WaiverAmount, @Remark, @WaiverDate, @CreatedBy);

    SET @NewId = SCOPE_IDENTITY();

    -- Reduce ContractInstallments amount
    UPDATE ContractInstallments
    SET Amount = CASE WHEN Amount - @WaiverAmount < 0 THEN 0 ELSE Amount - @WaiverAmount END
    WHERE ContractId = @ContractId AND InstallmentNo = @InstallmentNo
      AND Status IN ('Pending','Partial');

    -- Process room-wise waivers
    IF @RoomWaiversJson IS NOT NULL AND LEN(@RoomWaiversJson) > 2
    BEGIN
        -- Parse JSON
        CREATE TABLE #RoomWaivers (CriId INT, RoomId INT, CampId INT, Amount DECIMAL(18,2));
        INSERT INTO #RoomWaivers (CriId, RoomId, CampId, Amount)
        SELECT j.criId, j.roomId, j.campId, j.amount
        FROM OPENJSON(@RoomWaiversJson)
        WITH (criId INT '$.criId', roomId INT '$.roomId', campId INT '$.campId', amount DECIMAL(18,2) '$.amount') j
        WHERE j.amount > 0;

        -- Update ContractRoomInstallments — reduce InstallAmount (waiver reduces what's owed)
        UPDATE cri
        SET
            cri.InstallAmount = CASE WHEN cri.InstallAmount - rw.Amount < 0 THEN 0 ELSE cri.InstallAmount - rw.Amount END,
            cri.Balance       = CASE WHEN (cri.InstallAmount - rw.Amount) - cri.PaidAmount < 0 THEN 0
                                     ELSE (cri.InstallAmount - rw.Amount) - cri.PaidAmount END,
            cri.Status        = CASE
                WHEN cri.PaidAmount >= (CASE WHEN cri.InstallAmount - rw.Amount < 0 THEN 0 ELSE cri.InstallAmount - rw.Amount END) THEN 'Paid'
                WHEN cri.PaidAmount > 0 THEN 'Partial'
                ELSE 'Pending' END,
            cri.UpdatedAt     = GETDATE()
        FROM ContractRoomInstallments cri
        JOIN #RoomWaivers rw ON rw.CriId = cri.Id
        WHERE cri.ContractId = @ContractId;

        -- Update ContractRooms — reduce TotalAmount + Balance
        UPDATE cr
        SET
            cr.TotalAmount = CASE WHEN cr.TotalAmount - rw.TotalAmt < 0 THEN 0 ELSE cr.TotalAmount - rw.TotalAmt END,
            cr.Balance     = CASE WHEN cr.Balance - rw.TotalAmt < 0 THEN 0 ELSE cr.Balance - rw.TotalAmt END
        FROM ContractRooms cr
        JOIN (
            SELECT RoomId, SUM(Amount) TotalAmt FROM #RoomWaivers GROUP BY RoomId
        ) rw ON rw.RoomId = cr.RoomId
        WHERE cr.ContractId = @ContractId;

        DROP TABLE #RoomWaivers;
    END

    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#RoomWaivers') IS NOT NULL DROP TABLE #RoomWaivers;
        THROW;
    END CATCH
END
GO

PRINT '064 - sp_CreateRoomWaiver created';
GO
