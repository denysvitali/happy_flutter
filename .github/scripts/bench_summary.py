#!/usr/bin/env python3
"""Turn BENCH| lines from a flutter-test log into a step-summary table.

Usage: bench_summary.py <bench-output.log> [csv-output-path]

Parses one `BENCH|group|name|ops_per_iter|iterations|mean_ms|p50_ms|p90_ms|p99_ms|ops_per_s`
line per scenario (emitted by benchmark/bench_runner.dart), writes a
markdown table to stdout and optionally a CSV next to the log.
"""

import argparse
import csv
import sys
from pathlib import Path


def parse_log(path: Path) -> list[dict[str, str]]:
    fields = (
        'group', 'name', 'ops_per_iter', 'iterations',
        'mean_ms', 'p50_ms', 'p90_ms', 'p99_ms', 'ops_per_s',
    )
    rows = []
    for raw in path.read_text(errors='replace').splitlines():
        if not raw.startswith('BENCH|'):
            continue
        parts = raw.split('|')
        if len(parts) != len(fields) + 1:
            print(f'::warning::malformed BENCH line ({len(parts)} fields): {raw}',
                  file=sys.stderr)
            continue
        rows.append({k: v for k, v in zip(fields, parts[1:])})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('log', type=Path)
    parser.add_argument('csv_out', type=Path, nargs='?')
    args = parser.parse_args()

    rows = parse_log(args.log)
    if not rows:
        print('No BENCH| lines found in log; nothing to summarize.',
              file=sys.stderr)
        return 0

    if args.csv_out:
        with args.csv_out.open('w', newline='') as fh:
            writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
        print(f'Wrote {len(rows)} rows to {args.csv_out}', file=sys.stderr)

    groups: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        groups.setdefault(row['group'], []).append(row)

    print('## Mocked-backend benchmarks')
    print()
    print('JIT-mode relative indicators (VM `flutter test`), not AOT')
    print('production latencies. Rows sorted by p50 within each group.')
    for group, group_rows in sorted(groups.items()):
        group_rows.sort(key=lambda r: -float(r['p50_ms']))
        print()
        print(f'### {group}')
        print()
        print('| scenario | ops/iter | iters | mean ms | p50 ms |'
              ' p90 ms | p99 ms | ops/s |')
        print('|---|---|---|---|---|---|---|---|')
        for r in group_rows:
            print(f"| {r['name']} | {r['ops_per_iter']} |"
                  f" {r['iterations']} | {r['mean_ms']} | {r['p50_ms']} |"
                  f" {r['p90_ms']} | {r['p99_ms']} | {r['ops_per_s']} |")
    print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
