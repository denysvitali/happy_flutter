# Happy Protocol Documentation

This document describes the API protocol used by the Happy system, including both the REST API and WebSocket connections. This documentation is intended to maintain API compatibility for the Flutter client implementation.

## Base URL

The default server URL is: `https://api.cluster-fluster.com`

Clients can configure a custom server URL which takes priority over the default.

## Authentication

All authenticated requests require a Bearer token in the `Authorization` header:

```
Authorization: Bearer <token>
```

The User-Agent header should be set to identify the client:

```
User-Agent: HappyFlutter/1.0
```

---

## REST API Endpoints

### Health & Configuration

#### GET /v1/config

Check if the server is reachable and get basic configuration.

**Request:**
```http
GET /v1/config
```

**Response:**
- Returns 2xx if server is reachable
- Returns 401 if server requires authentication
- Any response (2xx, 3xx, 4xx except 5xx) indicates the server is up

---

### Authentication

#### POST /v1/auth/account/request

Initiate QR code authentication. Sends a public key to the server to begin the authentication flow.

**Request:**
```http
POST /v1/auth/account/request
Content-Type: application/json
```

**Body:**
```json
{
  "publicKey": "<base64-encoded-public-key>"
}
```

**Response:**
- `200 OK` - Request accepted
- `4xx` - Client error (invalid request)
- `5xx` - Server error

---

#### POST /v1/auth/account/wait

Poll for authentication approval. Returns when the user has approved the request on another device.

**Request:**
```http
POST /v1/auth/account/wait
Content-Type: application/json
```

**Body:**
```json
{
  "publicKey": "<base64-encoded-public-key>"
}
```

**Response Codes:**
- `200 OK` - Authentication approved, returns token and encrypted secret
- `202 Accepted` - Still waiting for approval (continue polling)
- `403 Forbidden` - Authentication rejected by server
- `4xx` - Client error (invalid request)
- `5xx` - Server error

**Success Response Body (200):**
```json
{
  "token": "<authentication-token>",
  "secret": "<base64-encoded-encrypted-secret>"
}
```

---

#### GET /v1/auth/verify

Verify if an authentication token is still valid.

**Request:**
```http
GET /v1/auth/verify?token=<authentication-token>
```

**Response:**
- `200 OK` - Token is valid
- `403 Forbidden` - Token is invalid or revoked
- Other status codes indicate error conditions

---

## WebSocket API

### WebSocket Connection

#### GET /v1/updates

Real-time updates stream for sessions, messages, and other events.

**Connection URL:**
```
ws://<server-url>/v1/updates?token=<authentication-token>
or
wss://<server-url>/v1/updates?token=<authentication-token>
```

**Protocol:**
- Convert `http` to `ws` and `https` to `wss` for the connection URL
- Authentication token is passed as a query parameter
- Messages are JSON-encoded

**Message Format:**
```json
{
  "event": "<event-type>",
  "data": { ... }
}
```

---

### WebSocket Event Types

#### update

General update event containing session state changes.

```json
{
  "event": "update",
  "data": {
    "t": "<update-type>",
    ...event-specific-fields
  }
}
```

#### New Session (`t: "newSession"`)

A new session has been created.

```json
{
  "t": "newSession",
  "id": "<session-id>",
  "createdAt": 1700000000000,
  "updatedAt": 1700000000000
}
```

#### Delete Session (`t: "deleteSession"`)

A session has been deleted.

```json
{
  "t": "deleteSession",
  "sid": "<session-id>"
}
```

#### New Message (`t: "newMessage"`)

A new message has been received in a session.

```json
{
  "t": "newMessage",
  "sid": "<session-id>",
  "message": {
    "id": "<message-id>",
    "seq": 1,
    "localId": "<local-id>",
    "content": {
      "t": "<content-type>",
      "c": "<content>"
    },
    "createdAt": 1700000000000
  }
}
```

#### Session State Update (`t: "updateSessionState"`)

Session agent state or metadata has been updated.

```json
{
  "t": "updateSessionState",
  "id": "<session-id>",
  "agentState": {
    "version": 1,
    "value": "<json-encoded-agent-state>"
  },
  "metadata": {
    "version": 1,
    "value": "<json-encoded-metadata>"
  }
}
```

---

## Data Models

### Session

Represents a chat session with an agent.

```typescript
interface Session {
  id: string;
  seq: number;
  createdAt: number;
  updatedAt: number;
  active: boolean;
  activeAt: number;
  metadata: SessionMetadata | null;
  metadataVersion: number;
  agentState: AgentState | null;
  agentStateVersion: number;
  thinking: boolean;
  thinkingAt: number | null;
  presence: string;
  todos: TodoItem[] | null;
  draft: string | null;
  permissionMode: string | null;
  modelMode: string | null;
  latestUsage: UsageData | null;
}
```

### SessionMetadata

```typescript
interface SessionMetadata {
  path: string | null;
  host: string;
  version: string | null;
  name: string | null;
  os: string | null;
  summary: Summary | null;
  machineId: string | null;
  claudeSessionId: string | null;
  tools: string[] | null;
  slashCommands: string[] | null;
  homeDir: string | null;
  happyHomeDir: string | null;
  hostPid: number | null;
  flavor: string | null;
}
```

### AgentState

```typescript
interface AgentState {
  controlledByUser: boolean | null;
  requests: Record<string, RequestInfo> | null;
  completedRequests: Record<string, CompletedRequestInfo> | null;
}
```

### Message

```typescript
interface ApiMessage {
  id: string;
  seq: number;
  localId: string | null;
  content: ApiMessageContent;
  createdAt: number;
}

interface ApiMessageContent {
  t: string;  // content type
  c: string;  // content
}
```

### ToolCall

```typescript
interface ToolCall {
  name: string;
  state: string;
  input: any;
  createdAt: number;
  startedAt: number | null;
  completedAt: number | null;
  description: string | null;
  result: any;
  permission: Permission | null;
}
```

### Permission

```typescript
interface Permission {
  id: string;
  status: string;
  reason: string | null;
  mode: string | null;
  allowedTools: string[] | null;
  decision: string | null;
  date: number | null;
}
```

### Machine

Represents a connected machine.

```typescript
interface Machine {
  id: string;
  seq: number;
  createdAt: number;
  updatedAt: number;
  active: boolean;
  activeAt: number;
  metadata: MachineMetadata | null;
  metadataVersion: number;
  daemonState: any;
  daemonStateVersion: number;
}
```

### MachineMetadata

```typescript
interface MachineMetadata {
  host: string;
  platform: string;
  happyCliVersion: string;
  happyHomeDir: string;
  homeDir: string;
  username: string | null;
  arch: string | null;
  displayName: string | null;
  daemonLastKnownStatus: string | null;
  daemonLastKnownPid: number | null;
  shutdownRequestedAt: number | null;
  shutdownSource: string | null;
}
```

### TodoItem

```typescript
interface TodoItem {
  content: string;
  status: string;
  priority: string;
  id: string;
}
```

### UsageData

```typescript
interface UsageData {
  inputTokens: number;
  outputTokens: number;
  cacheCreation: number;
  cacheRead: number;
  contextSize: number;
  timestamp: number;
}
```

---

## Error Handling

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 202 | Accepted (used for polling responses) |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden (authentication rejected) |
| 500 | Internal Server Error |

### Error Response Format

```json
{
  "error": "<error-message>",
  "message": "<human-readable-message>"
}
```

---

## Client Implementation Notes

### Token Storage

Authentication tokens should be stored securely using platform-specific secure storage:
- **iOS**: Keychain
- **Android**: EncryptedSharedPreferences

### Reconnection Strategy

When the WebSocket connection is lost:
1. Attempt to reconnect with exponential backoff
2. Verify token is still valid before reconnecting
3. Re-subscribe to session updates after reconnection

### Certificate Handling

For self-signed certificate environments:
- On Android, user-added CAs in the system trust store are automatically trusted
- Custom CA certificates can be configured via Network Security Config

### Content-Type

All API requests and responses use JSON:
```
Content-Type: application/json
```

---

## References

- Original client: https://github.com/slopus/happy
- Original server: https://github.com/slopus/happy-server
- Flutter implementation: https://github.com/denysvitali/happy_flutter
