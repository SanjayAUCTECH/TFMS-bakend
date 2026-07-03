namespace TFMS_software_api.Common;

/// <summary>Shared pagination meta builder. Accepts nullable ints safely.</summary>
public static class PaginationHelper
{
    public static PaginationMeta Build(int total, int? pageNumber, int? pageSize)
    {
        int pn   = pageNumber ?? 1;
        int ps   = pageSize   > 0 ? pageSize.Value : 10;
        int pages = ps > 0 ? (int)Math.Ceiling((double)total / ps) : 1;
        return new PaginationMeta
        {
            TotalRecords    = total,
            TotalPages      = pages,
            CurrentPage     = pn,
            PageSize        = ps,
            HasNextPage     = pn < pages,
            HasPreviousPage = pn > 1,
        };
    }
}
