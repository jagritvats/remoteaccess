# ClaudeRemote Server

Windows background service that exposes system control via REST API + WebSocket. Built with ASP.NET Core Minimal APIs on .NET 10.0.

## Architecture

```
Program.cs                          ← Entry point, all endpoint routing
├── Services/
│   ├── AuthService.cs              ← PIN generation + JWT token issuance
│   ├── TerminalService.cs          ← ConPTY session manager (VT100 terminal)
│   ├── SystemInfoService.cs        ← CPU/RAM/disk via WMI + PerformanceCounter
│   ├── FileService.cs              ← Filesystem CRUD + text file reading
│   ├── ActionService.cs            ← Lock/sleep/shutdown/clipboard (P/Invoke)
│   ├── ScreenCaptureService.cs     ← GDI screen capture → JPEG
│   ├── DiscoveryService.cs         ← UDP broadcast on port 41234
│   └── ConPty/
│       ├── NativeMethods.cs        ← kernel32.dll P/Invoke declarations
│       └── PseudoConsole.cs        ← ConPTY lifecycle (pipes, process, resize)
├── Hubs/
│   └── WebSocketHandler.cs         ← WebSocket message dispatcher + stats streaming
└── Models/
    ├── MessageEnvelope.cs          ← WebSocket message wrapper + type constants
    ├── AuthModels.cs               ← PairRequest/PairResponse/PairedDevice DTOs
    └── SystemModels.cs             ← SystemInfo/DiskInfo/ProcessInfo/FileEntry DTOs
```

## How It Works

### Startup Flow
1. `Program.cs` registers all services as singletons in DI
2. JWT Bearer auth configured with server-generated secret
3. CORS enabled for tunnel proxy support
4. `DiscoveryService` starts broadcasting on UDP 41234
5. Kestrel listens on `http://0.0.0.0:8443`
6. Console displays PIN and tunnel setup instructions

### Authentication
- Server generates a random 6-digit PIN on startup (displayed in console)
- Client sends `POST /api/pair { pin, deviceName }` — no auth required
- Server validates PIN, returns JWT token (7-day expiry)
- All subsequent requests require `Authorization: Bearer <token>`
- WebSocket auth: token passed as `?token=<jwt>` query parameter

### Terminal (ConPTY)
The terminal uses Windows Pseudo Console (ConPTY) — the same API that Windows Terminal uses.

**Data flow:**
```
Client keystroke → WebSocket terminalInput → TerminalSession.WriteInput()
                                              ↓ (writes to ConPTY input pipe)
                                            ConPTY + cmd.exe
                                              ↓ (VT100 output on output pipe)
TerminalSession.ReadOutputLoop() → OutputReceived event → WebSocket terminalOutput → Client xterm.write()
```

**Key files:**
- `ConPty/NativeMethods.cs`: P/Invoke for `CreatePseudoConsole`, `ResizePseudoConsole`, `ClosePseudoConsole`, `CreatePipe`, `CreateProcessW`
- `ConPty/PseudoConsole.cs`: Manages pipes, ConPTY handle, child process lifecycle
- `TerminalService.cs`: `TerminalSession` wraps PseudoConsole with event-based output + `TerminalManager` manages multiple sessions

**Why ConPTY over Process.Start:**
- VT100/ANSI escape sequences in output (colors, cursor positioning)
- Interactive programs work (python REPL, vim, tab completion)
- Resize support via `ResizePseudoConsole`
- UTF-8 encoding (not codepage 437)
- Proper prompt display (no line-buffering issues)

### WebSocket Protocol
All messages use a JSON envelope: `{ type, id, payload, timestamp }`

| Type | Direction | Purpose |
|------|-----------|---------|
| `terminalCreate` | client→server | Create new ConPTY session |
| `terminalCreated` | server→client | Returns `{ sessionId }` |
| `terminalInput` | client→server | Send keystrokes `{ sessionId, data }` |
| `terminalOutput` | server→client | VT100 output `{ sessionId, data }` |
| `terminalResize` | client→server | Resize `{ sessionId, cols, rows }` |
| `terminalClose` | client→server | Close session `{ sessionId }` |
| `subscribeStats` | client→server | Start 3s stats push |
| `unsubscribeStats` | client→server | Stop stats push |
| `systemStats` | server→client | CPU/RAM/disk metrics |
| `screenCapture` | client→server | Request screenshot |
| *(binary frame)* | server→client | JPEG screenshot data |
| `ping` | client→server | Heartbeat |
| `pong` | server→client | Heartbeat response |

### REST Endpoints

**Public (no auth):**
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| POST | `/api/pair` | Pair with PIN |

**Authenticated:**
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/system` | CPU/RAM/disk/uptime |
| GET | `/api/processes?top=50` | Process list |
| DELETE | `/api/processes/{pid}` | Kill process |
| GET | `/api/files?path=C:\` | List directory (omit path for drives) |
| GET | `/api/files/read?path=...` | Read text file (max 500KB) |
| POST | `/api/files/mkdir?path=...` | Create directory |
| DELETE | `/api/files?path=...` | Delete file/dir |
| PUT | `/api/files/rename?oldPath=...&newPath=...` | Rename |
| GET | `/api/files/download?path=...` | Download file |
| POST | `/api/files/upload?dir=...` | Upload (multipart) |
| POST | `/api/actions/shutdown` | Shutdown PC |
| POST | `/api/actions/restart` | Restart PC |
| POST | `/api/actions/lock` | Lock screen |
| POST | `/api/actions/sleep` | Sleep PC |
| GET | `/api/actions/clipboard` | Get clipboard text |
| POST | `/api/actions/clipboard?text=...` | Set clipboard text |

### System Info Collection
- **CPU**: `PerformanceCounter("Processor", "% Processor Time", "_Total")` — first call always returns 0
- **RAM**: WMI `Win32_OperatingSystem` → `TotalVisibleMemorySize`, `FreePhysicalMemory`
- **Disk**: `DriveInfo.GetDrives()` → fixed drives only
- **Processes**: `Process.GetProcesses()` sorted by WorkingSet64

### Remote Access (Tunnels)
Server supports tunnel proxies via CORS + `ForwardedHeaders` middleware. No server changes needed — just run a tunnel alongside the server:

```bash
ngrok http 8443                                    # ngrok
cloudflared tunnel --url http://localhost:8443      # Cloudflare
bore local 8443 --to bore.pub                      # bore
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| Microsoft.AspNetCore.Authentication.JwtBearer | 10.0.5 | JWT auth |
| System.IdentityModel.Tokens.Jwt | 8.16.0 | Token generation |
| System.Management | 10.0.5 | WMI queries |

Framework: `net10.0-windows` with `UseWindowsForms` (for Clipboard + Screen capture)

## Enhancement Ideas

- **ConPTY → PowerShell default**: Change `cmd.exe` to `pwsh.exe` or `powershell.exe`
- **Persistent pairing**: Store paired devices to disk (JSON/SQLite)
- **HTTPS**: Self-signed TLS certificate for direct LAN connections
- **System tray**: WinForms `NotifyIcon` for background operation
- **Notifications**: Forward Windows notifications to client
- **Multi-client**: Current WebSocket handler wires terminal output to ALL connected clients — needs per-client session tracking
- **File streaming**: Large file upload/download with progress
- **Audio**: NAudio for volume control instead of PowerShell
