using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Net;
using System.Text;
using System.Text.Json;
using TFMS_software_api.Common;
using TFMS_software_api.Repositories;
using TFMS_software_api.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Controllers & JSON ───────────────────────────────────────────────────────
builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "TFMS API", Version = "v1" });
    c.EnableAnnotations();  // [SwaggerSchema] descriptions enable
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Description = "JWT Bearer token. Format: 'Bearer {token}'",
        Name = "Authorization", In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey, Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement {{
        new Microsoft.OpenApi.Models.OpenApiSecurityScheme {
            Reference = new Microsoft.OpenApi.Models.OpenApiReference
                { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" }
        }, Array.Empty<string>()
    }});
});

// ── CORS ─────────────────────────────────────────────────────────────────────
// Allow ALL origins, methods, headers — koi bhi port se koi bhi frontend connect kar sake
builder.Services.AddCors(options =>
    options.AddPolicy("AllowAll", p =>
    {
        p.SetIsOriginAllowed(_ => true)
         .AllowAnyMethod()
         .AllowAnyHeader()
         .AllowCredentials();
    }));

// ── JWT Auth ─────────────────────────────────────────────────────────────────
var jwtKey = builder.Configuration["Jwt:Key"]!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true, ValidateAudience = true,
            ValidateLifetime = true, ValidateIssuerSigningKey = true,
            ValidIssuer    = builder.Configuration["Jwt:Issuer"],
            ValidAudience  = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.FromMinutes(5)
        };
    });
// ── Authorization: require valid JWT for all endpoints ──────────────────────
builder.Services.AddAuthorization(options =>
{
    // Open access — no token required (both dev and production)
    options.DefaultPolicy = new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder()
        .RequireAssertion(_ => true)
        .Build();
    options.FallbackPolicy = null;
});

// ── Database ─────────────────────────────────────────────────────────────────
var connStr = builder.Configuration.GetConnectionString("DefaultConnection")!;
builder.Services.AddSingleton<IDbConnectionFactory>(_ => new SqlConnectionFactory(connStr));

// ── Cloudinary ────────────────────────────────────────────────────────────────
builder.Services.AddSingleton<ICloudinaryService, CloudinaryService>();

// ── Repositories ─────────────────────────────────────────────────────────────
builder.Services.AddScoped<IPartnerRepository,      PartnerRepository>();
builder.Services.AddScoped<IOwnerRepository,        OwnerRepository>();
builder.Services.AddScoped<IFloorRepository,        FloorRepository>();
builder.Services.AddScoped<IRoomStatusRepository,   RoomStatusRepository>();
builder.Services.AddScoped<IPaymentModeRepository,  PaymentModeRepository>();
builder.Services.AddScoped<IFundPoolRepository,     FundPoolRepository>();
builder.Services.AddScoped<IAccountsHeadRepository, AccountsHeadRepository>();
builder.Services.AddScoped<IDesignationRepository,  DesignationRepository>();
builder.Services.AddScoped<IOtherPersonRepository,  OtherPersonRepository>();
builder.Services.AddScoped<IRoleRepository,         RoleRepository>();
builder.Services.AddScoped<ICampRepository,         CampRepository>();
builder.Services.AddScoped<IRoomRepository,         RoomRepository>();
builder.Services.AddScoped<ITenantRepository,       TenantRepository>();
builder.Services.AddScoped<IContractRepository,     ContractRepository>();
builder.Services.AddScoped<IPaymentRepository,      PaymentRepository>();
builder.Services.AddScoped<IWaiverRepository,       WaiverRepository>();
builder.Services.AddScoped<IDashboardRepository,    DashboardRepository>();
builder.Services.AddScoped<IIncomeRepository,       IncomeRepository>();
builder.Services.AddScoped<IExpenseRepository,      ExpenseRepository>();
builder.Services.AddScoped<IUserRepository,         UserRepository>();
builder.Services.AddScoped<IReportRepository,       ReportRepository>();
builder.Services.AddScoped<IStaffRepository,        StaffRepository>();
builder.Services.AddScoped<IMisRepository,          MisRepository>();
builder.Services.AddScoped<IOwnerContractRepository, OwnerContractRepository>();
builder.Services.AddScoped<IOwnerPaymentRepository,  OwnerPaymentRepository>();
builder.Services.AddScoped<IOwnerContractCancellationRepository, OwnerContractCancellationRepository>();
builder.Services.AddScoped<ICampbossRepository, CampbossRepository>();
builder.Services.AddScoped<ITxnRecordRepository,    TxnRecordRepository>();
builder.Services.AddScoped<ICompanyAssetRepository, CompanyAssetRepository>();
builder.Services.AddScoped<IContractTermRepository, ContractTermRepository>();
builder.Services.AddScoped<IContractRenewalRepository, ContractRenewalRepository>();
builder.Services.AddScoped<IContractCancellationRepository, ContractCancellationRepository>();
builder.Services.AddScoped<ICompanyRepository, CompanyRepository>();
builder.Services.AddScoped<IPartnerTransRepository,  PartnerTransRepository>();
builder.Services.AddScoped<IPartnerPayoutRepository, PartnerPayoutRepository>();
builder.Services.AddScoped<IPartnerPayoutService,    PartnerPayoutService>();
// Salon Management
builder.Services.AddScoped<ISalonMasterRepository,     SalonMasterRepository>();
builder.Services.AddScoped<ISalonHeadMasterRepository, SalonHeadMasterRepository>();
builder.Services.AddScoped<ISalonStaffAssignRepository, SalonStaffAssignRepository>();
builder.Services.AddScoped<ISalonDailyCollectionRepository, SalonDailyCollectionRepository>();
builder.Services.AddScoped<ICompanyExpensePostingRepository, CompanyExpensePostingRepository>();
builder.Services.AddScoped<ISalonExpenseReportRepository,    SalonExpenseReportRepository>();
builder.Services.AddScoped<ISalonFundBalanceRepository,      SalonFundBalanceRepository>();

// ── Services ─────────────────────────────────────────────────────────────────
builder.Services.AddScoped<IPartnerService,      PartnerService>();
builder.Services.AddScoped<IOwnerService,        OwnerService>();
builder.Services.AddScoped<IFloorService,        FloorService>();
builder.Services.AddScoped<IRoomStatusService,   RoomStatusService>();
builder.Services.AddScoped<IPaymentModeService,  PaymentModeService>();
builder.Services.AddScoped<IFundPoolService,     FundPoolService>();
builder.Services.AddScoped<IAccountsHeadService, AccountsHeadService>();
builder.Services.AddScoped<IAccountMasterService, AccountMasterService>();
builder.Services.AddScoped<IAccountMasterRepository, AccountMasterRepository>();
builder.Services.AddScoped<ITaskAlertService, TaskAlertService>();
builder.Services.AddScoped<ITaskAlertRepository, TaskAlertRepository>();
builder.Services.AddScoped<IDesignationService,  DesignationService>();
builder.Services.AddScoped<IOtherPersonService,  OtherPersonService>();
builder.Services.AddScoped<IRoleService,         RoleService>();
builder.Services.AddScoped<ICampService,         CampService>();
builder.Services.AddScoped<IRoomService,         RoomService>();
builder.Services.AddScoped<ITenantService,       TenantService>();
builder.Services.AddScoped<IContractService,     ContractService>();
builder.Services.AddScoped<IPaymentService,      PaymentService>();
builder.Services.AddScoped<IWaiverService,       WaiverService>();
builder.Services.AddScoped<IDashboardService,    DashboardService>();
builder.Services.AddScoped<IAuthService,         AuthService>();
builder.Services.AddScoped<IIncomeService,       IncomeService>();
builder.Services.AddScoped<IActivityLogService,  ActivityLogService>();
builder.Services.AddScoped<IExpenseService,      ExpenseService>();
builder.Services.AddScoped<IUserService,         UserService>();
builder.Services.AddScoped<IReportService,       ReportService>();
builder.Services.AddScoped<IStaffService,        StaffService>();
builder.Services.AddScoped<IMisService,          MisService>();
builder.Services.AddScoped<IOwnerPaymentService, OwnerPaymentService>();
// Salon Management
builder.Services.AddScoped<ISalonMasterService,      SalonMasterService>();
builder.Services.AddScoped<ISalonHeadMasterService,  SalonHeadMasterService>();
builder.Services.AddScoped<ISalonStaffAssignService, SalonStaffAssignService>();
builder.Services.AddScoped<ISalonDailyCollectionService, SalonDailyCollectionService>();
builder.Services.AddScoped<ICompanyExpensePostingService, CompanyExpensePostingService>();
builder.Services.AddScoped<ISalonExpenseReportService,    SalonExpenseReportService>();
builder.Services.AddScoped<ISalonFundBalanceService,      SalonFundBalanceService>();

var app = builder.Build();

// ── Global Exception Handler ─────────────────────────────────────────────────
app.UseExceptionHandler(errApp => errApp.Run(async ctx => {
    ctx.Response.ContentType = "application/json";
    var err = ctx.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>();
    var ex  = err?.Error;

    string message;
    int statusCode;

    // SQL Foreign Key / Reference constraint violation
    if (ex is Microsoft.Data.SqlClient.SqlException sqlEx)
    {
        switch (sqlEx.Number)
        {
            case 547:  // FK constraint violation — record used in another table
                statusCode = (int)HttpStatusCode.Conflict;
                message = GetFriendlyFkMessage(sqlEx.Message);
                break;
            case 2601: // Unique index duplicate
            case 2627: // Unique constraint duplicate
                statusCode = (int)HttpStatusCode.Conflict;
                message = "This record already exists. Please use a unique value.";
                break;
            default:
                statusCode = (int)HttpStatusCode.InternalServerError;
                message = app.Environment.IsDevelopment()
                    ? $"Database error ({sqlEx.Number}): {sqlEx.Message}"
                    : "A database error occurred. Please try again.";
                break;
        }
    }
    else
    {
        statusCode = (int)HttpStatusCode.InternalServerError;
        message = app.Environment.IsDevelopment()
            ? ex?.ToString() ?? "Unknown error"
            : "An internal error occurred.";
    }

    ctx.Response.StatusCode = statusCode;
    await ctx.Response.WriteAsync(JsonSerializer.Serialize(
        ApiResponse<object>.Fail(message)));
}));

// ── Friendly FK message helper ────────────────────────────────────────────────
static string GetFriendlyFkMessage(string sqlMsg)
{
    // Parse table name from SQL error message for a specific message
    var lower = sqlMsg.ToLower();
    if      (lower.Contains("camps"))            return "Cannot delete: this record is being used in Camps. Please remove the reference first.";
    else if (lower.Contains("camppartners"))      return "Cannot delete: this Partner is assigned to one or more Camps. Remove camp assignment first.";
    else if (lower.Contains("campowners"))        return "Cannot delete: this Owner is assigned to one or more Camps. Remove camp assignment first.";
    else if (lower.Contains("rooms"))             return "Cannot delete: this record is being used in Rooms. Please delete or reassign those Rooms first.";
    else if (lower.Contains("contracts"))         return "Cannot delete: this record is being used in Contracts. Please close or delete those Contracts first.";
    else if (lower.Contains("payments"))          return "Cannot delete: this record has associated Payments. Delete the Payments first.";
    else if (lower.Contains("waivers"))           return "Cannot delete: this record has associated Waivers. Delete the Waivers first.";
    else if (lower.Contains("tenants"))           return "Cannot delete: this record is being used in Tenants. Please reassign or delete those Tenants first.";
    else if (lower.Contains("ownercontracts"))    return "Cannot delete: this Owner has active Owner Contracts. Delete the contracts first.";
    else if (lower.Contains("ownerinstallments")) return "Cannot delete: this record has Owner Installments linked to it.";
    else if (lower.Contains("incomes"))           return "Cannot delete: this record is referenced in Incomes. Remove those entries first.";
    else if (lower.Contains("expenses"))          return "Cannot delete: this record is referenced in Expenses. Remove those entries first.";
    else if (lower.Contains("floors"))            return "Cannot delete: this Floor is being used in Rooms. Please reassign or delete those Rooms first.";
    else if (lower.Contains("staff"))             return "Cannot delete: this record is associated with Staff entries.";
    else if (lower.Contains("appusers"))          return "Cannot delete: this record is linked to a User account. Delete the User first.";
    else if (lower.Contains("designation"))       return "Cannot delete: this Designation is assigned to Staff members. Reassign them first.";
    else if (lower.Contains("fundpool"))          return "Cannot delete: this Fund Pool is referenced in Incomes or Expenses. Remove those entries first.";
    else if (lower.Contains("paymentmode"))       return "Cannot delete: this Payment Mode is used in existing transactions. Remove those first.";
    else if (lower.Contains("accountshead"))      return "Cannot delete: this Accounts Head is used in Incomes or Expenses. Remove those entries first.";
    else if (lower.Contains("roles"))             return "Cannot delete: this Role is assigned to Users. Reassign those Users first.";
    else
        return "Cannot delete: this record is being used in another part of the system. Please remove all references before deleting.";
}

// ── Swagger (enabled on all environments including production for test server) ──
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "TFMS API v1");
    c.RoutePrefix = "swagger";
    c.DocumentTitle = "TFMS API";
    // Add API Docs button only — no auto-login, no embedded credentials
    c.HeadContent = @"
<script>
window.addEventListener('load', function () {
  setTimeout(function() {
    var topbar = document.querySelector('.topbar-wrapper');
    if (topbar && !document.getElementById('api-docs-btn')) {
      var btn = document.createElement('a');
      btn.id = 'api-docs-btn';
      btn.href = '/api-docs.html';
      btn.target = '_blank';
      btn.style = 'margin-left:16px;padding:6px 18px;background:#c89d4a;color:#1a1a2e;border-radius:6px;font-weight:700;font-size:13px;text-decoration:none;display:inline-flex;align-items:center;gap:6px;';
      btn.innerHTML = '📋 API Docs';
      topbar.appendChild(btn);
    }
  }, 800);
});
</script>";
});

app.UseCors("AllowAll");
// NOTE: No UseHttpsRedirection — API runs on plain HTTP
app.UseStaticFiles();   // serve wwwroot/login.html
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// ── Root "/" → Login page for Swagger ────────────────────────────────────────
app.MapGet("/", async ctx => {
    ctx.Response.ContentType = "text/html";
    await ctx.Response.SendFileAsync(Path.Combine(app.Environment.ContentRootPath, "wwwroot", "login.html"));
});

app.Run();
