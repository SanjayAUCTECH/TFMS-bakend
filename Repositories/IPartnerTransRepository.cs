using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IPartnerTransRepository
{
    /// <summary>Get all transactions for a specific partner.</summary>
    Task<IEnumerable<PartnerTrans>> GetByPartnerIdAsync(int partnerId);

    /// <summary>Get a single transaction by Id.</summary>
    Task<PartnerTrans?> GetByIdAsync(int id);
}
