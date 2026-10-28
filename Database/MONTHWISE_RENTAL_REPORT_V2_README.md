# MonthwiseRentalReport V2 - With Occupied & Vacant Rooms

## 🎯 Overview
Updated stored procedure `sp_GetMonthwiseRentalReport` now returns **BOTH Occupied and Vacant rooms**.

---

## 📊 What's New?

### **Version 1 (Old)**
- Only showed rooms with active installments (from `ContractRoomInstallments`)
- Missing rooms were invisible

### **Version 2 (New)** ✨
- Shows **Occupied Rooms** - Rooms with active contracts/installments
- Shows **Vacant Rooms** - Rooms without contracts (available for rent)
- New field: `RoomStatus` = "Occupied" or "Vacant"

---

## 🏠 Room Status Logic

### 1. **Occupied Rooms** 
✅ **Source:** `ContractRoomInstallments` table  
✅ **Condition:** Room has active contract for the selected month  
✅ **Data:** Full contract & payment details

**Fields:**
```json
{
  "roomStatus": "Occupied",
  "contractId": "CNT-000123",
  "tenantName": "John Doe",
  "installAmount": 5000,
  "paidAmount": 5000,
  "balance": 0,
  "status": "Paid"
}
```

---

### 2. **Vacant Rooms** 
✅ **Source:** `Rooms` table  
✅ **Condition:** Room does NOT have active contract for the selected month  
✅ **Data:** Only room & camp details

**Fields:**
```json
{
  "roomStatus": "Vacant",
  "contractId": null,
  "tenantName": "N/A",
  "installAmount": 0,
  "paidAmount": 0,
  "balance": 0,
  "status": "Vacant"
}
```

---

## 🔧 Database Changes

### **Step 1: Run SQL Script**
Execute: `sp_GetMonthwiseRentalReport_V2.sql`

```sql
-- This will:
-- 1. DROP existing sp_GetMonthwiseRentalReport
-- 2. CREATE new version with Occupied + Vacant logic
```

### **Step 2: Rebuild Backend**
```bash
cd TFMS-bakend
dotnet build
```

### **Step 3: Restart Application**
```bash
dotnet run
```

---

## 📝 SQL Logic Explanation

### **CTE 1: OccupiedRooms**
```sql
SELECT rooms FROM ContractRoomInstallments
WHERE IsDeleted = 0 AND Contract.Status = 'Active'
```

### **CTE 2: VacantRooms**
```sql
SELECT rooms FROM Rooms
WHERE NOT EXISTS (
  SELECT 1 FROM ContractRoomInstallments 
  WHERE RoomId = Rooms.Id 
  AND Month = @Month
  AND Contract.Status = 'Active'
)
```

### **Final Result**
```sql
SELECT * FROM OccupiedRooms
UNION ALL
SELECT * FROM VacantRooms
ORDER BY RoomNo
```

---

## 🎨 API Response Example

### Request:
```http
GET /api/MonthwiseRentalReport?month=Dec26&campId=1
```

### Response:
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalRecords": 150,
      "occupiedRooms": 120,
      "vacantRooms": 30,
      "totalInstallAmount": 600000,
      "totalPaidAmount": 550000
    },
    "reportData": [
      {
        "roomNo": "101",
        "roomStatus": "Occupied",
        "tenantName": "John Doe",
        "installAmount": 5000,
        "status": "Paid"
      },
      {
        "roomNo": "102",
        "roomStatus": "Vacant",
        "tenantName": "N/A",
        "installAmount": 0,
        "status": "Vacant"
      }
    ]
  }
}
```

---

## 🚀 Use Cases

### 1. **Occupancy Report**
- Filter by Camp → See total occupied vs vacant rooms
- Identify available rooms for new tenants

### 2. **Camp Utilization**
- See which rooms are generating revenue
- Find underutilized camps

### 3. **Room Assignment**
- Show vacant rooms when assigning new contracts
- Real-time availability

### 4. **Revenue Analysis**
- Compare occupied rooms with revenue
- Identify gaps in collections

---

## ⚠️ Important Notes

1. **RoomStatus Filter:**
   - To see only Occupied: Don't use status filter, data comes from installments
   - To see only Vacant: Vacant rooms have `Status = 'Vacant'`

2. **Month Filter:**
   - Vacant rooms only shown if `@Month` is provided
   - Without month, only occupied rooms shown

3. **Performance:**
   - Vacant rooms query adds minimal overhead
   - Uses efficient NOT EXISTS check

4. **Data Consistency:**
   - Vacant rooms show 0 amounts
   - All vacant fields show "N/A" or NULL

---

## 🔍 Frontend Changes Required

Update your frontend table to handle:

```javascript
// Add RoomStatus column
{
  header: "Status",
  accessor: "roomStatus",
  cell: (row) => (
    <Badge color={row.roomStatus === 'Occupied' ? 'green' : 'gray'}>
      {row.roomStatus}
    </Badge>
  )
}

// Handle N/A values
{
  header: "Tenant",
  accessor: "tenantName",
  cell: (row) => row.tenantName === 'N/A' ? 
    <Text color="gray">No Tenant</Text> : 
    row.tenantName
}

// Show 0 amounts for vacant
{
  header: "Amount",
  accessor: "installAmount",
  cell: (row) => row.roomStatus === 'Vacant' ? 
    <Text color="gray">-</Text> : 
    formatCurrency(row.installAmount)
}
```

---

## ✅ Testing Checklist

- [ ] Occupied rooms show correct contract data
- [ ] Vacant rooms show "N/A" for tenant
- [ ] Vacant rooms show 0 for all amounts
- [ ] RoomStatus field present in API response
- [ ] Month filter works correctly
- [ ] Camp filter shows all camp rooms (occupied + vacant)
- [ ] Pagination works with combined data
- [ ] Total count includes both occupied + vacant
- [ ] Sorting works correctly

---

## 📦 Deployment Steps

### Production Database:
```sql
-- Connect to production DB
USE TFMS_Production;
GO

-- Run the V2 script
-- (Paste content of sp_GetMonthwiseRentalReport_V2.sql)
```

### Production Backend:
1. Copy updated `MonthwiseRentalReportController.cs`
2. Rebuild: `dotnet publish -c Release`
3. Deploy ZIP file
4. Restart IIS/Service

---

## 🐛 Troubleshooting

### Issue: "Invalid column name 'RoomStatus'"
**Fix:** Procedure not updated. Run V2 SQL script.

### Issue: Vacant rooms not showing
**Check:** 
1. Month parameter provided?
2. Camp has rooms in Rooms table?
3. Rooms.IsDeleted = 0?

### Issue: Duplicate rooms
**Check:** Same room might have multiple installments (by design)

---

## 📚 Related Files

- `sp_GetMonthwiseRentalReport_V2.sql` - Updated procedure
- `MonthwiseRentalReportController.cs` - Controller updates
- `MONTHWISE_RENTAL_REPORT_V2_README.md` - This file

---

**Version:** 2.0  
**Date:** October 28, 2026  
**Author:** TFMS Development Team
