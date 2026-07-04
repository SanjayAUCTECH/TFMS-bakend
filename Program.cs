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
// AllowAnyOrigin: works for both local dev and production server
builder.Services.AddCors(options =>
    options.AddPolicy("AllowAll", p => p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

// ── JWT Auth ─────────────────────────────────────────────────────────────────
var jwtKey = builder.Configuration["Jwt:Key"]!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true, ValidateAudience = true,
            ValidateLifetime = false, ValidateIssuerSigningKey = true,
            ValidIssuer    = builder.Configuration["Jwt:Issuer"],
            ValidAudience  = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });
builder.Services.AddAuthorization();

// ── Database ─────────────────────────────────────────────────────────────────
var connStr = builder.Configuration.GetConnectionString("DefaultConnection")!;
builder.Services.AddSingleton<IDbConnectionFactory>(_ => new SqlConnectionFactory(connStr));

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

// ── Services ─────────────────────────────────────────────────────────────────
builder.Services.AddScoped<IPartnerService,      PartnerService>();
builder.Services.AddScoped<IOwnerService,        OwnerService>();
builder.Services.AddScoped<IFloorService,        FloorService>();
builder.Services.AddScoped<IRoomStatusService,   RoomStatusService>();
builder.Services.AddScoped<IPaymentModeService,  PaymentModeService>();
builder.Services.AddScoped<IFundPoolService,     FundPoolService>();
builder.Services.AddScoped<IAccountsHeadService, AccountsHeadService>();
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
builder.Services.AddScoped<IExpenseService,      ExpenseService>();
builder.Services.AddScoped<IUserService,         UserService>();
builder.Services.AddScoped<IReportService,       ReportService>();
builder.Services.AddScoped<IStaffService,        StaffService>();
builder.Services.AddScoped<IMisService,          MisService>();

var app = builder.Build();

// ── Global Exception Handler ─────────────────────────────────────────────────
app.UseExceptionHandler(errApp => errApp.Run(async ctx => {
    ctx.Response.StatusCode  = (int)HttpStatusCode.InternalServerError;
    ctx.Response.ContentType = "application/json";
    var err = ctx.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>();
    var msg = app.Environment.IsDevelopment() ? err?.Error?.ToString() : "An internal error occurred.";
    await ctx.Response.WriteAsync(JsonSerializer.Serialize(
        ApiResponse<object>.Fail(msg ?? "Unknown error")));
}));

// ── Swagger (all environments) ───────────────────────────────────────────────
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "TFMS API v1");
    c.RoutePrefix = "swagger";
    c.DocumentTitle = "TFMS API";
    // Inject JS: auto-login and set Bearer token on page load
    c.HeadContent = @"
<script>
window.addEventListener('load', function () {
  // Auto-login with default admin credentials and set Bearer token
  setTimeout(function () {
    fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'Admin@123' })
    })
    .then(r => r.json())
    .then(function(res) {
      if (res.success && res.data && res.data.token) {
        var token = res.data.token;
        // Set token in Swagger UI authorize
        window.ui.preauthorizeApiKey('Bearer', 'Bearer ' + token);
        console.log('[TFMS] Auto-authorized as:', res.data.username);
        // Show small banner
        var banner = document.createElement('div');
        banner.style = 'background:#1a7a4a;color:#fff;padding:8px 16px;font-size:13px;position:fixed;top:0;left:0;right:0;z-index:9999;text-align:center';
        banner.innerHTML = '✅ Auto-logged in as <strong>' + res.data.name + '</strong> (' + res.data.role + ') — Token valid till ' + new Date(res.data.expiresAt).toLocaleTimeString();
        document.body.prepend(banner);
        setTimeout(() => banner.remove(), 5000);
      }
    })
    .catch(function(e) { console.warn('[TFMS] Auto-login failed:', e); });
  }, 1000);
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
