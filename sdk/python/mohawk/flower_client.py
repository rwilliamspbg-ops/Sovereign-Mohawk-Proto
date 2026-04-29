"""Flower compatibility helpers for the MOHAWK Python SDK."""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass
from typing import Any, Callable, List, Mapping, Optional, Sequence, Tuple, Union

try:  # pragma: no cover - optional dependency
    from flwr.client import NumPyClient as _FlowerNumPyClient
except Exception:  # pragma: no cover - executed when Flower is not installed

    class _FlowerNumPyClient:
        """Fallback base class that mirrors Flower's NumPyClient surface."""

        def get_parameters(self, config: Mapping[str, Any]):
            raise NotImplementedError

        def fit(self, parameters: Sequence[Any], config: Mapping[str, Any]):
            raise NotImplementedError

        def evaluate(self, parameters: Sequence[Any], config: Mapping[str, Any]):
            raise NotImplementedError


from .client import JsonDict, MohawkNode

Scalar = Union[bool, int, float, str]
TrainFn = Callable[
    [Sequence[Any], Mapping[str, Any]], Tuple[Sequence[Any], int, Mapping[str, Scalar]]
]
EvaluateFn = Callable[[Sequence[Any], Mapping[str, Any]], Tuple[float, int, Mapping[str, Scalar]]]


@dataclass(frozen=True)
class FlowerTrainingReport:
    """Summary returned by the Mohawk Flower adapter after a round."""

    node_id: str
    num_examples: int
    compression: JsonDict
    proof_manifest: JsonDict
    aggregation: JsonDict
    metrics: JsonDict


def _normalize_value(value: Any) -> Any:
    if hasattr(value, "tolist"):
        value = value.tolist()
    if isinstance(value, Mapping):
        return {str(key): _normalize_value(inner) for key, inner in value.items()}
    if isinstance(value, (list, tuple)):
        return [_normalize_value(item) for item in value]
    if isinstance(value, (bytes, bytearray, memoryview)):
        return base64.b64encode(bytes(value)).decode("ascii")
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def _flatten_parameters(parameters: Sequence[Any]) -> List[float]:
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
        except (TypeError, ValueError):
            raise TypeError(f"unsupported parameter value for Flower bridge: {value!r}")

    for parameter in parameters:
        _walk(parameter)
    return flattened


def _hash_payload(*parts: Any) -> str:
    normalized = [_normalize_value(part) for part in parts]
    payload = json.dumps(normalized, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


class MohawkFlowerClient(_FlowerNumPyClient):
    """Flower-compatible client wrapper around :class:`mohawk.client.MohawkNode`.

    The caller supplies the local training and evaluation logic. The wrapper
    handles Mohawk compression, proof-envelope generation, and aggregation
    submission to the Go runtime.
    """

    def __init__(
        self,
        mohawk: MohawkNode,
        *,
        train_fn: TrainFn,
        evaluate_fn: Optional[EvaluateFn] = None,
        initial_parameters: Optional[Any] = None,
        node_id: str = "flower-client",
        compress_format: str = "auto",
        max_norm: float = 1.0,
        submit_updates: bool = True,
        proof_namespace: str = "mohawk-flower",
    ) -> None:
        self.mohawk = mohawk
        self._train_fn = train_fn
        self._evaluate_fn = evaluate_fn
        self._initial_parameters = initial_parameters
        self.node_id = node_id
        self.compress_format = compress_format
        self.max_norm = max_norm
        self.submit_updates = submit_updates
        self.proof_namespace = proof_namespace

    def get_parameters(self, config: Mapping[str, Any]):
        del config
        if self._initial_parameters is None:
            return []
        if isinstance(self._initial_parameters, Mapping):
            return [dict(self._initial_parameters)]
        if isinstance(self._initial_parameters, (list, tuple)):
            return [parameter for parameter in self._initial_parameters]
        return [self._initial_parameters]

    def _build_proof_manifest(
        self,
        *,
        input_parameters: Sequence[Any],
        updated_parameters: Sequence[Any],
        num_examples: int,
        metrics: Mapping[str, Scalar],
        compression: JsonDict,
        config: Mapping[str, Any],
    ) -> JsonDict:
        round_number = int(config.get("server_round", 0) or 0)
        manifest = {
            "namespace": self.proof_namespace,
            "node_id": self.node_id,
            "round": round_number,
            "num_examples": num_examples,
            "input_hash": _hash_payload(input_parameters),
            "output_hash": _hash_payload(updated_parameters),
            "metrics_hash": _hash_payload(metrics),
            "compression": {
                "format": compression.get("format"),
                "compressed_bytes": compression.get("compressed_bytes"),
                "compression_ratio": compression.get("compression_ratio"),
            },
        }
        manifest["proof"] = _hash_payload(manifest)
        return manifest

    def submit_update(
        self,
        *,
        input_parameters: Sequence[Any],
        updated_parameters: Sequence[Any],
        num_examples: int,
        metrics: Mapping[str, Scalar],
        config: Mapping[str, Any],
    ) -> FlowerTrainingReport:
        flattened = _flatten_parameters(updated_parameters)
        selected_format = config.get("mohawk_format", self.compress_format) or self.compress_format
        selected_max_norm = config.get("mohawk_max_norm", self.max_norm) or self.max_norm
        compression = self.mohawk.compress_gradients(
            flattened,
            format=str(selected_format),
            max_norm=float(selected_max_norm),
        )
        proof_manifest = self._build_proof_manifest(
            input_parameters=input_parameters,
            updated_parameters=updated_parameters,
            num_examples=num_examples,
            metrics=metrics,
            compression=compression,
            config=config,
        )
        aggregation = {"success": True, "skipped": True}
        if self.submit_updates:
            aggregation = self.mohawk.aggregate(
                [
                    {
                        "node_id": self.node_id,
                        "gradient": flattened,
                        "weight": float(num_examples),
                    }
                ]
            )
        return FlowerTrainingReport(
            node_id=self.node_id,
            num_examples=num_examples,
            compression=compression,
            proof_manifest=proof_manifest,
            aggregation=aggregation,
            metrics=dict(metrics),
        )

    def fit(self, parameters: Sequence[Any], config: Mapping[str, Any]):
        current_parameters = [parameter for parameter in parameters]
        updated_parameters, num_examples, metrics = self._train_fn(current_parameters, config)
        report = self.submit_update(
            input_parameters=current_parameters,
            updated_parameters=updated_parameters,
            num_examples=num_examples,
            metrics=metrics,
            config=config,
        )
        combined_metrics: JsonDict = {
            **dict(metrics),
            "mohawk_compressed_bytes": report.compression.get("compressed_bytes"),
            "mohawk_compression_ratio": report.compression.get("compression_ratio"),
            "mohawk_proof": report.proof_manifest["proof"],
            "mohawk_round": report.proof_manifest["round"],
        }
        return list(updated_parameters), num_examples, combined_metrics

    def evaluate(self, parameters: Sequence[Any], config: Mapping[str, Any]):
        if self._evaluate_fn is None:
            return 0.0, 0, {"mohawk_status": "evaluation skipped"}
        loss, num_examples, metrics = self._evaluate_fn(list(parameters), config)
        return loss, num_examples, dict(metrics)
