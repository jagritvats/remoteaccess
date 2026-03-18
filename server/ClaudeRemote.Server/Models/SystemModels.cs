using System.Text.Json.Serialization;

namespace ClaudeRemote.Server.Models;

public class SystemInfo
{
    [JsonPropertyName("cpuUsage")]
    public double CpuUsage { get; set; }

    [JsonPropertyName("totalRamMb")]
    public long TotalRamMb { get; set; }

    [JsonPropertyName("usedRamMb")]
    public long UsedRamMb { get; set; }

    [JsonPropertyName("disks")]
    public List<DiskInfo> Disks { get; set; } = [];

    [JsonPropertyName("hostname")]
    public string Hostname { get; set; } = string.Empty;

    [JsonPropertyName("uptime")]
    public string Uptime { get; set; } = string.Empty;
}

public class DiskInfo
{
    [JsonPropertyName("drive")]
    public string Drive { get; set; } = string.Empty;

    [JsonPropertyName("totalGb")]
    public double TotalGb { get; set; }

    [JsonPropertyName("freeGb")]
    public double FreeGb { get; set; }
}

public class ProcessInfo
{
    [JsonPropertyName("pid")]
    public int Pid { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("memoryMb")]
    public double MemoryMb { get; set; }

    [JsonPropertyName("cpuPercent")]
    public double CpuPercent { get; set; }
}

public class FileEntry
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("isDirectory")]
    public bool IsDirectory { get; set; }

    [JsonPropertyName("size")]
    public long Size { get; set; }

    [JsonPropertyName("modified")]
    public DateTime Modified { get; set; }
}

public class TerminalInput
{
    [JsonPropertyName("sessionId")]
    public string SessionId { get; set; } = string.Empty;

    [JsonPropertyName("data")]
    public string Data { get; set; } = string.Empty;
}

public class TerminalResize
{
    [JsonPropertyName("sessionId")]
    public string SessionId { get; set; } = string.Empty;

    [JsonPropertyName("cols")]
    public int Cols { get; set; } = 80;

    [JsonPropertyName("rows")]
    public int Rows { get; set; } = 24;
}
