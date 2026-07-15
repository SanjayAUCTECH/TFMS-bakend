using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OwnerContractsController : ControllerBase
{
    private readonly IOwnerContractRepository _repo;
    public OwnerContractsController(IOwnerContractRepository repo) => _repo = repo;

    /// <summary>GET api/ownercontracts?campId=1  — get all contracts, optionally filtered by camp</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int? campId)
    {
        var data = await _repo.GetByCampAsync(campId);
        return Ok(ApiResponse<IEnumerable<OwnerContractResponse>>.Ok(data.Select(ToResponse), "Owner contracts retrieved."));
    }

    /// <summary>GET api/ownercontracts/5</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var c = await _repo.GetByIdAsync(id);
        return c == null ? NotFound(ApiResponse<OwnerContractResponse>.Fail("Not found.")) : Ok(ApiResponse<OwnerContractResponse>.Ok(ToResponse(c)));
    }

    /// <summary>POST api/ownercontracts — create contract with installments + DR transaction</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateOwnerContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        if (request.TotalAmount <= 0)          return BadRequest(ApiResponse<object>.Fail("Total amount must be greater than 0."));
        if (request.Installments.Count == 0)   return BadRequest(ApiResponse<object>.Fail("At least one installment is required."));

        var installmentsJson = JsonSerializer.Serialize(request.Installments.Select(i => new
        {
            No      = i.No,
            Amount  = i.Amount,
            DueDate = i.DueDate
        }));

        var contract = new OwnerContract
        {
            CampId      = request.CampId,
            OwnerId     = request.OwnerId,
            PaymentType = request.PaymentType,
            TotalAmount = request.TotalAmount,
            StartDate   = DateTime.Parse(request.StartDate),
        };

        var newId = await _repo.CreateAsync(contract, installmentsJson);
        var created = await _repo.GetByIdAsync(newId);
        return CreatedAtAction(nameof(GetById), new { id = newId },
            ApiResponse<OwnerContractResponse>.Ok(ToResponse(created!), "Owner contract created successfully."));
    }

    /// <summary>DELETE api/ownercontracts/5 — deletes contract, installments and transactions</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null) return NotFound(ApiResponse<bool>.Fail("Contract not found."));
        await _repo.DeleteAsync(id);
        return Ok(ApiResponse<bool>.Ok(true, "Owner contract deleted successfully."));
    }

    /// <summary>GET api/ownercontracts/{id}/ledger — ledger entries (DR/CR) for an owner contract</summary>
    [HttpGet("{id:int}/ledger")]
    public async Task<IActionResult> GetLedger(int id)
    {
        var contract = await _repo.GetByIdAsync(id);
        if (contract == null)
            return NotFound(ApiResponse<IEnumerable<object>>.Fail("Owner contract not found."));

        // Build ledger: DR row (total payable) + CR rows (each payment made)
        var ledger = new List<object>();

        // Opening DR — contract total
        ledger.Add(new {
            date          = contract.StartDate.ToString("yyyy-MM-dd"),
            description   = $"Owner Contract {contract.OcCode} — Total Payable",
            installmentNo = (string?)null,
            dr            = contract.TotalAmount,
            cr            = 0m,
            balance       = contract.TotalAmount,
        });

        decimal runningBalance = contract.TotalAmount;

        // CR rows from transactions
        foreach (var txn in contract.Transactions.OrderBy(t => t.Date).ThenBy(t => t.Id))
        {
            if (txn.Type == "CR")
            {
                runningBalance -= txn.Amount;
                ledger.Add(new {
                    date          = txn.Date.ToString("yyyy-MM-dd"),
                    description   = txn.Description,
                    installmentNo = txn.InstallmentNos,
                    dr            = 0m,
                    cr            = txn.Amount,
                    balance       = runningBalance,
                });
            }
        }

        return Ok(ApiResponse<IEnumerable<object>>.Ok(ledger, "Ledger retrieved."));
    }

    private static OwnerContractResponse ToResponse(OwnerContract c) => new()
    {
        Id          = c.Id,
        OcCode      = c.OcCode,
        CampId      = c.CampId,
        CampName    = c.CampName,
        OwnerId     = c.OwnerId,
        OwnerName   = c.OwnerName,
        OwnerCode   = c.OwnerCode,
        PaymentType = c.PaymentType,
        TotalAmount = c.TotalAmount,
        PaidAmount  = c.PaidAmount,
        Balance     = c.Balance,
        StartDate   = c.StartDate.ToString("yyyy-MM-dd"),
        Status      = c.Status,
        CreatedAt   = c.CreatedAt,
        Installments = c.Installments.Select(i => new OwnerInstallmentResponse
        {
            Id              = i.Id,
            OwnerContractId = i.OwnerContractId,
            No              = i.No,
            Amount          = i.Amount,
            PaidAmount      = i.PaidAmount,
            DueDate         = i.DueDate.ToString("yyyy-MM-dd"),
            PaidDate        = i.PaidDate?.ToString("yyyy-MM-dd"),
            Status          = i.Status,
            ExpenseId       = i.ExpenseId,
        }).ToList(),
        Transactions = c.Transactions.Select(t => new OwnerTransactionResponse
        {
            Id              = t.Id,
            TxnCode         = t.TxnCode,
            OwnerContractId = t.OwnerContractId,
            OcCode          = t.OcCode,
            CampId          = t.CampId,
            CampName        = t.CampName,
            OwnerId         = t.OwnerId,
            OwnerName       = t.OwnerName,
            Type            = t.Type,
            Amount          = t.Amount,
            Date            = t.Date.ToString("yyyy-MM-dd"),
            Description     = t.Description,
            InstallmentNos  = t.InstallmentNos,
            ExpenseId       = t.ExpenseId,
            CreatedAt       = t.CreatedAt,
        }).ToList(),
    };
}
