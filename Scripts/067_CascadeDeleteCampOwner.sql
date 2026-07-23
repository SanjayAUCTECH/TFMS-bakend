-- ============================================================
-- Fix: Cascade delete OwnerContracts when CampOwner is removed
-- Issue: When owner is unassigned from camp, OwnerContract remains
-- Solution: Trigger on CampOwners DELETE to clean up related tables
-- ============================================================
USE TFMS_TestSoftwareDB;
GO

-- Drop trigger if exists
IF OBJECT_ID('trg_CampOwners_Delete', 'TR') IS NOT NULL
    DROP TRIGGER trg_CampOwners_Delete;
GO

CREATE TRIGGER trg_CampOwners_Delete
ON CampOwners
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get all OwnerContract IDs for deleted camp+owner combinations
    DECLARE @ContractIds TABLE (Id INT);
    
    INSERT INTO @ContractIds (Id)
    SELECT oc.Id
    FROM OwnerContracts oc
    INNER JOIN deleted d ON oc.CampId = d.CampId AND oc.OwnerId = d.OwnerId;
    
    -- Step 1: Delete OwnerTransactions first (FK reference, nullable but constrained)
    DELETE FROM OwnerTransactions 
    WHERE OwnerContractId IN (SELECT Id FROM @ContractIds);
    
    -- Step 2: Delete OwnerMonthlyContractInstallments
    DELETE FROM OwnerMonthlyContractInstallments 
    WHERE OwnerContractId IN (SELECT Id FROM @ContractIds);
    
    -- Step 3: Delete OwnerInstallments (FK reference with ON DELETE CASCADE, but explicit for safety)
    DELETE FROM OwnerInstallments 
    WHERE OwnerContractId IN (SELECT Id FROM @ContractIds);
    
    -- Step 4: Delete OwnerContracts
    DELETE FROM OwnerContracts 
    WHERE Id IN (SELECT Id FROM @ContractIds);
END
GO

PRINT '✅ Trigger trg_CampOwners_Delete created - cascades delete to OwnerContracts, OwnerInstallments, OwnerTransactions';
GO
