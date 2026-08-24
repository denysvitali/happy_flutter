#!/usr/bin/env python3
"""Pick the test files for one CI shard, balanced by measured duration.

    python3 .github/scripts/select_test_shard.py --shard 3 --total-shards 10
    python3 .github/scripts/select_test_shard.py --check --total-shards 10

`--check` assigns every shard and fails unless each non-golden test file
lands in exactly one shard; it also prints the per-shard estimate so an
unbalanced split is visible.  Durations come from
`.github/test-durations.json` (regenerate with
`.github/scripts/update_test_durations.py`); files without an entry use
`default_seconds`, or the median of the known entries when that key is
missing.  Self-check: `python3 -m doctest .github/scripts/select_test_shard.py`.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--shard', type=int)
    parser.add_argument('--total-shards', type=int, required=True)
    parser.add_argument(
        '--durations',
        type=Path,
        default=Path('.github/test-durations.json'),
    )
    parser.add_argument(
        '--check',
        action='store_true',
        help='verify every test file is assigned exactly once and exit',
    )
    args = parser.parse_args()
    if args.total_shards < 1:
        parser.error('--total-shards must be positive')
    if not args.check:
        if args.shard is None:
            parser.error('--shard is required unless --check is given')
        if args.shard < 1 or args.shard > args.total_shards:
            parser.error('--shard must be within --total-shards')
    return args


def discover_tests(root: Path = Path('.')) -> list[str]:
    tests = sorted(
        path.relative_to(root).as_posix()
        for path in (root / 'test').rglob('*_test.dart')
        if (root / 'test' / 'golden') not in path.parents
    )
    if not tests:
        raise RuntimeError('No non-golden tests found')
    return tests


def fallback_seconds(duration_data: dict) -> int:
    """Weight for files with no measurement.

    >>> fallback_seconds({'default_seconds': 3, 'tests': {}})
    3
    >>> fallback_seconds({'tests': {'a': 1, 'b': 9, 'c': 4}})
    4
    >>> fallback_seconds({'tests': {}})
    1
    """
    if 'default_seconds' in duration_data:
        return max(1, int(duration_data['default_seconds']))
    known = [int(value) for value in duration_data.get('tests', {}).values()]
    if not known:
        return 1
    return max(1, round(statistics.median(known)))


def assign_shards(
    tests: list[str],
    durations: dict[str, int],
    default_seconds: int,
    total_shards: int,
) -> tuple[list[list[str]], list[int]]:
    """Greedy longest-first bin packing; returns (assignments, loads).

    Heaviest files go first, each to the least-loaded shard (ties broken by
    fewer files, then lower index), so the result is deterministic.

    >>> tests = ['a', 'b', 'c', 'd', 'e']
    >>> groups, loads = assign_shards(tests, {'a': 10, 'b': 6, 'c': 5}, 2, 2)
    >>> groups
    [['a', 'd'], ['b', 'c', 'e']]
    >>> loads
    [12, 13]
    >>> sorted(sum(groups, [])) == tests
    True
    """
    weighted = sorted(
        ((int(durations.get(path, default_seconds)), path) for path in tests),
        key=lambda item: (-item[0], item[1]),
    )
    loads = [0] * total_shards
    assignments: list[list[str]] = [[] for _ in range(total_shards)]
    for seconds, path in weighted:
        target = min(
            range(total_shards),
            key=lambda index: (loads[index], len(assignments[index]), index),
        )
        assignments[target].append(path)
        loads[target] += seconds
    return assignments, loads


def main() -> int:
    args = parse_args()
    duration_data = json.loads(args.durations.read_text())
    default_seconds = fallback_seconds(duration_data)
    durations = {
        str(path): int(seconds)
        for path, seconds in duration_data.get('tests', {}).items()
    }
    tests = discover_tests()
    assignments, loads = assign_shards(
        tests, durations, default_seconds, args.total_shards
    )

    if args.check:
        seen: dict[str, int] = {}
        for index, group in enumerate(assignments, start=1):
            for path in group:
                seen[path] = seen.get(path, 0) + 1
        duplicates = sorted(path for path, count in seen.items() if count > 1)
        missing = sorted(set(tests) - set(seen))
        unknown = sorted(path for path in tests if path not in durations)
        for index, (group, load) in enumerate(zip(assignments, loads), 1):
            print(
                f'shard {index}/{args.total_shards}: '
                f'{len(group)} files, estimated {load}s'
            )
        print(
            f'{len(tests)} test files, {len(unknown)} without a measured '
            f'duration (weighted {default_seconds}s each), '
            f'spread {min(loads)}-{max(loads)}s'
        )
        if duplicates or missing:
            for path in duplicates:
                print(f'assigned more than once: {path}', file=sys.stderr)
            for path in missing:
                print(f'never assigned: {path}', file=sys.stderr)
            return 1
        print('OK: every test file is assigned exactly once')
        return 0

    selected = assignments[args.shard - 1]
    print(
        f'Shard {args.shard}/{args.total_shards}: {len(selected)} of '
        f'{len(tests)} files, estimated {loads[args.shard - 1]}s',
        file=sys.stderr,
    )
    for path in selected:
        print(path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
