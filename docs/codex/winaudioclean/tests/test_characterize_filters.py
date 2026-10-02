"""Focused development-tool checks; no FFmpeg installation or real audio needed."""
from __future__ import annotations
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

DOC = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DOC / 'tools'))
import characterize_filters as c


def measurements(**changes):
    values = {'input_i': '-13.25', 'input_tp': '-1.40', 'input_lra': '0.10',
              'input_thresh': '-23.31', 'output_i': '-12.00', 'output_tp': '-1.50'}
    values.update(changes)
    return ('FFmpeg information before JSON\n' + json.dumps(values) + '\n'
            '[Parsed_astats_0 @ 123abc] Overall\n'
            '[Parsed_astats_0 @ 123abc] Peak level dB: -1.410000\n'
            '[Parsed_astats_0 @ 123abc] RMS level dB: -14.670000\n')


class CharacterizationTests(unittest.TestCase):
    def test_uses_final_file_input_metrics_not_analysis_output(self):
        result = c.parse_metrics(measurements())
        self.assertEqual(result['integrated_loudness']['value'], -13.25)
        self.assertEqual(result['true_peak']['value'], -1.40)
        self.assertEqual(result['sample_peak']['value'], -1.41)
        self.assertEqual(result['rms']['value'], -14.67)
        self.assertEqual(result['sample_peak']['unit'], 'dBFS')

    def test_nonfinite_metrics_are_null_with_reason_and_valid_json(self):
        stderr = measurements(input_i='-inf', input_tp='nan', input_lra='inf')
        stderr = stderr.replace('RMS level dB: -14.670000', 'RMS level dB: -inf')
        result = c.parse_metrics(stderr)
        for name in ('integrated_loudness', 'true_peak', 'loudness_range', 'rms'):
            self.assertIsNone(result[name]['value'])
            self.assertEqual(result[name]['status'], 'unavailable')
            self.assertTrue(result[name]['reason'])
        json.dumps(result, allow_nan=False)

    def test_missing_or_ambiguous_metrics_fail(self):
        cases = [measurements().replace('"input_tp": "-1.40", ', ''),
                 measurements().replace('RMS level dB', 'Not a metric'),
                 measurements() + measurements(), 'No measurement JSON']
        for stderr in cases:
            with self.subTest(stderr=stderr):
                with self.assertRaises(ValueError):
                    c.parse_metrics(stderr)

    def test_malformed_metric_fails_instead_of_becoming_unavailable(self):
        for value in ('garbage', None, True):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    c.parse_metrics(measurements(input_i=value))

    def test_sample_and_loudness_analyses_are_independent(self):
        path = Path('final.wav')
        sample_log = measurements().split('[Parsed_astats_', 1)[1]
        loudness_log = measurements().split('[Parsed_astats_', 1)[0]
        responses = [subprocess.CompletedProcess([], 0, '', sample_log),
                     subprocess.CompletedProcess([], 0, '', loudness_log)]
        with mock.patch.object(c, 'run', side_effect=responses) as runner:
            result = c.measure('ffmpeg', path, {})
        sample_args, loudness_args = [call.args[0] for call in runner.call_args_list]
        self.assertIn(c.SAMPLE_METRIC_FILTER, sample_args)
        self.assertNotIn(c.LOUDNESS_METRIC_FILTER, sample_args)
        self.assertIn(c.LOUDNESS_METRIC_FILTER, loudness_args)
        self.assertEqual(result['commands']['sample_metrics']['exit_code'], 0)

    def test_existing_output_is_refused_without_launch_or_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'existing'
            output.mkdir()
            marker = output / 'characterization.json'
            marker.write_text('preserve me', encoding='utf-8')
            with mock.patch.object(c, 'run') as runner:
                with self.assertRaises(FileExistsError):
                    c.characterize(output, sys.executable, sys.executable, DOC / 'BASELINE.json')
            runner.assert_not_called()
            self.assertEqual(marker.read_text(encoding='utf-8'), 'preserve me')

    def test_commands_sanitize_paths_and_use_bounded_no_shell_process(self):
        with tempfile.TemporaryDirectory() as temp:
            path = str(Path(temp) / 'input [mix] äö Å.wav')
            response = subprocess.CompletedProcess([], 0, '', '')
            with mock.patch.object(c.subprocess, 'run', return_value=response) as runner:
                _, command = c.recorded_run(['ffmpeg', '-i', path], {path: Path(path).name})
            self.assertEqual(command['argv'][-1], 'input [mix] äö Å.wav')
            self.assertNotIn(temp, json.dumps(command))
            self.assertEqual(runner.call_args.kwargs['timeout'], 90)
            self.assertFalse(runner.call_args.kwargs['shell'])

    def test_process_failure_is_not_reported_as_success(self):
        failed = subprocess.CompletedProcess([], 7, '', 'invalid filter')
        with mock.patch.object(c.subprocess, 'run', return_value=failed):
            with self.assertRaisesRegex(RuntimeError, 'exit 7'):
                c.run(['ffmpeg', '-version'])


if __name__ == '__main__':
    unittest.main()
