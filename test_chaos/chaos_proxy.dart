/// Local chaos proxy for the happy_flutter integration / chaos suite.
///
/// Sits between the device and the staging server.  Each request is
/// classified, then the proxy randomly applies one of:
///
///   - `pass`       — forward immediately
///   - `latency`    — sleep 100-2000ms before forwarding
///   - `drop`       — close the connection without forwarding
///   - `duplicate`  — forward and emit a second identical request
///
/// Frequencies are configurable via the `--profile` flag:
///
///   - `quiet`   — 90% pass, mostly latency jitter (default)
///   - `noisy`   — 50% pass, 30% latency, 10% drop, 10% duplicate
///   - `extreme` — 30% pass, 30% latency, 25% drop, 15% duplicate
///
/// CI does NOT run this harness; it's intended for local repro of
/// the messaging contract under realistic mobile-network conditions
/// while a Maestro flow drives the UI from outside.  See
/// `test_chaos/maestro_flow.yaml` for the corresponding Maestro
/// recipe and `test_chaos/run_chaos.sh` for the canonical invocation.
///
/// Usage:
///
///     dart run test_chaos/chaos_proxy.dart \\
///         --listen=8080 \\
///         --upstream=http://staging.example.com:80 \\
///         --profile=noisy \\
///         --seed=42
///
/// All knobs are seed-deterministic so a failing chaos run can be
/// replayed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;

const _profiles = <String, _Profile>{
  'quiet': _Profile(pass: 90, latency: 9, drop: 0, duplicate: 1),
  'noisy': _Profile(pass: 50, latency: 30, drop: 10, duplicate: 10),
  'extreme': _Profile(pass: 30, latency: 30, drop: 25, duplicate: 15),
};

class _Profile {
  const _Profile({
    required this.pass,
    required this.latency,
    required this.drop,
    required this.duplicate,
  });
  final int pass;
  final int latency;
  final int drop;
  final int duplicate;

  int get total => pass + latency + drop + duplicate;
}

class _Args {
  _Args({
    required this.listenPort,
    required this.upstream,
    required this.profile,
    required this.seed,
  });

  final int listenPort;
  final Uri upstream;
  final _Profile profile;
  final int seed;
}

_Args _parseArgs(List<String> argv) {
  var listen = 8080;
  Uri? upstream;
  var profile = _profiles['quiet']!;
  var seed = DateTime.now().millisecondsSinceEpoch;

  for (final arg in argv) {
    if (arg.startsWith('--listen=')) {
      listen = int.parse(arg.substring('--listen='.length));
    } else if (arg.startsWith('--upstream=')) {
      upstream = Uri.parse(arg.substring('--upstream='.length));
    } else if (arg.startsWith('--profile=')) {
      final name = arg.substring('--profile='.length);
      profile = _profiles[name] ??
          (throw ArgumentError('unknown profile: $name'));
    } else if (arg.startsWith('--seed=')) {
      seed = int.parse(arg.substring('--seed='.length));
    }
  }
  if (upstream == null) {
    throw ArgumentError('--upstream is required');
  }
  return _Args(
    listenPort: listen,
    upstream: upstream,
    profile: profile,
    seed: seed,
  );
}

enum _Action { pass, latency, drop, duplicate }

_Action _pick(Random rng, _Profile p) {
  final roll = rng.nextInt(p.total);
  var cum = 0;
  cum += p.pass;
  if (roll < cum) return _Action.pass;
  cum += p.latency;
  if (roll < cum) return _Action.latency;
  cum += p.drop;
  if (roll < cum) return _Action.drop;
  return _Action.duplicate;
}

Future<void> main(List<String> argv) async {
  final args = _parseArgs(argv);
  final rng = Random(args.seed);

  stdout.writeln(
    '[chaos] listening on :${args.listenPort} → ${args.upstream} '
    'profile=${_profileName(args.profile)} seed=${args.seed}',
  );

  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    args.listenPort,
  );
  await for (final request in server) {
    unawaited(_handle(request, args, rng));
  }
}

String _profileName(_Profile p) {
  for (final entry in _profiles.entries) {
    if (identical(entry.value, p)) return entry.key;
  }
  return 'custom';
}

Future<void> _handle(HttpRequest request, _Args args, Random rng) async {
  final action = _pick(rng, args.profile);
  final tag = '${request.method} ${request.uri}';
  switch (action) {
    case _Action.pass:
      await _forward(request, args.upstream);
      stdout.writeln('[chaos] PASS  $tag');
    case _Action.latency:
      final delay = Duration(milliseconds: 100 + rng.nextInt(1900));
      stdout.writeln(
        '[chaos] WAIT  $tag (sleeping ${delay.inMilliseconds}ms)',
      );
      await Future<void>.delayed(delay);
      await _forward(request, args.upstream);
    case _Action.drop:
      stdout.writeln('[chaos] DROP  $tag');
      try {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      } catch (_) {}
    case _Action.duplicate:
      stdout.writeln('[chaos] DUP   $tag');
      // Buffer the body so we can replay it; for streaming requests
      // this would need to be smarter, but happy_flutter sends only
      // small JSON envelopes.
      final body = await _readBody(request);
      // Send the duplicate first, fire-and-forget; then forward the
      // original.  This mirrors the failure mode where the network
      // re-sends after a timeout but the client still gets a 200.
      unawaited(_forwardWithBody(
        method: request.method,
        uri: request.uri,
        headers: request.headers,
        body: body,
        upstream: args.upstream,
        responseSink: null,
      ));
      await _forwardWithBody(
        method: request.method,
        uri: request.uri,
        headers: request.headers,
        body: body,
        upstream: args.upstream,
        responseSink: request.response,
      );
  }
}

Future<List<int>> _readBody(HttpRequest request) async {
  final builder = BytesBuilder();
  await request.forEach(builder.add);
  return builder.takeBytes();
}

Future<void> _forward(HttpRequest request, Uri upstream) async {
  final body = await _readBody(request);
  await _forwardWithBody(
    method: request.method,
    uri: request.uri,
    headers: request.headers,
    body: body,
    upstream: upstream,
    responseSink: request.response,
  );
}

Future<void> _forwardWithBody({
  required String method,
  required Uri uri,
  required HttpHeaders headers,
  required List<int> body,
  required Uri upstream,
  required HttpResponse? responseSink,
}) async {
  final client = HttpClient();
  try {
    final upstreamUri = upstream.replace(
      path: '${upstream.path}${uri.path}'.replaceAll('//', '/'),
      query: uri.query.isEmpty ? null : uri.query,
    );
    final upstreamReq = await client.openUrl(method, upstreamUri);
    headers.forEach((name, values) {
      if (name.toLowerCase() == 'host') return;
      upstreamReq.headers.set(name, values);
    });
    if (body.isNotEmpty) {
      upstreamReq.add(body);
    }
    final upstreamResp = await upstreamReq.close();
    if (responseSink == null) {
      await upstreamResp.drain<void>();
      return;
    }
    responseSink.statusCode = upstreamResp.statusCode;
    upstreamResp.headers.forEach((name, values) {
      try {
        responseSink.headers.set(name, values);
      } catch (_) {}
    });
    await upstreamResp.pipe(responseSink);
  } catch (e) {
    stderr.writeln('[chaos] forward error: $e');
    if (responseSink != null) {
      try {
        responseSink
          ..statusCode = HttpStatus.badGateway
          ..write(jsonEncode({'error': '$e'}));
        await responseSink.close();
      } catch (_) {}
    }
  } finally {
    client.close();
  }
}
