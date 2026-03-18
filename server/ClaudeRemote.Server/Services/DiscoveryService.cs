using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace ClaudeRemote.Server.Services;

public class DiscoveryService : BackgroundService
{
    private readonly int _serverPort;
    private readonly ILogger<DiscoveryService> _logger;
    private const int BroadcastPort = 41234;
    private const int BroadcastIntervalMs = 3000;

    public DiscoveryService(IConfiguration config, ILogger<DiscoveryService> logger)
    {
        _serverPort = config.GetValue("Server:Port", 8443);
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Discovery service started, broadcasting on UDP port {Port}", BroadcastPort);

        using var udpClient = new UdpClient();
        udpClient.EnableBroadcast = true;

        var broadcastEndpoint = new IPEndPoint(IPAddress.Broadcast, BroadcastPort);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var announcement = JsonSerializer.Serialize(new
                {
                    service = "clauderemote",
                    host = GetLocalIpAddress(),
                    port = _serverPort,
                    name = Environment.MachineName
                });

                var data = Encoding.UTF8.GetBytes(announcement);
                await udpClient.SendAsync(data, data.Length, broadcastEndpoint);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send discovery broadcast");
            }

            await Task.Delay(BroadcastIntervalMs, stoppingToken);
        }
    }

    private static string GetLocalIpAddress()
    {
        foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (ni.OperationalStatus != OperationalStatus.Up) continue;
            if (ni.NetworkInterfaceType is NetworkInterfaceType.Loopback or NetworkInterfaceType.Tunnel) continue;

            foreach (var addr in ni.GetIPProperties().UnicastAddresses)
            {
                if (addr.Address.AddressFamily == AddressFamily.InterNetwork)
                    return addr.Address.ToString();
            }
        }
        return "127.0.0.1";
    }
}
