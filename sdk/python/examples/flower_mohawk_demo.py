#!/usr/bin/env python3
"""Smoke test for the Flower-compatible Mohawk adapter."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from examples.flower_integrated.common import FlowerIntegratedExample, run_example


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ci", action="store_true", help="Emit machine-readable output")
    parser.add_argument("--round", dest="server_round", type=int, default=1)
    args = parser.parse_args()

    example = FlowerIntegratedExample(
        name="flower-mohawk-demo",
        node_id="flower-demo-node",
        initial_parameters=[[0.0, 1.0], [2.0, 3.0]],
        delta=0.25,
        train_examples=32,
        base_loss=0.125,
        accuracy=0.95,
        compress_format="fp16",
    )
    print(run_example(example, server_round=args.server_round, pretty=not args.ci))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
