#!/usr/bin/env python3
"""Export a gradient trained by a real Flower NumPyClient.

Requires the optional `flower` extra (`flwr[simulation]>=1.17,<2`) and numpy.
The exported JSON matches `MOHAWK_GRADIENT_FILE` used by node-agent.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

try:
    import flwr
    import numpy as np
    from flwr.client import NumPyClient
except ImportError as exc:  # pragma: no cover - exercised only without the extra
    raise SystemExit("flwr and numpy are required; install the repo's flower extra") from exc


class LinearFlowerClient(NumPyClient):
    """A genuine Flower client training a small linear model with SGD."""

    def __init__(self, features: np.ndarray, labels: np.ndarray, learning_rate: float):
        self.features = features
        self.labels = labels
        self.learning_rate = learning_rate
        self.weights = np.zeros(features.shape[1], dtype=np.float64)

    def get_parameters(self, config):  # noqa: D102 - Flower interface
        return [self.weights.copy()]

    def fit(self, parameters, config):  # noqa: D102 - Flower interface
        self.weights = np.asarray(parameters[0], dtype=np.float64).copy()
        before = self.weights.copy()
        error = self.features @ self.weights - self.labels
        gradient = self.features.T @ error / len(self.features)
        self.weights -= self.learning_rate * gradient
        exported = (before - self.weights) / self.learning_rate
        return [self.weights], len(self.features), {"gradient": exported.tolist()}

    def evaluate(self, parameters, config):  # noqa: D102 - Flower interface
        weights = np.asarray(parameters[0], dtype=np.float64)
        error = self.features @ weights - self.labels
        return float(np.mean(error**2)), len(self.features), {}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--node-id", required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--dims", type=int, default=128)
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--learning-rate", type=float, default=0.05)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    rng = np.random.default_rng(args.seed)
    features = rng.normal(size=(args.samples, args.dims))
    true_weights = rng.normal(size=args.dims)
    labels = features @ true_weights + rng.normal(scale=0.05, size=args.samples)

    client = LinearFlowerClient(features, labels, args.learning_rate)
    _, _, metrics = client.fit(client.get_parameters({}), {"epochs": 1})
    gradient = [float(value) for value in metrics["gradient"]]
    if not all(math.isfinite(value) for value in gradient):
        raise SystemExit("Flower client produced non-finite gradients")

    payload = {
        "node_id": args.node_id,
        "gradient": gradient,
        "framework": "flwr",
        "flwr_version": flwr.__version__,
    }
    Path(args.out).write_text(json.dumps(payload))
    print(
        f"wrote {len(gradient)}-dimension Flower-client gradient for {args.node_id} to {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
