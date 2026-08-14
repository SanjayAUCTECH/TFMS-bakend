using Microsoft.Data.SqlClient;
using System.Data;
using TFMS_software_api.DTOs;

namespace TFMS_software_api.Repositories;

public class PartnerPayoutRepository : IPartnerPayoutRepository
{
    private readonly IDbConnectionFactory _factory;
    public PartnerPayoutRepository(IDbConnectionFactory factory) => _factory = factory;

    // ──────────────────────────────────────────────────────────────
    // GET — all distinct payout dates (PartnerMonthlyPayout)
    // ──────────────────────────────────────────────────────────────
    public async Task<List<MonthlyPayoutDateItem>> GetMonthlyPayoutDatesAsync()
    {
        var list = new List<MonthlyPayoutDateItem>();

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetMonthlyPayoutDates", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new MonthlyPayoutDateItem
            {
                FromDate     = reader.GetDateTime(reader.GetOrdinal("FromDate")),
                ToDate       = reader.GetDateTime(reader.GetOrdinal("ToDate")),
                PayoutDate   = reader.GetDateTime(reader.GetOrdinal("PayoutDate")),
                PartnerCount = reader.GetInt32(reader.GetOrdinal("PartnerCount")),
                CreatedAt    = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            });
        }

        return list;
    }

    // ──────────────────────────────────────────────────────────────
    // GET — last monthly payout date (PartnerMonthlyPayout table)
    // ──────────────────────────────────────────────────────────────
    public async Task<LastMonthlyPayoutDateResponse> GetLastMonthlyPayoutDateAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetLastMonthlyPayoutDate", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using var reader = await cmd.ExecuteReaderAsync();
        var response = new LastMonthlyPayoutDateResponse();

        if (await reader.ReadAsync())
        {
            response.LastPayoutDate = reader.IsDBNull(reader.GetOrdinal("LastPayoutDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastPayoutDate"));
            response.LastToDate = reader.IsDBNull(reader.GetOrdinal("LastToDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastToDate"));
            response.LastFromDate = reader.IsDBNull(reader.GetOrdinal("LastFromDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastFromDate"));
            response.LastCreatedAt = reader.IsDBNull(reader.GetOrdinal("LastCreatedAt"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastCreatedAt"));
        }

        return response;
    }

    // ──────────────────────────────────────────────────────────────
    // GET — last payout date (PartnerMonthlyCampPayout table)
    // ──────────────────────────────────────────────────────────────
    public async Task<LastPayoutDateResponse> GetLastPayoutDateAsync()
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetLastPayoutDate", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        await using var reader = await cmd.ExecuteReaderAsync();
        var response = new LastPayoutDateResponse();

        if (await reader.ReadAsync())
        {
            response.LastPayoutDate = reader.IsDBNull(reader.GetOrdinal("LastPayoutDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastPayoutDate"));
            response.LastToDate = reader.IsDBNull(reader.GetOrdinal("LastToDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastToDate"));
            response.LastFromDate = reader.IsDBNull(reader.GetOrdinal("LastFromDate"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastFromDate"));
            response.LastCreatedAt = reader.IsDBNull(reader.GetOrdinal("LastCreatedAt"))
                ? null : reader.GetDateTime(reader.GetOrdinal("LastCreatedAt"));
        }

        return response;
    }

    // ──────────────────────────────────────────────────────────────
    // GET — camp-wise payout data for a date range
    // ──────────────────────────────────────────────────────────────
    public async Task<PartnerPayoutDataResponse> GetPayoutDataAsync(DateTime fromDate, DateTime toDate)
    {
        var response = new PartnerPayoutDataResponse
        {
            FromDate    = fromDate,
            ToDate      = toDate,
            PeriodLabel = $"{fromDate:dd MMM yyyy} – {toDate:dd MMM yyyy}"
        };

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerMonthlyPayoutData", conn)
        {
            CommandType = CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@FromDate", fromDate.Date);
        cmd.Parameters.AddWithValue("@ToDate",   toDate.Date);

        await using var reader = await cmd.ExecuteReaderAsync();

        // Result Set 1: Camp-wise rows
        while (await reader.ReadAsync())
        {
            response.CampDetails.Add(new PartnerCampPayoutRow
            {
                CampId                 = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName               = S(reader, "CampName"),
                CampIncome             = D(reader, "CampIncome"),
                CampExpense            = D(reader, "CampExpense"),
                HOExpense              = D(reader, "HOExpense"),
                TotalExpense           = D(reader, "TotalExpense"),
                BenefitAmount          = D(reader, "BenefitAmount"),
                CampPartnerId          = reader.GetInt32(reader.GetOrdinal("CampPartnerId")),
                PartnerId              = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerName            = S(reader, "PartnerName"),
                ShareType              = S(reader, "ShareType"),
                CampPartnerPercentage  = D(reader, "CampPartnerPercentage"),
                PartnerShareAmount     = D(reader, "PartnerShareAmount"),
                TotalHOExpenseAllCamps = D(reader, "TotalHOExpenseAllCamps"),
                ActiveCampCount        = reader.IsDBNull(reader.GetOrdinal("ActiveCampCount"))
                                            ? 0 : reader.GetInt32(reader.GetOrdinal("ActiveCampCount")),
                PartnerInvestmentIncome = D(reader, "PartnerInvestmentIncome"),
            });
        }

        // Result Set 2: Partner summary
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                response.Summary.Add(new PartnerPayoutSummaryRow
                {
                    PartnerId          = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                    PartnerName        = S(reader, "PartnerName"),
                    TotalCampIncome    = D(reader, "TotalCampIncome"),
                    TotalCampExpense   = D(reader, "TotalCampExpense"),
                    TotalHOExpense     = D(reader, "TotalHOExpense"),
                    TotalAllExpense    = D(reader, "TotalAllExpense"),
                    TotalBenefitAmount = D(reader, "TotalBenefitAmount"),
                    PartnerShareAmount = D(reader, "PartnerShareAmount"),
                });
            }
        }

        return response;
    }

    // ──────────────────────────────────────────────────────────────
    // SAVE — insert into PartnerMonthlyCampPayout via SP
    // ──────────────────────────────────────────────────────────────
    public async Task<int> SaveMonthlyCampPayoutAsync(
        SavePartnerMonthlyCampPayoutRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_SavePartnerMonthlyCampPayout", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@FromDate", request.FromDate);
        cmd.Parameters.AddWithValue("@ToDate",   request.ToDate);
        cmd.Parameters.AddWithValue("@Date",     request.Date ?? DateTime.Now);
        cmd.Parameters.AddWithValue("@AddedBy",  (object?)userId ?? DBNull.Value);

        // Build TVP DataTable
        var dt = new DataTable();
        dt.Columns.Add("PartnerId",               typeof(int));
        dt.Columns.Add("CampId",                  typeof(int));
        dt.Columns.Add("CampPartnerPercentage",   typeof(decimal));
        dt.Columns.Add("CampIncome",              typeof(decimal));
        dt.Columns.Add("CampExpense",             typeof(decimal));
        dt.Columns.Add("HOExpense",               typeof(decimal));
        dt.Columns.Add("TotalExpense",            typeof(decimal));
        dt.Columns.Add("BenefitAmount",           typeof(decimal));
        dt.Columns.Add("PartnerInvestmentIncome", typeof(decimal));

        foreach (var row in request.Rows)
        {
            dt.Rows.Add(
                row.PartnerId,
                row.CampId,
                row.CampPartnerPercentage,
                row.CampIncome,
                row.CampExpense,
                row.HOExpense,
                row.TotalExpense,
                row.BenefitAmount,
                row.PartnerInvestmentIncome
            );
        }

        var tvp = cmd.Parameters.AddWithValue("@Rows", dt);
        tvp.SqlDbType = SqlDbType.Structured;
        tvp.TypeName  = "dbo.PartnerMonthlyCampPayoutType";

        await cmd.ExecuteNonQueryAsync();
        return request.Rows.Count;
    }

    // ──────────────────────────────────────────────────────────────
    // GET saved records from PartnerMonthlyCampPayout
    // ──────────────────────────────────────────────────────────────
    public async Task<(IEnumerable<PartnerMonthlyCampPayoutResponse> Data, int Total)>
        GetMonthlyCampPayoutAsync(GetPartnerMonthlyCampPayoutRequest request)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerMonthlyCampPayout", conn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@PartnerId",  (object?)request.PartnerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FromDate",   (object?)request.FromDate  ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ToDate",     (object?)request.ToDate    ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PageNumber", request.ResolvedPageNumber);
        cmd.Parameters.AddWithValue("@PageSize",   request.ResolvedPageSize);

        var totalParam = new SqlParameter("@TotalRecords", System.Data.SqlDbType.Int)
            { Direction = System.Data.ParameterDirection.Output };
        cmd.Parameters.Add(totalParam);

        var list = new List<PartnerMonthlyCampPayoutResponse>();
        await using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            list.Add(new PartnerMonthlyCampPayoutResponse
            {
                Id                    = reader.GetInt32(reader.GetOrdinal("Id")),
                FromDate              = reader.GetDateTime(reader.GetOrdinal("FromDate")),
                ToDate                = reader.GetDateTime(reader.GetOrdinal("ToDate")),
                Date                  = reader.GetDateTime(reader.GetOrdinal("Date")),
                PartnerId             = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerName           = S(reader, "PartnerName"),
                CampId                = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName              = S(reader, "CampName"),
                CampPartnerPercentage = D(reader, "CampPartnerPercentage"),
                CampIncome            = D(reader, "CampIncome"),
                CampExpense           = D(reader, "CampExpense"),
                HOExpense             = D(reader, "HOExpense"),
                TotalExpense          = D(reader, "TotalExpense"),
                BenefitAmount         = D(reader, "BenefitAmount"),
                AddedBy               = reader.IsDBNull(reader.GetOrdinal("AddedBy"))
                                            ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                CreatedAt             = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt             = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
            });
        }

        await reader.CloseAsync();
        int total = totalParam.Value == DBNull.Value ? 0 : (int)totalParam.Value;
        return (list, total);
    }

    // ──────────────────────────────────────────────────────────────
    // GET partner-wise payout by date range
    // ──────────────────────────────────────────────────────────────
    public async Task<PartnerPayoutByMonthResponse> GetPartnerPayoutByMonthAsync(DateTime fromDate, DateTime toDate)
    {
        var response = new PartnerPayoutByMonthResponse
        {
            FromDate    = fromDate,
            ToDate      = toDate,
            PeriodLabel = $"{fromDate:dd MMM yyyy} – {toDate:dd MMM yyyy}"
        };

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerPayoutByMonth", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@FromDate", fromDate.Date);
        cmd.Parameters.AddWithValue("@ToDate",   toDate.Date);

        await using var reader = await cmd.ExecuteReaderAsync();

        // ── Result Set 1: Camp-wise rows ──────────────────────────
        var campRows = new List<PartnerPayoutCampRow>();
        while (await reader.ReadAsync())
        {
            campRows.Add(new PartnerPayoutCampRow
            {
                Id                    = reader.GetInt32(reader.GetOrdinal("Id")),
                PartnerId             = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerName           = S(reader, "PartnerName"),
                PartnerCode           = S(reader, "PartnerCode"),
                CampId                = reader.GetInt32(reader.GetOrdinal("CampId")),
                CampName              = S(reader, "CampName"),
                FromDate              = reader.GetDateTime(reader.GetOrdinal("FromDate")),
                ToDate                = reader.GetDateTime(reader.GetOrdinal("ToDate")),
                CampPartnerPercentage = D(reader, "CampPartnerPercentage"),
                CampIncome            = D(reader, "CampIncome"),
                CampExpense           = D(reader, "CampExpense"),
                HOExpense             = D(reader, "HOExpense"),
                TotalExpense          = D(reader, "TotalExpense"),
                BenefitAmount         = D(reader, "BenefitAmount"),
                CampPayoutAmount      = D(reader, "CampPayoutAmount"),
            });
        }

        // ── Result Set 2: Partner totals ──────────────────────────
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                var partnerId = reader.GetInt32(reader.GetOrdinal("PartnerId"));
                var partnerRow = new PartnerPayoutTotalRow
                {
                    PartnerId          = partnerId,
                    PartnerName        = S(reader, "PartnerName"),
                    PartnerCode        = S(reader, "PartnerCode"),
                    TotalIncome        = D(reader, "TotalIncome"),
                    TotalCampExpense   = D(reader, "TotalCampExpense"),
                    TotalHOExpense     = D(reader, "TotalHOExpense"),
                    TotalExpense       = D(reader, "TotalExpense"),
                    TotalBenefitAmount = D(reader, "TotalBenefitAmount"),
                    TotalPayoutAmount  = D(reader, "TotalPayoutAmount"),
                    TotalCamps         = reader.IsDBNull(reader.GetOrdinal("TotalCamps"))
                                            ? 0 : reader.GetInt32(reader.GetOrdinal("TotalCamps")),
                    Camps = campRows.Where(c => c.PartnerId == partnerId).ToList()
                };
                response.Partners.Add(partnerRow);
            }
        }

        return response;
    }

    // ──────────────────────────────────────────────────────────────
    // SAVE — PartnerMonthlyPayout
    // ──────────────────────────────────────────────────────────────
    public async Task<int> SaveMonthlyPayoutAsync(
        SavePartnerMonthlyPayoutRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_SavePartnerMonthlyPayout", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@FromDate", request.FromDate);
        cmd.Parameters.AddWithValue("@ToDate",   request.ToDate);
        cmd.Parameters.AddWithValue("@Date",     request.Date ?? DateTime.Now);
        cmd.Parameters.AddWithValue("@AddedBy",  (object?)userId ?? DBNull.Value);

        var dt = new System.Data.DataTable();
        dt.Columns.Add("PartnerId",             typeof(int));
        dt.Columns.Add("CampPartnerPercentage", typeof(decimal));
        dt.Columns.Add("TotalCampIncome",       typeof(decimal));
        dt.Columns.Add("TotalCampExpense",      typeof(decimal));
        dt.Columns.Add("TotalHOExpense",        typeof(decimal));
        dt.Columns.Add("TotalAllExpense",       typeof(decimal));
        dt.Columns.Add("TotalBenefitAmount",    typeof(decimal));
        dt.Columns.Add("PartnerShareAmount",    typeof(decimal));

        foreach (var r in request.Rows)
            dt.Rows.Add(r.PartnerId, r.CampPartnerPercentage,
                        r.TotalCampIncome, r.TotalCampExpense,
                        r.TotalHOExpense,  r.TotalAllExpense,
                        r.TotalBenefitAmount, r.PartnerShareAmount);

        var tvp = cmd.Parameters.AddWithValue("@Rows", dt);
        tvp.SqlDbType  = System.Data.SqlDbType.Structured;
        tvp.TypeName   = "dbo.PartnerMonthlyPayoutType";

        await cmd.ExecuteNonQueryAsync();
        return request.Rows.Count;
    }

    // ──────────────────────────────────────────────────────────────
    // DELETE — soft-delete by Month + Year (+ optional PartnerId)
    // ──────────────────────────────────────────────────────────────
    public async Task<int> DeleteMonthlyPayoutAsync(
        int month, int year, int? partnerId, int? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeletePartnerMonthlyPayout", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Month",     month);
        cmd.Parameters.AddWithValue("@Year",      year);
        cmd.Parameters.AddWithValue("@PartnerId", (object?)partnerId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return reader.IsDBNull(0) ? 0 : reader.GetInt32(0);
        return 0;
    }

    // ──────────────────────────────────────────────────────────────
    // GET PartnerMonthlyPayout list by month/year
    // ──────────────────────────────────────────────────────────────
    public async Task<GetPartnerMonthlyPayoutListResponse> GetMonthlyPayoutListAsync(
        int month, int year, int? partnerId)
    {
        var response = new GetPartnerMonthlyPayoutListResponse
        {
            Month      = month,
            Year       = year,
            MonthLabel = new DateTime(year, month, 1).ToString("MMMM yyyy")
        };

        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_GetPartnerMonthlyPayout", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@Month",     month);
        cmd.Parameters.AddWithValue("@Year",      year);
        cmd.Parameters.AddWithValue("@PartnerId", (object?)partnerId ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            response.Partners.Add(new PartnerMonthlyPayoutResponse
            {
                Id                    = reader.GetInt32(reader.GetOrdinal("Id")),
                FromDate              = reader.GetDateTime(reader.GetOrdinal("FromDate")),
                ToDate                = reader.GetDateTime(reader.GetOrdinal("ToDate")),
                Date                  = reader.GetDateTime(reader.GetOrdinal("Date")),
                PartnerId             = reader.GetInt32(reader.GetOrdinal("PartnerId")),
                PartnerName           = S(reader, "PartnerName"),
                PartnerCode           = S(reader, "PartnerCode"),
                CampPartnerPercentage = D(reader, "CampPartnerPercentage"),
                TotalCampIncome       = D(reader, "TotalCampIncome"),
                TotalCampExpense      = D(reader, "TotalCampExpense"),
                TotalHOExpense        = D(reader, "TotalHOExpense"),
                TotalAllExpense       = D(reader, "TotalAllExpense"),
                TotalBenefitAmount    = D(reader, "TotalBenefitAmount"),
                PartnerShareAmount    = D(reader, "PartnerShareAmount"),
                AddedBy               = reader.IsDBNull(reader.GetOrdinal("AddedBy"))
                                            ? null : reader.GetInt32(reader.GetOrdinal("AddedBy")),
                CreatedAt             = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                UpdatedAt             = reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
            });
        }

        return response;
    }

    // ──────────────────────────────────────────────────────────────
    // SAVE — PartnerReleasePayout
    // ──────────────────────────────────────────────────────────────
    public async Task<int> SaveReleasePayoutAsync(
        CreatePartnerReleasePayoutRequest request, int? userId)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_SavePartnerReleasePayout", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };

        cmd.Parameters.AddWithValue("@Date",                  request.Date);
        cmd.Parameters.AddWithValue("@ReleaseDate",           request.ReleaseDate);
        cmd.Parameters.AddWithValue("@PartnerId",             request.PartnerId);
        cmd.Parameters.AddWithValue("@CampPartnerPercentage", request.CampPartnerPercentage);
        cmd.Parameters.AddWithValue("@TotalCampIncome",       request.TotalCampIncome);
        cmd.Parameters.AddWithValue("@TotalCampExpense",      request.TotalCampExpense);
        cmd.Parameters.AddWithValue("@TotalHOExpense",        request.TotalHOExpense);
        cmd.Parameters.AddWithValue("@TotalAllExpense",       request.TotalAllExpense);
        cmd.Parameters.AddWithValue("@TotalBenefitAmount",    request.TotalBenefitAmount);
        cmd.Parameters.AddWithValue("@PartnerShareAmount",    request.PartnerShareAmount);
        cmd.Parameters.AddWithValue("@ReleaseAmount",         request.ReleaseAmount);
        cmd.Parameters.AddWithValue("@BalanceAmount",         request.BalanceAmount);
        cmd.Parameters.AddWithValue("@AddedBy",               (object?)userId ?? DBNull.Value);

        var newIdParam = new SqlParameter("@NewId", System.Data.SqlDbType.Int)
            { Direction = System.Data.ParameterDirection.Output };
        cmd.Parameters.Add(newIdParam);

        await cmd.ExecuteNonQueryAsync();
        return (int)newIdParam.Value;
    }

    // ──────────────────────────────────────────────────────────────
    // DELETE — soft-delete PartnerMonthlyCampPayout by ToDate only
    // ──────────────────────────────────────────────────────────────
    public async Task<int> DeleteCampPayoutAsync(DateTime toDate, int? deletedBy)
    {
        await using var conn = _factory.CreateConnection();
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("sp_DeletePartnerMonthlyCampPayout", conn)
        {
            CommandType = System.Data.CommandType.StoredProcedure
        };
        cmd.Parameters.AddWithValue("@ToDate",    toDate.Date);
        cmd.Parameters.AddWithValue("@DeletedBy", (object?)deletedBy ?? DBNull.Value);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
            return reader.IsDBNull(0) ? 0 : reader.GetInt32(0);
        return 0;
    }

    // ── Helpers ───────────────────────────────────────────────────
    private static string  S(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? "" : r.GetString(o);  } catch { return ""; } }
    private static decimal D(SqlDataReader r, string c) { try { var o = r.GetOrdinal(c); return r.IsDBNull(o) ? 0m : r.GetDecimal(o); } catch { return 0m; } }
}
