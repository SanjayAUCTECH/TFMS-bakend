using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FundPoolsController : ControllerBase
{
    private readonly IFundPoolService _service;
    public FundPoolsController(IFundPoolService service) => _service = service;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] FundPoolListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        return Ok(await _service.GetAllAsync(request));
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetAllActive() => Ok(await _service.GetAllActiveAsync());

    /// <summary>GET api/fundpools/summary — Fund pools with income, expense, balance info</summary>
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary([FromServices] IDbConnectionFactory factory)
    {
        await using var conn = factory.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = new Microsoft.Data.SqlClient.SqlCommand(@"
            SELECT fp.Id, fp.Code, fp.Name, fp.Status, fp.Balance,
                   ISNULL((SELECT SUM(Amount) FROM Incomes 
                           WHERE FundPool=fp.Code OR FundPool=CAST(fp.Id AS NVARCHAR(50)) OR FundPoolName=fp.Name), 0) TotalIncome,
                   ISNULL((SELECT SUM(e.Amount) FROM Expenses e 
                           WHERE e.FundPool=fp.Code OR e.FundPool=CAST(fp.Id AS NVARCHAR(50)) OR e.FundPoolName=fp.Name), 0) TotalExpense
            FROM FundPools fp WHERE fp.Status='Active' ORDER BY fp.Id DESC", conn);
        var list = new List<object>();
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            var balance = r.GetDecimal(r.GetOrdinal("Balance"));
            var income = r.GetDecimal(r.GetOrdinal("TotalIncome"));
            var expense = r.GetDecimal(r.GetOrdinal("TotalExpense"));
            list.Add(new {
                id = r.GetInt32(r.GetOrdinal("Id")),
                code = r.GetString(r.GetOrdinal("Code")),
                name = r.GetString(r.GetOrdinal("Name")),
                balance,
                totalIncome = income,
                totalExpense = expense,
                available = balance
            });
        }
        return Ok(Common.ApiResponse<IEnumerable<object>>.Ok(list, "Fund pool summary retrieved."));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id) { var r = await _service.GetByIdAsync(id); return r.Success ? Ok(r) : NotFound(r); }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateFundPoolRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.CreateAsync(request);
        return r.Success ? CreatedAtAction(nameof(GetById), new { id = r.Data!.Id }, r) : BadRequest(r);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateFundPoolRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.UpdateAsync(id, request);
        return r.Success ? Ok(r) : NotFound(r);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id) { var r = await _service.DeleteAsync(id); return r.Success ? Ok(r) : NotFound(r); }
}
