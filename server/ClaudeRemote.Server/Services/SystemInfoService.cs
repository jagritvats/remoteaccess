using System.Diagnostics;
using System.Management;
using ClaudeRemote.Server.Models;

namespace ClaudeRemote.Server.Services;

public class SystemInfoService
{
    private readonly PerformanceCounter? _cpuCounter;

    public SystemInfoService()
    {
        try
        {
            _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
            _cpuCounter.NextValue(); // First call always returns 0
        }
        catch
        {
            _cpuCounter = null;
        }
    }

    public SystemInfo GetSystemInfo()
    {
        var info = new SystemInfo
        {
            Hostname = Environment.MachineName,
            CpuUsage = GetCpuUsage(),
            Uptime = GetUptime()
        };

        // RAM via WMI
        try
        {
            using var searcher = new ManagementObjectSearcher("SELECT TotalVisibleMemorySize, FreePhysicalMemory FROM Win32_OperatingSystem");
            foreach (var obj in searcher.Get())
            {
                var totalKb = Convert.ToInt64(obj["TotalVisibleMemorySize"]);
                var freeKb = Convert.ToInt64(obj["FreePhysicalMemory"]);
                info.TotalRamMb = totalKb / 1024;
                info.UsedRamMb = (totalKb - freeKb) / 1024;
            }
        }
        catch { /* WMI may fail */ }

        // Disks
        foreach (var drive in DriveInfo.GetDrives())
        {
            if (!drive.IsReady || drive.DriveType != DriveType.Fixed) continue;
            info.Disks.Add(new DiskInfo
            {
                Drive = drive.Name.TrimEnd('\\'),
                TotalGb = Math.Round(drive.TotalSize / 1_073_741_824.0, 1),
                FreeGb = Math.Round(drive.AvailableFreeSpace / 1_073_741_824.0, 1)
            });
        }

        return info;
    }

    public List<ProcessInfo> GetProcesses(int top = 50)
    {
        return Process.GetProcesses()
            .Select(p =>
            {
                try
                {
                    return new ProcessInfo
                    {
                        Pid = p.Id,
                        Name = p.ProcessName,
                        MemoryMb = Math.Round(p.WorkingSet64 / 1_048_576.0, 1)
                    };
                }
                catch { return null; }
            })
            .Where(p => p is not null)
            .OrderByDescending(p => p!.MemoryMb)
            .Take(top)
            .ToList()!;
    }

    public bool KillProcess(int pid)
    {
        try
        {
            var process = Process.GetProcessById(pid);
            process.Kill(entireProcessTree: true);
            return true;
        }
        catch { return false; }
    }

    private double GetCpuUsage()
    {
        try
        {
            return _cpuCounter is not null ? Math.Round(_cpuCounter.NextValue(), 1) : 0;
        }
        catch { return 0; }
    }

    private static string GetUptime()
    {
        var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
        return $"{(int)uptime.TotalDays}d {uptime.Hours}h {uptime.Minutes}m";
    }
}
