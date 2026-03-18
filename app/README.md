# ClaudeRemote App

Flutter Android app for remote access to Windows PCs. Connects over LAN or internet (via tunnel).

## Architecture

```
lib/
├── main.dart                                    ← App entry, ProviderScope, MaterialApp.router
└── src/
    ├── core/
    │   ├── theme/app_theme.dart                 ← Material 3 light/dark theme (seed: purple)
    │   ├── router/app_router.dart               ← GoRouter with StatefulShellRoute (4 tabs)
    │   ├── providers/
    │   │   └── connection_provider.dart          ← Central connection state + API/WS management
    │   └── services/
    │       ├── api_client.dart                   ← Dio REST client with Bearer auth
    │       ├── websocket_client.dart             ← WS client with auto-reconnect + heartbeat
    │       └── discovery_service.dart            ← UDP listener for LAN server broadcasts
    └── features/
        ├── connection/screens/
        │   ├── discovery_screen.dart             ← Emulator + LAN + Remote + Manual connection
        │   └── pair_screen.dart                  ← 6-digit PIN entry
        ├── home/screens/
        │   └── home_shell.dart                   ← Bottom nav (Dashboard/Terminal/Files/Actions)
        ├── dashboard/
        │   ├── providers/system_provider.dart     ← WebSocket stats subscription
        │   └── screens/dashboard_screen.dart      ← CPU/RAM/disk gauges
        ├── terminal/
        │   ├── providers/terminal_provider.dart    ← ConPTY session management
        │   └── screens/terminal_screen.dart        ← xterm widget + special keys toolbar
        ├── files/
        │   ├── providers/file_provider.dart        ← File browser state + CRUD
        │   ├── screens/file_browser_screen.dart    ← Breadcrumb nav + file list
        │   └── screens/file_viewer_screen.dart     ← Text file content viewer
        ├── actions/screens/
        │   ├── actions_screen.dart                 ← Power actions + clipboard
        │   └── screen_viewer_screen.dart           ← Live screenshot viewer
        └── settings/screens/
            └── settings_screen.dart                ← Connection info + disconnect
```

## State Management

**Riverpod** with `StateNotifier` pattern throughout.

### Provider Dependency Graph

```
connectionProvider (StateNotifierProvider<ConnectionNotifier, ConnectionState>)
  ├── systemStatsProvider    ← watches connectionProvider state, reads wsClient
  ├── terminalProvider       ← watches connectionProvider state, reads wsClient
  ├── fileBrowserProvider    ← reads connectionProvider notifier for apiClient
  └── routerProvider         ← watches connectionProvider for initial route
```

**Critical pattern** — providers that need `wsClient` must watch the **state** (not the notifier) so they auto-recreate when connection status changes:

```dart
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  ref.watch(connectionProvider);                       // Triggers rebuild on state change
  final conn = ref.read(connectionProvider.notifier);  // Access wsClient/apiClient
  return MyNotifier(conn.wsClient);
});
```

### ConnectionState Lifecycle

```
App Start → Load saved baseUrl/token from SecureStorage
  ├── Found → connect() → WebSocket opens → isConnected=true → route to /dashboard
  └── Not found → route to /discover
         ↓
Discovery Screen → User selects server
         ↓
Pair Screen → User enters PIN → pair()/pairWithUrl()
         ↓
Store baseUrl + token → connect() → WebSocket → /dashboard
```

## Navigation

**GoRouter** with `StatefulShellRoute.indexedStack` for bottom nav:

| Route | Screen | Tab Index |
|-------|--------|-----------|
| `/discover` | DiscoveryScreen | — |
| `/pair` | PairScreen | — |
| `/dashboard` | DashboardScreen | 0 |
| `/terminal` | TerminalScreen | 1 |
| `/files` | FileBrowserScreen | 2 |
| `/actions` | ActionsScreen | 3 |
| `/screen-viewer` | ScreenViewerScreen | — (push) |
| `/file-viewer` | FileViewerScreen | — (push) |
| `/settings` | SettingsScreen | — (push) |

Tab state is preserved when switching (IndexedStack).

## Feature Details

### Terminal
- Uses `xterm` package (v4.0.0) for VT100/ANSI rendering
- Server runs Windows ConPTY — full color, interactive programs, resize
- Multi-session tabs with session management
- Special keys toolbar: ESC, TAB, CTRL, arrows, |, /, ~, Ctrl+C/D/Z/L
- Font size: 8-24px (adjustable)
- Session lifecycle: `terminalCreate` → `terminalCreated` → `terminalInput`/`terminalOutput` → `terminalClose`

### Dashboard
- Real-time stats pushed every 3 seconds via WebSocket
- CPU: circular gauge (green/orange/red thresholds at 60%/80%)
- RAM: circular gauge with GB readout
- Disks: linear progress bars per drive
- Pull-to-refresh re-subscribes

### Files
- Breadcrumb navigation starting from drive list
- 50+ viewable text extensions (opens in-app viewer)
- Context menu: rename, delete, download
- FAB: upload file, create folder
- File icons by extension type

### Actions
- Power: Lock, Sleep, Restart, Shutdown (all with confirmation dialogs)
- Clipboard: Pull from PC, Push to PC
- Screen Viewer: JPEG streaming with 0.5-5 fps slider, pinch-to-zoom

### Connection Modes
1. **LAN Discovery**: Auto-detect via UDP broadcast on port 41234
2. **Emulator**: Auto-detect host at `10.0.2.2:8443`
3. **Remote URL**: Paste ngrok/cloudflare/bore tunnel URL
4. **Manual**: Enter IP + port

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | 2.6.1 | State management |
| go_router | 14.8.1 | Declarative routing |
| dio | 5.7.0 | HTTP client |
| web_socket_channel | 3.0.2 | WebSocket |
| flutter_secure_storage | 9.2.4 | Encrypted token storage |
| xterm | 4.0.0 | Terminal emulator widget |
| fl_chart | 0.70.2 | Charts (available, lightly used) |
| percent_indicator | 4.2.3 | CPU/RAM/disk gauges |
| file_picker | 8.1.7 | File upload picker |
| google_fonts | 6.2.1 | Inter font family |

## Enhancement Ideas

- **SSH support**: Use `dartssh2` package alongside xterm for direct SSH
- **Biometric auth**: Fingerprint/face instead of PIN for re-pairing
- **Dark terminal themes**: Theme selector for terminal (currently whiteOnBlack)
- **File preview**: Image preview (JPEG/PNG), PDF viewer
- **Drag and drop upload**: From other apps into file browser
- **Notification forwarding**: Receive Windows notifications as push
- **Process manager screen**: Full process list with search, sort, kill
- **Offline indicator**: Banner when connection lost, auto-hide on reconnect
- **Connection profiles**: Save multiple servers (home PC, work PC)
- **Landscape terminal**: Full-screen terminal on rotation
