# ClaudeRemote Protocol

## Transport
- **REST API**: `http://<host>:8443/api/*` or `https://<tunnel-url>/api/*` — Request/response for CRUD operations
- **WebSocket**: `ws://<host>:8443/ws?token=<jwt>` or `wss://<tunnel-url>/ws?token=<jwt>` — Real-time streaming
- **UDP Broadcast**: Port `41234` — LAN discovery

## Authentication
1. Server displays 6-digit PIN on console
2. Client calls `POST /api/pair` with `{ pin, deviceName }`
3. Server returns `{ token, serverName, expiresAt }`
4. Client sends token as `Authorization: Bearer <token>` (REST) or `?token=<token>` (WebSocket)

## UDP Discovery Packet
```json
{ "service": "clauderemote", "host": "192.168.1.100", "port": 8443, "name": "DESKTOP-ABC" }
```
Broadcast every 3 seconds on port 41234.

## WebSocket Message Envelope
```json
{ "type": "messageType", "id": "abc12345", "payload": { ... }, "timestamp": 1710000000000 }
```

## WebSocket Message Types

### Terminal
| Type | Direction | Payload |
|------|-----------|---------|
| `terminalCreate` | client→server | `{}` |
| `terminalCreated` | server→client | `{ sessionId }` |
| `terminalInput` | client→server | `{ sessionId, data }` |
| `terminalOutput` | server→client | `{ sessionId, data }` |
| `terminalResize` | client→server | `{ sessionId, cols, rows }` |
| `terminalClose` | client→server | `{ sessionId }` |

### System Stats
| Type | Direction | Payload |
|------|-----------|---------|
| `subscribeStats` | client→server | `{}` |
| `unsubscribeStats` | client→server | `{}` |
| `systemStats` | server→client | `SystemInfo` object |

### Screen Capture
| Type | Direction | Payload |
|------|-----------|---------|
| `screenCapture` | client→server | `{}` |
| *(binary frame)* | server→client | Raw JPEG bytes (no envelope) |

### Heartbeat
| Type | Direction | Payload |
|------|-----------|---------|
| `ping` | client→server | `{}` |
| `pong` | server→client | `{}` |

Heartbeat sent every 15 seconds by client. Server responds with pong.

## REST Endpoints

### Public
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Server health check |
| POST | `/api/pair` | Pair device with PIN |

### Authenticated
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/system` | System info (CPU, RAM, disk) |
| GET | `/api/processes?top=50` | Process list |
| DELETE | `/api/processes/{pid}` | Kill process |
| GET | `/api/files?path=C:\` | List directory (omit path for drives) |
| GET | `/api/files/read?path=...` | Read text file content (max 500KB) |
| POST | `/api/files/mkdir?path=...` | Create directory |
| DELETE | `/api/files?path=...` | Delete file/directory |
| PUT | `/api/files/rename?oldPath=...&newPath=...` | Rename |
| GET | `/api/files/download?path=...` | Download file |
| POST | `/api/files/upload?dir=...` | Upload file (multipart) |
| POST | `/api/actions/shutdown` | Shutdown PC |
| POST | `/api/actions/restart` | Restart PC |
| POST | `/api/actions/lock` | Lock screen |
| POST | `/api/actions/sleep` | Sleep PC |
| GET | `/api/actions/clipboard` | Get clipboard text |
| POST | `/api/actions/clipboard?text=...` | Set clipboard text |
