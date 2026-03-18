using System.Text.Json;
using System.Text.Json.Serialization;

namespace ClaudeRemote.Server.Models;

public class MessageEnvelope
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString("N")[..8];

    [JsonPropertyName("payload")]
    public JsonElement? Payload { get; set; }

    [JsonPropertyName("timestamp")]
    public long Timestamp { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    public static MessageEnvelope Create<T>(string type, T payload)
    {
        var json = JsonSerializer.Serialize(payload);
        return new MessageEnvelope
        {
            Type = type,
            Payload = JsonDocument.Parse(json).RootElement
        };
    }

    public T? GetPayload<T>() =>
        Payload.HasValue ? JsonSerializer.Deserialize<T>(Payload.Value.GetRawText()) : default;
}

public static class MessageTypes
{
    // Terminal
    public const string TerminalCreate = "terminalCreate";
    public const string TerminalCreated = "terminalCreated";
    public const string TerminalAttach = "terminalAttach";
    public const string TerminalInput = "terminalInput";
    public const string TerminalOutput = "terminalOutput";
    public const string TerminalResize = "terminalResize";
    public const string TerminalClose = "terminalClose";

    // System
    public const string SystemStats = "systemStats";
    public const string SubscribeStats = "subscribeStats";
    public const string UnsubscribeStats = "unsubscribeStats";

    // Screen
    public const string ScreenCapture = "screenCapture";
    public const string ScreenFrame = "screenFrame";

    // Errors
    public const string Error = "error";
}
