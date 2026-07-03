using Microsoft.AspNetCore.Mvc.ModelBinding;
using System.Text.Json.Serialization;

namespace TFMS_software_api.DTOs;

public class MisRequest
{
    public int?    CampId    { get; set; }   // null = all camps
    public string? Month     { get; set; }   // format: "2026-06"  (YYYY-MM), null = all months
    public int?    PartnerId { get; set; }   // null = all partners

    [BindNever, JsonIgnore]
    public bool HasMonthFilter => !string.IsNullOrWhiteSpace(Month);
}

public class MisStatsResponse
{
    public decimal TotalRental      { get; set; }
    public decimal TotalCollected   { get; set; }
    public decimal TotalOutstanding { get; set; }
    public decimal TotalExpenses    { get; set; }
    public decimal NetProfit        { get; set; }
    public int     TotalUnits       { get; set; }
    public int     OccupiedUnits    { get; set; }
    public int     VacantUnits      { get; set; }
    public decimal OccupancyPct     { get; set; }
    public List<MisCampRow>         CampBreakdown     { get; set; } = new();
    public List<MisMonthlyRow>      MonthlyCollection { get; set; } = new();
    public List<MisExpenseHeadRow>  ExpenseByHead     { get; set; } = new();
}

public class MisCampRow
{
    public int     CampId          { get; set; }
    public string  CampName        { get; set; } = string.Empty;
    public int     TotalRooms      { get; set; }
    public int     OccupiedRooms   { get; set; }
    public decimal MonthlyRevenue  { get; set; }
    public decimal TotalCollected  { get; set; }
    public decimal TotalOutstanding { get; set; }
}

public class MisMonthlyRow
{
    public string  Month      { get; set; } = string.Empty;   // "Jan 2026"
    public decimal Collected  { get; set; }
    public decimal Due        { get; set; }
    public decimal Expenses   { get; set; }
    public decimal NetProfit  { get; set; }
}

public class MisExpenseHeadRow
{
    public string  Head   { get; set; } = string.Empty;
    public decimal Amount { get; set; }
}

public class OwnerReportRow
{
    public int      OwnerId        { get; set; }
    public string   OwnerCode      { get; set; } = string.Empty;
    public string   OwnerName      { get; set; } = string.Empty;
    public string   Contact        { get; set; } = string.Empty;
    public string   Email          { get; set; } = string.Empty;
    public string   Status         { get; set; } = string.Empty;
    public int      TotalCamps     { get; set; }
    public string   CampNames      { get; set; } = string.Empty;
    public decimal  ShareValue     { get; set; }
    public string   ShareType      { get; set; } = string.Empty;
}
