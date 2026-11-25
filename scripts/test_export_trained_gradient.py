#!/usr/bin/env python3
"""Tests for scripts/export_trained_gradient.py (stdlib only)."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "export_trained_gradient.py"


class TrainedGradientTest(unittest.TestCase):
    def test_export_is_deterministic_and_nonzero(self):
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "a.json"
            second = Path(directory) / "b.json"
            for path in (first, second):
                subprocess.run(
                    [sys.executable, str(SCRIPT), "--node-id", "n1", "--seed", "7",
                     "--dims", "16", "--steps", "20", "--out", str(path)],
                    check=True, capture_output=True,
                )
            a = json.loads(first.read_text())
            b = json.loads(second.read_text())
            self.assertEqual(a, b)
            self.assertEqual(a["node_id"], "n1")
            self.assertEqual(len(a["gradient"]), 16)
            self.assertTrue(any(value != 0 for value in a["gradient"]))

    def test_different_seeds_differ(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for seed in (1, 2):
                path = Path(directory) / f"{seed}.json"
                subprocess.run(
                    [sys.executable, str(SCRIPT), "--node-id", "n1", "--seed", str(seed),
                     "--dims", "16", "--steps", "20", "--out", str(path)],
                    check=True, capture_output=True,
                )
                paths.append(json.loads(path.read_text())["gradient"])
            self.assertNotEqual(paths[0], paths[1])


if __name__ == "__main__":
    unittest.main()
