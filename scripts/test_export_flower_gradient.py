#!/usr/bin/env python3
"""Tests for scripts/export_flower_gradient.py (skipped without flwr/numpy)."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "export_flower_gradient.py"
HAS_FLOWER = (
    importlib.util.find_spec("flwr") is not None and importlib.util.find_spec("numpy") is not None
)


@unittest.skipUnless(HAS_FLOWER, "flwr and numpy are optional dependencies")
class FlowerGradientTest(unittest.TestCase):
    def _run(self, out: Path, seed: int) -> None:
        subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--node-id",
                "flower-node",
                "--seed",
                str(seed),
                "--dims",
                "16",
                "--out",
                str(out),
            ],
            check=True,
            capture_output=True,
        )

    def test_export_is_deterministic_finite_and_nonzero(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / "a.json", Path(directory) / "b.json"
            self._run(first, 7)
            self._run(second, 7)
            a, b = json.loads(first.read_text()), json.loads(second.read_text())
            self.assertEqual(a, b)
            self.assertEqual(a["node_id"], "flower-node")
            self.assertEqual(len(a["gradient"]), 16)
            self.assertTrue(any(value != 0 for value in a["gradient"]))
            self.assertTrue(all(abs(value) != float("inf") for value in a["gradient"]))

    def test_different_seeds_differ(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / "a.json", Path(directory) / "b.json"
            self._run(first, 1)
            self._run(second, 2)
            self.assertNotEqual(
                json.loads(first.read_text())["gradient"],
                json.loads(second.read_text())["gradient"],
            )


if __name__ == "__main__":
    unittest.main()
