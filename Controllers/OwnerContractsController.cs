using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using TFMS_software_api.Common;
using TFMS_software_api.DTOs;
using TFMS_software_api.Models;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OwnerContractsController : BaseApiController
{
    private readonly IOwnerContractRepository _repo;
    public OwnerContractsController(IOwnerContractRepository repo, IActivityLogService log)
    { _repo = repo; _activityLog = log; }

    /// <summary>
    /// GET api/ownercontracts
    /// Query params:
    ///   campId       — filter by camp
    ///   ownerId      — filter by owner
    ///   contractType — new | renewal | cancelled | all (default: all)
    ///   fromDate     — contract date from (yyyy-MM-dd)
    ///   toDate       — contract date to (yyyy-MM-dd)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int?    campId,
        [FromQuery] int?    ownerId,
        [FromQuery] string? contractType,
        [FromQuery] string? fromDate,
        [FromQuery] string? toDate)
    {
        var data = await _repo.GetByCampAsync(campId, ownerId);

        // contractType filter
        var filtered = (contractType?.ToLower()) switch
        {
            "new"       => data.Where(c => !c.IsRenewal && c.Status != "Cancelled"),
            "renewal"   => data.Where(c => c.IsRenewal),
            "cancelled" => data.Where(c => c.Status == "Cancelled"),
            _           => data
        };

        // fromDate / toDate filter — ContractDate pe apply karo
        if (!string.IsNullOrEmpty(fromDate) && DateTime.TryParse(fromDate, out var from))
            filtered = filtered.Where(c =>
                !string.IsNullOrEmpty(c.ContractDate) &&
                DateTime.TryParse(c.ContractDate, out var cd) && cd >= from);

        if (!string.IsNullOrEmpty(toDate) && DateTime.TryParse(toDate, out var to))
            filtered = filtered.Where(c =>
                !string.IsNullOrEmpty(c.ContractDate) &&
                DateTime.TryParse(c.ContractDate, out var cd) && cd <= to);

        return Ok(ApiResponse<IEnumerable<OwnerContractResponse>>.Ok(
            filtered.Select(ToResponse), "Owner contracts retrieved."));
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
            No          = i.No,
            Amount      = i.Amount,
            DueDate     = i.DueDate,
            PaymentMode = i.PaymentMode,
            ReferenceNo = i.ReferenceNo,
            Month       = i.Month
        }));

        var monthlyInstallmentsJson = JsonSerializer.Serialize(request.MonthlyInstallments.Select(m => new
        {
            InstallmentNo = m.InstallmentNo,
            Amount        = m.Amount,
            PaidAmount    = m.PaidAmount,
            Balance       = m.Balance,
            DueDate       = m.DueDate,
            PaidDate      = m.PaidDate,
            Status        = m.Status,
            ExpenseId     = m.ExpenseId,
            PaymentMode   = m.PaymentMode,
            PaymentStatus = m.PaymentStatus,
            ReferenceNo   = m.ReferenceNo,
            Month         = m.Month
        }));

        var contract = new OwnerContract
        {
            CampId                   = request.CampId,
            OwnerId                  = request.OwnerId,
            PaymentType              = request.PaymentType,
            TotalAmount              = request.TotalAmount,
            StartDate                = DateTime.Parse(request.StartDate),
            EndDate                  = string.IsNullOrEmpty(request.EndDate) ? null : DateTime.Parse(request.EndDate),
            SecurityDeposit          = request.SecurityDeposit,
            SecurityDepositPaid      = request.SecurityDepositPaid,
            SecurityDepositPaidDate  = string.IsNullOrEmpty(request.SecurityDepositPaidDate) ? null : DateTime.Parse(request.SecurityDepositPaidDate),
            ContractDate             = request.ContractDate,
            MonthlyRent              = request.MonthlyRent,
            NoOfMonths               = request.NoOfMonths,
            AddedBy                  = CurrentUserId,
        };

        var newId = await _repo.CreateAsync(contract, installmentsJson, monthlyInstallmentsJson);
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
        await _repo.DeleteAsync(id, CurrentUserId);
        await Log(ActivityType.Delete, ActivityModule.OwnerContracts, $"Deleted OwnerContract #{id}", id.ToString(), "OwnerContract");
        return Ok(ApiResponse<bool>.Ok(true, "Owner contract deleted successfully."));
    }

    /// <summary>PUT api/ownercontracts/5 — update owner contract details</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateOwnerContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null)
            return NotFound(ApiResponse<object>.Fail($"Owner contract #{id} not found."));

        await _repo.UpdateAsync(id, request, CurrentUserId);

        var updated = await _repo.GetByIdAsync(id);
        await Log(ActivityType.Update, ActivityModule.OwnerContracts,
            $"Updated OwnerContract #{id}", id.ToString(), "OwnerContract");

        return Ok(ApiResponse<OwnerContractResponse>.Ok(ToResponse(updated!), "Owner contract updated successfully."));
    }

    /// <summary>POST api/ownercontracts/{id}/renew — renew an existing owner contract</summary>
    [HttpPost("{id:int}/renew")]
    public async Task<IActionResult> Renew(int id, [FromBody] RenewOwnerContractRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var original = await _repo.GetByIdAsync(id);
        if (original == null)
            return NotFound(ApiResponse<object>.Fail("Original owner contract not found."));
        request.OriginalOwnerContractId = id;
        if (request.TotalAmount <= 0)
            return BadRequest(ApiResponse<object>.Fail("Total amount must be greater than 0."));
        if (request.Installments.Count == 0)
            return BadRequest(ApiResponse<object>.Fail("At least one installment is required."));

        var newId       = await _repo.RenewAsync(request, CurrentUserId);
        var newContract = await _repo.GetByIdAsync(newId);

        await Log(ActivityType.Insert, ActivityModule.OwnerContracts,
            $"Renewed OwnerContract #{id} -> New #{newId}", newId.ToString(), "OwnerContract");

        return CreatedAtAction(nameof(GetById), new { id = newId },
            ApiResponse<object>.Ok(new { newContractId = newId, newContract = ToResponse(newContract!) },
            "Owner contract renewed successfully."));
    }

    /// <summary>GET api/ownercontracts/{id}/renewals — renewal history list</summary>
    [HttpGet("{id:int}/renewals")]
    public async Task<IActionResult> GetRenewals(int id)
    {
        var existing = await _repo.GetByIdAsync(id);
        if (existing == null)
            return NotFound(ApiResponse<object>.Fail("Owner contract not found."));
        var renewals = await _repo.GetRenewalsAsync(id);
        return Ok(ApiResponse<IEnumerable<OwnerContractRenewalResponse>>.Ok(renewals, "Renewals retrieved."));
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
        Id                       = c.Id,
        OcCode                   = c.OcCode,
        CampId                   = c.CampId,
        CampName                 = c.CampName,
        OwnerId                  = c.OwnerId,
        OwnerName                = c.OwnerName,
        OwnerCode                = c.OwnerCode,
        PaymentType              = c.PaymentType,
        TotalAmount              = c.TotalAmount,
        PaidAmount               = c.PaidAmount,
        Balance                  = c.Balance,
        StartDate                = c.StartDate.ToString("yyyy-MM-dd"),
        EndDate                  = c.EndDate?.ToString("yyyy-MM-dd"),
        SecurityDeposit          = c.SecurityDeposit,
        SecurityDepositPaid      = c.SecurityDepositPaid,
        SecurityDepositPaidDate  = c.SecurityDepositPaidDate?.ToString("yyyy-MM-dd"),
        ContractDate             = c.ContractDate,
        MonthlyRent              = c.MonthlyRent,
        NoOfMonths               = c.NoOfMonths,
        Status                   = c.Status,
        IsRenewal                = c.IsRenewal,
        CreatedAt                = c.CreatedAt,
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
            PaymentMode     = i.PaymentMode,
            ReferenceNo     = i.ReferenceNo,
            Remarks         = i.Remarks,
            Month           = i.Month,
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
            ReferenceNo     = t.ReferenceNo,
            PaymentMode     = t.PaymentMode,
            CreatedAt       = t.CreatedAt,
        }).ToList(),
        MonthlyInstallments = c.MonthlyInstallments.Select(m => new OwnerMonthlyContractInstallmentResponse
        {
            Id                           = m.Id,
            MonthlyContractInstallmentId = m.MonthlyContractInstallmentId,
            OwnerContractId              = m.OwnerContractId,
            OwnerId                      = m.OwnerId,
            CampId                       = m.CampId,
            InstallmentNo                = m.InstallmentNo,
            Amount                       = m.Amount,
            PaidAmount                   = m.PaidAmount,
            Balance                      = m.Balance,
            DueDate                      = m.DueDate.ToString("yyyy-MM-dd"),
            PaidDate                     = m.PaidDate?.ToString("yyyy-MM-dd"),
            Status                       = m.Status,
            ExpenseId                    = m.ExpenseId,
            PaymentMode                  = m.PaymentMode,
            PaymentStatus                = m.PaymentStatus,
            ReferenceNo                  = m.ReferenceNo,
            Month                        = m.Month,
            CreatedAt                    = m.CreatedAt,
            UpdatedAt                    = m.UpdatedAt,
        }).ToList(),
    };
}
