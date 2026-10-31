using Microsoft.Data.SqlClient;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class DatabaseBackupRepository : IDatabaseBackupRepository
{
    private readonly IDbConnectionFactory _factory;

    public DatabaseBackupRepository(IDbConnectionFactory factory) => _factory = factory;

    public async Task<int> CreateBackupAsync(CreateBackupDto request, string backupFilePath, string? addedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        
        // FORCE CREATE BACKUP DIRECTORY using SQL Server's file operations
        // This will create C:\Backups\Database if it doesn't exist
        try
        {
            var createDirSql = @"
                DECLARE @Path NVARCHAR(500) = @Location
                DECLARE @Cmd NVARCHAR(1000)
                
                -- Try to create the directory structure
                -- First create C:\Backups
                SET @Cmd = 'IF NOT EXIST ""C:\Backups"" MKDIR ""C:\Backups""'
                EXEC master.dbo.xp_cmdshell @Cmd, NO_OUTPUT
                
                -- Then create C:\Backups\Database
                SET @Cmd = 'IF NOT EXIST ""' + @Path + '"" MKDIR ""' + @Path + '""'
                EXEC master.dbo.xp_cmdshell @Cmd, NO_OUTPUT
            ";
            
            await using var createDirCmd = new SqlCommand(createDirSql, conn);
            createDirCmd.Parameters.AddWithValue("@Location", request.Location);
            
            try
            {
                await createDirCmd.ExecuteNonQueryAsync();
            }
            catch
            {
                // xp_cmdshell might be disabled, try xp_create_subdir instead
                try
                {
                    var altDirSql = "EXEC master.dbo.xp_create_subdir @Path";
                    await using var altCmd = new SqlCommand(altDirSql, conn);
                    altCmd.Parameters.AddWithValue("@Path", request.Location);
                    await altCmd.ExecuteNonQueryAsync();
                }
                catch
                {
                    // If both fail, proceed anyway - backup command will create better error message
                }
            }
        }
        catch
        {
            // Ignore directory creation errors, let backup command handle it
        }
        
        // Create backup record in table
        var insertSql = @"
            INSERT INTO DatabaseBackups (BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt)
            VALUES (@BackupDate, @BackupName, @Location, @Remarks, @AddedBy, GETUTCDATE());
            SELECT SCOPE_IDENTITY();";
        
        await using var cmd = new SqlCommand(insertSql, conn);
        cmd.Parameters.AddWithValue("@BackupDate", request.BackupDate);
        cmd.Parameters.AddWithValue("@BackupName", request.BackupName);
        cmd.Parameters.AddWithValue("@Location", request.Location);
        cmd.Parameters.AddWithValue("@Remarks", (object?)request.Remarks ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AddedBy", (object?)addedBy ?? DBNull.Value);

        var result = await cmd.ExecuteScalarAsync();
        int backupId = Convert.ToInt32(result);

        // Perform actual database backup
        var backupSql = $@"
            BACKUP DATABASE [{conn.Database}] 
            TO DISK = @BackupPath 
            WITH FORMAT, INIT, 
            NAME = @BackupName, 
            SKIP, NOREWIND, NOUNLOAD, STATS = 10";

        await using var backupCmd = new SqlCommand(backupSql, conn);
        backupCmd.CommandTimeout = 600; // 10 minutes timeout for large databases
        backupCmd.Parameters.AddWithValue("@BackupPath", backupFilePath);
        backupCmd.Parameters.AddWithValue("@BackupName", request.BackupName);
        
        await backupCmd.ExecuteNonQueryAsync();

        return backupId;
    }

    public async Task<(IEnumerable<BackupListDto> Backups, int TotalRecords)> GetAllAsync(
        int pageNumber, int pageSize, string? search)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var countSql = @"
            SELECT COUNT(*) FROM DatabaseBackups
            WHERE (@Search IS NULL OR BackupName LIKE '%' + @Search + '%' OR Location LIKE '%' + @Search + '%')";

        var dataSql = @"
            SELECT Id, BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt
            FROM DatabaseBackups
            WHERE (@Search IS NULL OR BackupName LIKE '%' + @Search + '%' OR Location LIKE '%' + @Search + '%')
            ORDER BY BackupDate DESC, CreatedAt DESC
            OFFSET (@Offset) ROWS FETCH NEXT @PageSize ROWS ONLY";

        // Get total count
        await using var countCmd = new SqlCommand(countSql, conn);
        countCmd.Parameters.AddWithValue("@Search", (object?)search ?? DBNull.Value);
        var totalRecords = (int)(await countCmd.ExecuteScalarAsync())!;

        // Get page data
        await using var dataCmd = new SqlCommand(dataSql, conn);
        dataCmd.Parameters.AddWithValue("@Search", (object?)search ?? DBNull.Value);
        dataCmd.Parameters.AddWithValue("@Offset", (pageNumber - 1) * pageSize);
        dataCmd.Parameters.AddWithValue("@PageSize", pageSize);

        var list = new List<BackupListDto>();
        await using var reader = await dataCmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            list.Add(new BackupListDto
            {
                Id         = reader.GetInt32(reader.GetOrdinal("Id")),
                BackupDate = reader.GetDateTime(reader.GetOrdinal("BackupDate")),
                BackupName = reader.GetString(reader.GetOrdinal("BackupName")),
                Location   = reader.GetString(reader.GetOrdinal("Location")),
                Remarks    = reader.IsDBNull(reader.GetOrdinal("Remarks")) ? null : reader.GetString(reader.GetOrdinal("Remarks")),
                AddedBy    = reader.IsDBNull(reader.GetOrdinal("AddedBy")) ? null : reader.GetString(reader.GetOrdinal("AddedBy")),
                CreatedAt  = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
            });
        }

        return (list, totalRecords);
    }

    public async Task<BackupListDto?> GetByIdAsync(int id)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        var sql = @"
            SELECT Id, BackupDate, BackupName, Location, Remarks, AddedBy, CreatedAt
            FROM DatabaseBackups
            WHERE Id = @Id";

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await using var reader = await cmd.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return new BackupListDto
            {
                Id         = reader.GetInt32(reader.GetOrdinal("Id")),
                BackupDate = reader.GetDateTime(reader.GetOrdinal("BackupDate")),
                BackupName = reader.GetString(reader.GetOrdinal("BackupName")),
                Location   = reader.GetString(reader.GetOrdinal("Location")),
                Remarks    = reader.IsDBNull(reader.GetOrdinal("Remarks")) ? null : reader.GetString(reader.GetOrdinal("Remarks")),
                AddedBy    = reader.IsDBNull(reader.GetOrdinal("AddedBy")) ? null : reader.GetString(reader.GetOrdinal("AddedBy")),
                CreatedAt  = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
            };
        }

        return null;
    }

    public async Task DownloadBackupToLocalAsync(string sqlServerBackupPath, string localDestinationPath)
    {
        // Create local directory if it doesn't exist
        var localDir = Path.GetDirectoryName(localDestinationPath);
        if (!string.IsNullOrEmpty(localDir) && !Directory.Exists(localDir))
        {
            Directory.CreateDirectory(localDir);
        }

        // Check if SQL Server and API are on the same machine
        // If yes, use direct file copy. If no, use SQL Server's file operations
        
        // Try direct file copy first (works when SQL Server is local)
        if (File.Exists(sqlServerBackupPath))
        {
            // Direct file copy for local SQL Server
            File.Copy(sqlServerBackupPath, localDestinationPath, overwrite: true);
            return;
        }

        // For remote SQL Server or when direct access fails, use SQL-based approach
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        try
        {
            // Method 1: Try using xp_cmdshell to copy file
            var copySql = @"
                DECLARE @SourcePath NVARCHAR(500) = @SqlServerPath
                DECLARE @DestPath NVARCHAR(500) = @LocalPath
                DECLARE @Cmd NVARCHAR(1000)
                
                -- Create destination directory first
                DECLARE @DestDir NVARCHAR(500)
                SET @DestDir = LEFT(@DestPath, LEN(@DestPath) - CHARINDEX('\', REVERSE(@DestPath)))
                SET @Cmd = 'IF NOT EXIST ""' + @DestDir + '"" MKDIR ""' + @DestDir + '""'
                EXEC master.dbo.xp_cmdshell @Cmd, NO_OUTPUT
                
                -- Copy file
                SET @Cmd = 'COPY ""' + @SourcePath + '"" ""' + @DestPath + '"" /Y'
                EXEC master.dbo.xp_cmdshell @Cmd, NO_OUTPUT
            ";

            await using var copyCmd = new SqlCommand(copySql, conn);
            copyCmd.Parameters.AddWithValue("@SqlServerPath", sqlServerBackupPath);
            copyCmd.Parameters.AddWithValue("@LocalPath", localDestinationPath);
            copyCmd.CommandTimeout = 600; // 10 minutes for large files
            
            await copyCmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            // If xp_cmdshell fails, try OPENROWSET method
            try
            {
                // Build dynamic SQL since OPENROWSET doesn't accept parameters
                var bulkSql = $@"
                    SELECT BulkColumn 
                    FROM OPENROWSET(BULK '{sqlServerBackupPath.Replace("'", "''")}', SINGLE_BLOB) AS FileData
                ";

                await using var bulkCmd = new SqlCommand(bulkSql, conn);
                bulkCmd.CommandTimeout = 600;

                await using var reader = await bulkCmd.ExecuteReaderAsync();
                
                if (await reader.ReadAsync())
                {
                    if (!reader.IsDBNull(0))
                    {
                        var backupData = (byte[])reader[0];
                        await File.WriteAllBytesAsync(localDestinationPath, backupData);
                        return;
                    }
                }
                
                throw new Exception("No data returned from backup file");
            }
            catch
            {
                throw new Exception($"Unable to download backup file. Tried both xp_cmdshell and OPENROWSET methods. Original error: {ex.Message}");
            }
        }
    }
}
