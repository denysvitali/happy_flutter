#!/usr/bin/env python3
"""Regenerate .github/test-durations.json from `flutter test` CI output.

Preferred input: the JSON file reporter that every `Test (shard N/M)` job
writes (`--file-reporter=json:test-results.json`) and uploads as the
`test-results-shard-<N>` artifact.  Download all shards of one main run and
feed them in:

    gh run download <run-id> -p 'test-results-shard-*' -D /tmp/shards
    python3 .github/scripts/update_test_durations.py \
        --source 'run <run-id> (main, YYYY-MM-DD)' \
        /tmp/shards/test-results-shard-*/test-results.json

Legacy input: raw job logs of the expanded reporter (the pre-file-reporter
format, only reliable for `--concurrency=1` runs because the expanded
reporter prints one `loading <file>` line per file only when files run
serially).  Lines may carry the GitHub Actions ISO timestamp prefix
(`2026-08-23T18:00:40.7274572Z `); without it the reporter's own `mm:ss`
clock is used.  Both formats may be mixed on one command line.

Per file the measurement is: time from the end of its `loading` phase to
its last `testDone`, plus the load phase itself.  The load phase of the
first file(s) of a shard also pays the one-off kernel compile of the whole
run, so any load phase longer than the median load phase of that input is
clamped to the median.

Files that exist in the repository but were not seen in any input keep
their previous value (if any), otherwise the new `default_seconds`, which
is the median of every measured file.  Files that no longer exist are
dropped.  Self-check:
`python3 -m doctest .github/scripts/update_test_durations.py`.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import sys
from datetime import datetime
from pathlib import Path

GH_TIMESTAMP = re.compile(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z) ')
# `00:12 +37:`, `01:46 +230 ~1:`, `00:05 +27 -1:`
REPORTER_CLOCK = re.compile(r'^(\d+):(\d{2}) \+\d+(?: -\d+)?(?: ~\d+)?: (.*)$')
LOADING = re.compile(r'^loading (\S+_test\.dart)$')
TEST_LINE = re.compile(r'^(\S+_test\.dart): ')
RUN_END = re.compile(r'^(All tests passed!|Some tests failed\.)$')


def parse_timestamp(value: str) -> float:
    """ISO-8601 GitHub log timestamp -> seconds since the epoch.

    >>> parse_timestamp('2026-08-23T18:00:40.7274572Z') - \\
    ...     parse_timestamp('2026-08-23T18:00:39.7274572Z')
    1.0
    """
    head, _, frac = value[:-1].partition('.')
    seconds = datetime.fromisoformat(head + '+00:00').timestamp()
    return seconds + float('0.' + frac[:6]) if frac else seconds


def split_line(raw: str) -> tuple[float | None, str]:
    """Return (absolute seconds or None, reporter message without timestamps).

    >>> split_line('2026-08-23T18:00:40.0000000Z 00:12 +37: '
    ...            'loading /r/test/a_test.dart')[1]
    'loading /r/test/a_test.dart'
    >>> split_line('00:12 +37 ~1: All tests passed!')
    (12.0, 'All tests passed!')
    >>> split_line('random noise')
    (None, 'random noise')
    """
    line = raw.rstrip('\n')
    absolute: float | None = None
    match = GH_TIMESTAMP.match(line)
    if match:
        absolute = parse_timestamp(match.group(1))
        line = line[match.end():]
    clock = REPORTER_CLOCK.match(line)
    if clock:
        if absolute is None:
            absolute = float(int(clock.group(1)) * 60 + int(clock.group(2)))
        line = clock.group(3)
    return absolute, line


def relative_test_path(path: str, known: set[str] | None = None) -> str:
    """Strip the checkout prefix from an absolute test path.

    >>> relative_test_path('/home/runner/work/x/x/test/api/kv_api_test.dart')
    'test/api/kv_api_test.dart'
    >>> relative_test_path('/tmp/test/repo/test/a_test.dart',
    ...                    {'test/a_test.dart'})
    'test/a_test.dart'
    >>> relative_test_path('test/a_test.dart')
    'test/a_test.dart'
    """
    candidates = [
        path[index:]
        for index in range(len(path))
        if path.startswith('test/', index)
        and (index == 0 or path[index - 1] == '/')
    ]
    if not candidates:
        return path
    if known:
        for candidate in candidates:
            if candidate in known:
                return candidate
    return candidates[-1]


def _durations_from_phases(
    files: list[dict],
    known: set[str] | None,
) -> dict[str, float]:
    """Combine (path, load, run) phases into per-file seconds.

    Load phases above the median are clamped to it: the first file(s) of a
    run pay the whole-run kernel compile, which is not their own cost.

    >>> phases = [
    ...     {'path': '/r/test/a_test.dart', 'load': 20.0, 'run': 10.0},
    ...     {'path': '/r/test/b_test.dart', 'load': 1.0, 'run': 2.0},
    ...     {'path': '/r/test/c_test.dart', 'load': 1.5, 'run': 3.0},
    ... ]
    >>> durations = _durations_from_phases(phases, None)
    >>> for path, seconds in sorted(durations.items()):
    ...     print(path, seconds)
    test/a_test.dart 11.5
    test/b_test.dart 3.0
    test/c_test.dart 4.5
    """
    loads = [entry['load'] for entry in files if entry['load'] is not None]
    typical_load = statistics.median(loads) if loads else None
    durations: dict[str, float] = {}
    for entry in files:
        load = entry['load']
        if load is None:
            load = typical_load or 0.0
        elif typical_load is not None:
            load = min(load, typical_load)
        duration = max(entry['run'], 0.0) + max(load, 0.0)
        durations[relative_test_path(entry['path'], known)] = duration
    return durations


def parse_log(lines, known: set[str] | None = None) -> dict[str, float]:
    """Per-file wall seconds from one serial expanded-reporter log.

    >>> log = '''
    ... 00:00 +0: loading /r/test/first_test.dart
    ... 00:20 +0: /r/test/first_test.dart: slow compile then a test
    ... 00:30 +1: loading /r/test/second_test.dart
    ... 00:31 +1: /r/test/second_test.dart: t
    ... 00:33 +2: loading /r/test/third_test.dart
    ... 00:34 +2: /r/test/third_test.dart: t
    ... 00:37 +3: All tests passed!
    ... '''.strip().splitlines()
    >>> for path, seconds in sorted(parse_log(log).items()):
    ...     print(path, seconds)
    test/first_test.dart 11.0
    test/second_test.dart 3.0
    test/third_test.dart 4.0
    """
    files: list[dict] = []
    end_at: float | None = None
    for raw in lines:
        at, message = split_line(raw)
        if at is None:
            continue
        loading = LOADING.match(message)
        if loading:
            files.append({'path': loading.group(1), 'start': at, 'first': None})
            continue
        if RUN_END.match(message):
            end_at = at
            break
        if files and files[-1]['first'] is None:
            test = TEST_LINE.match(message)
            if test and test.group(1) == files[-1]['path']:
                files[-1]['first'] = at

    phases: list[dict] = []
    for index, entry in enumerate(files):
        if index + 1 < len(files):
            end = files[index + 1]['start']
        elif end_at is not None:
            end = end_at
        else:
            continue  # truncated log: the last file never finished
        first = entry['first']
        if first is None:
            phases.append({
                'path': entry['path'],
                'load': None,
                'run': end - entry['start'],
            })
        else:
            phases.append({
                'path': entry['path'],
                'load': first - entry['start'],
                'run': end - first,
            })
    return _durations_from_phases(phases, known)


def parse_json_report(lines, known: set[str] | None = None) -> dict[str, float]:
    """Per-file wall seconds from a `--file-reporter=json:` file.

    Works for any --concurrency: every test carries its suite id, so the
    interleaving of parallel files does not matter.

    >>> import json
    >>> def ev(kind, time, **fields):
    ...     return json.dumps({'type': kind, 'time': time, **fields})
    >>> report = [
    ...     ev('start', 0),
    ...     ev('suite', 0, suite={'id': 0, 'path': '/r/test/a_test.dart'}),
    ...     ev('testStart', 0, test={'id': 1, 'suiteID': 0,
    ...                              'name': 'loading /r/test/a_test.dart'}),
    ...     ev('suite', 5, suite={'id': 2, 'path': '/r/test/b_test.dart'}),
    ...     ev('testStart', 5, test={'id': 3, 'suiteID': 2,
    ...                              'name': 'loading /r/test/b_test.dart'}),
    ...     ev('testDone', 1005, testID=3),
    ...     ev('testStart', 1010, test={'id': 4, 'suiteID': 2, 'name': 'b'}),
    ...     ev('testDone', 3005, testID=4),
    ...     ev('testDone', 20000, testID=1),
    ...     ev('testStart', 20010, test={'id': 5, 'suiteID': 0, 'name': 'a'}),
    ...     ev('testDone', 30000, testID=5),
    ...     ev('suite', 30000, suite={'id': 6, 'path': '/r/test/c_test.dart'}),
    ...     ev('testStart', 30000, test={
    ...         'id': 7, 'suiteID': 6, 'name': 'loading /r/test/c_test.dart'}),
    ...     ev('testDone', 31000, testID=7),
    ...     ev('testStart', 31010, test={'id': 8, 'suiteID': 6, 'name': 'c'}),
    ...     ev('testDone', 32000, testID=8),
    ...     ev('done', 32100, success=True),
    ... ]
    >>> for path, seconds in sorted(parse_json_report(report).items()):
    ...     print(path, round(seconds, 3))
    test/a_test.dart 11.0
    test/b_test.dart 3.0
    test/c_test.dart 2.0
    """
    suites: dict[int, dict] = {}
    test_suite: dict[int, int] = {}
    loading_tests: dict[int, int] = {}
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        kind = event.get('type')
        if kind == 'suite':
            suite = event['suite']
            suites[suite['id']] = {
                'path': suite['path'],
                'load_start': event['time'],
                'load_end': None,
                'last_done': None,
            }
        elif kind == 'testStart':
            test = event['test']
            test_suite[test['id']] = test['suiteID']
            if str(test.get('name', '')).startswith('loading '):
                loading_tests[test['id']] = test['suiteID']
                suites[test['suiteID']]['load_start'] = event['time']
        elif kind == 'testDone':
            suite_id = test_suite.get(event['testID'])
            if suite_id is None:
                continue
            suite = suites[suite_id]
            if event['testID'] in loading_tests:
                suite['load_end'] = event['time']
            suite['last_done'] = max(suite['last_done'] or 0, event['time'])

    phases: list[dict] = []
    for suite in suites.values():
        if suite['last_done'] is None:
            continue  # never ran (load failure or truncated report)
        if suite['load_end'] is None:
            phases.append({
                'path': suite['path'],
                'load': None,
                'run': (suite['last_done'] - suite['load_start']) / 1000.0,
            })
        else:
            phases.append({
                'path': suite['path'],
                'load': (suite['load_end'] - suite['load_start']) / 1000.0,
                'run': (suite['last_done'] - suite['load_end']) / 1000.0,
            })
    return _durations_from_phases(phases, known)


def parse_input(path: Path, known: set[str] | None = None) -> dict[str, float]:
    """Dispatch on content: JSON-lines reporter file or expanded text log."""
    with path.open(encoding='utf-8', errors='replace') as handle:
        head = handle.readline()
        handle.seek(0)
        if head.lstrip().startswith('{'):
            return parse_json_report(handle, known)
        return parse_log(handle, known)


def repo_test_files(root: Path) -> set[str]:
    return {
        path.relative_to(root).as_posix()
        for path in (root / 'test').rglob('*_test.dart')
    }


def build_durations(
    measured: dict[str, list[float]],
    known: set[str],
    previous: dict[str, int],
) -> tuple[int, dict[str, int]]:
    """Merge measurements into the (default_seconds, tests) payload.

    >>> build_durations({'test/a_test.dart': [2.2, 3.9]},
    ...                 {'test/a_test.dart', 'test/new_test.dart',
    ...                  'test/old_test.dart'},
    ...                 {'test/old_test.dart': 9, 'test/gone_test.dart': 7})
    (4, {'test/a_test.dart': 4, 'test/new_test.dart': 4, \
'test/old_test.dart': 9})
    """
    rounded = {
        path: max(1, math.ceil(statistics.fmean(values)))
        for path, values in measured.items()
    }
    default = (
        max(1, math.ceil(statistics.median(rounded.values())))
        if rounded
        else 1
    )
    tests: dict[str, int] = {}
    for path in sorted(known | set(rounded)):
        if path in rounded:
            tests[path] = rounded[path]
        elif path in previous:
            tests[path] = previous[path]
        else:
            tests[path] = default
    return default, tests


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument(
        'logs',
        nargs='+',
        type=Path,
        help='JSON reporter files and/or expanded CI logs',
    )
    parser.add_argument(
        '--durations',
        type=Path,
        default=Path('.github/test-durations.json'),
    )
    parser.add_argument('--repo-root', type=Path, default=Path('.'))
    parser.add_argument('--source', default='', help='provenance note')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    known = repo_test_files(args.repo_root)
    previous: dict[str, int] = {}
    if args.durations.exists():
        previous = {
            str(path): int(seconds)
            for path, seconds in json.loads(args.durations.read_text())
            .get('tests', {})
            .items()
        }
    measured: dict[str, list[float]] = {}
    for log in args.logs:
        for path, seconds in parse_input(log, known).items():
            measured.setdefault(path, []).append(seconds)
        print(f'{log}: {len(measured)} files measured so far', file=sys.stderr)
    if not measured:
        raise SystemExit('no per-file timings found in the given inputs')

    default, tests = build_durations(measured, known, previous)
    unseen = sorted(path for path in known if path not in measured)
    payload = {
        'default_seconds': default,
        'source': args.source,
        'tests': tests,
    }
    args.durations.write_text(json.dumps(payload, indent=2) + '\n')
    print(
        f'wrote {args.durations}: {len(tests)} files, '
        f'{len(measured)} measured, {len(unseen)} unseen, '
        f'default {default}s, total {sum(tests.values())}s',
        file=sys.stderr,
    )
    for path in unseen:
        print(f'  unseen: {path}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
