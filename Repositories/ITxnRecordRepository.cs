using TFMS_software_api.Models;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public interface ITxnRecordRepository
{
    Task<(IEnumerable<TxnRecord> Data, int Total)> GetAllAsync(TxnRecordListRequest r);
    Task<int>  CreateAsync(TxnRecord t);
    Task<bool> UpdateAsync(int id, UpdateTxnRecordRequest r);
    Task<bool> DeleteAsync(int id);
}
