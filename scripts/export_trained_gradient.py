#!/usr/bin/env python3
"""Export a genuinely trained gradient vector for the live gradient path.

Uses only the Python standard library: a small linear model trained with SGD on
deterministic synthetic data. Each seed yields a different honest gradient,
so Multi-Krum sees real distances rather than synthetic noise.
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path


def train(seed: int, dims: int, steps: int) -> list[float]:
    rng = random.Random(seed)
    weights = [rng.uniform(-0.1, 0.1) for _ in range(dims)]
    true_weights = [rng.uniform(-1.0, 1.0) for _ in range(dims)]
    learning_rate = 0.02
    last_gradient = [0.0] * dims
    for _ in range(steps):
        x = [rng.gauss(0.0, 1.0) for _ in range(dims)]
        target = sum(w * v for w, v in zip(true_weights, x)) + rng.gauss(0.0, 0.05)
        prediction = sum(w * v for w, v in zip(weights, x))
        error = prediction - target
        last_gradient = [error * value for value in x]
        for i in range(dims):
            weights[i] -= learning_rate * last_gradient[i]
    return [value / steps for value in last_gradient]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--node-id", required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--dims", type=int, default=128)
    parser.add_argument("--steps", type=int, default=200)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    gradient = train(args.seed, args.dims, args.steps)
    if not all(math.isfinite(value) for value in gradient):
        raise SystemExit("trained gradient contains non-finite values")
    Path(args.out).write_text(json.dumps({"node_id": args.node_id, "gradient": gradient}))
    print(f"wrote {len(gradient)}-dimension trained gradient for {args.node_id} to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
