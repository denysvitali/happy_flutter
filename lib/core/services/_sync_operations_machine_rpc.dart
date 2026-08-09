part of 'sync_service.dart';

/// Machine-scoped RPC calls issued by [Sync].
///
/// These are request/response round-trips to a machine's daemon (`bash`,
/// `read-file`, and the per-vendor usage/limit probes). None of them mutate
/// `Sync`'s in-memory session state — they only read from a machine — which
/// is why they live apart from the session spawn logic in
/// `_sync_operations_session.dart`.
extension SyncMachineRpcOperations on Sync {
  static const int _codexModelsSuccessTtlMs = 60 * 60 * 1000;
  static const int _codexModelsFailureTtlMs = 30 * 1000;

  /// Execute a bash command on a machine.
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'bash',
        BashRequest(command: command, cwd: cwd).toJson(),
        BashResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineBash: socket not connected');
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineBash: transient RPC failure — $error');
      } else {
        logger.error('machineBash error', error, stackTrace);
      }
    }
    return const BashResponse(success: false, stderr: 'RPC call failed');
  }

  /// Read a file from a machine via encrypted RPC.
  Future<ReadFileResponse> machineReadFile({
    required String machineId,
    required String filePath,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'readFile',
        ReadFileRequest(path: filePath).toJson(),
        ReadFileResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineReadFile: socket not connected');
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineReadFile: RPC method not available '
          '(daemon too old) — $error',
        );
        return const ReadFileResponse(
          success: false,
          error: 'File viewing requires a newer machine agent',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineReadFile: transient RPC failure — $error');
      } else {
        logger.error('machineReadFile error', error, stackTrace);
      }
    }
    return const ReadFileResponse(success: false, error: 'RPC call failed');
  }

  /// Fetch Claude Code usage limits from a machine via encrypted RPC.
  /// The machine daemon reads `~/.claude/.credentials.json` and calls the
  /// Anthropic OAuth usage API, returning the raw JSON payload.
  Future<ClaudeUsageLimitsResponse> machineGetClaudeUsageLimits({
    required String machineId,
  }) async {
    try {
      // HAPPY_FLUTTER-3D5: usage limits is a UI-blocking call from
      // claude_limits_screen. The 30s default machineRPC timeout
      // burned the user out of patience 10× in 2 days — every
      // failure pinned the screen on a spinner for 30s. 15s is
      // well over the 3.2s p99 we see for healthy daemons (the
      // SLOW get-codex-models breadcrumb for this same user) and
      // bounded enough that a stuck daemon doesn't lock the user
      // out of the screen.
      return await _typedMachineRPC(
        machineId,
        'get-claude-usage-limits',
        <String, dynamic>{},
        ClaudeUsageLimitsResponse.fromJson,
        timeout: const Duration(seconds: 15),
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetClaudeUsageLimits: machine offline');
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetClaudeUsageLimits: RPC method not available '
          '(daemon too old)',
        );
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        // Daemon flakiness, not a client bug — log at info so we
        // still get the breadcrumb without inflating the warning
        // count. The screen handles the error in its UI.
        logger.info(
          'machineGetClaudeUsageLimits: transient RPC failure — $error',
        );
      } else {
        logger.error('machineGetClaudeUsageLimits error', error, stackTrace);
      }
    }
    return const ClaudeUsageLimitsResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch aggregated local Claude Code token usage (lifetime + per-day
  /// per-model) scraped from `~/.claude/stats-cache.json` on the machine.
  /// Distinct from [machineGetClaudeUsageLimits] which is the OAuth
  /// rate-limit response (5-hour/7-day windows as percentages).
  Future<ClaudeLocalUsageResponse> machineGetClaudeLocalUsage({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-claude-local-usage',
        <String, dynamic>{},
        ClaudeLocalUsageResponse.fromJson,
        timeout: const Duration(seconds: 15),
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetClaudeLocalUsage: machine offline');
        return const ClaudeLocalUsageResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetClaudeLocalUsage: RPC method not available '
          '(daemon too old)',
        );
        return const ClaudeLocalUsageResponse(
          success: false,
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info(
          'machineGetClaudeLocalUsage: transient RPC failure — $error',
        );
      } else {
        logger.error('machineGetClaudeLocalUsage error', error, stackTrace);
      }
    }
    return const ClaudeLocalUsageResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch the Codex model catalog from the machine's installed Codex CLI.
  Future<CodexModelsResponse> machineGetCodexModels({
    required String machineId,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cached = _codexModelsCache[machineId];
    final cachedAtMs = _codexModelsCacheAtMs[machineId];
    if (cached != null && cachedAtMs != null) {
      final ttlMs = cached.success
          ? _codexModelsSuccessTtlMs
          : _codexModelsFailureTtlMs;
      if (nowMs - cachedAtMs < ttlMs) {
        _recordCodexModelsPolicy(
          cached.success ? 'cache_hit' : 'failure_backoff',
        );
        return Future<CodexModelsResponse>.value(cached);
      }
    }

    final inFlight = _codexModelsInFlight[machineId];
    if (inFlight != null) {
      _recordCodexModelsPolicy('shared_in_flight');
      return inFlight;
    }

    _recordCodexModelsPolicy('transport_started');
    late final Future<CodexModelsResponse> request;
    request = _fetchCodexModels(machineId)
        .then((response) {
          _codexModelsCache[machineId] = response;
          _codexModelsCacheAtMs[machineId] =
              DateTime.now().millisecondsSinceEpoch;
          return response;
        })
        .whenComplete(() {
          if (identical(_codexModelsInFlight[machineId], request)) {
            _codexModelsInFlight.remove(machineId);
          }
        });
    _codexModelsInFlight[machineId] = request;
    return request;
  }

  void _recordCodexModelsPolicy(String outcome) {
    OpenTelemetryService().recordCount(
      'app.codex_models.policy',
      attributes: <String, Object?>{'outcome': outcome},
      description: 'Codex model catalog cache/coalescing policy',
    );
  }

  Future<CodexModelsResponse> _fetchCodexModels(String machineId) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-codex-models',
        <String, dynamic>{},
        CodexModelsResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexModels: machine offline');
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexModels: RPC method not available '
          '(daemon too old)',
        );
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineGetCodexModels: transient RPC failure — $error');
      } else {
        logger.error('machineGetCodexModels error', error, stackTrace);
      }
    }
    return const CodexModelsResponse(
      success: false,
      models: [],
      error: 'RPC call failed',
    );
  }

  /// Fetch Codex usage data from the machine's local Codex auth state.
  Future<CodexUsageSummaryResponse> machineGetCodexUsage({
    required String machineId,
  }) async {
    final machine = _machines[machineId];
    final cwd = machine?.metadata?.homeDir ?? '/';
    const codexUsageBashScript = r"""
python3 <<'PY'
import json
import os
import urllib.error
import urllib.request


def fail(message):
    print(json.dumps({'success': False, 'error': message}))
    raise SystemExit(0)


try:
    with open(os.path.expanduser('~/.codex/auth.json'), 'r',
              encoding='utf-8') as auth_file:
        auth = json.load(auth_file)
except Exception as exc:
    fail(f'Failed to read Codex auth.json: {exc}')

def find_access_token(value):
    if isinstance(value, dict):
        preferred_keys = (
            'accessToken',
            'access_token',
            'token',
            'idToken',
            'id_token',
        )
        for key in preferred_keys:
            token = value.get(key)
            if isinstance(token, str) and token:
                return token
        for nested in value.values():
            token = find_access_token(nested)
            if token:
                return token
    elif isinstance(value, list):
        for nested in value:
            token = find_access_token(nested)
            if token:
                return token
    return None


access_token = find_access_token(auth)
if not access_token:
    fail('No Codex access token found in auth.json')

request = urllib.request.Request(
    'https://chatgpt.com/backend-api/wham/usage',
    headers={
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'codex-cli',
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode('utf-8'))
except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    fail(f'Codex usage request failed ({exc.code}): {body}')
except Exception as exc:
    fail(f'Failed to fetch Codex usage: {exc}')

if isinstance(payload, dict) and isinstance(payload.get('data'), dict):
    payload = payload['data']

if not isinstance(payload, dict):
    fail('Codex usage response was not an object')

print(json.dumps({'success': True, 'data': payload}))
PY
""";

    CodexUsageSummaryResponse parseRpcResponse(Map<String, dynamic> raw) {
      final data = raw.containsKey('data') ? raw['data'] : raw;
      final summary = data is Map<String, dynamic>
          ? CodexUsageSummary.fromJson(data)
          : data is Map
          ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
          : null;
      final hasSummary = summary?.hasUsageData ?? false;
      return CodexUsageSummaryResponse(
        success: raw['success'] == true || hasSummary,
        data: hasSummary ? summary : null,
        error: raw['error'] as String?,
      );
    }

    Future<CodexUsageSummaryResponse> fetchFromBash() async {
      final response = await machineBash(
        machineId: machineId,
        command: codexUsageBashScript,
        cwd: cwd,
      );

      if (!response.success) {
        return CodexUsageSummaryResponse(
          success: false,
          error: response.stderr.isNotEmpty ? response.stderr : response.error,
        );
      }

      try {
        final raw = jsonDecode(response.stdout) as Map<String, dynamic>;
        final success = raw['success'] == true;
        final data = raw['data'] ?? raw;
        final summary = data is Map<String, dynamic>
            ? CodexUsageSummary.fromJson(data)
            : data is Map
            ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
            : null;
        final hasSummary = summary?.hasUsageData ?? false;
        if (!success) {
          return CodexUsageSummaryResponse(
            success: false,
            error: raw['error'] as String?,
          );
        }
        return CodexUsageSummaryResponse(
          success: true,
          data: hasSummary ? summary : null,
          error: raw['error'] as String?,
        );
      } catch (error, stackTrace) {
        logger.error('machineGetCodexUsage parse error', error, stackTrace);
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Failed to parse Codex usage response',
        );
      }
    }

    try {
      final response = await _typedMachineRPC(
        machineId,
        'get-codex-usage',
        <String, dynamic>{},
        parseRpcResponse,
        timeout: const Duration(seconds: 20),
      );
      if (!response.success) {
        return response;
      }
      if (response.data == null) {
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Codex usage data missing',
        );
      }
      return response;
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexUsage: machine offline');
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexUsage: RPC method not available '
          '(daemon too old); falling back to machineBash',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineGetCodexUsage: transient RPC failure — $error');
      } else {
        logger.error('machineGetCodexUsage RPC error', error, stackTrace);
      }
    }

    return fetchFromBash();
  }

  /// Lists Codex usage-limit reset credits without redeeming any of them.
  Future<CodexRateLimitResetCredits?> machineGetCodexResetCredits({
    required String machineId,
  }) async {
    final machine = _machines[machineId];
    final cwd = machine?.metadata?.homeDir ?? '/';
    const script = r"""
python3 <<'PY'
import json
import os
import urllib.request

def find_token(value):
    if isinstance(value, dict):
        keys = ('accessToken', 'access_token', 'token', 'idToken', 'id_token')
        for key in keys:
            token = value.get(key)
            if isinstance(token, str) and token:
                return token
        for nested in value.values():
            token = find_token(nested)
            if token:
                return token
    elif isinstance(value, list):
        for nested in value:
            token = find_token(nested)
            if token:
                return token
    return None

try:
    with open(os.path.expanduser('~/.codex/auth.json'), encoding='utf-8') as f:
        auth = json.load(f)
    token = find_token(auth)
    if not token:
        raise ValueError('No Codex access token found')
    headers = {
        'Authorization': f'Bearer {token}',
        'Accept': 'application/json',
        'User-Agent': 'codex-cli',
    }
    account_id = None
    if isinstance(auth, dict):
        account_id = (
            auth.get('last_active_account_id')
            or auth.get('account_id')
            or (auth.get('account') or {}).get('id')
        )
    if isinstance(account_id, str) and account_id:
        headers['ChatGPT-Account-Id'] = account_id
    request = urllib.request.Request(
        'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits',
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        print(response.read().decode('utf-8'))
except Exception as exc:
    print(json.dumps({'error': str(exc)}))
PY
""";

    try {
      final response = await machineBash(
        machineId: machineId,
        command: script,
        cwd: cwd,
      );
      if (!response.success) return null;
      final raw = jsonDecode(response.stdout);
      if (raw is! Map || raw['error'] != null) return null;
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      return CodexRateLimitResetCredits.fromJson(data);
    } catch (error, stackTrace) {
      logger.warning('machineGetCodexResetCredits failed', error, stackTrace);
      return null;
    }
  }

  /// Fetch Grok Build billing usage from a machine via encrypted RPC.
  ///
  /// The machine daemon reads `~/.grok/auth.json` (or `XAI_API_KEY`) and
  /// calls `cli-chat-proxy.grok.com/v1/billing`. Falls back to a remote
  /// bash script when the daemon is too old to expose `get-grok-usage`.
  Future<GrokUsageSummaryResponse> machineGetGrokUsage({
    required String machineId,
  }) async {
    final machine = _machines[machineId];
    final cwd = machine?.metadata?.homeDir ?? '/';
    const grokUsageBashScript = r"""
python3 <<'PY'
import json
import os
import urllib.error
import urllib.request


def fail(message):
    print(json.dumps({'success': False, 'error': message}))
    raise SystemExit(0)


def cents_val(value):
    if isinstance(value, dict):
        return cents_val(value.get('val'))
    if isinstance(value, bool) or value is None:
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return 0
    return 0


def find_token():
    env_key = os.environ.get('XAI_API_KEY', '').strip()
    if env_key:
        return env_key, ''
    search = [os.path.expanduser('~/.grok/auth.json')]
    grok_home = os.environ.get('GROK_HOME')
    if grok_home:
        search.insert(0, os.path.join(grok_home, 'auth.json'))
    last_err = None
    for path in search:
        try:
            with open(path, 'r', encoding='utf-8') as f:
                auth = json.load(f)
        except Exception as exc:
            last_err = exc
            continue
        if not isinstance(auth, dict):
            continue
        for entry in auth.values():
            if not isinstance(entry, dict):
                continue
            key = entry.get('key') or entry.get('accessToken') or entry.get('access_token')
            if isinstance(key, str) and key.strip():
                email = entry.get('email') if isinstance(entry.get('email'), str) else ''
                return key.strip(), email
    if last_err is not None:
        fail(f'Failed to read Grok auth.json: {last_err}')
    fail('No Grok credentials found')


token, email = find_token()
base = os.environ.get('GROK_CLI_CHAT_PROXY_BASE_URL', 'https://cli-chat-proxy.grok.com/v1').rstrip('/')


def get_json(url):
    request = urllib.request.Request(
        url,
        headers={
            'Authorization': f'Bearer {token}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'happy-flutter',
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode('utf-8'))


try:
    billing = get_json(f'{base}/billing')
except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    fail(f'Grok billing request failed ({exc.code}): {body}')
except Exception as exc:
    fail(f'Failed to fetch Grok usage: {exc}')

if not email:
    try:
        user = get_json(f'{base}/user')
        if isinstance(user, dict) and isinstance(user.get('email'), str):
            email = user['email']
    except Exception:
        pass

config = billing.get('config') if isinstance(billing, dict) else None
if not isinstance(config, dict):
    config = billing if isinstance(billing, dict) else {}

payload = {
    'email': email or None,
    'monthlyLimitCents': cents_val(config.get('monthlyLimit')),
    'usedCents': cents_val(config.get('used')),
    'onDemandCapCents': cents_val(config.get('onDemandCap')),
    'billingPeriodStart': config.get('billingPeriodStart'),
    'billingPeriodEnd': config.get('billingPeriodEnd'),
}
print(json.dumps({'success': True, 'data': payload}))
PY
""";

    GrokUsageSummaryResponse parseRpcResponse(Map<String, dynamic> raw) {
      final data = raw.containsKey('data') ? raw['data'] : raw;
      final summary = data is Map<String, dynamic>
          ? GrokUsageSummary.fromJson(data)
          : data is Map
          ? GrokUsageSummary.fromJson(Map<String, dynamic>.from(data))
          : null;
      final hasSummary = summary?.hasUsageData ?? false;
      return GrokUsageSummaryResponse(
        success: raw['success'] == true || hasSummary,
        data: hasSummary ? summary : null,
        error: raw['error'] as String?,
      );
    }

    Future<GrokUsageSummaryResponse> fetchFromBash() async {
      final response = await machineBash(
        machineId: machineId,
        command: grokUsageBashScript,
        cwd: cwd,
      );

      if (!response.success) {
        return GrokUsageSummaryResponse(
          success: false,
          error: response.stderr.isNotEmpty ? response.stderr : response.error,
        );
      }

      try {
        final raw = jsonDecode(response.stdout) as Map<String, dynamic>;
        final success = raw['success'] == true;
        final data = raw['data'] ?? raw;
        final summary = data is Map<String, dynamic>
            ? GrokUsageSummary.fromJson(data)
            : data is Map
            ? GrokUsageSummary.fromJson(Map<String, dynamic>.from(data))
            : null;
        final hasSummary = summary?.hasUsageData ?? false;
        if (!success) {
          return GrokUsageSummaryResponse(
            success: false,
            error: raw['error'] as String?,
          );
        }
        return GrokUsageSummaryResponse(
          success: true,
          data: hasSummary ? summary : null,
          error: raw['error'] as String?,
        );
      } catch (error, stackTrace) {
        logger.error('machineGetGrokUsage parse error', error, stackTrace);
        return const GrokUsageSummaryResponse(
          success: false,
          error: 'Failed to parse Grok usage response',
        );
      }
    }

    try {
      final response = await _typedMachineRPC(
        machineId,
        'get-grok-usage',
        <String, dynamic>{},
        parseRpcResponse,
        timeout: const Duration(seconds: 20),
      );
      if (!response.success) {
        return response;
      }
      if (response.data == null) {
        return const GrokUsageSummaryResponse(
          success: false,
          error: 'Grok usage data missing',
        );
      }
      return response;
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetGrokUsage: machine offline');
        return const GrokUsageSummaryResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetGrokUsage: RPC method not available '
          '(daemon too old); falling back to machineBash',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineGetGrokUsage: transient RPC failure — $error');
      } else {
        logger.error('machineGetGrokUsage RPC error', error, stackTrace);
      }
    }

    return fetchFromBash();
  }
}
