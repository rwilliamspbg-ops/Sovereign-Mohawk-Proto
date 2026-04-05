"""High-level pythonic request/response models for SDK v2 workflows."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Dict, Mapping, Optional, Union

JsonDict = Dict[str, Any]


@dataclass(frozen=True)
class BridgeTransferIntent:
    """Declarative bridge transfer input for a full cross-chain receipt."""

    source_chain: str
    target_chain: str
    asset: str
    amount: float
    sender: str
    receiver: str
    nonce: int
    proof: Union[str, Mapping[str, Any]]
    route_policy: Optional[Mapping[str, Any]] = None
    policy_manifest_path: Optional[str] = None
    policy_manifest: Optional[Mapping[str, Any]] = None
    settle: bool = False
    settlement_minter: Optional[str] = None
    finality_depth: int = 0
    auth_token: Optional[str] = None
    role: Optional[str] = None

    @classmethod
    def from_mapping(cls, payload: Mapping[str, Any]) -> "BridgeTransferIntent":
        return cls(
            source_chain=str(payload["source_chain"]),
            target_chain=str(payload["target_chain"]),
            asset=str(payload["asset"]),
            amount=float(payload["amount"]),
            sender=str(payload["sender"]),
            receiver=str(payload["receiver"]),
            nonce=int(payload["nonce"]),
            proof=payload["proof"],
            route_policy=payload.get("route_policy"),
            policy_manifest_path=payload.get("policy_manifest_path"),
            policy_manifest=payload.get("policy_manifest"),
            settle=bool(payload.get("settle", False)),
            settlement_minter=payload.get("settlement_minter"),
            finality_depth=int(payload.get("finality_depth", 0)),
            auth_token=payload.get("auth_token"),
            role=payload.get("role"),
        )

    def to_api_kwargs(self) -> JsonDict:
        payload: JsonDict = {
            "source_chain": self.source_chain,
            "target_chain": self.target_chain,
            "asset": self.asset,
            "amount": self.amount,
            "sender": self.sender,
            "receiver": self.receiver,
            "nonce": self.nonce,
            "proof": self.proof,
            "finality_depth": self.finality_depth,
        }
        if self.route_policy is not None:
            payload["route_policy"] = dict(self.route_policy)
        if self.policy_manifest_path is not None:
            payload["policy_manifest_path"] = self.policy_manifest_path
        if self.policy_manifest is not None:
            payload["policy_manifest"] = dict(self.policy_manifest)
        if self.settle:
            payload["settle"] = True
        if self.settlement_minter is not None:
            payload["settlement_minter"] = self.settlement_minter
        if self.auth_token is not None:
            payload["auth_token"] = self.auth_token
        if self.role is not None:
            payload["role"] = self.role
        return payload


@dataclass(frozen=True)
class BridgeTransferReceipt:
    """Normalized bridge receipt from a transfer call."""

    success: bool
    message: str
    transfer_id: Optional[str]
    status: Optional[str]
    settled: bool
    raw: JsonDict

    @classmethod
    def from_api_result(cls, result: Mapping[str, Any]) -> "BridgeTransferReceipt":
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

        settled = bool(result.get("settled", False) or data_obj.get("settled", False))
        return cls(
            success=bool(result.get("success", False)),
            message=str(result.get("message", "")),
            transfer_id=(
                str(data_obj.get("transfer_id"))
                if data_obj.get("transfer_id") is not None
                else None
            ),
            status=(
                str(data_obj.get("status"))
                if data_obj.get("status") is not None
                else None
            ),
            settled=settled,
            raw=dict(result),
        )


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
