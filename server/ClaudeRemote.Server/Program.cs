using System.Net.WebSockets;
using ClaudeRemote.Server.Hubs;
using ClaudeRemote.Server.Models;
using ClaudeRemote.Server.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

// Configure Kestrel to listen on all interfaces
var port = builder.Configuration.GetValue("Server:Port", 8443);
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// Services
var authService = new AuthService();
builder.Services.AddSingleton(authService);
builder.Services.AddSingleton<TerminalManager>();
builder.Services.AddSingleton<SystemInfoService>();
builder.Services.AddSingleton<FileService>();
builder.Services.AddSingleton<ActionService>();
builder.Services.AddSingleton<ScreenCaptureService>();
builder.Services.AddSingleton<WebSocketHandler>();
builder.Services.AddHostedService<DiscoveryService>();

// JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = authService.GetTokenValidationParameters();
        // Allow token from query string for WebSocket
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var token = context.Request.Query["token"].FirstOrDefault();
                if (!string.IsNullOrEmpty(token))
                    context.Token = token;
                return Task.CompletedTask;
            }
        };
    });
builder.Services.AddAuthorization();

// CORS — allow all origins (needed for tunnel proxies like ngrok/cloudflare)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

// Forwarded headers (tunnels send X-Forwarded-* headers)
app.UseForwardedHeaders(new Microsoft.AspNetCore.Builder.ForwardedHeadersOptions
{
    ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor
                     | Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto
});

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseWebSockets();

// ============ Public Endpoints (no auth) ============

app.MapGet("/api/health", () => Results.Ok(new
{
    status = "ok",
    server = Environment.MachineName,
    version = "1.0.0"
}));

app.MapPost("/api/pair", (PairRequest request) =>
{
    var result = authService.TryPair(request);
    return result is not null ? Results.Ok(result) : Results.Unauthorized();
});

// ============ Authenticated Endpoints ============

var api = app.MapGroup("/api").RequireAuthorization();

// Terminals
api.MapGet("/terminals", (TerminalManager mgr) =>
    mgr.GetActiveSessionIds().Select(id => new { sessionId = id }));

// System
api.MapGet("/system", (SystemInfoService svc) => svc.GetSystemInfo());

api.MapGet("/processes", (SystemInfoService svc, int? top) =>
    svc.GetProcesses(top ?? 50));

api.MapDelete("/processes/{pid}", (SystemInfoService svc, int pid) =>
    svc.KillProcess(pid) ? Results.Ok() : Results.NotFound());

// Files
api.MapGet("/files", (FileService svc, string? path) =>
    path is null ? Results.Ok(svc.GetDrives()) : Results.Ok(svc.ListDirectory(path)));

api.MapPost("/files/mkdir", (FileService svc, HttpRequest req) =>
{
    var path = req.Query["path"].ToString();
    if (string.IsNullOrEmpty(path)) return Results.BadRequest("path required");
    svc.CreateDirectory(path);
    return Results.Ok();
});

api.MapDelete("/files", (FileService svc, string path) =>
{
    svc.Delete(path);
    return Results.Ok();
});

api.MapPut("/files/rename", (FileService svc, HttpRequest req) =>
{
    var oldPath = req.Query["oldPath"].ToString();
    var newPath = req.Query["newPath"].ToString();
    if (string.IsNullOrEmpty(oldPath) || string.IsNullOrEmpty(newPath))
        return Results.BadRequest("oldPath and newPath required");
    svc.Rename(oldPath, newPath);
    return Results.Ok();
});

// Read text file content (for in-app preview)
api.MapGet("/files/read", async (FileService svc, string path, int? maxBytes) =>
{
    try
    {
        var bytes = maxBytes ?? 512_000; // Default 500KB max
        var content = await svc.ReadTextAsync(path, bytes);
        return Results.Ok(new { content, path, truncated = new System.IO.FileInfo(path).Length > bytes });
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

api.MapGet("/files/download", async (FileService svc, string path) =>
{
    var stream = svc.OpenRead(path);
    var fileName = Path.GetFileName(path);
    return Results.File(stream, "application/octet-stream", fileName);
});

api.MapPost("/files/upload", async (FileService svc, HttpRequest req) =>
{
    var dir = req.Query["dir"].ToString();
    if (string.IsNullOrEmpty(dir)) return Results.BadRequest("dir required");

    var form = await req.ReadFormAsync();
    foreach (var file in form.Files)
    {
        using var stream = file.OpenReadStream();
        await svc.SaveUploadAsync(dir, file.FileName, stream);
    }
    return Results.Ok();
}).DisableAntiforgery();

// Actions
api.MapPost("/actions/shutdown", (ActionService svc) => { svc.Shutdown(); return Results.Ok(); });
api.MapPost("/actions/restart", (ActionService svc) => { svc.Restart(); return Results.Ok(); });
api.MapPost("/actions/lock", (ActionService svc) => { svc.Lock(); return Results.Ok(); });
api.MapPost("/actions/sleep", (ActionService svc) => { svc.Sleep(); return Results.Ok(); });

api.MapGet("/actions/clipboard", (ActionService svc) => Results.Ok(new { text = svc.GetClipboard() }));
api.MapPost("/actions/clipboard", (ActionService svc, HttpRequest req) =>
{
    var body = req.Query["text"].ToString();
    svc.SetClipboard(body);
    return Results.Ok();
});

// WebSocket endpoint (auth via query string token)
app.Map("/ws", async (HttpContext context, WebSocketHandler handler) =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = 400;
        return;
    }

    // Validate auth - token passed as query param
    var authResult = await context.AuthenticateAsync(JwtBearerDefaults.AuthenticationScheme);
    if (!authResult.Succeeded)
    {
        context.Response.StatusCode = 401;
        return;
    }

    var ws = await context.WebSockets.AcceptWebSocketAsync();
    await handler.HandleAsync(ws, context.RequestAborted);
});

// ============ Startup Banner ============

app.Lifetime.ApplicationStarted.Register(() =>
{
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.WriteLine(@"
   ╔══════════════════════════════════════╗
   ║        ClaudeRemote Server           ║
   ╠══════════════════════════════════════╣");
    Console.ForegroundColor = ConsoleColor.Green;
    Console.WriteLine($"   ║  PIN:  {authService.Pin}                       ║");
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.WriteLine($"   ║  Port: {port}                          ║");
    Console.WriteLine($"   ║  Host: {Environment.MachineName,-28} ║");
    Console.WriteLine(@"   ╚══════════════════════════════════════╝");
    Console.ResetColor();
    Console.WriteLine();
    Console.WriteLine("  Waiting for connections...");
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.DarkYellow;
    Console.WriteLine("  Remote access (pick one):");
    Console.ResetColor();
    Console.WriteLine("    ngrok:      ngrok http " + port);
    Console.WriteLine("    cloudflare: cloudflared tunnel --url http://localhost:" + port);
    Console.WriteLine("    bore:       bore local " + port + " --to bore.pub");
    Console.WriteLine();
    Console.WriteLine("  Press Ctrl+C to stop the server.");
    Console.WriteLine();
});

app.Run();
