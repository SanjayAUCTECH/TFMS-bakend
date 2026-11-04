# Fund Pool Report - Include Balance Feature Implementation

## Overview
This feature adds an `IncludeBalance` parameter to the Fund Pool Report that controls whether to show cumulative balances or only current month transactions.

## Implementation Steps

### 1. Database Update
Run the stored procedure update script:
```sql
-- File: sp_GetFundPoolReport_UPDATE.sql
-- This will ALTER the existing sp_GetFundPoolReport procedure
```

**Execute the script in your database:**
- Open SQL Server Management Studio (SSMS)
- Connect to your TFMS database
- Open the file: `sp_GetFundPoolReport_UPDATE.sql`
- Execute the script (F5)

### 2. Backend Changes (Already Done ✅)

**Files Modified:**
- `DTOs/FundPoolReportDtos.cs` - Added `IncludeBalance` property
- `Controllers/FundPoolReportController.cs` - Added parameter to stored procedure call

### 3. Frontend Changes (Already Done ✅)

**File Modified:**
- `TFMS-Software_CRM/src/views/reports/FundPoolReport/FundPoolReport.jsx`
- Added checkbox UI
- Added state management
- Integrated with API call

## How It Works

### API Request
```
GET /api/FundPoolReport?Month=11&Year=2026&PageSize=1000&IncludeBalance=false
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `IncludeBalance` | boolean | `true` | Controls balance calculation |

### Behavior

#### When `IncludeBalance = true` (Checked - Default)
- Shows **cumulative balance** up to the selected month
- Includes all transactions from the beginning to the end of selected month
- **Example**: Select November 2026 → Shows all transactions from start to Nov 30, 2026

#### When `IncludeBalance = false` (Unchecked)
- Shows **only current month** transactions
- Only includes transactions within the selected month
- **Example**: Select November 2026 → Shows only Nov 1-30, 2026 transactions

### SQL Logic

The stored procedure uses conditional logic:

```sql
CASE 
    WHEN @IncludeBalance = 1 THEN 
        -- Include all up to end date
        CASE WHEN TransactionDate <= @EndDate THEN Amount ELSE 0 END
    ELSE 
        -- Only current month
        CASE WHEN TransactionDate BETWEEN @StartDate AND @EndDate THEN Amount ELSE 0 END
END
```

This applies to:
- ✅ FundPoolIncome
- ✅ FundPoolExpense  
- ✅ FundPoolPayment
- ✅ BufferFundTransfer
- ✅ Transaction details view

## Testing

### Test Case 1: Include Balance = True
1. Select Month: November 2026
2. Check "Include Balances" checkbox
3. Expected: Shows cumulative totals from start to Nov 30, 2026

### Test Case 2: Include Balance = False
1. Select Month: November 2026
2. Uncheck "Include Balances" checkbox
3. Expected: Shows only November 2026 transactions

### Verification Points
- Check `CurrentBalance` column values
- Check `TotalIncome`, `TotalExpense`, `TotalPaymentsReceived`
- Verify summary cards reflect correct totals
- Check Buffer Fund Pool calculations

## Database Tables Affected

The procedure reads from:
- `FundPools`
- `FundPoolIncome`
- `FundPoolExpense`
- `FundPoolPayment`
- `BufferFundTransfer`
- `AccountsHead`
- `Camps`

## Rollback

If you need to revert changes:

### Database
```sql
-- Restore the previous version of sp_GetFundPoolReport
-- Or remove the @IncludeBalance parameter and related logic
```

### Backend
```csharp
// Remove IncludeBalance property from FundPoolReportRequest
// Remove parameter from controller
```

### Frontend
```javascript
// Remove the checkbox and related state
// Remove IncludeBalance from API call
```

## Support

If you encounter any issues:
1. Check SQL Server logs for procedure errors
2. Verify parameter names match between frontend/backend
3. Check network tab in browser for API request/response
4. Verify stored procedure was updated successfully

## Date: November 2026
## Version: 1.0
