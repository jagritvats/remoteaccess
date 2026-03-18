using System.Text.Json.Serialization;

namespace ClaudeRemote.Server.Models;

public class PairRequest
{
    [JsonPropertyName("pin")]
    public string Pin { get; set; } = string.Empty;

    [JsonPropertyName("deviceName")]
    public string DeviceName { get; set; } = string.Empty;
}

public class PairResponse
{
    [JsonPropertyName("token")]
    public string Token { get; set; } = string.Empty;

    [JsonPropertyName("serverName")]
    public string ServerName { get; set; } = string.Empty;

    [JsonPropertyName("expiresAt")]
    public long ExpiresAt { get; set; }
}

public class PairedDevice
{
    public string DeviceName { get; set; } = string.Empty;
    public string TokenId { get; set; } = string.Empty;
    public DateTime PairedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
}
