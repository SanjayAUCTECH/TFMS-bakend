USE TFMS_TestSoftwareDB;
GO
-- Test: 2 rooms, security=12000 → each room gets 6000
DECLARE @NewCID NVARCHAR(450);
EXEC sp_CreateContract
    @TenantId=49, @StartDate='2026-07-28', @Months=2,
    @RoomIdsJson='[{"roomId":684,"monthlyAmount":1200,"campId":81},{"roomId":685,"monthlyAmount":1200,"campId":81}]',
    @SecurityDeposit=12000, @AddedBy=1,
    @NewContractId=@NewCID OUTPUT;

SELECT 'CONTRACT' AS T, @NewCID AS ContractId;
SELECT 'ROOMS' AS T, RoomId, MonthlyAmount, TotalAmount,
    SecurityAmount, SecurityPaidAmount, SecurityDueAmount, SecurityPaidDate, AddedBy
FROM ContractRooms WHERE ContractId=@NewCID;

-- Cleanup
DELETE FROM ContractRoomInstallments WHERE ContractId=@NewCID;
DELETE FROM ContractInstallments WHERE ContractId=@NewCID;
DELETE FROM ContractCamps WHERE ContractId=@NewCID;
DELETE FROM ContractRooms WHERE ContractId=@NewCID;
DELETE FROM Contracts WHERE ContractId=@NewCID;
UPDATE Rooms SET Occupied=0, Status='Vacant' WHERE Id IN(684,685);
SELECT 'CLEANUP_DONE' AS T;
GO
