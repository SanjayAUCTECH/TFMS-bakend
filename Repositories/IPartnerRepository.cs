using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;

namespace TFMS_software_api.Repositories;

public interface IPartnerRepository
{
    Task<(IEnumerable<Partner> Data, int TotalRecords)> GetAllAsync(PartnerListRequest request);
    Task<Partner?>                                       GetByIdAsync(int id);
    Task<int>                                            CreateAsync(Partner partner);
    Task<bool>                                           UpdateAsync(Partner partner);
    Task<bool>                                           DeleteAsync(int id);
    Task<bool>                                           ExistsAsync(int id);
}
