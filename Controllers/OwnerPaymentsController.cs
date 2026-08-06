using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TFMS_software_api.DTOs;
using TFMS_software_api.Services;

namespace TFMS_software_api.Controllers;

/// <summary>
/// Owner Payments — Company pays Owner (Expense).
/// All data managed via OwnerContracts + related tables only.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OwnerPaymentsController : BaseApiController
{
    private readonly IOwnerPaymentService _service;

    public OwnerPaymentsController(IOwnerPaymentService service, IActivityLogService log)
    {
        _service = service;
        _activityLog = log;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  LIST — GET api/ownerpayments/contracts
    //  Paginated owner contract list for payment selection dropdown
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("contracts")]
    public async Task<IActionResult> GetAllContracts([FromQuery] OwnerPaymentListRequest request)
    {
        var r = await _service.GetAllContractsAsync(request);
        return Ok(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SUMMARY — GET api/ownerpayments/summary/{ownerContractId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("summary/{ownerContractId:int}")]
    public async Task<IActionResult> GetSummary(int ownerContractId)
    {
        var r = await _service.GetSummaryAsync(ownerContractId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  HISTORY — GET api/ownerpayments/history/{ownerContractId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("history/{ownerContractId:int}")]
    public async Task<IActionResult> GetHistory(int ownerContractId)
    {
        var r = await _service.GetHistoryAsync(ownerContractId);
        return Ok(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GET BY ID — GET api/ownerpayments/payment/{txnId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("payment/{txnId:int}")]
    public async Task<IActionResult> GetPaymentById(int txnId)
    {
        var r = await _service.GetPaymentByIdAsync(txnId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  INSTALLMENTS — GET api/ownerpayments/installments/{ownerContractId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("installments/{ownerContractId:int}")]
    public async Task<IActionResult> GetInstallments(int ownerContractId)
    {
        var r = await _service.GetInstallmentsAsync(ownerContractId);
        return Ok(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  INSTALLMENT MONTHS — GET api/ownerpayments/installments/{ownerContractId}/months
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("installments/{ownerContractId:int}/months")]
    public async Task<IActionResult> GetInstallmentMonths(int ownerContractId)
    {
        var r = await _service.GetInstallmentMonthsAsync(ownerContractId);
        return Ok(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  LEDGER — GET api/ownerpayments/ledger/{ownerContractId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("ledger/{ownerContractId:int}")]
    public async Task<IActionResult> GetLedger(int ownerContractId)
    {
        var r = await _service.GetLedgerAsync(ownerContractId);
        return Ok(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  PAY OWNER — POST api/ownerpayments/pay
    // ══════════════════════════════════════════════════════════════════════════
    [HttpPost("pay")]
    public async Task<IActionResult> PayOwner([FromBody] PayOwnerRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        request.AddedBy = CurrentUserId;
        var r = await _service.PayOwnerAsync(request);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.OwnerContracts,
                $"Paid {request.Amount} to owner for OC#{request.OwnerContractId} Inst:{request.InstallmentNos}",
                request.OwnerContractId.ToString(), "OwnerPayment");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  UPDATE PAYMENT — PUT api/ownerpayments/pay/{txnId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpPut("pay/{txnId:int}")]
    public async Task<IActionResult> UpdatePayment(int txnId, [FromBody] UpdateOwnerPaymentRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        request.UpdatedBy = CurrentUserId;
        var r = await _service.UpdatePaymentAsync(txnId, request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.OwnerContracts,
                $"Updated owner payment TxnId#{txnId} Amount:{request.Amount}",
                txnId.ToString(), "OwnerPayment");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  DELETE PAYMENT — DELETE api/ownerpayments/pay/{txnId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpDelete("pay/{txnId:int}")]
    public async Task<IActionResult> DeletePayment(int txnId)
    {
        var r = await _service.DeletePaymentAsync(txnId, CurrentUserId);
        if (r.Success)
            await Log(ActivityType.Delete, ActivityModule.OwnerContracts,
                $"Reversed owner payment TxnId#{txnId}",
                txnId.ToString(), "OwnerPayment");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  VOUCHER — GET api/ownerpayments/voucher/{txnId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("voucher/{txnId:int}")]
    public async Task<IActionResult> GetVoucher(int txnId)
    {
        var r = await _service.GetVoucherAsync(txnId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  EDIT DATA — GET api/ownerpayments/edit-data/{txnId}
    //  Returns payment info + monthlyPayments array for edit pre-fill
    // ══════════════════════════════════════════════════════════════════════════
    /// <summary>Get payment + monthly breakdown for edit form pre-fill</summary>
    [HttpGet("edit-data/{txnId:int}")]
    public async Task<IActionResult> GetPaymentEditData(int txnId)
    {
        var r = await _service.GetPaymentEditDataAsync(txnId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SD STATUS — GET api/ownerpayments/security-deposit/status/{ownerContractId}
    // ══════════════════════════════════════════════════════════════════════════
    [HttpGet("security-deposit/status/{ownerContractId:int}")]
    public async Task<IActionResult> GetSecurityDepositStatus(int ownerContractId)
    {
        var r = await _service.GetSecurityDepositStatusAsync(ownerContractId);
        return r.Success ? Ok(r) : NotFound(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SD PAY — POST api/ownerpayments/security-deposit/pay
    // ══════════════════════════════════════════════════════════════════════════
    [HttpPost("security-deposit/pay")]
    public async Task<IActionResult> PaySecurityDeposit([FromBody] PayOwnerSecurityDepositRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.PaySecurityDepositAsync(request);
        if (r.Success)
            await Log(ActivityType.Insert, ActivityModule.OwnerContracts,
                $"Paid SD {request.Amount} to owner OC#{request.OwnerContractId}",
                request.OwnerContractId.ToString(), "OwnerPayment-SD");
        return r.Success ? Ok(r) : BadRequest(r);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  SD SETTLE — POST api/ownerpayments/security-deposit/settle
    // ══════════════════════════════════════════════════════════════════════════
    [HttpPost("security-deposit/settle")]
    public async Task<IActionResult> SettleSecurityDeposit([FromBody] SettleOwnerSecurityDepositRequest request)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var r = await _service.SettleSecurityDepositAsync(request);
        if (r.Success)
            await Log(ActivityType.Update, ActivityModule.OwnerContracts,
                $"Settled SD OC#{request.OwnerContractId} Recover:{request.RecoverAmount} Adjust:{request.AdjustAmount} Forfeit:{request.ForfeitAmount}",
                request.OwnerContractId.ToString(), "OwnerPayment-SD");
        return r.Success ? Ok(r) : BadRequest(r);
    }
}
