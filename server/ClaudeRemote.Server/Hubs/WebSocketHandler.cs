using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using ClaudeRemote.Server.Models;
using ClaudeRemote.Server.Services;

namespace ClaudeRemote.Server.Hubs;

public class WebSocketHandler
{
    private readonly TerminalManager _terminalManager;
    private readonly SystemInfoService _systemInfoService;
    private readonly ScreenCaptureService _screenCaptureService;
    private readonly ILogger<WebSocketHandler> _logger;

    public WebSocketHandler(
        TerminalManager terminalManager,
        SystemInfoService systemInfoService,
        ScreenCaptureService screenCaptureService,
        ILogger<WebSocketHandler> logger)
    {
        _terminalManager = terminalManager;
        _systemInfoService = systemInfoService;
        _screenCaptureService = screenCaptureService;
        _logger = logger;
    }

    private class ClientState
    {
        public CancellationTokenSource? StatsSubscription;
    }

    public async Task HandleAsync(WebSocket webSocket, CancellationToken ct)
    {
        _logger.LogInformation("WebSocket client connected");

        var sendLock = new SemaphoreSlim(1, 1);
        var state = new ClientState();

        // Wire up terminal output → WebSocket
        _terminalManager.OutputReceived += async (sessionId, data) =>
        {
            if (webSocket.State != WebSocketState.Open) return;
            var msg = MessageEnvelope.Create(MessageTypes.TerminalOutput, new { sessionId, data });
            await SendJsonAsync(webSocket, msg, sendLock, ct);
        };

        var buffer = new byte[4096];

        try
        {
            while (webSocket.State == WebSocketState.Open && !ct.IsCancellationRequested)
            {
                var result = await webSocket.ReceiveAsync(buffer, ct);

                if (result.MessageType == WebSocketMessageType.Close)
                    break;

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var json = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    var envelope = JsonSerializer.Deserialize<MessageEnvelope>(json);
                    if (envelope is null) continue;

                    await DispatchAsync(webSocket, envelope, sendLock, state, ct);
                }
            }
        }
        catch (WebSocketException) { /* client disconnected */ }
        catch (OperationCanceledException) { /* server shutting down */ }
        finally
        {
            state.StatsSubscription?.Cancel();
            if (webSocket.State == WebSocketState.Open)
                await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Bye", CancellationToken.None);
            _logger.LogInformation("WebSocket client disconnected");
        }
    }

    private async Task DispatchAsync(
        WebSocket ws, MessageEnvelope envelope, SemaphoreSlim sendLock,
        ClientState state, CancellationToken ct)
    {
        switch (envelope.Type)
        {
            case MessageTypes.TerminalInput:
                var input = envelope.GetPayload<TerminalInput>();
                if (input is null) break;
                var session = _terminalManager.GetSession(input.SessionId);
                session?.WriteInput(input.Data);
                break;

            case MessageTypes.TerminalResize:
                var resize = envelope.GetPayload<TerminalResize>();
                if (resize is not null)
                {
                    var resizeSession = _terminalManager.GetSession(resize.SessionId);
                    resizeSession?.Resize((short)resize.Cols, (short)resize.Rows);
                }
                break;

            case MessageTypes.TerminalClose:
                var closePayload = envelope.GetPayload<TerminalInput>();
                if (closePayload is not null)
                    _terminalManager.CloseSession(closePayload.SessionId);
                break;

            case "terminalCreate":
                var newSession = _terminalManager.CreateSession();
                var created = MessageEnvelope.Create(MessageTypes.TerminalCreated, new { sessionId = newSession.Id });
                await SendJsonAsync(ws, created, sendLock, ct);
                break;

            case MessageTypes.SubscribeStats:
                state.StatsSubscription?.Cancel();
                state.StatsSubscription = new CancellationTokenSource();
                _ = PushStatsLoopAsync(ws, sendLock, state.StatsSubscription.Token);
                break;

            case MessageTypes.UnsubscribeStats:
                state.StatsSubscription?.Cancel();
                state.StatsSubscription = null;
                break;

            case MessageTypes.ScreenCapture:
                try
                {
                    var frame = _screenCaptureService.CaptureScreen();
                    await sendLock.WaitAsync(ct);
                    try
                    {
                        await ws.SendAsync(frame, WebSocketMessageType.Binary, true, ct);
                    }
                    finally { sendLock.Release(); }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Screen capture failed");
                }
                break;

            case "ping":
                var pong = MessageEnvelope.Create("pong", new { });
                await SendJsonAsync(ws, pong, sendLock, ct);
                break;

            default:
                _logger.LogWarning("Unknown message type: {Type}", envelope.Type);
                break;
        }
    }

    private async Task PushStatsLoopAsync(WebSocket ws, SemaphoreSlim sendLock, CancellationToken ct)
    {
        while (!ct.IsCancellationRequested && ws.State == WebSocketState.Open)
        {
            try
            {
                var stats = _systemInfoService.GetSystemInfo();
                var msg = MessageEnvelope.Create(MessageTypes.SystemStats, stats);
                await SendJsonAsync(ws, msg, sendLock, ct);
                await Task.Delay(3000, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Stats push failed");
                break;
            }
        }
    }

    private static async Task SendJsonAsync(
        WebSocket ws, MessageEnvelope msg, SemaphoreSlim sendLock, CancellationToken ct)
    {
        if (ws.State != WebSocketState.Open) return;
        var json = JsonSerializer.Serialize(msg);
        var data = Encoding.UTF8.GetBytes(json);
        await sendLock.WaitAsync(ct);
        try
        {
            await ws.SendAsync(data, WebSocketMessageType.Text, true, ct);
        }
        finally { sendLock.Release(); }
    }
}
