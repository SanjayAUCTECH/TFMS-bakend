using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TxnRecordsController : ControllerBase
{
    private readonly ITxnRecordRepository _repo;
    public TxnRecordsController(ITxnRecordRepository repo) => _repo = repo;

    /// <summary>GET api/txnrecords?contractId=CNT001&tenantId=1&campId=2&txnType=DR</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] TxnRecordListRequest request)
    {
        var (data, total) = await _repo.GetAllAsync(request);
        var response = data.Select(t => new TxnRecordResponse
        {
            Id=t.Id, TxnId=t.TxnId, TxnType=t.TxnType,
            ContractId=t.ContractId, ContractCode=t.ContractCode,
            TenantId=t.TenantId, TenantName=t.TenantName,
            CampId=t.CampId, CampName=t.CampName,
            TotalAmount=t.TotalAmount, Amount=t.Amount,
            TxnDate=t.TxnDate, FromDate=t.FromDate, ToDate=t.ToDate,
            PaymentMode=t.PaymentMode, PaymentModeId=t.PaymentModeId,
            ChequeNumber=t.ChequeNumber,
            FundPoolId=t.FundPoolId, FundPoolName=t.FundPoolName,
            Description=t.Description, ReceivedBy=t.ReceivedBy,
            ReceivedContact=t.ReceivedContact, IssuedBy=t.IssuedBy,
            InstallmentNo=t.InstallmentNo,
            AppliedInstallments=t.AppliedInstallments,
            Unallocated=t.Unallocated,
            CreatedAt=t.CreatedAt, UpdatedAt=t.UpdatedAt,
        });
        return Ok(ApiResponse<IEnumerable<TxnRecordResponse>>.Ok(response, "Txn records retrieved.",
            PaginationHelper.Build(total, request.ResolvedPage, request.ResolvedPageSize)));
    }

    /// <summary>POST api/txnrecords</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateTxnRecordRequest req)
    {
        var txn = new TxnRecord
        {
            TxnType=req.TxnType, ContractId=req.ContractId, ContractCode=req.ContractCode,
            TenantId=req.TenantId, CampId=req.CampId,
            TotalAmount=req.TotalAmount, Amount=req.Amount,
            TxnDate=req.TxnDate, FromDate=req.FromDate, ToDate=req.ToDate,
            PaymentMode=req.PaymentMode, PaymentModeId=req.PaymentModeId,
            FundPoolId=req.FundPoolId, FundPoolName=req.FundPoolName,
            Description=req.Description, ReceivedBy=req.ReceivedBy,
            InstallmentNo=req.InstallmentNo,
        };
        var id = await _repo.CreateAsync(txn);
        return Ok(ApiResponse<object>.Ok(new { id }, "Txn record created."));
    }

    /// <summary>PUT api/txnrecords/{id}</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateTxnRecordRequest req)
    {
        var ok = await _repo.UpdateAsync(id, req);
        return ok ? Ok(ApiResponse<object?>.Ok(null, "Txn record updated."))
                  : NotFound(ApiResponse<object?>.Fail("Txn record not found."));
    }

    /// <summary>DELETE api/txnrecords/{id}</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repo.DeleteAsync(id);
        return Ok(ApiResponse<object?>.Ok(null, "Txn record deleted."));
    }
}
