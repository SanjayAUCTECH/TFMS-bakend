using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FundPoolMonthlyBalanceController : BaseApiController
{
    private readonly IFundPoolMonthlyBalanceService _service;
    public FundPoolMonthlyBalanceController(
        IFundPoolMonthlyBalanceService service, 
        IActivityLogService log)
    { 
        _service = service; 
        _activityLog = log; 
    }

    /// <summary>POST api/fundpoolmonthlybalance/save - Save monthly balance</summary>
    [HttpPost("save")]
    public async Task<IActionResult> SaveMonthlyBalance([FromBody] SaveFundPoolMonthlyBalanceRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        
        var result = await _service.SaveMonthlyBalanceAsync(request, CurrentUserId);
        
        if (result.Success)
            await Log(
                ActivityType.Insert, 
                ActivityModule.FundPools, 
                $"Saved Fund Pool monthly balance for {request.ReportMonth}/{request.ReportYear}", 
                $"{request.ReportMonth}-{request.ReportYear}", 
                "FundPoolMonthlyBalance");
        
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>GET api/fundpoolmonthlybalance?reportMonth=10&reportYear=2026</summary>
    [HttpGet]
    public async Task<IActionResult> GetMonthlyBalance([FromQuery] GetFundPoolMonthlyBalanceRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        
        var result = await _service.GetMonthlyBalanceAsync(request);
        return result.Success ? Ok(result) : NotFound(result);
    }

    /// <summary>GET api/fundpoolmonthlybalance/all - Get all saved monthly balances</summary>
    [HttpGet("all")]
    public async Task<IActionResult> GetAllMonthlyBalances([FromQuery] FundPoolMonthlyBalanceListRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        
        var result = await _service.GetAllMonthlyBalancesAsync(request);
        return Ok(result);
    }

    /// <summary>DELETE api/fundpoolmonthlybalance?reportMonth=10&reportYear=2026</summary>
    [HttpDelete]
    public async Task<IActionResult> DeleteMonthlyBalance([FromQuery] DeleteFundPoolMonthlyBalanceRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        
        var result = await _service.DeleteMonthlyBalanceAsync(request, CurrentUserId);
        
        if (result.Success)
            await Log(
                ActivityType.Delete, 
                ActivityModule.FundPools, 
                $"Deleted Fund Pool monthly balance for {request.ReportMonth}/{request.ReportYear}", 
                $"{request.ReportMonth}-{request.ReportYear}", 
                "FundPoolMonthlyBalance");
        
        return result.Success ? Ok(result) : NotFound(result);
    }
}
