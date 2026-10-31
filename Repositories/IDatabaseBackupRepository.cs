using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface IDatabaseBackupRepository
{
    Task<int> CreateBackupAsync(CreateBackupDto request, string backupFilePath, string? addedBy);
    Task<(IEnumerable<BackupListDto> Backups, int TotalRecords)> GetAllAsync(int pageNumber, int pageSize, string? search);
    Task<BackupListDto?> GetByIdAsync(int id);
    Task DownloadBackupToLocalAsync(string sqlServerBackupPath, string localDestinationPath);
}
