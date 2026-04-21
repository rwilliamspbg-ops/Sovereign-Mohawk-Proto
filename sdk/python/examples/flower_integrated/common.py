"""Shared helpers for Flower-integrated SDK examples."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, Mapping, Sequence

from mohawk import MohawkFlowerClient, MohawkNode


def _shift_value(value: Any, delta: float) -> Any:
    if hasattr(value, "tolist"):
        value = value.tolist()
    if isinstance(value, list):
        return [_shift_value(item, delta) for item in value]
    if isinstance(value, tuple):
        return tuple(_shift_value(item, delta) for item in value)
    if isinstance(value, dict):
        return {key: _shift_value(inner, delta) for key, inner in value.items()}
    if isinstance(value, (bool, int, float)):
        return float(value) + delta
    return value


def _train_factory(
    *,
    delta: float,
    num_examples: int,
    base_loss: float,
    extra_metrics: Mapping[str, float],
):
    def _train(parameters: Sequence[Any], config: Mapping[str, Any]):
        round_delta = float(config.get("round_delta", delta))
        updated = [_shift_value(parameter, round_delta) for parameter in parameters]
        metrics = {"loss": base_loss, **{key: float(value) for key, value in extra_metrics.items()}}
        return updated, num_examples, metrics

    return _train


def _evaluate_factory(*, loss: float, num_examples: int, accuracy: float):
    def _evaluate(parameters: Sequence[Any], config: Mapping[str, Any]):
        del parameters, config
        return loss, num_examples, {"accuracy": accuracy}

    return _evaluate


@dataclass(frozen=True)
class FlowerIntegratedExample:
    name: str
    node_id: str
    initial_parameters: Sequence[Any]
    delta: float
    train_examples: int
    base_loss: float
    accuracy: float
    compress_format: str = "fp16"
    max_norm: float = 1.0

    def build_client(self) -> MohawkFlowerClient:
        return MohawkFlowerClient(
            MohawkNode(),
            train_fn=_train_factory(
                delta=self.delta,
                num_examples=self.train_examples,
                base_loss=self.base_loss,
                extra_metrics={"accuracy": self.accuracy},
            ),
            evaluate_fn=_evaluate_factory(
                loss=self.base_loss,
                num_examples=self.train_examples,
                accuracy=self.accuracy,
            ),
            initial_parameters=self.initial_parameters,
            node_id=self.node_id,
            compress_format=self.compress_format,
            max_norm=self.max_norm,
            submit_updates=False,
        )

    def run(self, *, server_round: int = 1) -> Dict[str, Any]:
        client = self.build_client()
        parameters = client.get_parameters({})
        updated_parameters, num_examples, metrics = client.fit(
            parameters,
            {
                "server_round": server_round,
                "mohawk_format": self.compress_format,
                "mohawk_max_norm": self.max_norm,
            },
        )
        loss, eval_examples, eval_metrics = client.evaluate(updated_parameters, {})
        payload = {
            "example": self.name,
            "node_id": self.node_id,
            "num_examples": num_examples,
            "loss": loss,
            "eval_examples": eval_examples,
            "fit_metrics": metrics,
            "eval_metrics": eval_metrics,
        }
        return payload

    def run_json(self, *, server_round: int = 1, pretty: bool = False) -> str:
        payload = self.run(server_round=server_round)
        if pretty:
            return json.dumps(payload, indent=2, sort_keys=True)
        return json.dumps(payload, sort_keys=True)


def run_example(
    example: FlowerIntegratedExample, *, server_round: int = 1, pretty: bool = False
) -> str:
    return example.run_json(server_round=server_round, pretty=pretty)
