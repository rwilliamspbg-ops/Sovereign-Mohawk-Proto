#!/usr/bin/env python3
"""Smoke test for the Flower-compatible Mohawk adapter."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from mohawk import MohawkFlowerClient, MohawkNode


def build_training_fn():
    def _train(parameters, config):
        del config
        updated = []
        for tensor in parameters:
            if isinstance(tensor, list):
                updated.append([value + 0.25 for value in tensor])
            else:
                updated.append(tensor + 0.25)
        metrics = {"loss": 0.125, "accuracy": 0.95}
        return updated, 32, metrics

    return _train


def build_evaluate_fn():
    def _evaluate(parameters, config):
        del parameters, config
        return 0.125, 32, {"accuracy": 0.95}

    return _evaluate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ci", action="store_true", help="Emit machine-readable smoke output")
    args = parser.parse_args()

    client = MohawkFlowerClient(
        MohawkNode(),
        train_fn=build_training_fn(),
        evaluate_fn=build_evaluate_fn(),
        initial_parameters=[[0.0, 1.0], [2.0, 3.0]],
        node_id="flower-demo-node",
        submit_updates=True,
    )

    parameters = client.get_parameters({})
    updated_parameters, num_examples, metrics = client.fit(
        parameters,
        {"server_round": 1, "mohawk_format": "fp16", "mohawk_max_norm": 1.0},
    )
    loss, eval_examples, eval_metrics = client.evaluate(updated_parameters, {})

    payload = {
        "node_id": client.node_id,
        "num_examples": num_examples,
        "loss": loss,
        "eval_examples": eval_examples,
        "fit_metrics": metrics,
        "eval_metrics": eval_metrics,
    }
    if args.ci:
        print(json.dumps(payload, sort_keys=True))
    else:
        print("Flower-compatible Mohawk demo")
        print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
