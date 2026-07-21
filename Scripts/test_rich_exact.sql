USE TFMS_TestSoftwareDB;
DECLARE @NewId NVARCHAR(450);
DECLARE @rooms NVARCHAR(MAX) = '[{"roomId":442,"campId":62,"monthlyAmount":1200,"totalAmount":null}]';
PRINT 'RoomIds JSON: ' + @rooms;
EXEC sp_CreateContract 
    @TenantId=37, 
    @CampIdsJson='[62]',
    @StartDate='2026-10-01', 
    @Months=2, 
    @RoomIdsJson=@rooms,
    @NewContractId=@NewId OUTPUT;
PRINT 'Created: ' + ISNULL(@NewId,'NULL');
SELECT cr.ContractId, cr.RoomId, r.RoomNo, cr.MonthlyAmount FROM ContractRooms cr JOIN Rooms r ON r.Id=cr.RoomId WHERE cr.ContractId=@NewId;
SELECT ContractId, RoomNo, InstallmentNo, Month FROM ContractRoomInstallments WHERE ContractId=@NewId;
-- cleanup
DELETE FROM ContractRoomInstallments WHERE ContractId=@NewId;
DELETE FROM ContractInstallments WHERE ContractId=@NewId;
DELETE FROM ContractRooms WHERE ContractId=@NewId;
DELETE FROM ContractCamps WHERE ContractId=@NewId;
UPDATE Rooms SET Occupied=1, Status='Occupied' WHERE Id=442;
DELETE FROM Contracts WHERE ContractId=@NewId;
