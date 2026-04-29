"""Thin Flower strategy forwarding helpers for the MOHAWK Python SDK."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

from .client import JsonDict, MohawkNode


def _normalize_parameters(parameters: Any) -> List[float]:
    flattened: List[float] = []

    def _walk(value: Any) -> None:
        if hasattr(value, "tolist"):
            value = value.tolist()
        if isinstance(value, Mapping):
            for inner in value.values():
                _walk(inner)
            return
        if isinstance(value, (list, tuple)):
            for inner in value:
                _walk(inner)
            return
        if isinstance(value, (bool, int, float)):
            flattened.append(float(value))
            return
        try:
            flattened.append(float(value))
        except (TypeError, ValueError) as exc:
            raise TypeError(
                f"unsupported Flower strategy parameter: {value!r}"
            ) from exc

    _walk(parameters)
    return flattened


def _extract_payload_value(payload: Any, key: str, default: Any = None) -> Any:
    if isinstance(payload, Mapping):
        return payload.get(key, default)
    return getattr(payload, key, default)


def _weighted_average(values: Sequence[Tuple[float, int]]) -> float:
    total_weight = sum(weight for _, weight in values)
    if total_weight <= 0:
        return 0.0
    return sum(value * weight for value, weight in values) / total_weight


@dataclass(frozen=True)
class FlowerStrategyRoundSummary:
    """Summary returned by a Flower strategy bridge round."""

    strategy_name: str
    server_round: int
    mohawk_result: JsonDict
    delegate_result: Optional[Any]
    metrics: JsonDict


class FlowerStrategyForwarder:
    """Forward Flower-style rounds into the Go-backed Mohawk aggregation path.

    The class is intentionally thin: it normalizes client outputs into Mohawk
    update payloads, calls the Go runtime for aggregation, and optionally
    forwards the round to a delegate strategy object if one is supplied.
    """

    def __init__(
        self,
        mohawk: MohawkNode,
        *,
        delegate: Optional[Any] = None,
        strategy_name: str = "fedavg",
        max_norm: float = 1.0,
        compress_format: str = "fp16",
    ) -> None:
        self.mohawk = mohawk
        self.delegate = delegate
        self.strategy_name = strategy_name
        self.max_norm = max_norm
        self.compress_format = compress_format

    def _build_updates(self, results: Iterable[Any]) -> List[Dict[str, Any]]:
        updates: List[Dict[str, Any]] = []
        for index, result in enumerate(results):
            if isinstance(result, tuple) and len(result) == 2:
                client_proxy, fit_result = result
            else:
                client_proxy, fit_result = None, result

            node_id = _extract_payload_value(client_proxy, "cid", f"client-{index:03d}")
            parameters = _extract_payload_value(
                fit_result,
                "parameters",
                _extract_payload_value(fit_result, "weights", []),
            )
            num_examples = int(
                _extract_payload_value(fit_result, "num_examples", 1) or 1
            )
            metrics = _extract_payload_value(fit_result, "metrics", {})

            updates.append(
                {
                    "node_id": str(node_id),
                    "gradient": _normalize_parameters(parameters),
                    "weight": float(num_examples),
                    "metrics": dict(metrics) if isinstance(metrics, Mapping) else {},
                }
            )
        return updates

    def aggregate_fit(
        self,
        server_round: int,
        results: Iterable[Any],
        failures: Iterable[Any] = (),
    ) -> FlowerStrategyRoundSummary:
        results_list = list(results)
        failures_list = list(failures)
        updates = self._build_updates(results_list)
        mohawk_result = self.mohawk.aggregate(updates)
        delegate_result = None
        if self.delegate is not None and hasattr(self.delegate, "aggregate_fit"):
            delegate_result = self.delegate.aggregate_fit(
                server_round, results_list, failures_list
            )

        metrics = {
            "strategy": self.strategy_name,
            "clients": len(updates),
            "failures": len(failures_list),
            "aggregated_updates": mohawk_result.get("count", len(updates)),
        }
        return FlowerStrategyRoundSummary(
            strategy_name=self.strategy_name,
            server_round=server_round,
            mohawk_result=mohawk_result,
            delegate_result=delegate_result,
            metrics=metrics,
        )

    def aggregate_evaluate(
        self,
        server_round: int,
        results: Iterable[Any],
        failures: Iterable[Any] = (),
    ) -> FlowerStrategyRoundSummary:
        evaluations = list(results)
        failures_list = list(failures)
        delegate_result = None
        if self.delegate is not None and hasattr(self.delegate, "aggregate_evaluate"):
            delegate_result = self.delegate.aggregate_evaluate(
                server_round, evaluations, failures_list
            )

        weighted_losses: List[Tuple[float, int]] = []
        weighted_metrics: List[Tuple[float, int]] = []
        for item in evaluations:
            if isinstance(item, tuple) and len(item) == 2:
                _, eval_result = item
            else:
                eval_result = item

            loss = float(_extract_payload_value(eval_result, "loss", 0.0) or 0.0)
            num_examples = int(
                _extract_payload_value(eval_result, "num_examples", 1) or 1
            )
            weighted_losses.append((loss, num_examples))
            weighted_metrics.append(
                (
                    float(_extract_payload_value(eval_result, "accuracy", 0.0) or 0.0),
                    num_examples,
                )
            )

        metrics = {
            "strategy": self.strategy_name,
            "clients": len(evaluations),
            "failures": len(failures_list),
            "loss": _weighted_average(weighted_losses),
            "accuracy": _weighted_average(weighted_metrics),
        }
        return FlowerStrategyRoundSummary(
            strategy_name=self.strategy_name,
            server_round=server_round,
            mohawk_result={"success": True, "message": "evaluation forwarded"},
            delegate_result=delegate_result,
            metrics=metrics,
        )

    def forward_round(
        self,
        server_round: int,
        fit_results: Iterable[Any],
        eval_results: Optional[Iterable[Any]] = None,
        failures: Iterable[Any] = (),
    ) -> Dict[str, Any]:
        fit_summary = self.aggregate_fit(server_round, fit_results, failures)
        evaluation_summary = None
        if eval_results is not None:
            evaluation_summary = self.aggregate_evaluate(
                server_round, eval_results, failures
            )
        return {
            "strategy": self.strategy_name,
            "server_round": server_round,
            "fit": fit_summary,
            "evaluate": evaluation_summary,
        }
