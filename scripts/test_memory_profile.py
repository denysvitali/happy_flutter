"""Contract checks for the profile artifact schema (CI only)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'memory_profile', Path(__file__).with_name('memory_profile.py'))
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class MemoryProfileTest(unittest.TestCase):
    def test_summary_rejects_partial_capture_and_preserves_unknown_native(self):
        rows = [{'schema': 1, 'type': 'manifest', 'cycles': 1,
                 'revision': 'test-only', 'fixture': 'deterministic-v1'}]
        for phase in profile.PHASES:
            for index, stage in enumerate(('before', 'after_workload', 'after_gc')):
                rows.append({'schema': 1, 'phase': phase, 'cycle': 0,
                             'stage': stage, 'native_bytes': None,
                             **{key: 100 + index for key in profile.FIELDS}})
        rows.append({'schema': 1, 'type': 'complete', 'samples': 9})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'capture.jsonl'
            path.write_text('\n'.join(map(json.dumps, rows)))
            result = profile.summarize(path)
            self.assertEqual(result['samples'], 9)
            self.assertEqual(result['maxima']['rss_bytes'], 102)
            self.assertEqual(result['post_gc_growth']['long_chat']['rss_bytes'], 2)
            self.assertIsNone(result['native_bytes'])
            path.write_text('\n'.join(map(json.dumps, rows[:-1])))
            with self.assertRaises(ValueError):
                profile.summarize(path)

    def test_attribution_is_not_native(self):
        result = profile.attribution(1000, [
            {'heapUsage': 200, 'heapCapacity': 400, 'externalUsage': 50},
            {'heapUsage': 100, 'heapCapacity': 200, 'externalUsage': 20},
        ])
        self.assertEqual(result['heap_used_bytes'], 300)
        self.assertEqual(result['heap_capacity_bytes'], 600)
        self.assertEqual(result['estimated_rss_minus_heap_bytes'], 700)
        self.assertIsNone(result['native_bytes'])
        self.assertEqual(result['vm_external_bytes'], 70)

    def test_rss_below_heap_is_not_negative_native_memory(self):
        result = profile.attribution(10, [
            {'heapUsage': 200, 'heapCapacity': 300, 'externalUsage': 0},
        ])
        self.assertEqual(result['estimated_rss_minus_heap_bytes'], -190)
        self.assertIsNone(result['native_bytes'])

    def test_phase_order_is_fixed(self):
        self.assertEqual(profile.PHASES, (
            'long_chat', 'session_switch', 'background_resume'))

    def test_invalid_metrics_fail_closed(self):
        with self.assertRaises(ValueError):
            profile.validate_metrics({'resident_rows': -1})
        with self.assertRaises(ValueError):
            profile.validate_metrics({'resident_rows': 1})
        metrics = {key: 0 for key in profile.METRICS}
        self.assertEqual(profile.validate_metrics(metrics), metrics)


if __name__ == '__main__':
    unittest.main()
