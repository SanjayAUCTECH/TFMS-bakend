# Month-wise Rental Report - Quick Setup Guide

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Database Procedures
```powershell
cd "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend\Database"
.\RUN_MonthwiseRentalReport_Procedures.ps1
```

### Step 2: Test Procedures (Optional)
```powershell
.\TEST_MonthwiseRentalReport.ps1
```

### Step 3: Start Backend API
```powershell
cd "g:\Sanjay Kumar\AI project\TFMS Software\Tfms-full project\TFMS-bakend"
dotnet run
```

### Step 4: Test API
Open browser: `http://localhost:5000/swagger`
Navigate to: **MonthwiseRentalReport** section

---

## 📊 API Quick Reference

### Main Report Endpoint
```
GET /api/monthwiserentalreport
```

**Common Query Examples:**

```bash
# Get all records (first page)
?pageSize=50

# Filter by month
?month=Dec26

# Filter by camp
?campId=5

# Filter by tenant
?tenantId=25

# Filter by status
?status=Pending

# Multiple filters
?month=Dec26&campId=5&status=Paid

# Sort by balance (highest first)
?sortBy=Balance&sortDirection=DESC

# Date range filter
?fromDate=2026-12-01&toDate=2026-12-31

# Active contracts only
?contractStatus=Active
```

### Monthly Summary
```
GET /api/monthwiserentalreport/summary
```

### Export Data
```
GET /api/monthwiserentalreport/export?month=Dec26
```

---

## 🎯 Common Use Cases

### 1. Camp Manager Dashboard
**Scenario:** View all rentals for my camps
```
GET /api/monthwiserentalreport?campId=5&pageSize=100
```

### 2. Tenant Statement
**Scenario:** Generate tenant's rental history
```
GET /api/monthwiserentalreport?tenantId=25&sortBy=DueDate
```

### 3. Collection Report
**Scenario:** Find all overdue payments
```
GET /api/monthwiserentalreport?status=Overdue
```

### 4. Monthly Revenue
**Scenario:** Calculate revenue for specific month
```
GET /api/monthwiserentalreport/summary?month=Dec26&status=Paid
```

### 5. Room Occupancy
**Scenario:** Check rental history for a room
```
GET /api/monthwiserentalreport?roomId=101
```

---

## 📋 Filter Options

### Status Values
- `Paid` - Fully paid installments
- `Pending` - Unpaid installments
- `Partial` - Partially paid
- `Overdue` - Past due date

### Contract Status
- `Active` - Active contracts
- `Completed` - Completed contracts
- `Cancelled` - Cancelled contracts

### Sort Columns
- `DueDate` (default)
- `Month`
- `InstallAmount`
- `PaidAmount`
- `Balance`
- `Status`
- `TenantName`
- `CampName`
- `RoomNo`

---

## 🔧 Troubleshooting

### Issue: Procedure not found
**Solution:** Run the setup script
```powershell
.\RUN_MonthwiseRentalReport_Procedures.ps1
```

### Issue: No data returned
**Solution:** Check filters and verify data exists
```sql
SELECT COUNT(*) FROM ContractRoomInstallments WHERE IsDeleted = 0;
```

### Issue: Slow performance
**Solution:** 
- Use smaller page sizes
- Add specific filters (month, camp, etc.)
- Check database indexes

### Issue: Permission denied
**Solution:** Grant execute permissions
```sql
GRANT EXECUTE ON sp_GetMonthwiseRentalReport TO [YourAppUser];
GRANT EXECUTE ON sp_GetMonthwiseRentalSummary TO [YourAppUser];
```

---

## 📁 File Locations

```
Backend API:
  Controllers/MonthwiseRentalReportController.cs

Database Procedures:
  Database/sp_GetMonthwiseRentalReport.sql
  Database/sp_GetMonthwiseRentalSummary.sql

Setup & Test Scripts:
  Database/RUN_MonthwiseRentalReport_Procedures.ps1
  Database/TEST_MonthwiseRentalReport.ps1

Documentation:
  MONTHWISE_RENTAL_REPORT_README.md (detailed)
  MONTHWISE_RENTAL_REPORT_QUICK_GUIDE.md (this file)
```

---

## 🔐 Authorization

All endpoints require JWT authentication token:

```http
Authorization: Bearer <your-jwt-token>
```

---

## 📊 Response Structure

```json
{
  "success": true,
  "message": "...",
  "data": {
    "summary": { /* totals and stats */ },
    "reportData": [ /* array of records */ ],
    "totalRecords": 150
  },
  "pagination": {
    "pageNumber": 1,
    "pageSize": 50,
    "totalPages": 3,
    "hasNextPage": true
  }
}
```

---

## 🎨 Frontend Integration Example (React/JavaScript)

```javascript
// API call example
const fetchReport = async (filters) => {
  const params = new URLSearchParams({
    month: filters.month || '',
    campId: filters.campId || '',
    status: filters.status || '',
    pageNumber: filters.page || 1,
    pageSize: 50
  });
  
  const response = await fetch(
    `/api/monthwiserentalreport?${params}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return await response.json();
};

// Usage
const report = await fetchReport({
  month: 'Dec26',
  campId: 5,
  status: 'Pending',
  page: 1
});

console.log('Total Records:', report.data.totalRecords);
console.log('Summary:', report.data.summary);
console.log('Data:', report.data.reportData);
```

---

## 📞 Support

For detailed documentation, see: `MONTHWISE_RENTAL_REPORT_README.md`

---

## ✅ Checklist

- [ ] Procedures created (run setup script)
- [ ] Procedures tested (run test script)
- [ ] Backend API started
- [ ] Swagger tested
- [ ] Endpoints accessible
- [ ] Data returned correctly
- [ ] Filters working
- [ ] Pagination working
- [ ] Sorting working
- [ ] Export working

---

**Last Updated:** October 27, 2026
**Version:** 1.0
