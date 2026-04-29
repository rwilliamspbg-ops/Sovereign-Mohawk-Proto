"""High-level pythonic request/response models for SDK v2 workflows."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, Mapping, Optional

JsonDict = Dict[str, Any]


@dataclass(frozen=True)
class HybridProofCheck:
    """Declarative hybrid proof verification input."""

    snark_proof: str
    stark_proof: str
    mode: str = "prefer_snark"
    stark_backend: str = "simulated_fri"
    auth_token: Optional[str] = None
    role: Optional[str] = None

    @classmethod
    def from_mapping(cls, payload: Mapping[str, Any]) -> "HybridProofCheck":
        return cls(
            snark_proof=str(payload["snark_proof"]),
            stark_proof=str(payload["stark_proof"]),
            mode=str(payload.get("mode", "prefer_snark")),
            stark_backend=str(payload.get("stark_backend", "simulated_fri")),
            auth_token=payload.get("auth_token"),
            role=payload.get("role"),
        )

    def to_api_kwargs(self) -> JsonDict:
        payload: JsonDict = {
            "snark_proof": self.snark_proof,
            "stark_proof": self.stark_proof,
            "mode": self.mode,
            "stark_backend": self.stark_backend,
        }
        if self.auth_token is not None:
            payload["auth_token"] = self.auth_token
        if self.role is not None:
            payload["role"] = self.role
        return payload


@dataclass(frozen=True)
class HybridVerificationReceipt:
    """Normalized response for hybrid verification workflows."""

    success: bool
    message: str
    mode: Optional[str]
    selected_scheme: Optional[str]
    backend: Optional[str]
    raw: JsonDict

    @classmethod
    def from_api_result(cls, result: Mapping[str, Any]) -> "HybridVerificationReceipt":
        data = result.get("data")
        data_obj: JsonDict = {}
        if isinstance(data, dict):
            data_obj = dict(data)
        elif isinstance(data, str) and data.strip():
            try:
                parsed = json.loads(data)
                if isinstance(parsed, dict):
                    data_obj = parsed
            except json.JSONDecodeError:
                data_obj = {}

        return cls(
            success=bool(result.get("success", False)),
            message=str(result.get("message", "")),
            mode=(
                str(data_obj.get("mode")) if data_obj.get("mode") is not None else None
            ),
            selected_scheme=(
                str(data_obj.get("selected_scheme"))
                if data_obj.get("selected_scheme") is not None
                else None
            ),
            backend=(
                str(data_obj.get("stark_backend"))
                if data_obj.get("stark_backend") is not None
                else None
            ),
            raw=dict(result),
        )
