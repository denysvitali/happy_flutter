"""CPU capture accounting contracts; run in CI only."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    'cpu_profile', Path(__file__).with_name('cpu_profile.py'))
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class CpuProfileTest(unittest.TestCase):
    def test_multicore_and_weighted_summary(self):
        first = {'elapsed_seconds': 10, 'cpu_seconds': 3, 'start_ticks': 7,
                 'rss_bytes': 100}
        second = {**first, 'elapsed_seconds': 12, 'cpu_seconds': 8}
        third = {**second, 'elapsed_seconds': 20, 'cpu_seconds': 9,
                 'rss_bytes': 200}
        busy = profile.interval(first, second)
        quiet = profile.interval(second, third)
        self.assertEqual(busy['cpu_percent'], 250)
        self.assertEqual(quiet['cpu_percent'], 12.5)
        summary = profile.summarize([busy, quiet])
        self.assertEqual(summary['mean_cpu_percent'], 60)
        self.assertEqual(summary['peak_rss_bytes'], 200)

    def test_reused_pid_and_reset_counters_fail_closed(self):
        first = {'elapsed_seconds': 10, 'cpu_seconds': 3, 'start_ticks': 7,
                 'rss_bytes': 100}
        for second in [
            {**first, 'elapsed_seconds': 11, 'start_ticks': 8},
            {**first, 'elapsed_seconds': 11, 'cpu_seconds': 2},
            first,
        ]:
            with self.assertRaises(ValueError):
                profile.interval(first, second)


if __name__ == '__main__':
    unittest.main()
