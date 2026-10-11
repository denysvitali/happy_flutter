#!/usr/bin/env python3
"""Check correctness lanes and independent Linux publication in CI."""
from pathlib import Path
import re
import unittest

import yaml


def check(workflow):
    jobs = workflow['jobs']
    gate = jobs['quality-gate']
    for lane, flag, suite in (
        ('native-contract', 'HAPPY_REQUIRE_NATIVE',
         'test/encryption/native_at_rest_compat_test.dart'),
        ('cross-repo-contract', 'HAPPY_REQUIRE_CLI_GO',
         'test/integration/cross_repo_contract_test.dart'),
    ):
        assert lane in gate['needs'], f'{lane} must gate quality'
        assert f'needs.{lane}.result' in str(gate['steps'])
        assert 'continue-on-error' not in jobs[lane]
        assert all('continue-on-error' not in step
                   for step in jobs[lane]['steps'])
        commands = '\n'.join(step.get('run', '') for step in jobs[lane]['steps'])
        assert f'--dart-define={flag}=true' in commands
        assert suite in commands
    browser = jobs['browser-contract']
    assert 'browser-contract' in gate['needs']
    assert 'needs.browser-contract.result' in str(gate['steps'])
    assert 'if' not in browser
    assert 'continue-on-error' not in browser
    assert all('continue-on-error' not in step for step in browser['steps'])
    browser_commands = '\n'.join(step.get('run', '') for step in browser['steps'])
    assert '--platform chrome' in browser_commands
    assert 'test/browser/mmkv_storage_web_test.dart' in browser_commands
    assert 'CHROME_EXECUTABLE' in browser_commands
    native_commands = str(jobs['native-contract']['steps'])
    assert 'cargo build --release --locked' in native_commands
    for suite in ('native_json_batch_test.dart',
                  'native_sidechain_planner_test.dart'):
        assert suite in native_commands
    go_checkout = next(
        step for step in jobs['cross-repo-contract']['steps']
        if step.get('with', {}).get('repository') == 'denysvitali/happy-cli-go'
    )
    assert re.fullmatch(r'[0-9a-f]{40}', go_checkout['with']['ref'])
    assert go_checkout['with']['persist-credentials'] is False
    assert go_checkout['with']['token'] == '${{ secrets.HAPPY_CLI_GO_READ_TOKEN }}'
    credential = next(
        step for step in jobs['cross-repo-contract']['steps']
        if 'HAPPY_CLI_GO_READ_TOKEN' in step.get('env', {})
    )
    assert 'exit 1' in credential['run']
    assert jobs['cross-repo-contract']['steps'].index(credential) < (
        jobs['cross-repo-contract']['steps'].index(go_checkout))
    assert 'HAPPY_CLI_GO_PATH' in jobs['cross-repo-contract']['env']

    publish = jobs['attach-linux']
    assert set(publish['needs']) == {'build-release', 'build-linux',
                                    'build-flatpak'}
    condition = publish['if']
    assert 'always()' in condition
    assert "needs.build-release.result == 'success'" in condition
    assert 'needs.build-linux.result' not in condition
    assert 'needs.build-flatpak.result' not in condition
    assert publish['strategy']['fail-fast'] is False
    entries = publish['strategy']['matrix']['include']
    assert {(entry['package'], entry['architecture'], entry['extension'])
            for entry in entries} == {
        (package, arch, extension)
        for package, extension in (('linux', 'tar.gz'), ('flatpak', 'flatpak'))
        for arch in ('x64', 'arm64')
    }
    # Each matrix entry discovers its own artifact, then publishes only that
    # file. A missing/failed peer package never gates a successful entry.
    steps = publish['steps']
    discover = next(step for step in steps if step.get('id') == 'artifact')
    assert 'listWorkflowRunArtifacts' in discover['with']['script']
    download = next(step for step in steps
                    if step.get('uses', '').startswith('actions/download-artifact'))
    upload = next(step for step in steps
                  if 'gh release upload' in step.get('run', ''))
    for step in (download, upload):
        assert step['if'] == "steps.artifact.outputs.available == 'true'"
        assert 'continue-on-error' not in step
    assert 'matrix.package' in download['with']['name']
    assert 'matrix.architecture' in download['with']['name']
    assert 'matrix.extension' in upload['env']['ASSET_PATH']
    assert publish['permissions'] == {'actions': 'read', 'contents': 'write'}
    # APK policy: never gate release builds on the test/contract lanes.
    assert not set(jobs['build-release'].get('needs', [])).intersection(
        {'test', 'native-contract', 'cross-repo-contract', 'quality-gate'})


class WorkflowContracts(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.safe_load(
            Path('.github/workflows/ci.yml').read_text())

    def test_current_workflow(self):
        check(self.workflow)

    def test_optional_archive_failure_cannot_gate_publication(self):
        self.workflow['jobs']['attach-linux']['if'] += (
            " && needs.build-linux.result == 'success'")
        with self.assertRaises(AssertionError):
            check(self.workflow)

    def test_one_architecture_failure_cannot_gate_flatpaks(self):
        self.workflow['jobs']['attach-linux']['if'] += (
            " && needs.build-flatpak.result == 'success'")
        with self.assertRaises(AssertionError):
            check(self.workflow)

    def test_native_lane_cannot_be_optional(self):
        self.workflow['jobs']['native-contract']['continue-on-error'] = True
        with self.assertRaises(AssertionError):
            check(self.workflow)

    def test_go_pin_cannot_float(self):
        for step in self.workflow['jobs']['cross-repo-contract']['steps']:
            if step.get('with', {}).get('repository') == 'denysvitali/happy-cli-go':
                step['with']['ref'] = 'main'
        with self.assertRaises(AssertionError):
            check(self.workflow)


if __name__ == '__main__':
    unittest.main()
