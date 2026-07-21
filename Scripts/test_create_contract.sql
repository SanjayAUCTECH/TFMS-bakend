USE TFMS_TestSoftwareDB;
DECLARE @NewId NVARCHAR(MAX);
EXEC sp_CreateContract 
    @TenantId=37, 
    @CampIdsJson='[62]',
    @StartDate='2026-08-01', 
    @Months=2, 
    @RoomIdsJson='[442]',
    @NewContractId=@NewId OUTPUT;
PRINT 'Created: ' + @NewId;
-- cleanup test
DELETE FROM ContractRoomInstallments WHERE ContractId=@NewId;
DELETE FROM ContractInstallments WHERE ContractId=@NewId;
DELETE FROM ContractRooms WHERE ContractId=@NewId;
DELETE FROM ContractCamps WHERE ContractId=@NewId;
UPDATE Rooms SET Occupied=1, Status='Occupied' WHERE Id=442;
DELETE FROM Contracts WHERE ContractId=@NewId;
