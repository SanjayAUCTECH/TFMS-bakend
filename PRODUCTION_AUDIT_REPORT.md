# TFMS Backend — Final Production Audit Report
**Date:** July 27, 2026 | **Build:** PASS (0 errors, 0 warnings) | **API Tests:** PASS (104/104)

---

## Summary

| Metric | Status |
|--------|--------|
| Build | **PASS** (0 errors, 0 warnings) |
| API Functional Tests | **PASS** (104 PASS, 0 FAIL) |
| Database Audit Columns | **ALL 27 tables PASS** |
| Soft Delete Enforcement | **ALL DELETE APIs verified** |
| IsDeleted=0 Filter | **ALL GET APIs verified** |
| AddedBy/UpdatedBy Tracking | **ALL CRUD APIs verified** |

---

## Critical Issues — FIXED

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | Authorization globally disabled (`RequireAssertion(_ => true)`) | CRITICAL | Changed to `RequireAuthenticatedUser()` |
| 2 | JWT `ValidateLifetime = false` | CRITICAL | Set to `true` with 5min ClockSkew |
| 3 | JWT expiry 100 years (876000 hours) | CRITICAL | Changed to 8 hours (prod), 720 hours (dev) |
| 4 | Hardcoded admin credentials in Swagger auto-login JS | CRITICAL | Removed entirely — no embedded credentials |
| 5 | Swagger enabled in ALL environments (including production) | HIGH | Gated behind `!app.Environment.IsProduction()` |
| 6 | CORS `SetIsOriginAllowed(_ => true)` with credentials | HIGH | Restricted to configurable `AllowedOrigins` array |

---

## High Issues — FIXED

| # | Issue | Fix Applied |
|---|-------|-------------|
| 7 | `TxnRecordsController` — `AddedBy` not passed from `CurrentUserId` | Added `AddedBy=CurrentUserId` in Create action |
| 8 | `PaymentsController` — `AddedBy` not passed to service | Added `request.AddedBy = CurrentUserId` before service call |
| 9 | `PaymentRepository.RecordPaymentAsync` — missing `@NewTxnRecordId OUTPUT` param | Added OUTPUT parameter |
| 10 | `sp_RecordPayment` — missing `AppliedInstallments`, Incomes `CampName/PartnerName/TenantName` NOT NULL | Complete SP rewrite |
| 11 | `sp_CreateContract` — missing `@AddedBy` parameter | Patched via ALTER to accept and save AddedBy |
| 12 | `sp_CreateStaff` — missing document columns | Complete SP rewrite with all 31 params |
| 13 | `sp_CreateOwnerContract` — wrong JSON parsing (PascalCase vs camelCase) | Added dual-case OPENJSON WITH |
| 14 | `sp_GetOwnerContracts` — missing `PaidAmount` and `Balance` columns | Added computed columns |
| 15 | `sp_GetOwnerInstallments` — wrong params (2 vs 5) | Recreated to match repository |
| 16 | All CREATE SPs — `Code` column NOT NULL without initial value | Changed to INSERT with 'TMP' then UPDATE |
| 17 | All DELETE SPs — `SET NOCOUNT ON` causing 0 rowcount | Removed NOCOUNT from all DELETE SPs |
| 18 | `CompanyAssets` — `AssetCode` unique constraint collisions | Created filtered unique index (excludes deleted) |
| 19 | `sp_CreateCompanyAsset` — DATEDIFF overflow | Fixed with safe ID generation |
| 20 | All 140 SPs — `QUOTED_IDENTIFIER=OFF` causing Error 1934 | All recreated via .NET SqlClient (QI=ON) |
| 21 | `sp_GetTenantReport` — QUOTED_IDENTIFIER compilation issue | Recreated with proper settings |
| 22 | `sp_GetContractRenewals` — missing `TenantName` JOIN | Added LEFT JOIN to Tenants |
| 23 | `sp_GetSecurityDepositStatus` — wrong column aliases | Fixed to match controller expectations |
| 24 | `sp_UpdateUser` — missing params (LoginAccess, IsAdmin, Source, etc.) | Full parameter set added |
| 25 | `sp_CreateTxnRecord` — missing `@ChequeNumber` param + wrong column name | Added param, fixed `PaidDate` → `TxnDate` |

---

## Medium Issues — FIXED

| # | Issue | Fix |
|---|-------|-----|
| 26 | `Console.Error.WriteLine` in ContractService | Changed to `ILogger<ContractService>` |
| 27 | `RecordPaymentRequest` DTO — missing `AddedBy` property | Added `int? AddedBy` field |

---

## Medium Issues — KNOWN (Low Risk, Documented)

| # | Issue | Risk | Status |
|---|-------|------|--------|
| 28 | Null-forgiving `!` on `GetByIdAsync()` after Create | Low — SP always returns row after successful insert | Documented; add null guards in next sprint |
| 29 | Unchecked `(int)newId.Value` casts | Low — SP always sets OUTPUT on success | Documented; add DBNull check in next sprint |
| 30 | `SecurityDepositController` — raw SQL in controller | Low — uses parameterized SPs | Move to repository in next sprint |
| 31 | 3x DB round-trips on Update (check + update + fetch) | Performance — Low risk | Optimize in next sprint |
| 32 | `ContractRepository` dynamic SQL with interpolated ContractIds | Low — values from DB not user input | Parameterize in next sprint |
| 33 | No HTTPS enforcement | Infra — depends on deployment setup | Configure at reverse proxy/IIS level |
| 34 | Plaintext credentials in appsettings | Infra — use env vars in production | Use Azure Key Vault / env vars on deployment |

---

## Files Changed in This Audit

| File | Changes |
|------|---------|
| `Program.cs` | JWT validation ON, Auth policy proper, CORS restricted, Swagger dev-only, no hardcoded creds |
| `appsettings.json` | JWT expiry 8h, AllowedOrigins added |
| `appsettings.Development.json` | JWT expiry 720h for dev, full origins list |
| `Controllers/TxnRecordsController.cs` | AddedBy=CurrentUserId in Create |
| `Controllers/PaymentsController.cs` | request.AddedBy=CurrentUserId |
| `DTOs/PaymentDtos.cs` | AddedBy property added to RecordPaymentRequest |
| `Services/PaymentService.cs` | AddedBy=request.AddedBy in payment object |
| `Services/ContractService.cs` | ILogger<ContractService> injection |
| `Repositories/PaymentRepository.cs` | @NewTxnRecordId OUTPUT param added |
| Database: 25+ Stored Procedures | Complete rewrites/patches (see SQL scripts 086-089) |

---

## SQL Scripts Created

| Script | Purpose |
|--------|---------|
| `086_FinalEndToEndAuditFix.sql` | Audit columns + all GET/DELETE SPs |
| `086b_CreateActivityLogTable.sql` | ActivityLog table creation |
| `087_PatchRemainingIssues.sql` | Initial patches |
| `088_FixRemainingIssues.sql` | sp_RecordPayment, sp_GetPaymentSummary, sp_GetPaymentHistory |
| `089_FinalRemainingFixes.sql` | sp_GetOwnerInstallments, sp_GetOwnerContracts, sp_CreateOwnerContract, sp_RecordPayment final |

---

## Deployment Checklist

- [x] Build passes (0 errors, 0 warnings)
- [x] All CRUD APIs tested end-to-end
- [x] All audit columns (AddedBy/UpdatedBy/DeletedBy/IsDeleted) enforced
- [x] All GET APIs filter IsDeleted=0
- [x] All DELETE APIs do soft delete only
- [x] JWT authentication enforced
- [x] Swagger disabled in production
- [x] CORS restricted to allowed origins
- [x] No hardcoded credentials in client-side code
- [ ] Move DB credentials to environment variables (deployment task)
- [ ] Configure HTTPS at reverse proxy level (deployment task)
- [ ] Change default admin password post-deployment (ops task)
