#!/usr/bin/env python3
"""Flower-integrated LLM fine-tuning style example."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from examples.flower_integrated.common import FlowerIntegratedExample, run_example


EXAMPLE = FlowerIntegratedExample(
    name="llm-fine-tune",
    node_id="flower-llm-001",
    initial_parameters=[{
        "layers": [
            [[0.01, 0.02, 0.03], [0.04, 0.05, 0.06]],
            [[0.07, 0.08, 0.09], [0.10, 0.11, 0.12]],
        ],
        "head": [0.2, 0.3, 0.4],
    }],
    delta=0.01,
    train_examples=128,
    base_loss=0.11,
    accuracy=0.97,
    compress_format="int8",
    max_norm=1.0,
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
