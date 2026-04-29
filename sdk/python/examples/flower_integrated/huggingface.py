#!/usr/bin/env python3
"""Flower-integrated Hugging Face-style client example."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from examples.flower_integrated.common import FlowerIntegratedExample, run_example

EXAMPLE = FlowerIntegratedExample(
    name="huggingface",
    node_id="flower-hf-001",
    initial_parameters=[
        {
            "encoder": [[0.1, 0.2], [0.3, 0.4]],
            "adapter": [0.5, 0.6],
        }
    ],
    delta=0.05,
    train_examples=48,
    base_loss=0.27,
    accuracy=0.89,
    compress_format="auto",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ci", action="store_true", help="Emit machine-readable output"
    )
    parser.add_argument("--round", dest="server_round", type=int, default=1)
    args = parser.parse_args()
    print(run_example(EXAMPLE, server_round=args.server_round, pretty=not args.ci))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
