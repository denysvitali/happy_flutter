#!/usr/bin/env python3
"""Capture Linux process CPU accounting without app payloads.

Run on the host owning the PID (not against an adb PID on a different host).
Use the same profile/release build, deterministic workload and session count for
before/after runs. 100% means one occupied core, not the whole machine.
Example: --pid PID --seconds 60 --scenario idle-chat --revision REV --output FILE
This measures all process threads; use Flutter DevTools/Perfetto for hot stacks.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import time


def process_sample(pid):
    # comm is parenthesized and can contain spaces or ')'. Fields after its
    # final ')' start at state (field 3), not at the process name.
    fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
    if fields[0] in ('Z', 'X'):
        raise ValueError('Process exited; capture is incomplete')
    ticks = os.sysconf('SC_CLK_TCK')
    return {
        'elapsed_seconds': time.monotonic(),
        'cpu_seconds': (int(fields[11]) + int(fields[12])) / ticks,
        'start_ticks': int(fields[19]),
        'rss_bytes': int(fields[21]) * os.sysconf('SC_PAGE_SIZE'),
    }


def interval(before, after):
    if before['start_ticks'] != after['start_ticks']:
        raise ValueError('PID was reused; capture is incomplete')
    elapsed = after['elapsed_seconds'] - before['elapsed_seconds']
    consumed = after['cpu_seconds'] - before['cpu_seconds']
    if elapsed <= 0 or consumed < 0:
        raise ValueError('Invalid process accounting interval')
    return {
        'seconds': elapsed,
        'cpu_seconds': consumed,
        'cpu_percent': 100 * consumed / elapsed,
        'rss_bytes': after['rss_bytes'],
    }


def summarize(samples):
    if not samples:
        raise ValueError('No complete intervals')
    elapsed = sum(row['seconds'] for row in samples)
    cpu = sum(row['cpu_seconds'] for row in samples)
    return {
        'seconds': elapsed, 'cpu_seconds': cpu,
        'mean_cpu_percent': 100 * cpu / elapsed,
        'peak_interval_cpu_percent': max(row['cpu_percent'] for row in samples),
        'peak_rss_bytes': max(row['rss_bytes'] for row in samples),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--interval', type=float, default=1)
    parser.add_argument('--scenario', required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.pid <= 0 or any(not math.isfinite(n) or n <= 0
                            for n in (args.seconds, args.interval)):
        parser.error('PID, seconds and interval must be positive and finite')
    before = process_sample(args.pid)
    deadline = time.monotonic() + args.seconds
    samples = []
    # Private, exclusive creation; a failed capture has no complete marker.
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as output:
        output.write(json.dumps({
            'schema': 1, 'type': 'manifest', 'scenario': args.scenario,
            'revision': args.revision, 'pid': args.pid,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'cpu_scale': '100 percent per core', 'source': 'linux-proc-stat',
        }) + '\n')
        output.flush()
        while time.monotonic() < deadline:
            time.sleep(min(args.interval, max(0, deadline - time.monotonic())))
            after = process_sample(args.pid)
            row = interval(before, after)
            samples.append(row)
            output.write(json.dumps({'type': 'sample', **row}) + '\n')
            output.flush()
            before = after
        summary = summarize(samples)
        output.write(json.dumps({'type': 'complete', 'samples': len(samples),
                                 **summary}) + '\n')
    print(json.dumps(summary, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Capture incomplete: ' + type(error).__name__) from None
