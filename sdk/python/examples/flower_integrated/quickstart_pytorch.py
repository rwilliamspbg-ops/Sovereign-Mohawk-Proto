#!/usr/bin/env python3
"""Flower-integrated quickstart-style client example."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from examples.flower_integrated.common import FlowerIntegratedExample, run_example


EXAMPLE = FlowerIntegratedExample(
    name="quickstart-pytorch",
    node_id="flower-pytorch-001",
    initial_parameters=[[0.0, 0.5], [1.0, 1.5]],
    delta=0.15,
    train_examples=64,
    base_loss=0.18,
    accuracy=0.94,
    compress_format="fp16",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ci", action="store_true", help="Emit machine-readable output")
    parser.add_argument("--round", dest="server_round", type=int, default=1)
    args = parser.parse_args()
    print(run_example(EXAMPLE, server_round=args.server_round, pretty=not args.ci))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
