using System.Collections.Concurrent;
using System.Text;
using ClaudeRemote.Server.Services.ConPty;

namespace ClaudeRemote.Server.Services;

/// <summary>
/// A terminal session backed by Windows ConPTY (pseudo console).
/// Produces VT100/ANSI output that xterm.dart can render directly.
/// </summary>
public class TerminalSession : IDisposable
{
    public string Id { get; }
    private readonly PseudoConsole _conPty = new();
    private readonly CancellationTokenSource _cts = new();
    private bool _disposed;

    public event Action<string, string>? OutputReceived; // sessionId, data

    public TerminalSession(string id, short cols = 50, short rows = 20, string? shell = null)
    {
        Id = id;
        _conPty.Start(cols, rows, shell);
    }

    /// <summary>Start reading output from the ConPTY. Call after wiring OutputReceived.</summary>
    public void BeginReading()
    {
        _ = Task.Run(() => ReadOutputLoop(_cts.Token));
    }

    private void ReadOutputLoop(CancellationToken ct)
    {
        var buffer = new byte[4096];
        var reader = _conPty.ReaderStream;
        if (reader is null) return;

        try
        {
            while (!ct.IsCancellationRequested)
            {
                var bytesRead = reader.Read(buffer, 0, buffer.Length);
                if (bytesRead == 0) break;

                // ConPTY outputs UTF-8 encoded VT100 sequences
                var text = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                OutputReceived?.Invoke(Id, text);
            }
        }
        catch (ObjectDisposedException) { }
        catch (IOException) { }
        catch { /* stream closed */ }
    }

    public void WriteInput(string data)
    {
        if (_disposed) return;
        try
        {
            var bytes = Encoding.UTF8.GetBytes(data);
            _conPty.WriterStream?.Write(bytes, 0, bytes.Length);
            _conPty.WriterStream?.Flush();
        }
        catch { /* stream closed */ }
    }

    public void Resize(short cols, short rows)
    {
        if (_disposed) return;
        _conPty.Resize(cols, rows);
    }

    public bool IsAlive => !_disposed && _conPty.IsRunning;

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _cts.Cancel();
        _conPty.Dispose();
        _cts.Dispose();
    }
}

public class TerminalManager : IDisposable
{
    private readonly ConcurrentDictionary<string, TerminalSession> _sessions = new();

    public event Action<string, string>? OutputReceived; // sessionId, data

    public TerminalSession CreateSession(short cols = 50, short rows = 20, string? shell = null)
    {
        var id = Guid.NewGuid().ToString("N")[..8];
        var session = new TerminalSession(id, cols, rows, shell);
        session.OutputReceived += (sid, data) => OutputReceived?.Invoke(sid, data);
        _sessions[id] = session;
        session.BeginReading(); // Start reading AFTER event handler is wired
        return session;
    }

    public TerminalSession? GetSession(string id) =>
        _sessions.TryGetValue(id, out var session) && session.IsAlive ? session : null;

    public void CloseSession(string id)
    {
        if (_sessions.TryRemove(id, out var session))
            session.Dispose();
    }

    public IEnumerable<string> GetActiveSessionIds() =>
        _sessions.Where(kv => kv.Value.IsAlive).Select(kv => kv.Key);

    public void Dispose()
    {
        foreach (var session in _sessions.Values)
            session.Dispose();
        _sessions.Clear();
    }
}
