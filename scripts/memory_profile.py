#!/usr/bin/env python3
"""Capture controlled Linux Flutter profile-mode memory experiments as JSONL.

Run with --help. Requires a loopback HTTP Dart VM service URL, the app's Linux
PID and an executable workload driver. Workload receives PHASE CYCLE SESSIONS ROWS
and must synchronously finish that fixed workload (including background/resume).
Metrics defaults to the profile app's count-only VM service extension; an
optional metrics executable receives no arguments and returns METRICS as JSON.
Drivers must fail if app state is unknown.
Use an isolated fixture account; artifacts deliberately contain no message text.
VM URLs may contain an auth code: never publish the command or service URL.
GC requests perturb the experiment; compare identical profile builds/workloads.
No claim about native allocation ownership is possible from RSS minus Dart heap.
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import subprocess
import time
from urllib.parse import urlencode, urlsplit
from urllib.request import urlopen

PHASES = ('long_chat', 'session_switch', 'background_resume')
METRICS = ('image_cache_bytes', 'encryption_cache_bytes', 'resident_rows',
           'resident_sessions')


def attribution(rss, usages):
    used = sum(item['heapUsage'] for item in usages)
    return {
        'rss_bytes': rss,
        'heap_used_bytes': used,
        'heap_capacity_bytes': sum(item['heapCapacity'] for item in usages),
        'vm_external_bytes': sum(item['externalUsage'] for item in usages),
        'estimated_rss_minus_heap_bytes': rss - used,
        'native_bytes': None,
    }


def validate_metrics(metrics):
    for key in METRICS:
        value = metrics.get(key)
        if (isinstance(value, bool) or not isinstance(value, (int, float))
                or not math.isfinite(value) or value < 0):
            raise ValueError('Missing or invalid app metric: ' + key)
    return {key: metrics[key] for key in METRICS}


def rpc(base, method, **params):
    # The URL is intentionally never written into artifacts or error output.
    with urlopen(base.rstrip('/') + '/' + method + '?' + urlencode(params),
                 timeout=20) as response:
        result = json.load(response)
    if 'error' in result or result.get('result', {}).get('type') == 'Sentinel':
        raise RuntimeError('VM service method failed: ' + method)
    return result['result']


def read_profile_metrics(base, isolates):
    method = 'ext.happy.performanceMetrics'
    for isolate in isolates:
        details = rpc(base, 'getIsolate', isolateId=isolate['id'])
        if method in details.get('extensionRPCs', []):
            return validate_metrics(rpc(base, method, isolateId=isolate['id']))
    raise ValueError('Profile app metrics extension is unavailable')


def sample(args, phase, cycle, stage):
    started = time.monotonic()
    vm = rpc(args.vm_service, 'getVM')
    if vm.get('pid') != args.pid or not vm.get('isolates'):
        raise ValueError('VM and RSS must describe the same live process')
    usages = []
    for isolate in vm['isolates']:
        isolate_id = isolate['id']
        if stage == 'after_gc':
            rpc(args.vm_service, 'getAllocationProfile',
                isolateId=isolate_id, gc='true')
        usages.append(rpc(args.vm_service, 'getMemoryUsage',
                          isolateId=isolate_id))
    # Linux kernel process accounting; not a cross-device adb PID.
    status = Path('/proc', str(args.pid), 'status').read_text()
    rss = next(int(line.split()[1]) * 1024 for line in status.splitlines()
               if line.startswith('VmRSS:'))
    if args.metrics:
        completed = subprocess.run([args.metrics], capture_output=True,
                                   check=True, timeout=args.driver_timeout)
        metrics = validate_metrics(json.loads(completed.stdout))
    else:
        metrics = read_profile_metrics(args.vm_service, vm['isolates'])
    return {
        'schema': 1, 'timestamp': datetime.now(timezone.utc).isoformat(),
        'phase': phase, 'cycle': cycle, 'stage': stage,
        'sample_duration_ms': round((time.monotonic() - started) * 1000),
        'gc_requested': stage == 'after_gc', 'gc_count': None,
        'isolate_count': len(usages),
        **attribution(rss, usages), **metrics,
    }



FIELDS = ('rss_bytes', 'heap_used_bytes', 'heap_capacity_bytes',
          'vm_external_bytes', 'estimated_rss_minus_heap_bytes',
          'image_cache_bytes', 'encryption_cache_bytes', 'resident_rows',
          'resident_sessions')


def summarize(path, *, max_bytes=8 * 1024 * 1024):
    """Return per-phase last-post-GC minus first-before deltas and sample maxima."""
    with Path(path).open('rb') as source:
        data = source.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise ValueError('Artifact exceeds byte limit')
    rows = [json.loads(line) for line in data.splitlines() if line.strip()]
    if len(rows) < 3 or any(row.get('schema') != 1 for row in rows):
        raise ValueError('Missing schema-1 evidence')
    manifest, *samples, complete = rows
    if manifest.get('type') != 'manifest' or complete.get('type') != 'complete':
        raise ValueError('Incomplete capture')
    phases = ('long_chat', 'session_switch', 'background_resume')
    expected = [(cycle, phase, stage)
                for cycle in range(manifest['cycles']) for phase in phases
                for stage in ('before', 'after_workload', 'after_gc')]
    actual = [(row['cycle'], row['phase'], row['stage']) for row in samples]
    if actual != expected or len(samples) != complete['samples'] or not samples:
        raise ValueError('Missing or reordered capture samples')
    if any(row.get('native_bytes') is not None for row in samples):
        raise ValueError('Unsupported native attribution claim')
    return {
        'revision': manifest['revision'], 'fixture': manifest['fixture'],
        'samples': len(samples), 'native_bytes': None,
        'maxima': {key: max(row[key] for row in samples) for key in FIELDS},
        'post_gc_growth': {
            phase: {key: [r for r in samples if r['phase'] == phase][-1][key]
                    - [r for r in samples if r['phase'] == phase][0][key]
                    for key in FIELDS}
            for phase in phases
        },
        'limits': 'Non-atomic samples; RSS minus heap is not native attribution; '
                  'external and cache values overlap. GC counts are unknown.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vm-service', required=True)
    parser.add_argument('--pid', required=True, type=int)
    parser.add_argument('--workload', required=True,
                        help='Executable workload driver (no shell expansion)')
    parser.add_argument('--metrics',
                        help='Override the profile VM metrics extension with '
                             'an executable returning app metrics as JSON')
    parser.add_argument('--revision', required=True)
    parser.add_argument('--fixture', required=True,
                        help='Non-sensitive deterministic fixture version')
    parser.add_argument('--cycles', type=int, default=5)
    parser.add_argument('--sessions', type=int, default=12)
    parser.add_argument('--rows', type=int, default=1000)
    parser.add_argument('--driver-timeout', type=int, default=180)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    url = urlsplit(args.vm_service)
    if url.scheme != 'http' or url.hostname not in ('127.0.0.1', 'localhost'):
        parser.error('VM service must use loopback HTTP (forward it first)')
    if min(args.pid, args.cycles, args.sessions, args.rows,
           args.driver_timeout) <= 0:
        parser.error('PID, workload sizes and timeout must be positive')
    # Exclusive creation prevents mixing builds or reusing stale evidence.
    with args.output.open('x', encoding='utf-8') as output:
        args.output.chmod(0o600)
        manifest = {
            'schema': 1, 'type': 'manifest', 'revision': args.revision,
            'fixture': args.fixture, 'cycles': args.cycles,
            'sessions': args.sessions, 'rows': args.rows,
            'phases': PHASES, 'platform': 'linux', 'declared_mode': 'profile',
            'attribution': 'RSS minus used heap is an estimate, not native; '
                           'external/cache bytes can overlap; do not sum them',
        }
        output.write(json.dumps(manifest) + '\n')
        output.flush()
        for cycle in range(args.cycles):
            for phase in PHASES:
                for stage in ('before', 'after_workload', 'after_gc'):
                    if stage == 'after_workload':
                        subprocess.run([
                            args.workload, phase, str(cycle),
                            str(args.sessions), str(args.rows),
                        ], check=True, capture_output=True,
                            timeout=args.driver_timeout)
                    output.write(json.dumps(sample(args, phase, cycle, stage))
                                 + '\n')
                    output.flush()
        output.write(json.dumps({'schema': 1, 'type': 'complete',
                                 'samples': args.cycles * len(PHASES) * 3})
                     + '\n')
    print(json.dumps(summarize(args.output), sort_keys=True))


if __name__ == '__main__':
    # Do not leak the authenticated VM URL or driver output on failure.
    try:
        main()
    except Exception as error:
        raise SystemExit('Capture incomplete: ' + type(error).__name__) from None
