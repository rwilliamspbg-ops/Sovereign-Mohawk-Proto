"""Async client interface for the MOHAWK Python SDK."""

from __future__ import annotations

import asyncio
from functools import partial
from typing import Any, Callable, Dict, Iterable, List, Mapping, Optional, Union

from .client import JsonDict, MohawkNode


class AsyncMohawkNode:
    """Async wrapper over :class:`MohawkNode` using executor offload."""

    def __init__(self, lib_path: Optional[str] = None):
        self._node = MohawkNode(lib_path=lib_path)

    @property
    def node(self) -> MohawkNode:
        return self._node

    def close(self) -> None:
        self._node.close()

    async def __aenter__(self) -> "AsyncMohawkNode":
        return self

    async def __aexit__(self, exc_type: Any, exc: Any, tb: Any) -> None:
        self.close()

    async def _run(
        self,
        fn: Callable[..., JsonDict],
        /,
        *args: Any,
        **kwargs: Any,
    ) -> JsonDict:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, partial(fn, *args, **kwargs))

    async def start(self, config_path: str, node_id: str = "default") -> JsonDict:
        return await self._run(self._node.start, config_path, node_id)

    async def verify_proof(self, proof: Dict[str, Any]) -> JsonDict:
        return await self._run(self._node.verify_proof, proof)

    async def batch_verify(self, proofs: List[Dict[str, str]]) -> JsonDict:
        return await self._run(self._node.batch_verify, proofs)

    async def verify_hybrid_proof(
        self,
        *,
        snark_proof: str,
        stark_proof: str,
        mode: str = "prefer_snark",
        stark_backend: str = "simulated_fri",
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.verify_hybrid_proof,
            snark_proof=snark_proof,
            stark_proof=stark_proof,
            mode=mode,
            stark_backend=stark_backend,
            auth_token=auth_token,
            role=role,
        )

    async def hybrid_backends(self) -> JsonDict:
        return await self._run(self._node.hybrid_backends)

    async def aggregate(self, updates: Iterable[JsonDict]) -> JsonDict:
        return await self._run(self._node.aggregate, updates)

    async def aggregate_buffer(
        self, gradient_buffer: Union[bytes, bytearray, memoryview]
    ) -> JsonDict:
        return await self._run(self._node.aggregate_buffer, gradient_buffer)

    async def stream_aggregate(
        self,
        gradient_stream: Iterable[Iterable[float]],
        *,
        format: str = "fp16",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        return await self._run(
            self._node.stream_aggregate,
            gradient_stream,
            format=format,
            max_norm=max_norm,
        )

    async def compress_gradients(
        self,
        gradients: Iterable[float],
        *,
        format: str = "auto",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        return await self._run(
            self._node.compress_gradients,
            gradients,
            format=format,
            max_norm=max_norm,
        )

    async def device_info(self) -> JsonDict:
        return await self._run(self._node.device_info)

    async def auto_tune_profile(self, vector_length: int = 0) -> JsonDict:
        return await self._run(self._node.auto_tune_profile, vector_length)

    async def metrics_snapshot(self) -> JsonDict:
        return await self._run(self._node.metrics_snapshot)

    async def router_publish_insight(
        self,
        *,
        source_vertical: str,
        model_id: str,
        summary: str,
        publisher_node_id: str,
        publisher_quote: Union[str, bytes, bytearray, memoryview],
        offer_id: Optional[str] = None,
        expected_proof_root: Optional[str] = None,
        proof_payload: Optional[Union[str, bytes, bytearray, memoryview]] = None,
        router_url: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.router_publish_insight,
            source_vertical=source_vertical,
            model_id=model_id,
            summary=summary,
            publisher_node_id=publisher_node_id,
            publisher_quote=publisher_quote,
            offer_id=offer_id,
            expected_proof_root=expected_proof_root,
            proof_payload=proof_payload,
            router_url=router_url,
        )

    async def router_subscribe(
        self,
        *,
        subscriber_vertical: str,
        source_verticals: List[str],
        subscriber_node_id: str,
        subscriber_quote: Union[str, bytes, bytearray, memoryview],
        router_url: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.router_subscribe,
            subscriber_vertical=subscriber_vertical,
            source_verticals=source_verticals,
            subscriber_node_id=subscriber_node_id,
            subscriber_quote=subscriber_quote,
            router_url=router_url,
        )

    async def router_discover(
        self,
        *,
        subscriber_vertical: str,
        router_url: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.router_discover,
            subscriber_vertical=subscriber_vertical,
            router_url=router_url,
        )

    async def router_append_provenance(
        self,
        *,
        offer_id: str,
        source_vertical: str,
        target_vertical: str,
        subscriber_model: str,
        impact_metric: str,
        impact_delta: float,
        router_url: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.router_append_provenance,
            offer_id=offer_id,
            source_vertical=source_vertical,
            target_vertical=target_vertical,
            subscriber_model=subscriber_model,
            impact_metric=impact_metric,
            impact_delta=impact_delta,
            router_url=router_url,
        )

    async def router_provenance(self, *, router_url: Optional[str] = None) -> JsonDict:
        return await self._run(self._node.router_provenance, router_url=router_url)

    async def bridge_transfer(
        self,
        *,
        source_chain: str,
        target_chain: str,
        asset: str,
        amount: float,
        sender: str,
        receiver: str,
        nonce: int,
        proof: Union[str, Mapping[str, Any]],
        route_policy: Optional[Mapping[str, Any]] = None,
        policy_manifest_path: Optional[str] = None,
        policy_manifest: Optional[Mapping[str, Any]] = None,
        settle: bool = False,
        settlement_minter: Optional[str] = None,
        finality_depth: int = 0,
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.bridge_transfer,
            source_chain=source_chain,
            target_chain=target_chain,
            asset=asset,
            amount=amount,
            sender=sender,
            receiver=receiver,
            nonce=nonce,
            proof=proof,
            route_policy=route_policy,
            policy_manifest_path=policy_manifest_path,
            policy_manifest=policy_manifest,
            settle=settle,
            settlement_minter=settlement_minter,
            finality_depth=finality_depth,
            auth_token=auth_token,
            role=role,
        )

    async def mint_utility_coin(
        self,
        *,
        to: str,
        amount: float,
        actor: str = "protocol",
        memo: str = "",
        auth_token: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        nonce: Optional[int] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.mint_utility_coin,
            to=to,
            amount=amount,
            actor=actor,
            memo=memo,
            auth_token=auth_token,
            idempotency_key=idempotency_key,
            nonce=nonce,
            role=role,
        )

    async def transfer_utility_coin(
        self,
        *,
        from_account: str,
        to_account: str,
        amount: float,
        memo: str = "",
        auth_token: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        nonce: Optional[int] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.transfer_utility_coin,
            from_account=from_account,
            to_account=to_account,
            amount=amount,
            memo=memo,
            auth_token=auth_token,
            idempotency_key=idempotency_key,
            nonce=nonce,
            role=role,
        )

    async def burn_utility_coin(
        self,
        *,
        from_account: str,
        amount: float,
        memo: str = "",
        auth_token: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        nonce: Optional[int] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.burn_utility_coin,
            from_account=from_account,
            amount=amount,
            memo=memo,
            auth_token=auth_token,
            idempotency_key=idempotency_key,
            nonce=nonce,
            role=role,
        )

    async def utility_coin_balance(self, account: str) -> JsonDict:
        return await self._run(self._node.utility_coin_balance, account)

    async def utility_coin_ledger(self) -> JsonDict:
        return await self._run(self._node.utility_coin_ledger)

    async def backup_utility_coin_ledger(
        self,
        path: str,
        *,
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.backup_utility_coin_ledger,
            path,
            auth_token=auth_token,
            role=role,
        )

    async def restore_utility_coin_ledger(
        self,
        path: str,
        *,
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.restore_utility_coin_ledger,
            path,
            auth_token=auth_token,
            role=role,
        )

    async def status(self, node_id: str) -> JsonDict:
        return await self._run(self._node.status, node_id)

    async def load_wasm(
        self,
        module_path: Optional[str] = None,
        *,
        wasm_bytes: Optional[Union[bytes, bytearray, memoryview]] = None,
        wasm_b64: Optional[str] = None,
    ) -> JsonDict:
        return await self._run(
            self._node.load_wasm,
            module_path,
            wasm_bytes=wasm_bytes,
            wasm_b64=wasm_b64,
        )

    async def attest(self, node_id: str) -> JsonDict:
        return await self._run(self._node.attest, node_id)
