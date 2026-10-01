using TFMS_software_api.DTOs;

namespace TFMS_software_api.Services;

public interface IBulkPaymentService
{
    /// <summary>
    /// Process bulk payment import (save to database)
    /// </summary>
    Task<BulkPaymentImportResponse> ProcessBulkImportAsync(BulkPaymentImportRequest request, int? userId);

    /// <summary>
    /// Validate bulk payment import without saving (dry run)
    /// </summary>
    Task<BulkPaymentImportResponse> ValidateBulkImportAsync(BulkPaymentImportRequest request);
}
