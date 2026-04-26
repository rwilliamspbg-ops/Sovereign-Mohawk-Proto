#!/usr/bin/env python3
"""Zero-config local simulator for Mohawk Flower-compatible clients.

This script runs a local-only simulation loop with virtual nodes and rounds,
without requiring a live orchestrator. It is intended for rapid laptop testing
and migration dry-runs.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from statistics import mean
from typing import Any, Dict, List

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from examples.flower_integrated.common import FlowerIntegratedExample


def _run_single_node(node_id: str, server_round: int, delta: float, compress_format: str) -> Dict[str, Any]:
    example = FlowerIntegratedExample(
        name="local-simulator",
        node_id=node_id,
        initial_parameters=[[0.0, 0.5], [1.0, 1.5]],
        delta=delta,
        train_examples=64,
        base_loss=0.18,
        accuracy=0.94,
        compress_format=compress_format,
    )
    return example.run(server_round=server_round)


def run_simulation(virtual_nodes: int, rounds: int, compress_format: str) -> Dict[str, Any]:
    started = time.perf_counter()
    round_summaries: List[Dict[str, Any]] = []

    for server_round in range(1, rounds + 1):
        round_start = time.perf_counter()
        losses: List[float] = []
        accuracies: List[float] = []

        for idx in range(virtual_nodes):
            node_id = f"virtual-node-{idx:05d}"
            # Small deterministic shift across nodes to emulate heterogeneous clients.
            delta = 0.10 + ((idx % 7) * 0.01)
            payload = _run_single_node(node_id, server_round, delta, compress_format)
            losses.append(float(payload["loss"]))
            accuracies.append(float(payload["eval_metrics"]["accuracy"]))

        duration = time.perf_counter() - round_start
        round_summaries.append(
            {
                "round": server_round,
                "virtual_nodes": virtual_nodes,
                "duration_seconds": duration,
                "mean_loss": mean(losses),
                "mean_accuracy": mean(accuracies),
                "nodes_per_second": (virtual_nodes / duration) if duration > 0 else 0.0,
            }
        )

    total_duration = time.perf_counter() - started
    return {
        "simulator": "mohawk-local",
        "virtual_nodes": virtual_nodes,
        "rounds": rounds,
        "compress_format": compress_format,
        "total_duration_seconds": total_duration,
        "throughput_nodes_per_second": (virtual_nodes * rounds / total_duration) if total_duration > 0 else 0.0,
        "round_summaries": round_summaries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a local Mohawk FL simulation")
    parser.add_argument("--virtual-nodes", type=int, default=1024, help="Number of virtual nodes")
    parser.add_argument("--rounds", type=int, default=3, help="Number of simulation rounds")
    parser.add_argument("--compress-format", default="fp16", help="Compression format")
    parser.add_argument("--ci", action="store_true", help="Emit machine-readable one-line JSON")
    args = parser.parse_args()

    summary = run_simulation(
        virtual_nodes=args.virtual_nodes,
        rounds=args.rounds,
        compress_format=args.compress_format,
    )

    if args.ci:
        print(json.dumps(summary, sort_keys=True))
    else:
        print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
