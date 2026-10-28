# MonthwiseRentalReport - Production Installation Guide

## 📋 Overview

This stored procedure provides month-wise rental report showing both **Booked** and **Vacant** rooms with complete contract, tenant, and security deposit details.

## 🚀 Installation Steps

### Step 1: Open the SQL File
Open file: `EXECUTE_ON_PRODUCTION_DB.sql`

### Step 2: Update Database Name
Find line 8 and update with your database name:
```sql
USE YourProductionDatabaseName;  -- <-- CHANGE THIS
```

Example:
```sql
USE TFMS_ProductionDB;
```

### Step 3: Execute the Script
- Open **SQL Server Management Studio (SSMS)** or **Azure Data Studio**
- Connect to your **Production database server**
- Open `EXECUTE_ON_PRODUCTION_DB.sql`
- Execute the entire script (F5 or Ctrl+E)

### Step 4: Verify Installation
You should see output like:
```
================================================
SUCCESS: Stored Procedure Created!
================================================
Procedure Name: sp_GetMonthwiseRentalReport
Version: 3.0
...
Installation Complete!
================================================
```

## 📊 Data Flow

### Base Table: **Rooms**
All rooms from the Rooms table are included in the report.

### Room Status Logic:
```
IF room exists in ContractRoomInstallments for @Month
   AND Contract.Status NOT IN ('Cancelled', 'Expired')
THEN
   RoomStatus = 'Booked'
ELSE
   RoomStatus = 'Vacant'
```

### Data Sources:

| Field | Source Table | Join Condition |
|-------|--------------|----------------|
| **Room Details** | `Rooms` | Base table |
| **Camp Details** | `Camps` | `Camps.Id = Rooms.CampId` |
| **Floor Details** | `Floors` | `Floors.Id = Rooms.FloorId` |
| **Booking Check** | `ContractRoomInstallments` | `cri.RoomId = Rooms.Id AND cri.Month = @Month` |
| **Contract Details** | `Contracts` | `Contracts.ContractId = cri.ContractId` (Active only) |
| **Tenant Details** | `Tenants` | `Tenants.Id = Contracts.TenantId` |
| **SD Amount** | `TxnRecords` | `TxnRecords.ContractId = Contracts.ContractId AND TxnType='SD-CR'` |

## 🔧 API Usage

### Endpoint
```
GET /api/MonthwiseRentalReport
```

### Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `month` | string | Filter by month | `Jul26`, `Aug26` |
| `campId` | int | Filter by camp | `1` |
| `tenantId` | int | Filter by tenant | `10` |
| `roomId` | int | Filter by room | `272` |
| `status` | string | Payment status | `Paid`, `Pending` |
| `contractStatus` | string | Contract status | `Active` |
| `pageNumber` | int | Page number (default: 1) | `1` |
| `pageSize` | int | Records per page (default: 50) | `50` |

### Example Requests

**1. All rooms for Camp 1 in July 2026:**
```
GET /api/MonthwiseRentalReport?campId=1&month=Jul26
```

**2. Vacant rooms only (no month filter):**
```
GET /api/MonthwiseRentalReport?campId=1&status=Vacant
```

**3. Booked rooms with pagination:**
```
GET /api/MonthwiseRentalReport?campId=1&month=Jul26&pageNumber=1&pageSize=20
```

## 📄 Response Fields

### Booked Rooms:
```json
{
  "id": 13544,
  "contractId": "CNT-000008",
  "roomStatus": "Booked",
  "contractType": "Contractual Based",
  "contractStatus": "Active",
  "installmentType": "Yearly",
  "tenantName": "BOK CONTRACTING",
  "tenantContact": "2222222222",
  "campName": "HELIX",
  "roomNo": "11",
  "installAmount": 4000.00,
  "status": "Paid",
  "sdAmount": 1200.00,
  "sdDate": "2026-07-01T00:00:00"
}
```

### Vacant Rooms:
```json
{
  "id": null,
  "contractId": null,
  "roomStatus": "Vacant",
  "contractType": null,
  "tenantName": "N/A",
  "campName": "HELIX",
  "roomNo": "18",
  "installAmount": 0.00,
  "status": "Vacant",
  "sdAmount": 0.00,
  "sdDate": null
}
```

## ⚠️ Important Notes

1. **Cancelled/Expired Contracts**: Rooms with Cancelled or Expired contracts will show as **Vacant** in the report.

2. **SD Amount**: Security Deposit amount comes from `TxnRecords` table where `TxnType = 'SD-CR'`.

3. **Month Filter**: When month parameter is provided, only rooms with bookings in that specific month will show as "Booked". Other rooms will show as "Vacant".

4. **Pagination**: Always use pagination for large datasets to improve performance.

## 🔍 Troubleshooting

### Issue: No data returned
**Solution:** Check if:
- Rooms table has data
- Camps table is populated
- IsDeleted = 0 for all records

### Issue: SD Amount showing 0.00
**Solution:** Check if:
- TxnRecords has entries with TxnType = 'SD-CR'
- TxnRecords.ContractId matches the contract

### Issue: Tenant details missing
**Solution:** Check if:
- Contract.Status is NOT 'Cancelled' or 'Expired'
- Tenants table has the TenantId from Contracts

## 📞 Support

For issues or questions:
1. Check the API logs in backend
2. Verify database table structure matches expected schema
3. Test the stored procedure directly in SSMS with parameters

---

**Version:** 3.0  
**Last Updated:** October 28, 2026  
**Created By:** TFMS Development Team
