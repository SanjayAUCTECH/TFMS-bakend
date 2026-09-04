using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface ISalonDailyCollectionRepository
{
    // SDCollection
    Task<(IEnumerable<SDCollection> Data, int TotalRecords)> GetAllCollectionsAsync(SDCollectionListRequest request);
    Task<SDCollection?> GetCollectionByIdAsync(int collectionId);
    Task<int>  BulkCreateCollectionsAsync(List<SDCollectionItem> items, string? addedBy = null);
    Task<bool> UpdateCollectionAsync(SDCollection item);
    Task<bool> DeleteCollectionAsync(int collectionId, string? deletedBy = null);

    // SDExpence
    Task<(IEnumerable<SDExpence> Data, int TotalRecords)> GetAllExpencesAsync(SDExpenceListRequest request);
    Task<SDExpence?> GetExpenceByIdAsync(int expenceId);
    Task<int>  BulkCreateExpencesAsync(List<SDExpenceItem> items, string? addedBy = null);
    Task<bool> UpdateExpenceAsync(SDExpence item);
    Task<bool> DeleteExpenceAsync(int expenceId, string? deletedBy = null);
}
