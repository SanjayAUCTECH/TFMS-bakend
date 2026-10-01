using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Services;

public class BulkPaymentService : IBulkPaymentService
{
    private readonly IDbConnectionFactory _factory;
    private readonly IPaymentRepository _paymentRepo;
    private readonly IPaymentService _paymentService;

    public BulkPaymentService(
        IDbConnectionFactory factory,
        IPaymentRepository paymentRepo,
        IPaymentService paymentService)
    {
        _factory = factory;
        _paymentRepo = paymentRepo;
        _paymentService = paymentService;
    }

    public async Task<BulkPaymentImportResponse> ProcessBulkImportAsync(
        BulkPaymentImportRequest request, 
        int? userId)
    {
        var response = new BulkPaymentImportResponse
        {
            TotalRecords = request.Payments.Count
        };

        int rowNumber = 1;
        foreach (var payment in request.Payments)
        {
            var result = new BulkPaymentResult
            {
                RowNumber = rowNumber,
                ContractId = payment.ContractId,
                PaymentType = payment.PaymentType,
                CampName = payment.CampName,
                RoomNo = payment.RoomNo,
                Amount = payment.Amount
            };

            try
            {
                // Validate payment item
                var validation = await ValidatePaymentItem(payment);
                
                if (!validation.IsValid)
                {
                    result.Success = false;
                    result.Message = "Validation failed";
                    result.ErrorDetails = validation.ErrorMessage;
                    response.Results.Add(result);
                    response.FailureCount++;
                    rowNumber++;
                    continue;
                }

                // Process based on payment type
                if (payment.PaymentType.Equals("Rent", StringComparison.OrdinalIgnoreCase))
                {
                    var txnId = await ProcessRentPayment(payment, validation, userId);
                    result.Success = true;
                    result.Message = "Rent payment processed successfully";
                    result.TxnRecordId = txnId;
                    response.SuccessCount++;
                }
                else if (payment.PaymentType.Equals("Security Deposit", StringComparison.OrdinalIgnoreCase) ||
                         payment.PaymentType.Equals("SD", StringComparison.OrdinalIgnoreCase))
                {
                    var txnId = await ProcessSecurityDeposit(payment, validation, userId);
                    result.Success = true;
                    result.Message = "Security deposit processed successfully";
                    result.TxnRecordId = txnId;
                    response.SuccessCount++;
                }
                else
                {
                    result.Success = false;
                    result.Message = "Invalid payment type";
                    result.ErrorDetails = $"PaymentType must be 'Rent' or 'Security Deposit', got '{payment.PaymentType}'";
                    response.FailureCount++;
                }
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.Message = "Processing failed";
                result.ErrorDetails = ex.Message;
                response.FailureCount++;
            }

            response.Results.Add(result);
            rowNumber++;
        }

        return response;
    }

    public async Task<BulkPaymentImportResponse> ValidateBulkImportAsync(BulkPaymentImportRequest request)
    {
        var response = new BulkPaymentImportResponse
        {
            TotalRecords = request.Payments.Count
        };

        int rowNumber = 1;
        foreach (var payment in request.Payments)
        {
            var result = new BulkPaymentResult
            {
                RowNumber = rowNumber,
                ContractId = payment.ContractId,
                PaymentType = payment.PaymentType,
                CampName = payment.CampName,
                RoomNo = payment.RoomNo,
                Amount = payment.Amount
            };

            var validation = await ValidatePaymentItem(payment);
            
            if (validation.IsValid)
            {
                result.Success = true;
                result.Message = "Validation passed";
                response.SuccessCount++;
            }
            else
            {
                result.Success = false;
                result.Message = "Validation failed";
                result.ErrorDetails = validation.ErrorMessage;
                response.FailureCount++;
            }

            response.Results.Add(result);
            rowNumber++;
        }

        return response;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VALIDATION
    // ═══════════════════════════════════════════════════════════════════════════

    private async Task<BulkPaymentValidation> ValidatePaymentItem(BulkPaymentItem payment)
    {
        var validation = new BulkPaymentValidation { IsValid = true };
        var errors = new List<string>();

        // Basic validation
        if (string.IsNullOrWhiteSpace(payment.ContractId))
            errors.Add("ContractId is required");

        if (string.IsNullOrWhiteSpace(payment.PaymentType))
            errors.Add("PaymentType is required");

        if (payment.Amount <= 0)
            errors.Add("Amount must be greater than 0");

        if (string.IsNullOrWhiteSpace(payment.CampName))
            errors.Add("CampName is required");

        if (string.IsNullOrWhiteSpace(payment.RoomNo))
            errors.Add("RoomNo is required");

        if (errors.Count > 0)
        {
            validation.IsValid = false;
            validation.ErrorMessage = string.Join("; ", errors);
            return validation;
        }

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Validate Contract exists
        var contractExists = await CheckContractExists(conn, payment.ContractId);
        if (!contractExists)
        {
            validation.IsValid = false;
            validation.ErrorMessage = $"Contract '{payment.ContractId}' not found";
            return validation;
        }

        // Get Camp ID from CampName
        validation.CampId = await GetCampIdByName(conn, payment.CampName);
        if (!validation.CampId.HasValue)
        {
            validation.IsValid = false;
            validation.ErrorMessage = $"Camp '{payment.CampName}' not found";
            return validation;
        }

        // Get Room ID from RoomNo and CampId
        validation.RoomId = await GetRoomIdByNoAndCamp(conn, payment.RoomNo, validation.CampId.Value);
        if (!validation.RoomId.HasValue)
        {
            validation.IsValid = false;
            validation.ErrorMessage = $"Room '{payment.RoomNo}' not found in camp '{payment.CampName}'";
            return validation;
        }

        // Validate room belongs to contract
        var roomInContract = await CheckRoomInContract(conn, payment.ContractId, validation.RoomId.Value);
        if (!roomInContract)
        {
            validation.IsValid = false;
            validation.ErrorMessage = $"Room '{payment.RoomNo}' not found in contract '{payment.ContractId}'";
            return validation;
        }

        // Get FundPool ID from FundPoolName
        if (!string.IsNullOrWhiteSpace(payment.FundPool))
        {
            validation.FundPoolId = await GetFundPoolIdByName(conn, payment.FundPool);
            if (!validation.FundPoolId.HasValue)
            {
                validation.IsValid = false;
                validation.ErrorMessage = $"Fund Pool '{payment.FundPool}' not found";
                return validation;
            }
        }

        // Get PaymentMode ID
        if (!string.IsNullOrWhiteSpace(payment.PaymentMode))
        {
            validation.PaymentModeId = await GetPaymentModeIdByName(conn, payment.PaymentMode);
        }

        // Rent-specific validation
        if (payment.PaymentType.Equals("Rent", StringComparison.OrdinalIgnoreCase))
        {
            if (string.IsNullOrWhiteSpace(payment.Month))
            {
                validation.IsValid = false;
                validation.ErrorMessage = "Month is required for Rent payments";
                return validation;
            }

            // Get InstallmentNo and ContractRoomInstallmentId from Month
            var (installmentNo, criId) = await GetInstallmentFromMonth(
                conn, 
                payment.ContractId, 
                validation.RoomId.Value, 
                payment.Month);

            if (!installmentNo.HasValue)
            {
                validation.IsValid = false;
                validation.ErrorMessage = $"Installment not found for month '{payment.Month}' in contract '{payment.ContractId}'";
                return validation;
            }

            validation.InstallmentNo = installmentNo;
            validation.ContractRoomInstallmentId = criId;
        }

        return validation;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RENT PAYMENT PROCESSING
    // ═══════════════════════════════════════════════════════════════════════════

    private async Task<int?> ProcessRentPayment(
        BulkPaymentItem payment, 
        BulkPaymentValidation validation, 
        int? userId)
    {
        // Build room payment item
        var roomPayment = new RoomPaymentItem
        {
            RoomId = validation.RoomId!.Value,
            CampId = validation.CampId!.Value,
            Amount = payment.Amount,
            Month = payment.Month,
            InstallmentNo = validation.InstallmentNo,
            ContractRoomInstallmentId = validation.ContractRoomInstallmentId,
            Status = NormalizeRentStatus(payment.Status)
        };

        // Build payment request
        var paymentRequest = new RecordPaymentRequest
        {
            ContractId = payment.ContractId,
            InstallmentNo = validation.InstallmentNo ?? 1,
            PaidAmount = payment.Amount,
            PaidDate = payment.PaymentDate,
            PaymentMode = payment.PaymentMode,
            PaymentModeId = validation.PaymentModeId,
            ChequeNumber = payment.ChequeNumber ?? "",
            ClearanceDate = ParseClearanceDate(payment.ClearanceDate),
            Description = payment.Description ?? "Bulk import - Rent payment",
            ReceivedBy = payment.ReceivedBy ?? "System",
            ReceivedContact = payment.ContactNumber ?? "",
            FundPoolId = validation.FundPoolId,
            FundPoolName = payment.FundPool ?? "",
            IssuedBy = payment.IssuedBy ?? "",
            AddedBy = userId,
            RoomPayments = new List<RoomPaymentItem> { roomPayment }
        };

        // Call existing payment service
        var paymentModel = new Models.Payment
        {
            ContractId = paymentRequest.ContractId,
            InstallmentNo = paymentRequest.InstallmentNo,
            PaidAmount = paymentRequest.PaidAmount,
            PaidDate = paymentRequest.PaidDate,
            PaymentMode = paymentRequest.PaymentMode,
            PaymentModeId = paymentRequest.PaymentModeId,
            ChequeNumber = paymentRequest.ChequeNumber,
            ClearanceDate = paymentRequest.ClearanceDate,
            Description = paymentRequest.Description,
            ReceivedBy = paymentRequest.ReceivedBy,
            ReceivedContact = paymentRequest.ReceivedContact,
            FundPoolId = paymentRequest.FundPoolId,
            FundPoolName = paymentRequest.FundPoolName,
            IssuedBy = paymentRequest.IssuedBy,
            AddedBy = paymentRequest.AddedBy
        };

        var roomPaymentsJson = System.Text.Json.JsonSerializer.Serialize(
            paymentRequest.RoomPayments,
            new System.Text.Json.JsonSerializerOptions { PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase });

        var success = await _paymentRepo.RecordPaymentWithRoomsAsync(paymentModel, roomPaymentsJson);

        if (!success)
            throw new Exception("Failed to record rent payment");

        // Get the created TxnRecordId
        var txnId = await GetLatestTxnRecordId(payment.ContractId, payment.PaymentDate);
        return txnId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SECURITY DEPOSIT PROCESSING
    // ═══════════════════════════════════════════════════════════════════════════

    private async Task<int?> ProcessSecurityDeposit(
        BulkPaymentItem payment, 
        BulkPaymentValidation validation, 
        int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        // Call sp_ReceiveSecurityDeposit
        await using var cmd = new SqlCommand("sp_ReceiveSecurityDeposit", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@ContractId", payment.ContractId);
        cmd.Parameters.AddWithValue("@Amount", payment.Amount);
        cmd.Parameters.AddWithValue("@PaidDate", payment.PaymentDate);
        cmd.Parameters.AddWithValue("@PaymentMode", payment.PaymentMode);
        cmd.Parameters.AddWithValue("@PaymentModeId", (object?)validation.PaymentModeId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ChequeNumber", payment.ChequeNumber ?? "");
        cmd.Parameters.AddWithValue("@FundPoolId", (object?)validation.FundPoolId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FundPoolName", payment.FundPool ?? "");
        cmd.Parameters.AddWithValue("@ReceivedBy", payment.ReceivedBy ?? "System");
        cmd.Parameters.AddWithValue("@Notes", payment.Description ?? "Bulk import - Security deposit");
        cmd.Parameters.AddWithValue("@PaymentStatus", NormalizeSDStatus(payment.Status));

        var pNewPaid = new SqlParameter("@NewPaid", SqlDbType.Decimal) 
            { Direction = ParameterDirection.Output, Precision = 18, Scale = 2 };
        var pNewStatus = new SqlParameter("@NewStatus", SqlDbType.NVarChar, 50) 
            { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(pNewPaid);
        cmd.Parameters.Add(pNewStatus);

        await cmd.ExecuteNonQueryAsync();

        // Sync to AccountMasters
        await using var syncCmd = new SqlCommand("sp_SyncSDReceiveToAccountMaster", conn) 
            { CommandType = CommandType.StoredProcedure };
        syncCmd.Parameters.AddWithValue("@ContractId", payment.ContractId);
        syncCmd.Parameters.AddWithValue("@Amount", payment.Amount);
        syncCmd.Parameters.AddWithValue("@PaidDate", payment.PaymentDate);
        syncCmd.Parameters.AddWithValue("@PaymentMode", payment.PaymentMode);
        syncCmd.Parameters.AddWithValue("@FundPoolId", (object?)validation.FundPoolId ?? DBNull.Value);
        await syncCmd.ExecuteNonQueryAsync();

        // Get the created TxnRecordId
        var txnId = await GetLatestTxnRecordId(payment.ContractId, payment.PaymentDate);
        return txnId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════════════════

    private async Task<bool> CheckContractExists(SqlConnection conn, string contractId)
    {
        await using var cmd = new SqlCommand(
            "SELECT COUNT(1) FROM Contracts WHERE ContractId = @ContractId AND ISNULL(IsDeleted,0)=0", 
            conn);
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        var count = (int)(await cmd.ExecuteScalarAsync() ?? 0);
        return count > 0;
    }

    private async Task<int?> GetCampIdByName(SqlConnection conn, string campName)
    {
        await using var cmd = new SqlCommand(
            "SELECT TOP 1 Id FROM Camps WHERE Name = @Name AND ISNULL(IsDeleted,0)=0", 
            conn);
        cmd.Parameters.AddWithValue("@Name", campName.Trim());
        var result = await cmd.ExecuteScalarAsync();
        return result != null && result != DBNull.Value ? (int)result : null;
    }

    private async Task<int?> GetRoomIdByNoAndCamp(SqlConnection conn, string roomNo, int campId)
    {
        await using var cmd = new SqlCommand(
            "SELECT TOP 1 Id FROM Rooms WHERE RoomNo = @RoomNo AND CampId = @CampId AND ISNULL(IsDeleted,0)=0", 
            conn);
        cmd.Parameters.AddWithValue("@RoomNo", roomNo.Trim());
        cmd.Parameters.AddWithValue("@CampId", campId);
        var result = await cmd.ExecuteScalarAsync();
        return result != null && result != DBNull.Value ? (int)result : null;
    }

    private async Task<bool> CheckRoomInContract(SqlConnection conn, string contractId, int roomId)
    {
        await using var cmd = new SqlCommand(
            "SELECT COUNT(1) FROM ContractRooms WHERE ContractId = @ContractId AND RoomId = @RoomId", 
            conn);
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@RoomId", roomId);
        var count = (int)(await cmd.ExecuteScalarAsync() ?? 0);
        return count > 0;
    }

    private async Task<int?> GetFundPoolIdByName(SqlConnection conn, string fundPoolName)
    {
        await using var cmd = new SqlCommand(
            "SELECT TOP 1 Id FROM FundPools WHERE Name = @Name AND ISNULL(IsDeleted,0)=0", 
            conn);
        cmd.Parameters.AddWithValue("@Name", fundPoolName.Trim());
        var result = await cmd.ExecuteScalarAsync();
        return result != null && result != DBNull.Value ? (int)result : null;
    }

    private async Task<int?> GetPaymentModeIdByName(SqlConnection conn, string paymentMode)
    {
        await using var cmd = new SqlCommand(
            "SELECT TOP 1 Id FROM PaymentModes WHERE Name = @Name AND ISNULL(IsDeleted,0)=0", 
            conn);
        cmd.Parameters.AddWithValue("@Name", paymentMode.Trim());
        var result = await cmd.ExecuteScalarAsync();
        return result != null && result != DBNull.Value ? (int)result : null;
    }

    private async Task<(int? InstallmentNo, int? CriId)> GetInstallmentFromMonth(
        SqlConnection conn, 
        string contractId, 
        int roomId, 
        string month)
    {
        // Parse month string (e.g., "Sep 2026" or "September 2026")
        DateTime? dueDate = ParseMonthString(month);
        if (!dueDate.HasValue)
            return (null, null);

        await using var cmd = new SqlCommand(@"
            SELECT TOP 1 InstallmentNo, Id 
            FROM ContractRoomInstallments 
            WHERE ContractId = @ContractId 
              AND RoomId = @RoomId 
              AND MONTH(DueDate) = @Month 
              AND YEAR(DueDate) = @Year
              AND ISNULL(IsDeleted,0) = 0
            ORDER BY InstallmentNo", conn);
        
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@RoomId", roomId);
        cmd.Parameters.AddWithValue("@Month", dueDate.Value.Month);
        cmd.Parameters.AddWithValue("@Year", dueDate.Value.Year);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var installmentNo = reader.GetInt32(0);
            var criId = reader.GetInt32(1);
            return (installmentNo, criId);
        }

        return (null, null);
    }

    private async Task<int?> GetLatestTxnRecordId(string contractId, DateTime txnDate)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand(@"
            SELECT TOP 1 Id 
            FROM TxnRecords 
            WHERE ContractId = @ContractId 
              AND CAST(TxnDate AS DATE) = CAST(@TxnDate AS DATE)
              AND ISNULL(IsDeleted,0) = 0
            ORDER BY CreatedAt DESC", conn);
        
        cmd.Parameters.AddWithValue("@ContractId", contractId);
        cmd.Parameters.AddWithValue("@TxnDate", txnDate);

        var result = await cmd.ExecuteScalarAsync();
        return result != null && result != DBNull.Value ? (int)result : null;
    }

    private DateTime? ParseMonthString(string month)
    {
        if (string.IsNullOrWhiteSpace(month))
            return null;

        // Try parse formats: "Sep 2026", "September 2026", "09-2026", "2026-09"
        string[] formats = {
            "MMM yyyy", "MMMM yyyy", "MM-yyyy", "yyyy-MM", "MM/yyyy", "yyyy/MM"
        };

        foreach (var format in formats)
        {
            if (DateTime.TryParseExact(month.Trim(), format, 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            {
                return date;
            }
        }

        return null;
    }

    private string? ParseClearanceDate(string clearanceDate)
    {
        if (string.IsNullOrWhiteSpace(clearanceDate))
            return null;

        if (DateTime.TryParse(clearanceDate, out var date))
            return date.ToString("yyyy-MM-dd");

        return null;
    }

    private string NormalizeRentStatus(string status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return "Paid";

        status = status.Trim();

        // Map various status values to standard ones
        if (status.Contains("Partial", StringComparison.OrdinalIgnoreCase))
            return "Partial";
        if (status.Contains("Advanced", StringComparison.OrdinalIgnoreCase))
            return "Advanced";
        if (status.Contains("Pending", StringComparison.OrdinalIgnoreCase))
            return "Pending";

        return "Paid";
    }

    private string NormalizeSDStatus(string status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return "Paid";

        status = status.Trim();

        // Map SD status values
        if (status.Contains("Advanced", StringComparison.OrdinalIgnoreCase))
            return "Advanced";

        return "Paid";  // Default for SD
    }
}
