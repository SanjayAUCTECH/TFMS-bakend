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

            // Enhance month with year from payment date if only month name provided
            string enhancedMonth = payment.Month;
            if (!payment.Month.Contains("202") && payment.PaymentDate != default(DateTime))
            {
                // If month is just "September", add year from payment date
                var monthNames = new[] { "January", "February", "March", "April", "May", "June", 
                                        "July", "August", "September", "October", "November", "December",
                                        "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
                
                if (monthNames.Any(m => payment.Month.Equals(m, StringComparison.OrdinalIgnoreCase)))
                {
                    enhancedMonth = $"{payment.Month} {payment.PaymentDate.Year}";
                    Console.WriteLine($"[BulkPayment] Enhanced month from '{payment.Month}' to '{enhancedMonth}'");
                }
            }

            // Get InstallmentNo and ContractRoomInstallmentId from Month
            // If RoomInstallmentNo is provided in payload, use it; otherwise fetch from month
            int? installmentNo = null;
            int? criId = null;
            
            if (payment.RoomInstallmentNo.HasValue && payment.RoomInstallmentNo.Value > 0)
            {
                // Use room installment from payload BUT still match with MONTH
                installmentNo = payment.RoomInstallmentNo;
                Console.WriteLine($"[BulkPayment] Using RoomInstallmentNo from payload: {installmentNo} for month: {enhancedMonth}");
                
                // Get CriId based on installment number AND month (IMPORTANT!)
                // This ensures we update the correct month's entry
                DateTime? monthDate = ParseMonthString(enhancedMonth);
                if (monthDate.HasValue)
                {
                    await using var criCmd = new SqlCommand(@"
                        SELECT TOP 1 Id 
                        FROM ContractRoomInstallments 
                        WHERE ContractId = @ContractId 
                          AND RoomId = @RoomId 
                          AND InstallmentNo = @InstallmentNo
                          AND MONTH(DueDate) = @Month
                          AND YEAR(DueDate) = @Year
                          AND ISNULL(IsDeleted,0) = 0", conn);
                    criCmd.Parameters.AddWithValue("@ContractId", payment.ContractId);
                    criCmd.Parameters.AddWithValue("@RoomId", validation.RoomId.Value);
                    criCmd.Parameters.AddWithValue("@InstallmentNo", installmentNo.Value);
                    criCmd.Parameters.AddWithValue("@Month", monthDate.Value.Month);
                    criCmd.Parameters.AddWithValue("@Year", monthDate.Value.Year);
                    
                    var criResult = await criCmd.ExecuteScalarAsync();
                    if (criResult != null && criResult != DBNull.Value)
                    {
                        criId = Convert.ToInt32(criResult);
                        Console.WriteLine($"[BulkPayment] Found CriId={criId} for InstallmentNo={installmentNo}, Month={monthDate.Value.Month}/{monthDate.Value.Year}");
                    }
                    else
                    {
                        Console.WriteLine($"[BulkPayment] WARNING: No matching entry found for InstallmentNo={installmentNo}, Month={enhancedMonth}");
                    }
                }
            }
            else
            {
                // Fallback: Get from month validation
                var result = await GetInstallmentFromMonth(
                    conn, 
                    payment.ContractId, 
                    validation.RoomId.Value, 
                    enhancedMonth);
                
                installmentNo = result.InstallmentNo;
                criId = result.CriId;
                Console.WriteLine($"[BulkPayment] Fetched RoomInstallmentNo from month '{enhancedMonth}': {installmentNo}");
            }

            if (!installmentNo.HasValue)
            {
                validation.IsValid = false;
                validation.ErrorMessage = $"Installment not found for month '{payment.Month}' (parsed as {enhancedMonth}) in contract '{payment.ContractId}'";
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
        try
        {
            // Validate required data
            if (!validation.RoomId.HasValue)
                throw new Exception("RoomId is required");
            if (!validation.CampId.HasValue)
                throw new Exception("CampId is required");
            if (string.IsNullOrEmpty(payment.ContractId))
                throw new Exception("ContractId is required");

            // Build room payment item
            var roomPayment = new RoomPaymentItem
            {
                RoomId = validation.RoomId.Value,
                CampId = validation.CampId.Value,
                Amount = payment.Amount,
                Month = payment.Month ?? "",
                InstallmentNo = validation.InstallmentNo,
                ContractRoomInstallmentId = validation.ContractRoomInstallmentId,
                Status = NormalizeRentStatus(payment.Status)
            };

            // Build payment request with proper date handling
            DateTime paidDate = payment.PaymentDate != default(DateTime) 
                ? payment.PaymentDate 
                : DateTime.Now;

            // ═══════════════════════════════════════════════════════════════
            // AUTO CONTRACT INSTALLMENT NUMBER MANAGEMENT (Bulk Import Only)
            // ═══════════════════════════════════════════════════════════════
            // Logic: 
            // - If ContractInstallmentNo is 0 or 1 (or null) → Auto-determine next installment
            // - Find last "Paid" installment and increment by 1
            // - RoomInstallmentNo is separate (used for ContractRoomInstallments)
            // ═══════════════════════════════════════════════════════════════
            int contractInstallmentNo;
            
            if (payment.ContractInstallmentNo == 0 || 
                payment.ContractInstallmentNo == 1 || 
                !payment.ContractInstallmentNo.HasValue)
            {
                // Auto-manage: Get next installment number
                contractInstallmentNo = await GetNextContractInstallmentNo(payment.ContractId);
                Console.WriteLine($"[BulkPayment] Auto-managed ContractInstallmentNo for {payment.ContractId} = {contractInstallmentNo}");
            }
            else
            {
                // Use provided contract installment number
                contractInstallmentNo = payment.ContractInstallmentNo.Value;
                Console.WriteLine($"[BulkPayment] Using provided ContractInstallmentNo for {payment.ContractId} = {contractInstallmentNo}");
            }
            
            var paymentRequest = new RecordPaymentRequest
            {
                ContractId = payment.ContractId,
                InstallmentNo = contractInstallmentNo,
                PaidAmount = payment.Amount,
                PaidDate = paidDate,
                PaymentMode = payment.PaymentMode ?? "Cash",
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
                InstallmentNo = contractInstallmentNo,
                PaidAmount = paymentRequest.PaidAmount,
                PaidDate = paymentRequest.PaidDate,
                PaymentMode = paymentRequest.PaymentMode ?? "",
                PaymentModeId = paymentRequest.PaymentModeId,
                ChequeNumber = paymentRequest.ChequeNumber ?? "",
                ClearanceDate = paymentRequest.ClearanceDate ?? "",
                Description = paymentRequest.Description ?? "",
                ReceivedBy = paymentRequest.ReceivedBy ?? "",
                ReceivedContact = paymentRequest.ReceivedContact ?? "",
                FundPoolId = paymentRequest.FundPoolId,
                FundPoolName = paymentRequest.FundPoolName ?? "",
                IssuedBy = paymentRequest.IssuedBy ?? "",
                AddedBy = paymentRequest.AddedBy
            };

            var roomPaymentsJson = System.Text.Json.JsonSerializer.Serialize(
                paymentRequest.RoomPayments,
                new System.Text.Json.JsonSerializerOptions { PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase });

            Console.WriteLine($"[BulkPayment] Processing Rent: Contract={payment.ContractId}, Room={validation.RoomId}, Amount={payment.Amount}");
            
            var success = await _paymentRepo.RecordPaymentWithRoomsAsync(paymentModel, roomPaymentsJson);

            if (!success)
            {
                Console.WriteLine($"[BulkPayment] RecordPaymentWithRoomsAsync returned false for Contract={payment.ContractId}");
                throw new Exception($"Failed to record rent payment for contract {payment.ContractId}");
            }

            Console.WriteLine($"[BulkPayment] Rent payment recorded successfully for Contract={payment.ContractId}");

            // Get the created TxnRecordId
            var txnId = await GetLatestTxnRecordId(payment.ContractId, paidDate);
            return txnId;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[BulkPayment] ProcessRentPayment ERROR: {ex.Message}");
            throw new Exception($"Rent payment processing failed: {ex.Message}", ex);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SECURITY DEPOSIT PROCESSING
    // ═══════════════════════════════════════════════════════════════════════════

    private async Task<int?> ProcessSecurityDeposit(
        BulkPaymentItem payment, 
        BulkPaymentValidation validation, 
        int? userId)
    {
        try
        {
            // Validate required data
            if (string.IsNullOrEmpty(payment.ContractId))
                throw new Exception("ContractId is required");
            if (payment.Amount <= 0)
                throw new Exception("Amount must be greater than 0");

            DateTime paidDate = payment.PaymentDate != default(DateTime) 
                ? payment.PaymentDate 
                : DateTime.Now;

            await using var conn = _factory.CreateConnection();
            await conn.OpenAsync();

            Console.WriteLine($"[BulkPayment] Processing SD: Contract={payment.ContractId}, Amount={payment.Amount}");

            // Call sp_ReceiveSecurityDeposit
            await using var cmd = new SqlCommand("sp_ReceiveSecurityDeposit", conn)
            {
                CommandType = CommandType.StoredProcedure
            };

            cmd.Parameters.AddWithValue("@ContractId", payment.ContractId);
            cmd.Parameters.AddWithValue("@Amount", payment.Amount);
            cmd.Parameters.AddWithValue("@PaidDate", paidDate);
            cmd.Parameters.AddWithValue("@PaymentMode", payment.PaymentMode ?? "Cash");
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

            Console.WriteLine($"[BulkPayment] sp_ReceiveSecurityDeposit executed for Contract={payment.ContractId}");

            // Sync to AccountMasters
            await using var syncCmd = new SqlCommand("sp_SyncSDReceiveToAccountMaster", conn) 
                { CommandType = CommandType.StoredProcedure };
            syncCmd.Parameters.AddWithValue("@ContractId", payment.ContractId);
            syncCmd.Parameters.AddWithValue("@Amount", payment.Amount);
            syncCmd.Parameters.AddWithValue("@PaidDate", paidDate);
            syncCmd.Parameters.AddWithValue("@PaymentMode", payment.PaymentMode ?? "Cash");
            syncCmd.Parameters.AddWithValue("@FundPoolId", (object?)validation.FundPoolId ?? DBNull.Value);
            await syncCmd.ExecuteNonQueryAsync();

            Console.WriteLine($"[BulkPayment] SD synced to AccountMasters for Contract={payment.ContractId}");

            // Get the created TxnRecordId
            var txnId = await GetLatestTxnRecordId(payment.ContractId, paidDate);
            return txnId;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[BulkPayment] ProcessSecurityDeposit ERROR: {ex.Message}");
            throw new Exception($"Security deposit processing failed: {ex.Message}", ex);
        }
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

        month = month.Trim();

        // Try parse formats with year first: "Sep 2026", "September 2026", "09-2026", "2026-09"
        string[] formatsWithYear = {
            "MMM yyyy", "MMMM yyyy", "MM-yyyy", "yyyy-MM", "MM/yyyy", "yyyy/MM",
            "MMM-yyyy", "MMMM-yyyy"
        };

        foreach (var format in formatsWithYear)
        {
            if (DateTime.TryParseExact(month, format, 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            {
                return date;
            }
        }

        // If only month name provided (e.g., "September", "Sep"), use current year
        string[] monthOnlyFormats = { "MMMM", "MMM" };
        foreach (var format in monthOnlyFormats)
        {
            if (DateTime.TryParseExact(month, format, 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
            {
                // Use current year
                var currentYear = DateTime.Now.Year;
                return new DateTime(currentYear, date.Month, 1);
            }
        }

        // Try parse month number only (e.g., "9", "09")
        if (int.TryParse(month, out var monthNum) && monthNum >= 1 && monthNum <= 12)
        {
            var currentYear = DateTime.Now.Year;
            return new DateTime(currentYear, monthNum, 1);
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

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO CONTRACT INSTALLMENT NUMBER CALCULATION
    // ═══════════════════════════════════════════════════════════════════════════
    /// <summary>
    /// Determines the next contract installment number based on completed installments.
    /// Logic:
    /// - Find the last COMPLETED (Status='Paid') installment
    /// - If no completed installments exist, return 1 (first installment)
    /// - Otherwise, return last_completed_installment + 1
    /// 
    /// Example:
    /// - No paid installments → Returns 1
    /// - Last paid installment is 2 → Returns 3
    /// - Last paid installment is 5 → Returns 6
    /// </summary>
    private async Task<int> GetNextContractInstallmentNo(string contractId)
    {
        try
        {
            await using var conn = _factory.CreateConnection();
            await conn.OpenAsync();

            // Query to find the last completed installment
            var query = @"
                SELECT MAX(InstallmentNo) 
                FROM ContractInstallments 
                WHERE ContractId = @ContractId 
                  AND ISNULL(IsDeleted, 0) = 0 
                  AND Status = 'Paid'";

            await using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@ContractId", contractId);

            var result = await cmd.ExecuteScalarAsync();

            // If no completed installment found, start from 1
            if (result == null || result == DBNull.Value)
            {
                Console.WriteLine($"[BulkPayment] No completed installments found for {contractId}. Starting from InstallmentNo = 1");
                return 1;
            }

            // Otherwise, increment the last completed installment
            int lastCompletedInstallment = Convert.ToInt32(result);
            int nextInstallment = lastCompletedInstallment + 1;

            Console.WriteLine($"[BulkPayment] Last completed installment for {contractId} = {lastCompletedInstallment}, Next = {nextInstallment}");
            return nextInstallment;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[BulkPayment] GetNextContractInstallmentNo ERROR: {ex.Message}");
            // Default to 1 in case of error
            return 1;
        }
    }
}

