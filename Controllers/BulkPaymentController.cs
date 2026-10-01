using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BulkPaymentController : BaseApiController
{
    private readonly IBulkPaymentService _service;

    public BulkPaymentController(IBulkPaymentService service, IActivityLogService log)
    {
        _service     = service;
        _activityLog = log;
    }

    /// <summary>
    /// POST /api/BulkPayment/import
    /// Import bulk payments from Excel (Rent + Security Deposit)
    /// Validates each row and processes accordingly
    /// </summary>
    [HttpPost("import")]
    public async Task<IActionResult> ImportPayments([FromBody] BulkPaymentImportRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ApiResponse<object>.Fail("Invalid request data."));

        if (request.Payments == null || request.Payments.Count == 0)
            return BadRequest(ApiResponse<object>.Fail("No payment data provided."));

        // Process bulk import
        var result = await _service.ProcessBulkImportAsync(request, CurrentUserId);

        // Log activity
        await Log(
            ActivityType.Insert,
            ActivityModule.Payments,
            $"Bulk Payment Import: Total {result.TotalRecords}, Success {result.SuccessCount}, Failed {result.FailureCount}",
            $"Bulk-{DateTime.UtcNow:yyyyMMddHHmmss}",
            "BulkPayment"
        );

        // Return appropriate status based on results
        if (result.FailureCount == 0)
        {
            return Ok(ApiResponse<BulkPaymentImportResponse>.Ok(
                result,
                $"All {result.SuccessCount} payments imported successfully."
            ));
        }
        else if (result.SuccessCount == 0)
        {
            // All failed - return as failed response with data
            var failResponse = new ApiResponse<BulkPaymentImportResponse>
            {
                Success = false,
                Message = $"All {result.FailureCount} payments failed. Check error details.",
                Data = result
            };
            return BadRequest(failResponse);
        }
        else
        {
            return Ok(ApiResponse<BulkPaymentImportResponse>.Ok(
                result,
                $"Partial success: {result.SuccessCount} succeeded, {result.FailureCount} failed."
            ));
        }
    }

    /// <summary>
    /// GET /api/BulkPayment/validate
    /// Validate bulk payment data without saving (dry run)
    /// </summary>
    [HttpPost("validate")]
    public async Task<IActionResult> ValidatePayments([FromBody] BulkPaymentImportRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ApiResponse<object>.Fail("Invalid request data."));

        if (request.Payments == null || request.Payments.Count == 0)
            return BadRequest(ApiResponse<object>.Fail("No payment data provided."));

        var result = await _service.ValidateBulkImportAsync(request);

        return Ok(ApiResponse<BulkPaymentImportResponse>.Ok(
            result,
            $"Validation complete: {result.SuccessCount} valid, {result.FailureCount} invalid."
        ));
    }

    /// <summary>
    /// GET /api/BulkPayment/template
    /// Download Excel template structure info
    /// </summary>
    [HttpGet("template")]
    public IActionResult GetTemplateInfo()
    {
        var template = new
        {
            columns = new[]
            {
                new { name = "ContractId",    type = "string",  required = true,  example = "CNT-00123" },
                new { name = "PaymentType",   type = "string",  required = true,  example = "Rent or Security Deposit" },
                new { name = "CampName",      type = "string",  required = true,  example = "MUMTAZ.R2" },
                new { name = "RoomNo",        type = "string",  required = true,  example = "306" },
                new { name = "Month",         type = "string",  required = false, example = "Sep 2026 (for Rent only)" },
                new { name = "Status",        type = "string",  required = true,  example = "Paid/Partial/Advanced/Received" },
                new { name = "Amount",        type = "decimal", required = true,  example = "2600" },
                new { name = "PaymentDate",   type = "date",    required = true,  example = "2026-09-30" },
                new { name = "PaymentMode",   type = "string",  required = true,  example = "Cash/Cheque/Bank Transfer" },
                new { name = "FundPool",      type = "string",  required = true,  example = "RENT COLLECTION" },
                new { name = "ChequeNumber",  type = "string",  required = false, example = "CHQ-45821" },
                new { name = "ClearanceDate", type = "string",  required = false, example = "2026-10-05" },
                new { name = "IssuedBy",      type = "string",  required = false, example = "John Doe" },
                new { name = "ReceivedBy",    type = "string",  required = false, example = "Admin" },
                new { name = "ContactNumber", type = "string",  required = false, example = "+971501234567" },
                new { name = "Description",   type = "string",  required = false, example = "Monthly rent payment" }
            },
            paymentTypes = new[] { "Rent", "Security Deposit" },
            statusValues = new
            {
                rent = new[] { "Paid", "Partial", "Advanced", "Pending" },
                securityDeposit = new[] { "Received", "Partially Received", "Paid", "Advanced" }
            },
            notes = new[]
            {
                "PaymentType determines which API is called (Rent → Payments, Security Deposit → SecurityDeposit)",
                "Month is required for Rent, optional for Security Deposit",
                "Status values differ based on PaymentType",
                "CampName and RoomNo are used to identify the exact room in the contract",
                "FundPool must exist in FundPools table",
                "All amounts must be positive numbers"
            }
        };

        return Ok(ApiResponse<object>.Ok(template, "Template information retrieved."));
    }
}
