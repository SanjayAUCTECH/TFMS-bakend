USE TFMS_TestSoftwareDB;
DECLARE @NewId NVARCHAR(450);
EXEC sp_CreateContract 
    @TenantId=37, 
    @CampIdsJson='[62]',
    @StartDate='2026-09-01', 
    @Months=3, 
    @RoomIdsJson='[{"roomId":442,"monthlyAmount":1500},{"roomId":441,"monthlyAmount":1200}]',
    @NewContractId=@NewId OUTPUT;
PRINT 'Created: ' + @NewId;
SELECT ContractId, RoomId, MonthlyAmount FROM ContractRooms WHERE ContractId=@NewId;
SELECT ContractId, RoomNo, InstallmentNo, InstallAmount, Month FROM ContractRoomInstallments WHERE ContractId=@NewId ORDER BY RoomNo, InstallmentNo;
-- cleanup
DELETE FROM ContractRoomInstallments WHERE ContractId=@NewId;
DELETE FROM ContractInstallments WHERE ContractId=@NewId;
DELETE FROM ContractRooms WHERE ContractId=@NewId;
DELETE FROM ContractCamps WHERE ContractId=@NewId;
UPDATE Rooms SET Occupied=1, Status='Occupied' WHERE Id IN (442,441);
DELETE FROM Contracts WHERE ContractId=@NewId;
PRINT 'Cleaned up.';
