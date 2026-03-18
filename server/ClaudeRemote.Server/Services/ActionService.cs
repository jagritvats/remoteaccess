using System.Diagnostics;
using System.Runtime.InteropServices;

namespace ClaudeRemote.Server.Services;

public class ActionService
{
    [DllImport("user32.dll")]
    private static extern bool LockWorkStation();

    [DllImport("powrprof.dll")]
    private static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);

    public void Lock() => LockWorkStation();

    public void Sleep() => SetSuspendState(false, true, false);

    public void Shutdown()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "shutdown",
            Arguments = "/s /t 0",
            CreateNoWindow = true,
            UseShellExecute = false
        });
    }

    public void Restart()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "shutdown",
            Arguments = "/r /t 0",
            CreateNoWindow = true,
            UseShellExecute = false
        });
    }

    public int GetVolume()
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = "-NoProfile -Command \"(Get-AudioDevice -PlaybackVolume).Replace('%','').Trim()\"",
                RedirectStandardOutput = true,
                CreateNoWindow = true,
                UseShellExecute = false
            };
            using var proc = Process.Start(psi);
            var output = proc?.StandardOutput.ReadToEnd().Trim();
            return int.TryParse(output, out var vol) ? vol : -1;
        }
        catch { return -1; }
    }

    public void SetVolume(int level)
    {
        // Use nircmd if available, fallback to PowerShell
        var psi = new ProcessStartInfo
        {
            FileName = "powershell",
            Arguments = $"-NoProfile -Command \"Set-AudioDevice -PlaybackVolume {level}\"",
            CreateNoWindow = true,
            UseShellExecute = false
        };
        Process.Start(psi)?.WaitForExit(3000);
    }

    public string GetClipboard()
    {
        string result = string.Empty;
        var thread = new Thread(() =>
        {
            try
            {
                if (System.Windows.Forms.Clipboard.ContainsText())
                    result = System.Windows.Forms.Clipboard.GetText();
            }
            catch { }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join(2000);
        return result;
    }

    public void SetClipboard(string text)
    {
        var thread = new Thread(() =>
        {
            try { System.Windows.Forms.Clipboard.SetText(text); }
            catch { }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join(2000);
    }
}
