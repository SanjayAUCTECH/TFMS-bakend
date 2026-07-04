namespace TFMS_software_api.Common;

/// <summary>Standard API response wrapper.</summary>
public class ApiResponse<T>
{
    public bool    Success    { get; set; }
    public string  Message    { get; set; } = string.Empty;
    public T?      Data       { get; set; }
    public object? Pagination { get; set; }
    public object? Cards      { get; set; }

    public static ApiResponse<T> Ok(T data, string message = "Success", object? pagination = null, object? cards = null)
        => new() { Success = true,  Message = message, Data = data, Pagination = pagination, Cards = cards };

    public static ApiResponse<T> Fail(string message)
        => new() { Success = false, Message = message };
}

/// <summary>Pagination metadata returned with every list API.</summary>
public class PaginationMeta
{
    public int  TotalRecords    { get; set; }
    public int  TotalPages      { get; set; }
    public int  CurrentPage     { get; set; }
    public int  PageSize        { get; set; }
    public bool HasNextPage     { get; set; }
    public bool HasPreviousPage { get; set; }
}
