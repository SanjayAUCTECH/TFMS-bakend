-- =============================================
-- DIAGNOSTIC SCRIPT: Check sp_GetDueReport
-- This will help identify what's wrong
-- =============================================

PRINT '========================================';
PRINT 'CHECKING sp_GetDueReport STATUS';
PRINT '========================================';
PRINT '';

-- Check 1: Does procedure exist?
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'sp_GetDueReport')
BEGIN
    PRINT '✓ Procedure EXISTS';
    PRINT '';
    
    -- Check 2: Get procedure parameters
    PRINT 'Current Parameters:';
    PRINT '-------------------';
    SELECT 
        p.name AS ParameterName,
        t.name AS DataType,
        p.max_length AS MaxLength
    FROM sys.parameters p
    JOIN sys.types t ON p.user_type_id = t.user_type_id
    WHERE object_id = OBJECT_ID('sp_GetDueReport')
    ORDER BY p.parameter_id;
    
    PRINT '';
    
    -- Check 3: Check if @CampbossId parameter exists
    IF EXISTS (
        SELECT * FROM sys.parameters 
        WHERE object_id = OBJECT_ID('sp_GetDueReport') 
        AND name = '@CampbossId'
    )
    BEGIN
        PRINT '✓ @CampbossId parameter EXISTS';
        PRINT '';
        PRINT 'Procedure is READY to use!';
        PRINT '';
        PRINT 'Test with: EXEC sp_GetDueReport @CampbossId = 5;';
    END
    ELSE
    BEGIN
        PRINT '✗ @CampbossId parameter MISSING!';
        PRINT '';
        PRINT 'ACTION REQUIRED:';
        PRINT '----------------';
        PRINT '1. Run UPDATE_sp_GetDueReport.sql';
        PRINT '2. Or run sp_GetDueReport_FINAL.sql';
        PRINT '3. Then restart your application';
    END
END
ELSE
BEGIN
    PRINT '✗ Procedure DOES NOT EXIST!';
    PRINT '';
    PRINT 'ACTION REQUIRED:';
    PRINT '----------------';
    PRINT '1. Run sp_GetDueReport_FINAL.sql to create it';
    PRINT '2. Or run UPDATE_sp_GetDueReport.sql';
    PRINT '3. Then restart your application';
END

PRINT '';
PRINT '========================================';
PRINT 'CHECK COMPLETE';
PRINT '========================================';
