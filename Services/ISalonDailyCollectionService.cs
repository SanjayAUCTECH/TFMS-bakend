using TFMS_software_api.Common;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface ISalonDailyCollectionService
{
    // Combined daily posting
    Task<ApiResponse<SalonDailyPostingResponse>> PostDailyAsync(SalonDailyPostingRequest request, string? addedBy = null);

    // SDCollection CRUD
    Task<ApiResponse<IEnumerable<SDCollectionResponse>>> GetAllCollectionsAsync(SDCollectionListRequest request);
    Task<ApiResponse<SDCollectionResponse>>              GetCollectionByIdAsync(int id);
    Task<ApiResponse<SalonDailyPostingResponse>>         BulkCreateCollectionsAsync(BulkCreateSDCollectionRequest request, string? addedBy = null);
    Task<ApiResponse<SDCollectionResponse>>              UpdateCollectionAsync(int id, UpdateSDCollectionRequest request, int? userId = null);
    Task<ApiResponse<bool>>                              DeleteCollectionAsync(int id, int? userId = null);

    // SDExpence CRUD
    Task<ApiResponse<IEnumerable<SDExpenceResponse>>>    GetAllExpencesAsync(SDExpenceListRequest request);
    Task<ApiResponse<SDExpenceResponse>>                 GetExpenceByIdAsync(int id);
    Task<ApiResponse<SalonDailyPostingResponse>>         BulkCreateExpencesAsync(BulkCreateSDExpenceRequest request, string? addedBy = null);
    Task<ApiResponse<SDExpenceResponse>>                 UpdateExpenceAsync(int id, UpdateSDExpenceRequest request, int? userId = null);
    Task<ApiResponse<bool>>                              DeleteExpenceAsync(int id, int? userId = null);
}
