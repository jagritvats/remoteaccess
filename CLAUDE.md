# ClaudeRemote — Developer Reference

## Project Overview

ClaudeRemote is a remote access system for Windows PCs, controlled from an Android phone. Two separate codebases communicate over WebSocket (real-time) and REST API (CRUD).

| Component | Tech | Location |
|-----------|------|----------|
| Server | C# / .NET 10.0 (ASP.NET Core Minimal APIs) | `server/ClaudeRemote.Server/` |
| App | Flutter 3.41.4 / Dart 3.11.1 | `app/` |
| Protocol | JSON/WebSocket + REST, JWT auth | `protocol/messages.md` |

## Quick Start

```bash
# Server (Windows)
cd server/ClaudeRemote.Server
dotnet run
# → Shows PIN, listens on port 8443

# App (Android device/emulator)
cd app
flutter run
# → Discovery screen → Enter PIN → Connected

# Remote access (optional)
ngrok http 8443
# → Paste tunnel URL in app's "Remote / Tunnel" field
```

## Build Commands

```bash
# Server
dotnet build                          # Debug build
dotnet build -c Release               # Release build
dotnet publish -r win-x64 --self-contained -p:PublishTrimmed=true  # Single exe

# App
flutter analyze --no-fatal-infos      # Lint check
flutter build apk --release           # Release APK
flutter run                           # Debug run
```

## Architecture

```
Phone (Flutter)                    Windows PC (C# .NET)
┌──────────────┐                   ┌──────────────────────┐
│ Discovery    │ ←── UDP 41234 ──→ │ DiscoveryService     │
│ Pair Screen  │ ── POST /pair ──→ │ AuthService (PIN+JWT)│
│              │                   │                      │
│ Dashboard    │ ←── WS stats ───→ │ SystemInfoService    │
│ Terminal     │ ←── WS VT100 ───→ │ ConPTY + cmd.exe     │
│ Files        │ ←── REST CRUD ──→ │ FileService          │
│ Actions      │ ←── REST ───────→ │ ActionService        │
│ Screen View  │ ←── WS binary ──→ │ ScreenCaptureService │
└──────────────┘                   └──────────────────────┘
```

## Key Conventions

- **State management**: Riverpod `StateNotifier` + `StateNotifierProvider`
- **Navigation**: GoRouter with `StatefulShellRoute` for bottom nav tabs
- **HTTP**: Dio with Bearer token interceptor
- **WebSocket**: Custom `WebSocketClient` with auto-reconnect + message routing
- **Terminal**: Windows ConPTY (pseudo console) → VT100/ANSI → xterm.dart
- **Auth**: 6-digit PIN pairing → JWT token (7-day expiry)
- **Server port**: 8443 (configurable via `Server:Port` in appsettings)
- **Discovery port**: UDP 41234

## Provider Lifecycle Pattern

Providers that depend on WebSocket must watch **state** (not notifier) to auto-recreate when connection changes:

```dart
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  ref.watch(connectionProvider);  // Watch STATE → triggers rebuild on connect
  final conn = ref.read(connectionProvider.notifier);  // Read notifier for wsClient
  return MyNotifier(conn.wsClient);
});
```

## Testing Checklist

1. Server health: `curl http://localhost:8443/api/health`
2. Discovery: Server + app on same WiFi → auto-detect
3. Emulator: App auto-detects host at 10.0.2.2:8443
4. Terminal: `dir`, `python`, `vim` all work with colors
5. Dashboard: CPU/RAM/disk gauges update every 3s
6. Files: Browse, upload, download, view text files
7. Actions: Lock, clipboard sync, screen viewer
8. Remote: ngrok/cloudflare tunnel → paste URL → pair
