#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('--shard', type=int, required=True)
    parser.add_argument('--total-shards', type=int, required=True)
    parser.add_argument(
        '--durations',
        type=Path,
        default=Path('.github/test-durations.json'),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.total_shards < 1:
        raise ValueError('--total-shards must be positive')
    if args.shard < 1 or args.shard > args.total_shards:
        raise ValueError('--shard must be within --total-shards')

    duration_data = json.loads(args.durations.read_text())
    default_seconds = int(duration_data['default_seconds'])
    durations = duration_data['tests']
    tests = sorted(
        str(path)
        for path in Path('test').rglob('*_test.dart')
        if Path('test/golden') not in path.parents
    )
    if not tests:
        raise RuntimeError('No non-golden tests found')

    weighted_tests = sorted(
        ((int(durations.get(path, default_seconds)), path) for path in tests),
        key=lambda item: (-item[0], item[1]),
    )
    loads = [0] * args.total_shards
    assignments: list[list[str]] = [[] for _ in range(args.total_shards)]
    for seconds, path in weighted_tests:
        target = min(
            range(args.total_shards),
            key=lambda index: (loads[index], len(assignments[index]), index),
        )
        assignments[target].append(path)
        loads[target] += seconds

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
