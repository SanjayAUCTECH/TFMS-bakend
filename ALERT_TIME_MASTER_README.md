# Alert Time Master API Documentation

## Overview
Alert Time Master module allows you to configure alert timings (in days) for different types of alerts in the system.

---

## Database Setup

### 1. Run the SQL Script
Execute the following SQL file to create table and stored procedures:
```
Database/AlertTimeMaster_Setup.sql
```

This will create:
- **Table:** `AlertTimeMaster`
- **Stored Procedures:**
  - `sp_GetAlertTimes`
  - `sp_GetAlertTimeById`
  - `sp_CreateAlertTime`
  - `sp_UpdateAlertTime`
  - `sp_DeleteAlertTime`

### 2. Default Alert Times Created
The script automatically inserts default alert configurations:
- Emirates ID Expiry Alert (30 days)
- Passport Expiry Alert (60 days)
- Visa Expiry Alert (45 days)
- Labour Card Expiry Alert (30 days)
- Insurance Expiry Alert (30 days)
- Contract Renewal Alert (90 days)

---

## API Endpoints

Base URL: `/api/AlertTime`

### 1. Get All Alert Times (Paginated)
**GET** `/api/AlertTime`

**Query Parameters:**
- `PageNumber` (optional, default: 1)
- `PageSize` (optional, default: 10)
- `SearchText` (optional) - Search by alert name
- `Status` (optional) - Filter by status (Active/Inactive)
- `SortBy` (optional, default: "Id")

**Response:**
```json
{
  "success": true,
  "message": "Alert times retrieved successfully.",
  "data": [
    {
      "id": 1,
      "alertName": "Emirates ID Expiry Alert",
      "days": 30,
      "status": "Active",
      "createdAt": "2024-01-01T00:00:00",
      "updatedAt": "2024-01-01T00:00:00",
      "addedBy": null,
      "updatedBy": null
    }
  ],
  "pagination": {
    "totalRecords": 6,
    "totalPages": 1,
    "currentPage": 1,
    "pageSize": 10,
    "hasNextPage": false,
    "hasPreviousPage": false
  }
}
```

---

### 2. Get Alert Time By ID
**GET** `/api/AlertTime/{id}`

**Response:**
```json
{
  "success": true,
  "message": "Alert time retrieved successfully.",
  "data": {
    "id": 1,
    "alertName": "Emirates ID Expiry Alert",
    "days": 30,
    "status": "Active",
    "createdAt": "2024-01-01T00:00:00",
    "updatedAt": "2024-01-01T00:00:00",
    "addedBy": null,
    "updatedBy": null
  }
}
```

---

### 3. Create Alert Time
**POST** `/api/AlertTime`

**Request Body:**
```json
{
  "alertName": "New Alert",
  "days": 45,
  "status": "Active"
}
```

**Validations:**
- `alertName` - Required, max 100 characters
- `days` - Required, must be between 1-365
- `status` - Optional, default: "Active"

**Response:**
```json
{
  "success": true,
  "message": "Alert time created successfully.",
  "data": {
    "id": 7,
    "alertName": "New Alert",
    "days": 45,
    "status": "Active",
    "createdAt": "2024-01-01T00:00:00",
    "updatedAt": "2024-01-01T00:00:00",
    "addedBy": 1,
    "updatedBy": null
  }
}
```

**Error Response (Duplicate Name):**
```json
{
  "success": false,
  "message": "Alert name already exists.",
  "data": null
}
```

---

### 4. Update Alert Time
**PUT** `/api/AlertTime/{id}`

**Request Body:**
```json
{
  "alertName": "Updated Alert Name",
  "days": 60,
  "status": "Active"
}
```

**Validations:**
- `alertName` - Required, max 100 characters
- `days` - Required, must be between 1-365
- `status` - Required

**Response:**
```json
{
  "success": true,
  "message": "Alert time updated successfully.",
  "data": {
    "id": 1,
    "alertName": "Updated Alert Name",
    "days": 60,
    "status": "Active",
    "createdAt": "2024-01-01T00:00:00",
    "updatedAt": "2024-01-02T00:00:00",
    "addedBy": 1,
    "updatedBy": 1
  }
}
```

---

### 5. Delete Alert Time (Soft Delete)
**DELETE** `/api/AlertTime/{id}`

**Response:**
```json
{
  "success": true,
  "message": "Alert time deleted successfully.",
  "data": true
}
```

**Error Response (Not Found):**
```json
{
  "success": false,
  "message": "Alert time not found.",
  "data": false
}
```

---

## Database Table Structure

### AlertTimeMaster Table
| Column      | Type            | Description                    |
|-------------|-----------------|--------------------------------|
| Id          | INT (PK)        | Primary key, auto-increment    |
| AlertName   | NVARCHAR(100)   | Name of the alert              |
| Days        | INT             | Number of days before alert    |
| Status      | NVARCHAR(20)    | Active/Inactive                |
| CreatedAt   | DATETIME        | Record creation timestamp      |
| UpdatedAt   | DATETIME        | Last update timestamp          |
| AddedBy     | INT (nullable)  | User ID who created            |
| UpdatedBy   | INT (nullable)  | User ID who last updated       |
| IsDeleted   | BIT             | Soft delete flag               |

**Indexes:**
- `IX_AlertTimeMaster_AlertName` on AlertName
- `IX_AlertTimeMaster_IsDeleted` on IsDeleted

---

## Files Created

### Models
- `Models/AlertTimeMaster.cs`

### DTOs
- `DTOs/AlertTimeDtos.cs`
  - AlertTimeListRequest
  - AlertTimeResponse
  - CreateAlertTimeRequest
  - UpdateAlertTimeRequest

### Repository
- `Repositories/IAlertTimeRepository.cs`
- `Repositories/AlertTimeRepository.cs`

### Service
- `Services/IAlertTimeService.cs`
- `Services/AlertTimeService.cs`

### Controller
- `Controllers/AlertTimeController.cs`

### Database
- `Database/AlertTimeMaster_Setup.sql`

---

## Activity Logging

All CRUD operations are automatically logged in the ActivityLog table with:
- **Module:** Settings
- **Activity Types:** Create, Update, Delete
- **Logged Information:** User ID, IP Address, User Agent, Timestamp

---

## Testing the API

### Using Swagger
1. Start the API: `dotnet run`
2. Open: `http://localhost:9001/swagger`
3. Navigate to **AlertTime** section
4. Test all endpoints

### Using Postman/cURL
```bash
# Get all alert times
curl -X GET "http://localhost:9001/api/AlertTime?PageNumber=1&PageSize=10" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Create new alert time
curl -X POST "http://localhost:9001/api/AlertTime" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alertName": "Test Alert",
    "days": 30,
    "status": "Active"
  }'

# Update alert time
curl -X PUT "http://localhost:9001/api/AlertTime/1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alertName": "Updated Alert",
    "days": 45,
    "status": "Active"
  }'

# Delete alert time
curl -X DELETE "http://localhost:9001/api/AlertTime/1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Error Handling

All APIs return consistent error responses:
```json
{
  "success": false,
  "message": "Error message here",
  "data": null
}
```

Common error scenarios:
- **400 Bad Request:** Validation failed
- **404 Not Found:** Alert time ID not found
- **401 Unauthorized:** Missing or invalid token

---

## Authorization

All endpoints require JWT authentication. Include the token in the Authorization header:
```
Authorization: Bearer YOUR_JWT_TOKEN
```

---

## Notes

1. **Soft Delete:** Records are not physically deleted, only marked as `IsDeleted = 1`
2. **Duplicate Prevention:** Alert names must be unique (case-sensitive)
3. **Days Validation:** Alert days must be between 1-365
4. **Status Values:** Typically "Active" or "Inactive"
5. **Pagination:** Default page size is 10, adjustable via query parameters

---

## API Running Status

✅ **Backend API:** http://localhost:9001  
✅ **Frontend UI:** http://localhost:5174  
✅ **Swagger Documentation:** http://localhost:9001/swagger

---

## Support

For issues or questions, contact the development team.
