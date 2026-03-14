"""Cross-chain bridge proof helpers for the MOHAWK Python SDK."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Any, List


@dataclass
class EVMLogProof:
    block_hash: str
    tx_hash: str
    log_index: int
    event_sig: str
    receipt_root: str

    def to_payload(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class CosmosIBCProof:
    client_id: str
    connection_id: str
    channel_id: str
    port_id: str
    sequence: int
    commitment: str
    height: int

    def to_payload(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class RoutePolicy:
    id: str
    allowed_assets: List[str]
    min_amount: float = 0.0
    max_amount: float = 0.0
    min_finality_blocks: int = 0

    def to_payload(self) -> Dict[str, Any]:
        return asdict(self)


def build_evm_log_proof(
    *,
    block_hash: str,
    tx_hash: str,
    log_index: int,
    event_sig: str,
    receipt_root: str,
) -> Dict[str, Any]:
    return EVMLogProof(
        block_hash=block_hash,
        tx_hash=tx_hash,
        log_index=log_index,
        event_sig=event_sig,
        receipt_root=receipt_root,
    ).to_payload()


def build_cosmos_ibc_proof(
    *,
    client_id: str,
    connection_id: str,
    channel_id: str,
    port_id: str,
    sequence: int,
    commitment: str,
    height: int,
) -> Dict[str, Any]:
    return CosmosIBCProof(
        client_id=client_id,
        connection_id=connection_id,
        channel_id=channel_id,
        port_id=port_id,
        sequence=sequence,
        commitment=commitment,
        height=height,
    ).to_payload()


def build_route_policy_manifest(
    *, routes: List[Dict[str, Any]], version: str = "v1"
) -> Dict[str, Any]:
    return {
        "version": version,
        "routes": routes,
    }
