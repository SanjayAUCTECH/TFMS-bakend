-- =============================================
-- SQL Server Agent Job: Daily Expired Contract Check
-- Purpose: Run sp_UpdateExpiredContractRooms daily at midnight
-- Note: Execute this script WHEN YOU'RE READY to activate automation
-- Created: 2026-09-21
-- =============================================

USE [msdb];
GO

-- =============================================
-- IMPORTANT: Read Before Executing
-- =============================================
/*
⚠️ THIS SCRIPT WILL CREATE AND START A DAILY JOB

What this does:
1. Creates SQL Server Agent Job
2. Schedules it to run DAILY at 12:00 AM (midnight)
3. Job will automatically check for expired contracts
4. Rooms with expired contracts will be marked as Vacant

When to execute:
- Execute this script ONLY when you want automation to start
- Make sure sp_UpdateExpiredContractRooms procedure is already created
- Test the procedure manually first before scheduling

To disable job later:
- EXEC msdb.dbo.sp_update_job @job_name = 'Daily_Update_Expired_Contract_Rooms', @enabled = 0;

To enable job later:
- EXEC msdb.dbo.sp_update_job @job_name = 'Daily_Update_Expired_Contract_Rooms', @enabled = 1;
*/

-- =============================================
-- Step 1: Check if SQL Server Agent is running
-- =============================================

DECLARE @AgentStatus INT;
EXEC master.dbo.xp_servicecontrol N'QUERYSTATE', N'SQLServerAGENT';

-- =============================================
-- Step 2: Delete existing job if exists
-- =============================================

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Daily_Update_Expired_Contract_Rooms')
BEGIN
    PRINT '🗑️ Deleting existing job...';
    EXEC msdb.dbo.sp_delete_job @job_name = N'Daily_Update_Expired_Contract_Rooms', @delete_unused_schedule=1;
    PRINT '✓ Existing job deleted.';
END
GO

-- =============================================
-- Step 3: Create the Job
-- =============================================

BEGIN TRANSACTION;

DECLARE @ReturnCode INT;
DECLARE @jobId BINARY(16);

-- Create Job
EXEC @ReturnCode = msdb.dbo.sp_add_job 
    @job_name=N'Daily_Update_Expired_Contract_Rooms', 
    @enabled=1,  -- 1 = Enabled, 0 = Disabled
    @notify_level_eventlog=0, 
    @notify_level_email=0, 
    @notify_level_netsend=0, 
    @notify_level_page=0, 
    @delete_level=0, 
    @description=N'Automatically updates room status to Vacant when contract expires. Runs daily at midnight.', 
    @category_name=N'[Uncategorized (Local)]', 
    @owner_login_name=N'sa',  -- Change if needed
    @job_id = @jobId OUTPUT;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
BEGIN
    ROLLBACK TRANSACTION;
    PRINT '❌ Job creation failed!';
    GOTO QuitWithRollback;
END

-- =============================================
-- Step 4: Add Job Step (Execute Procedure)
-- =============================================

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep 
    @job_id=@jobId, 
    @step_name=N'Execute Expired Contract Check', 
    @step_id=1, 
    @cmdexec_success_code=0, 
    @on_success_action=1,  -- Quit with success
    @on_success_step_id=0, 
    @on_fail_action=2,  -- Quit with failure
    @on_fail_step_id=0, 
    @retry_attempts=0, 
    @retry_interval=0, 
    @os_run_priority=0, 
    @subsystem=N'TSQL', 
    @command=N'EXEC [TFMS_TestSoftwareDB].[dbo].[sp_UpdateExpiredContractRooms];', 
    @database_name=N'TFMS_TestSoftwareDB',  -- Change to your database name
    @flags=0;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
BEGIN
    ROLLBACK TRANSACTION;
    PRINT '❌ Job step creation failed!';
    GOTO QuitWithRollback;
END

EXEC @ReturnCode = msdb.dbo.sp_update_job 
    @job_id = @jobId, 
    @start_step_id = 1;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
BEGIN
    ROLLBACK TRANSACTION;
    PRINT '❌ Job update failed!';
    GOTO QuitWithRollback;
END

-- =============================================
-- Step 5: Create Schedule (Daily at Midnight)
-- =============================================

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule 
    @job_id=@jobId, 
    @name=N'Daily at Midnight', 
    @enabled=1, 
    @freq_type=4,  -- Daily
    @freq_interval=1,  -- Every 1 day
    @freq_subday_type=1,  -- At specified time
    @freq_subday_interval=0, 
    @freq_relative_interval=0, 
    @freq_recurrence_factor=0, 
    @active_start_date=20260921,  -- YYYYMMDD format
    @active_end_date=99991231,  -- End date (9999-12-31 = never ends)
    @active_start_time=000000,  -- HHMMSS format (000000 = 12:00 AM midnight)
    @active_end_time=235959;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
BEGIN
    ROLLBACK TRANSACTION;
    PRINT '❌ Schedule creation failed!';
    GOTO QuitWithRollback;
END

-- =============================================
-- Step 6: Assign Job to Local Server
-- =============================================

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver 
    @job_id = @jobId, 
    @server_name = N'(local)';

IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
BEGIN
    ROLLBACK TRANSACTION;
    PRINT '❌ Job server assignment failed!';
    GOTO QuitWithRollback;
END

COMMIT TRANSACTION;

-- =============================================
-- Success Message
-- =============================================

PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✅ SQL Server Agent Job Created Successfully!';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT '📋 Job Details:';
PRINT '   Name: Daily_Update_Expired_Contract_Rooms';
PRINT '   Status: ENABLED ✓';
PRINT '   Schedule: Every day at 12:00 AM (Midnight)';
PRINT '   Action: Execute sp_UpdateExpiredContractRooms';
PRINT '';
PRINT '🔍 View Job in SSMS:';
PRINT '   SQL Server Agent → Jobs → Daily_Update_Expired_Contract_Rooms';
PRINT '';
PRINT '▶️ Run Job Manually Now:';
PRINT '   EXEC msdb.dbo.sp_start_job @job_name = ''Daily_Update_Expired_Contract_Rooms'';';
PRINT '';
PRINT '⏸️ Disable Job:';
PRINT '   EXEC msdb.dbo.sp_update_job @job_name = ''Daily_Update_Expired_Contract_Rooms'', @enabled = 0;';
PRINT '';
PRINT '▶️ Enable Job:';
PRINT '   EXEC msdb.dbo.sp_update_job @job_name = ''Daily_Update_Expired_Contract_Rooms'', @enabled = 1;';
PRINT '';
PRINT '🗑️ Delete Job:';
PRINT '   EXEC msdb.dbo.sp_delete_job @job_name = ''Daily_Update_Expired_Contract_Rooms'';';
PRINT '';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';

-- Display job information
SELECT 
    j.name AS JobName,
    j.enabled AS IsEnabled,
    j.description AS Description,
    s.name AS ScheduleName,
    CASE s.freq_type
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        ELSE 'Other'
    END AS Frequency,
    STUFF(STUFF(RIGHT('000000' + CAST(s.active_start_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':') AS StartTime,
    j.date_created AS CreatedDate
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name = 'Daily_Update_Expired_Contract_Rooms';

GOTO EndSave;

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
    
EndSave:
GO

-- =============================================
-- Optional: Test Job Execution Immediately
-- =============================================

PRINT '';
PRINT '🧪 Would you like to test the job now?';
PRINT 'Uncomment the line below to run job immediately:';
PRINT '';

-- Uncomment to run job now
-- EXEC msdb.dbo.sp_start_job @job_name = N'Daily_Update_Expired_Contract_Rooms';

PRINT '';
PRINT '✅ Setup complete! Job will run automatically every day at midnight.';
PRINT '';
