using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IPaymentRepository
{
    Task<(IEnumerable<Payment> Data, int TotalRecords)> GetAllAsync(PaymentListRequest request);
    Task<Payment?> GetByIdAsync(int id);
    Task<IEnumerable<Payment>> GetByContractIdAsync(string contractId);
    Task<bool>     RecordPaymentAsync(Payment payment);
    Task<bool>     RecordPaymentWithRoomsAsync(Payment payment, string roomPaymentsJson);
    Task<PaymentSummaryResponse?>              GetSummaryAsync(string contractId);
    Task<IEnumerable<PaymentHistoryResponse>>  GetHistoryAsync(string contractId);
    Task<IEnumerable<ContractRoomPaymentInfo>> GetContractRoomsForPaymentAsync(string contractId);
    Task<IEnumerable<RoomTransactionResponse>> GetRoomTransactionsAsync(string contractId, string? txnDate, int? txnRecordId);
}
