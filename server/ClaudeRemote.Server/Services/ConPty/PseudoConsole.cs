using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace ClaudeRemote.Server.Services.ConPty;

/// <summary>
/// Manages the lifecycle of a Windows Pseudo Console (ConPTY) session.
/// Creates pipes, pseudo console, and child process (cmd.exe).
/// </summary>
internal sealed class PseudoConsole : IDisposable
{
    private IntPtr _hPC;
    private IntPtr _hProcess;
    private IntPtr _hThread;
    private IntPtr _attributeList;
    private bool _disposed;

    /// <summary>Stream to write user input into the pseudo console.</summary>
    public FileStream? WriterStream { get; private set; }

    /// <summary>Stream to read VT100 output from the pseudo console.</summary>
    public FileStream? ReaderStream { get; private set; }

    public int ProcessId { get; private set; }

    public bool IsRunning
    {
        get
        {
            if (_hProcess == IntPtr.Zero) return false;
            try
            {
                var process = System.Diagnostics.Process.GetProcessById(ProcessId);
                return !process.HasExited;
            }
            catch { return false; }
        }
    }

    /// <summary>
    /// Creates a new ConPTY session running cmd.exe.
    /// </summary>
    public void Start(short cols, short rows, string? workingDirectory = null)
    {
        workingDirectory ??= Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        var sa = new SECURITY_ATTRIBUTES
        {
            nLength = Marshal.SizeOf<SECURITY_ATTRIBUTES>(),
            bInheritHandle = true
        };

        // Create input pipe: we write to inputWriteSide, ConPTY reads from inputReadSide
        if (!NativeMethods.CreatePipe(out var inputReadSide, out var inputWriteSide, ref sa, 0))
            throw new InvalidOperationException($"CreatePipe (input) failed: {Marshal.GetLastWin32Error()}");

        // Create output pipe: ConPTY writes to outputWriteSide, we read from outputReadSide
        if (!NativeMethods.CreatePipe(out var outputReadSide, out var outputWriteSide, ref sa, 0))
            throw new InvalidOperationException($"CreatePipe (output) failed: {Marshal.GetLastWin32Error()}");

        // Create the pseudo console
        var size = new COORD(cols, rows);
        var hr = NativeMethods.CreatePseudoConsole(size, inputReadSide, outputWriteSide, 0, out _hPC);
        if (hr != 0)
            throw new InvalidOperationException($"CreatePseudoConsole failed: HRESULT 0x{hr:X8}");

        // ConPTY now owns these sides of the pipes — close our copies
        inputReadSide.Dispose();
        outputWriteSide.Dispose();

        // We keep these for I/O
        WriterStream = new FileStream(inputWriteSide, FileAccess.Write);
        ReaderStream = new FileStream(outputReadSide, FileAccess.Read);

        // Prepare startup info with pseudo console attribute
        InitializeStartupInfo(out var startupInfo);

        // Create the child process (cmd.exe)
        var commandLine = "cmd.exe";
        if (!NativeMethods.CreateProcessW(
                null,
                commandLine,
                IntPtr.Zero,
                IntPtr.Zero,
                false,
                NativeMethods.EXTENDED_STARTUPINFO_PRESENT,
                IntPtr.Zero,
                workingDirectory,
                ref startupInfo,
                out var processInfo))
        {
            throw new InvalidOperationException($"CreateProcess failed: {Marshal.GetLastWin32Error()}");
        }

        _hProcess = processInfo.hProcess;
        _hThread = processInfo.hThread;
        ProcessId = processInfo.dwProcessId;
    }

    /// <summary>Resize the pseudo console buffer.</summary>
    public void Resize(short cols, short rows)
    {
        if (_hPC == IntPtr.Zero) return;
        NativeMethods.ResizePseudoConsole(_hPC, new COORD(cols, rows));
    }

    private void InitializeStartupInfo(out STARTUPINFOEX si)
    {
        si = default;
        si.StartupInfo.cb = Marshal.SizeOf<STARTUPINFOEX>();

        // Discover required size for attribute list
        var lpSize = IntPtr.Zero;
        NativeMethods.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref lpSize);

        // Allocate and initialize the attribute list
        _attributeList = Marshal.AllocHGlobal(lpSize);
        if (!NativeMethods.InitializeProcThreadAttributeList(_attributeList, 1, 0, ref lpSize))
            throw new InvalidOperationException($"InitializeProcThreadAttributeList failed: {Marshal.GetLastWin32Error()}");

        // Set the pseudo console handle as an attribute
        if (!NativeMethods.UpdateProcThreadAttribute(
                _attributeList,
                0,
                (IntPtr)NativeMethods.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                _hPC,
                (IntPtr)IntPtr.Size,
                IntPtr.Zero,
                IntPtr.Zero))
        {
            throw new InvalidOperationException($"UpdateProcThreadAttribute failed: {Marshal.GetLastWin32Error()}");
        }

        si.lpAttributeList = _attributeList;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        // Close pseudo console first (this will signal the child process to exit)
        if (_hPC != IntPtr.Zero)
        {
            NativeMethods.ClosePseudoConsole(_hPC);
            _hPC = IntPtr.Zero;
        }

        // Clean up streams
        WriterStream?.Dispose();
        ReaderStream?.Dispose();

        // Terminate the process if still running
        if (_hProcess != IntPtr.Zero)
        {
            try { NativeMethods.TerminateProcess(_hProcess, 0); } catch { }
            NativeMethods.CloseHandle(_hProcess);
            _hProcess = IntPtr.Zero;
        }

        if (_hThread != IntPtr.Zero)
        {
            NativeMethods.CloseHandle(_hThread);
            _hThread = IntPtr.Zero;
        }

        // Clean up attribute list
        if (_attributeList != IntPtr.Zero)
        {
            NativeMethods.DeleteProcThreadAttributeList(_attributeList);
            Marshal.FreeHGlobal(_attributeList);
            _attributeList = IntPtr.Zero;
        }
    }
}
