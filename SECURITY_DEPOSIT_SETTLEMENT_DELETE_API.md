# Security Deposit Settlement - DELETE API Documentation

## Overview
This document describes the DELETE API endpoint that reverts/deletes a security deposit settlement operation. When a settlement is deleted, all related data insertions and updates are reverted across multiple tables.

---

## API Endpoint

### **DELETE** `/api/SecurityDeposit/settle/{contractId}`

Deletes/reverts a security deposit settlement for a specific contract.

---

## Request

### URL Parameters
- `contractId` (string, required) - The contract ID for which settlement needs to be reverted

### Headers
```
Authorization: Bearer {token}
Content-Type: application/json
```

### Example Request
```http
DELETE http://192.168.1.34:9001/api/SecurityDeposit/settle/CNT-000123
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Response

### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Settlement reverted successfully. Deposit status restored to Received.",
  "data": {
    "contractId": "CNT-000123",
    "refundAmountReverted": 5000.00,
    "forfeitAmountReverted": 500.00,
    "fundPoolRestored": true,
    "newStatus": "Received"
  },
  "pagination": null,
  "cards": null
}
```

### Error Response (400 Bad Request)
```json
{
  "success": false,
  "message": "ContractId required.",
  "data": null,
  "pagination": null,
  "cards": null
}
```

### Error Response (404 Not Found)
```json
{
  "success": false,
  "message": "No settlement records found for this contract.",
  "data": null,
  "pagination": null,
  "cards": null
}
```

---

## What This API Does

When you call this DELETE endpoint, it performs the following operations:

### 1. **Retrieves Settlement Information**
   - Gets refund amount, forfeit amount, and fund pool ID from existing settlement records
   - Queries `TxnRecords` table for SD-REF, SD-ADJ, SD-FORFEIT transactions

### 2. **Reverts FundPool Balance**
   - **Adds back** refund amount (was subtracted during settlement)
   - **Subtracts** forfeit amount (was added during settlement)
   - Updates `FundPools` table

### 3. **Soft Deletes TxnRecords**
   - Sets `IsDeleted = 1` for all SD-REF, SD-ADJ, SD-FORFEIT records
   - Updates `DeletedBy` and `DeletedAt` fields
   - Table: `TxnRecords`

### 4. **Soft Deletes ContractRoomsTrns**
   - Sets `IsDeleted = 1` for all SD-REF, SD-ADJ, SD-FORFEIT records
   - Updates `DeletedBy` and `DeletedAt` fields
   - Table: `ContractRoomsTrns`

### 5. **Soft Deletes AccountMasters**
   - Removes SD Refund and SD Forfeit entries
   - Matches by `Purpose` field containing "SD Refund" or "SD Forfeit"
   - Table: `AccountMasters`

### 6. **Soft Deletes Expenses**
   - Removes SD refund expense entries
   - Matches by `Head = 'SD'` or `Purpose LIKE '%SD Refund%'`
   - Table: `Expenses`

### 7. **Restores Contract Deposit Status**
   - Recalculates `DepositPaid` from remaining (non-deleted) SD-CR transactions
   - Recalculates `DepositBalance` = DepositAmount - DepositPaid
   - Updates `DepositStatus`:
     - `Pending` if DepositPaid = 0
     - `Received` if DepositPaid >= DepositAmount
     - `Partial` if DepositPaid < DepositAmount
   - Table: `Contracts`

### 8. **Logs Activity**
   - Creates activity log entry with details of reverted settlement
   - Module: `SecurityDeposit`
   - Type: `Delete`

---

## Tables Affected

| Table | Operation | Description |
|-------|-----------|-------------|
| `FundPools` | UPDATE | Balance restored (refund added back, forfeit removed) |
| `TxnRecords` | SOFT DELETE | SD-REF, SD-ADJ, SD-FORFEIT records marked as deleted |
| `ContractRoomsTrns` | SOFT DELETE | Settlement transaction records marked as deleted |
| `AccountMasters` | SOFT DELETE | Refund/Forfeit accounting entries marked as deleted |
| `Expenses` | SOFT DELETE | SD refund expense entries marked as deleted |
| `Contracts` | UPDATE | DepositPaid, DepositBalance, DepositStatus recalculated |
| `ActivityLogs` | INSERT | Activity log entry created |

---

## Related Endpoints

### POST `/api/SecurityDeposit/settle`
Creates a security deposit settlement (adjust/refund/forfeit). This DELETE endpoint reverts that operation.

**Settlement creates:**
- TxnRecords (SD-REF, SD-ADJ, SD-FORFEIT)
- ContractRoomsTrns (settlement transactions)
- AccountMasters (refund/forfeit entries)
- Expenses (refund expenses)
- Updates Contracts (deposit status)
- Updates FundPools (balance)

**DELETE reverts all of the above.**

---

## Business Logic

### Deposit Status Calculation After Delete
After deletion, the system recalculates deposit status based on **remaining non-deleted SD-CR transactions**:

```sql
-- If no payments received
DepositPaid = 0 → Status = 'Pending'

-- If fully paid
DepositPaid >= DepositAmount → Status = 'Received'

-- If partially paid
DepositPaid < DepositAmount → Status = 'Partial'
```

### Fund Pool Balance Reversion
```
New Balance = Old Balance + RefundAmount - ForfeitAmount

Example:
- Refund was 5000 (deducted during settle) → Add back 5000
- Forfeit was 500 (added during settle) → Subtract 500
- Net change: +4500 to fund pool
```

---

## Usage Example (PowerShell)

```powershell
# Test the DELETE endpoint
$token = "your-jwt-token-here"
$contractId = "CNT-000123"

Invoke-RestMethod -Uri "http://192.168.1.34:9001/api/SecurityDeposit/settle/$contractId" `
    -Method Delete `
    -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } | ConvertTo-Json -Depth 5
```

---

## Notes

1. **Soft Delete**: All deletions are soft deletes (IsDeleted = 1), data is not physically removed from database
2. **Reversible**: If needed, settlement can be re-applied using POST `/api/SecurityDeposit/settle`
3. **Fund Pool Safety**: Fund pool balance is carefully restored to maintain accounting accuracy
4. **Activity Tracking**: All delete operations are logged in ActivityLogs table
5. **Authorization**: Requires valid JWT token with appropriate permissions

---

## Testing Checklist

- [ ] Delete settlement for contract with refund only
- [ ] Delete settlement for contract with forfeit only
- [ ] Delete settlement for contract with both refund and forfeit
- [ ] Verify fund pool balance is correctly restored
- [ ] Verify contract deposit status is recalculated correctly
- [ ] Verify all related records are soft-deleted
- [ ] Check activity log entry is created
- [ ] Test with invalid contract ID
- [ ] Test without authorization token

---

## Developer: Sanjay Kumar
## Date: October 27, 2026
## Backend URL: http://192.168.1.34:9001
