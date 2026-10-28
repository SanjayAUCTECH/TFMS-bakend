# Month-wise Rental Report API

## Overview
Comprehensive Month-wise Rental Report API with advanced filtering, pagination, sorting, and export capabilities. Data is fetched from `ContractRoomInstallments` table joined with `Contracts`, `Tenants`, `Camps`, `Rooms`, and `Floors` tables.

---

## API Endpoints

### 1. **GET** `/api/monthwiserentalreport`
Get month-wise rental report with detailed filtering and pagination.

#### Query Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `month` | string | No | Filter by specific month | `Dec26`, `Jan27` |
| `campId` | integer | No | Filter by camp ID | `1`, `5` |
| `tenantId` | integer | No | Filter by tenant ID | `10`, `25` |
| `roomId` | integer | No | Filter by room ID | `101`, `205` |
| `status` | string | No | Filter by installment status | `Paid`, `Pending`, `Partial`, `Overdue` |
| `contractStatus` | string | No | Filter by contract status | `Active`, `Completed`, `Cancelled` |
| `fromDate` | datetime | No | Filter by due date (start range) | `2026-12-01` |
| `toDate` | datetime | No | Filter by due date (end range) | `2026-12-31` |
| `pageNumber` | integer | No | Page number (default: 1) | `1`, `2`, `3` |
| `pageSize` | integer | No | Records per page (default: 50) | `25`, `50`, `100` |
| `sortBy` | string | No | Sort column (default: DueDate) | `DueDate`, `Month`, `InstallAmount`, `Status` |
| `sortDirection` | string | No | Sort direction (default: ASC) | `ASC`, `DESC` |

#### Response Example
```json
{
  "success": true,
  "message": "Month-wise rental report for Dec26 retrieved successfully.",
  "data": {
    "summary": {
      "totalRecords": 150,
      "currentPageRecords": 50,
      "totalInstallAmount": 750000.00,
      "totalPaidAmount": 500000.00,
      "totalBalance": 250000.00,
      "filterApplied": {
        "month": "Dec26",
        "campId": "All",
        "tenantId": "All",
        "roomId": "All",
        "status": "All",
        "contractStatus": "All",
        "dateRange": "All"
      }
    },
    "reportData": [
      {
        "id": 1001,
        "contractId": "CONT-2026-001",
        "contractType": "Monthly",
        "contractStatus": "Active",
        "startDate": "2026-01-01T00:00:00",
        "endDate": "2026-12-31T00:00:00",
        "tenantId": 25,
        "tenantName": "ABC Company Ltd.",
        "tenantContactPerson": "John Doe",
        "tenantPhone": "+1234567890",
        "campId": 5,
        "campName": "North Camp",
        "campLocation": "North Industrial Area",
        "roomId": 101,
        "roomNo": "R-101",
        "floorName": "Ground Floor",
        "installmentNo": 12,
        "month": "Dec26",
        "dueDate": "2026-12-01T00:00:00",
        "installAmount": 5000.00,
        "paymentMode": "Bank Transfer",
        "referenceNo": "TXN123456",
        "clearanceDate": "2026-12-02T00:00:00",
        "paidDate": "2026-12-01T10:30:00",
        "paidAmount": 5000.00,
        "balance": 0.00,
        "status": "Paid",
        "createdAt": "2026-01-01T00:00:00",
        "updatedAt": "2026-12-01T10:30:00"
      }
      // ... more records
    ],
    "totalRecords": 150
  },
  "pagination": {
    "pageNumber": 1,
    "pageSize": 50,
    "totalRecords": 150,
    "totalPages": 3,
    "hasNextPage": true,
    "hasPreviousPage": false
  }
}
```

#### Sortable Columns
- `Id` - Record ID
- `ContractId` - Contract identifier
- `Month` - Month name
- `DueDate` - Due date (default)
- `InstallAmount` - Installment amount
- `PaidAmount` - Paid amount
- `Balance` - Balance amount
- `Status` - Payment status
- `CampName` - Camp name
- `RoomNo` - Room number
- `TenantName` - Tenant name
- `ContractStatus` - Contract status
- `InstallmentNo` - Installment number
- `CreatedAt` - Creation timestamp

---

### 2. **GET** `/api/monthwiserentalreport/summary`
Get aggregated monthly summary with statistics.

#### Query Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `campId` | integer | No | Filter by camp ID | `1`, `5` |
| `tenantId` | integer | No | Filter by tenant ID | `10`, `25` |
| `status` | string | No | Filter by installment status | `Paid`, `Pending` |

#### Response Example
```json
{
  "success": true,
  "message": "Monthly summary retrieved successfully.",
  "data": {
    "summaryData": [
      {
        "month": "Dec26",
        "totalRooms": 50,
        "totalInstallments": 150,
        "totalInstallAmount": 750000.00,
        "totalPaidAmount": 500000.00,
        "totalBalance": 250000.00,
        "paidCount": 80,
        "pendingCount": 40,
        "partialCount": 20,
        "overdueCount": 10
      },
      {
        "month": "Jan27",
        "totalRooms": 52,
        "totalInstallments": 156,
        "totalInstallAmount": 780000.00,
        "totalPaidAmount": 650000.00,
        "totalBalance": 130000.00,
        "paidCount": 120,
        "pendingCount": 25,
        "partialCount": 8,
        "overdueCount": 3
      }
      // ... more months
    ],
    "totalRecords": 12
  }
}
```

---

### 3. **GET** `/api/monthwiserentalreport/export`
Export complete report data (no pagination) for Excel/CSV export.

#### Query Parameters
Same as main report endpoint, except:
- `pageNumber` - Not used (returns all records)
- `pageSize` - Not used (returns all records)
- `sortBy` - Fixed to `DueDate`
- `sortDirection` - Fixed to `ASC`

#### Response Example
```json
{
  "success": true,
  "message": "Export data retrieved successfully - 1500 records.",
  "data": {
    "exportData": [
      {
        "contractId": "CONT-2026-001",
        "contractType": "Monthly",
        "contractStatus": "Active",
        "tenantName": "ABC Company Ltd.",
        "tenantContactPerson": "John Doe",
        "tenantPhone": "+1234567890",
        "campName": "North Camp",
        "campLocation": "North Industrial Area",
        "roomNo": "R-101",
        "floorName": "Ground Floor",
        "month": "Dec26",
        "dueDate": "2026-12-01",
        "installAmount": 5000.00,
        "paidAmount": 5000.00,
        "balance": 0.00,
        "status": "Paid",
        "paymentMode": "Bank Transfer",
        "referenceNo": "TXN123456",
        "paidDate": "2026-12-01"
      }
      // ... all matching records
    ],
    "totalRecords": 1500
  }
}
```

---

## Database Setup

### Tables Used
- **ContractRoomInstallments** - Main data source
- **Contracts** - Contract details and status
- **Tenants** - Tenant information
- **Camps** - Camp details and location
- **Rooms** - Room information
- **Floors** - Floor information (optional)

### Stored Procedures

#### 1. `sp_GetMonthwiseRentalReport`
Main report procedure with filtering, sorting, and pagination.

**Parameters:**
```sql
@Month           VARCHAR(10)  = NULL,
@CampId          INT          = NULL,
@TenantId        INT          = NULL,
@RoomId          INT          = NULL,
@Status          VARCHAR(20)  = NULL,
@ContractStatus  VARCHAR(20)  = NULL,
@FromDate        DATETIME     = NULL,
@ToDate          DATETIME     = NULL,
@PageNumber      INT          = 1,
@PageSize        INT          = 50,
@SortBy          VARCHAR(50)  = 'DueDate',
@SortDirection   VARCHAR(4)   = 'ASC',
@TotalRecords    INT          OUTPUT
```

#### 2. `sp_GetMonthwiseRentalSummary`
Aggregated monthly summary procedure.

**Parameters:**
```sql
@CampId    INT         = NULL,
@TenantId  INT         = NULL,
@Status    VARCHAR(20) = NULL
```

### Installation Steps

1. **Using PowerShell Script (Recommended)**
   ```powershell
   cd "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\Database"
   .\RUN_MonthwiseRentalReport_Procedures.ps1
   ```

2. **Manual Installation**
   - Update SQL Server instance and database name in script
   - Execute `sp_GetMonthwiseRentalReport.sql`
   - Execute `sp_GetMonthwiseRentalSummary.sql`

---

## Usage Examples

### Example 1: Get all rental records for December 2026
```http
GET /api/monthwiserentalreport?month=Dec26&pageSize=50
```

### Example 2: Get rental report for specific camp
```http
GET /api/monthwiserentalreport?campId=5&pageSize=100
```

### Example 3: Get pending payments for a tenant
```http
GET /api/monthwiserentalreport?tenantId=25&status=Pending
```

### Example 4: Get overdue payments in date range
```http
GET /api/monthwiserentalreport?status=Overdue&fromDate=2026-11-01&toDate=2026-11-30
```

### Example 5: Get monthly summary for all camps
```http
GET /api/monthwiserentalreport/summary
```

### Example 6: Export all data for specific month
```http
GET /api/monthwiserentalreport/export?month=Dec26
```

### Example 7: Get report sorted by balance (highest first)
```http
GET /api/monthwiserentalreport?sortBy=Balance&sortDirection=DESC
```

### Example 8: Get active contract rentals for a room
```http
GET /api/monthwiserentalreport?roomId=101&contractStatus=Active
```

---

## Filter Combinations

### Common Scenarios

1. **Camp Manager View**: All rentals for their camps
   ```
   ?campId=5&pageSize=100
   ```

2. **Tenant Statement**: All rental records for a tenant
   ```
   ?tenantId=25&sortBy=DueDate&sortDirection=ASC
   ```

3. **Overdue Collection Report**: All overdue payments
   ```
   ?status=Overdue&sortBy=DueDate
   ```

4. **Monthly Revenue Report**: Paid rentals for a month
   ```
   ?month=Dec26&status=Paid
   ```

5. **Room Occupancy Report**: Rentals for specific rooms
   ```
   ?roomId=101&sortBy=Month
   ```

---

## Response Fields

### Report Data Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Record ID |
| `contractId` | string | Contract identifier |
| `contractType` | string | Contract type (Monthly, Yearly, etc.) |
| `contractStatus` | string | Contract status (Active, Completed, Cancelled) |
| `startDate` | datetime | Contract start date |
| `endDate` | datetime | Contract end date |
| `tenantId` | integer | Tenant ID |
| `tenantName` | string | Tenant name |
| `tenantContactPerson` | string | Tenant contact person |
| `tenantPhone` | string | Tenant phone number |
| `campId` | integer | Camp ID |
| `campName` | string | Camp name |
| `campLocation` | string | Camp location |
| `roomId` | integer | Room ID |
| `roomNo` | string | Room number |
| `floorName` | string | Floor name |
| `installmentNo` | integer | Installment number |
| `month` | string | Month (e.g., Dec26) |
| `dueDate` | datetime | Payment due date |
| `installAmount` | decimal | Installment amount |
| `paymentMode` | string | Payment mode (Cash, Bank Transfer, Cheque, etc.) |
| `referenceNo` | string | Payment reference number |
| `clearanceDate` | datetime | Payment clearance date |
| `paidDate` | datetime | Payment date |
| `paidAmount` | decimal | Amount paid |
| `balance` | decimal | Remaining balance |
| `status` | string | Payment status (Paid, Pending, Partial, Overdue) |
| `createdAt` | datetime | Record creation timestamp |
| `updatedAt` | datetime | Record update timestamp |

---

## Notes

1. **Performance**: 
   - Main report timeout: 2 minutes
   - Export timeout: 5 minutes
   - Use appropriate page sizes for better performance

2. **Authorization**: All endpoints require authentication (JWT token)

3. **Activity Logging**: Export operations are logged in activity log

4. **Date Formats**: All dates use ISO 8601 format (`yyyy-MM-ddTHH:mm:ss`)

5. **Decimal Precision**: All monetary values use 2 decimal places

---

## API Testing

### Using Swagger
```
https://your-api-url/swagger
Navigate to: MonthwiseRentalReport section
```

### Using Postman
```
Import collection from: /TFMS-bakend/Postman/MonthwiseRentalReport.json
```

---

## Controller Location
```
File: Controllers/MonthwiseRentalReportController.cs
Namespace: TFMS_software_api.Controllers
Route: api/monthwiserentalreport
```

## Database Scripts Location
```
Procedures: Database/sp_GetMonthwiseRentalReport.sql
            Database/sp_GetMonthwiseRentalSummary.sql
Setup Script: Database/RUN_MonthwiseRentalReport_Procedures.ps1
```

---

## Version History
- **v1.0** (2026-10-27): Initial implementation
  - Main report endpoint with filtering and pagination
  - Monthly summary endpoint
  - Export functionality
  - Comprehensive filtering support

---

## Support
For issues or questions, contact the development team.
