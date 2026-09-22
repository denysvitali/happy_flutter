#!/usr/bin/env python3
"""Report real Flutter test failures as one GitHub annotation per error.

The JSON reporter distinguishes failed assertions from application log lines
containing ``Error:``. Escaped newlines keep a failure and its stack in one
annotation, so unrelated log context cannot consume GitHub's annotation cap.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def read_events(lines: list[str]) -> list[dict]:
    """Keep completed events if a killed test process left a partial last line.

    >>> read_events(['{"type":"done"}', '{"type":', 'null'])
    [{'type': 'done'}]
    """
    events = []
    for line in lines:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def escape(value: str, *, property_value: bool = False) -> str:
    r"""Escape workflow command data and, separately, property delimiters.

    >>> escape('100%\n::error::oops\r')
    '100%25%0A::error::oops%0D'
    >>> escape('test/a,b:c.dart', property_value=True)
    'test/a%2Cb%3Ac.dart'
    """
    value = value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    if property_value:
        value = value.replace(',', '%2C').replace(':', '%3A')
    return value


def failure_annotations(events: list[dict], root: Path) -> list[str]:
    r"""Ignore passing-test diagnostics and preserve each actual failure.

    >>> events = [
    ...     {'type': 'suite', 'suite': {'id': 1, 'path': '/repo/test/a.dart'}},
    ...     {'type': 'testStart', 'test': {
    ...         'id': 2, 'suiteID': 1, 'name': 'spawn preference'}},
    ...     {'type': 'print', 'message': 'Error: expected mock response'},
    ...     {'type': 'error', 'testID': 2,
    ...      'error': 'Expected: empty\nActual: explicit',
    ...      'stackTrace': 'stack'},
    ... ]
    >>> result = failure_annotations(events, Path('/repo'))
    >>> len(result)
    1
    >>> result[0] == (
    ...     '::error file=test/a.dart,title=Flutter test failure::'
    ...     'spawn preference%0AExpected: empty%0AActual: explicit%0Astack')
    True
    >>> failure_annotations(events[:3], Path('/repo'))
    []
    >>> result = failure_annotations(
    ...     [{'type': 'error', 'error': 'compile failed'}], Path('/repo'))
    >>> result == ['::error title=Flutter test failure::'
    ...            'Flutter test failure%0Acompile failed']
    True
    >>> len(failure_annotations(events * 12, Path('/repo')))
    10
    >>> widget_events = [
    ...     {'type': 'print', 'testID': 99,
    ...      'message': '══╡ EXCEPTION CAUGHT BY WIDGETS ╞\nOther test'},
    ...     {'type': 'print', 'testID': 2, 'message': 'Error: app diagnostic'},
    ...     {'type': 'print', 'testID': 2,
    ...      'message': '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞\n'
    ...                 'A Timer is still pending.'},
    ...     {'type': 'error', 'testID': 2,
    ...      'error': 'Test failed. See exception logs above.'},
    ... ]
    >>> result = failure_annotations(events[:2] + widget_events, Path('/repo'))
    >>> len(result), 'A Timer is still pending.' in result[0]
    (1, True)
    >>> 'Other test' in result[0] or 'app diagnostic' in result[0]
    False
    >>> widget_events[2]['message'] += 'x' * 9000
    >>> result = failure_annotations(events[:2] + widget_events, Path('/repo'))
    >>> len(result[0]) < 9000
    True
    """
    suites = {
        event['suite']['id']: event['suite']
        for event in events if event.get('type') == 'suite'
    }
    tests = {
        event['test']['id']: event['test']
        for event in events if event.get('type') == 'testStart'
    }
    annotations = []
    framework_errors: dict[int, str] = {}
    for event in events:
        test_id = event.get('testID')
        if event.get('type') == 'print' and test_id is not None:
            printed = str(event.get('message', '')).lstrip()
            if printed.startswith('══╡ EXCEPTION CAUGHT'):
                # Widget assertions use a generic error event; the actual
                # exception is a separate print event for the same test.
                prior = framework_errors.get(test_id, '')
                framework_errors[test_id] = f'{prior}\n{printed}'.strip()[:8000]
        if event.get('type') != 'error':
            continue
        test = tests.get(test_id, {})
        suite = suites.get(test.get('suiteID'), {})
        properties = ['title=Flutter test failure']
        if suite.get('path'):
            path = Path(suite['path'])
            try:
                path = path.relative_to(root)
            except ValueError:
                pass
            location = escape(str(path), property_value=True)
            properties.insert(0, f'file={location}')
        message = '\n'.join(
            str(value).strip() for value in (
                test.get('name', 'Flutter test failure'),
                event.get('error', ''),
                event.get('stackTrace', ''),
                framework_errors.pop(test_id, ''),
            ) if value
        )
        annotations.append(f'::error {",".join(properties)}::{escape(message)}')
        if len(annotations) == 10:
            break
    return annotations


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('results', type=Path)
    args = parser.parse_args()
    lines = (
        args.results.read_text().splitlines() if args.results.exists() else []
    )
    annotations = failure_annotations(read_events(lines), Path.cwd())
    if not annotations:
        annotations = [
            '::error::Flutter exited unsuccessfully without a structured '
            'test failure. Inspect the test step log for compilation errors '
            'or process termination.'
        ]
    for annotation in annotations:
        print(annotation)


if __name__ == '__main__':
    main()
