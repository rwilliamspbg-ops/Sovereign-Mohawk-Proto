"""Main client interface for the MOHAWK Python SDK."""

from __future__ import annotations

import ctypes
import json
import sys
import time
import base64
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Union

from .accelerator import (
    build_auto_tune_profile,
    compression_ratio,
    detect_devices,
    fp32_to_fp16,
    quantize_int8,
)
from .exceptions import (
    AggregationError,
    AttestationError,
    InitializationError,
    VerificationError,
    verification_error_for_code,
)
from .gradient import CompressedGradient, GradientBuffer
from .high_level import (
    BridgeTransferIntent,
    BridgeTransferReceipt,
    HybridProofCheck,
    HybridVerificationReceipt,
)

JsonDict = Dict[str, Any]
BufferLike = Union[bytes, bytearray, memoryview]
MAX_GRADIENT_ELEMENTS = 1_000_000


def _validate_gradient_count(count: int) -> None:
    if count < 0:
        raise AggregationError(f"invalid gradient count: {count}")
    if count > MAX_GRADIENT_ELEMENTS:
        raise AggregationError(
            f"gradient length {count} exceeds MAX_GRADIENT_ELEMENTS={MAX_GRADIENT_ELEMENTS}"
        )


class ZeroCopyBridge:
    """ctypes bridge that prefers zero-copy buffers when the caller supplies one."""

    def __init__(self, lib_path: Optional[str] = None):
        self.lib_path = self._resolve_library(lib_path)
        self.lib = self._load_library(self.lib_path) if self.lib_path else None
        self._free_string = None
        if self.lib is not None and hasattr(self.lib, "FreeString"):
            free_func = self.lib.FreeString
            free_func.argtypes = [ctypes.c_void_p]
            free_func.restype = None
            self._free_string = free_func

    def close(self) -> None:
        self._free_string = None
        self.lib = None

    def invoke_json(self, symbol: str, payload: Any) -> JsonDict:
        if self.lib is None:
            return {
                "success": True,
                "message": f"{symbol} simulated",
                "data": json.dumps(payload),
            }

        func = getattr(self.lib, symbol)
        func.argtypes = [ctypes.c_char_p]
        func.restype = ctypes.c_void_p
        encoded = json.dumps(payload).encode("utf-8")
        result_ptr = func(encoded)
        if not result_ptr:
            return {"success": False, "message": f"{symbol} returned no data"}
        try:
            raw = ctypes.string_at(result_ptr)
            return json.loads(raw.decode("utf-8"))
        finally:
            if self._free_string is not None:
                self._free_string(result_ptr)

    def has_symbol(self, symbol: str) -> bool:
        return self.lib is not None and hasattr(self.lib, symbol)

    def compress_gradients_zero_copy(
        self,
        gradients: BufferLike,
        *,
        format: str = "auto",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        view = self.view(gradients)
        # Validate element count based on raw bytes before any buffer materialization
        # to prevent memory/CPU DoS from oversized payloads.
        _validate_gradient_count(view.nbytes // 4)
        if view.format in {"f", "=f", "<f"}:
            float_view = view
        elif view.format in {"B", "b", "c"}:
            float_view = view.cast("f")
        else:
            float_view = memoryview(bytearray(view.tobytes())).cast("f")

        if self.lib is None or not self.has_symbol("CompressGradientsZeroCopy"):
            return {
                "success": True,
                "message": "Gradients compressed (python zero-copy fallback)",
                "zero_copy": False,
                "format": format,
                "count": len(float_view),
            }

        func = getattr(self.lib, "CompressGradientsZeroCopy")
        func.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_double,
        ]
        func.restype = ctypes.c_void_p

        holder = bytearray(float_view.tobytes())
        array_type = ctypes.c_float * len(float_view)
        grad_array = array_type.from_buffer(holder)
        ptr = ctypes.cast(grad_array, ctypes.POINTER(ctypes.c_float))

        result_ptr = func(ptr, len(float_view), format.encode("utf-8"), max_norm)
        if not result_ptr:
            return {
                "success": False,
                "message": "CompressGradientsZeroCopy returned no data",
            }

        try:
            raw = ctypes.string_at(result_ptr)
            parsed = json.loads(raw.decode("utf-8"))
        finally:
            if self._free_string is not None:
                self._free_string(result_ptr)

        parsed.setdefault("zero_copy", True)
        parsed.setdefault("count", len(float_view))
        return parsed

    def view(self, payload: BufferLike) -> memoryview:
        view = memoryview(payload)
        if not view.contiguous:
            return memoryview(bytearray(view.tobytes()))
        return view

    @staticmethod
    def _resolve_library(lib_path: Optional[str]) -> Optional[str]:
        if lib_path:
            candidate = Path(lib_path).resolve()
            if not candidate.exists():
                raise InitializationError(f"Shared library not found: {candidate}")
            return str(candidate)

        package_root = Path(__file__).resolve().parent
        repo_root = Path(__file__).resolve().parents[3]
        if sys.platform == "darwin":
            name = "libmohawk.dylib"
        elif sys.platform.startswith("linux"):
            name = "libmohawk.so"
        else:
            name = "libmohawk.dll"

        for root in (package_root, repo_root):
            candidate = root / name
            if candidate.exists():
                return str(candidate)
        return None

    @staticmethod
    def _load_library(lib_path: str) -> ctypes.CDLL:
        try:
            return ctypes.CDLL(lib_path)
        except OSError as exc:
            raise InitializationError(str(exc)) from exc


class MohawkNode:
    """Python SDK v2 client backed by the Go shared library when available."""

    def __init__(self, lib_path: Optional[str] = None):
        self.version = "2.0.0a2"
        self.bridge = ZeroCopyBridge(lib_path)
        self.lib_path = self.bridge.lib_path
        self.lib = self.bridge.lib

    def close(self) -> None:
        self.bridge.close()
        self.lib = None

    def __enter__(self) -> "MohawkNode":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def start(self, config_path: str, node_id: str = "default") -> JsonDict:
        payload = {
            "node_id": node_id,
            "config_path": config_path,
            "capabilities": "federated-learning,libp2p,ipfs,tpm2",
        }
        result = self.bridge.invoke_json("InitializeNode", payload)
        if not result.get("success", False):
            raise InitializationError(result.get("message", "node initialization failed"))
        return result

    def verify_proof(self, proof: JsonDict) -> JsonDict:
        started = time.perf_counter()
        result = self.bridge.invoke_json("VerifyZKProof", proof)
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        result.setdefault("verification_time_ms", round(elapsed_ms, 3))
        if not result.get("success", False):
            code = result.get("error_code", "")
            msg = result.get("message", "proof verification failed")
            raise verification_error_for_code(code, msg)
        return result

    def batch_verify(self, proofs: List[Dict[str, str]]) -> JsonDict:
        result = self.bridge.invoke_json("BatchVerifyProofs", proofs)
        if not result.get("success", False):
            raise VerificationError(result.get("message", "batch verification failed"))
        return result

    def verify_hybrid_proof(
        self,
        *,
        snark_proof: str,
        stark_proof: str,
        mode: str = "prefer_snark",
        stark_backend: str = "simulated_fri",
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        payload = {
            "mode": mode,
            "snark_proof": snark_proof,
            "stark_proof": stark_proof,
            "stark_backend": stark_backend,
        }
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("VerifyHybridProof", payload)
        if not result.get("success", False):
            raise VerificationError(result.get("message", "hybrid verification failed"))
        return result

    def verify_hybrid(
        self,
        check: Union[HybridProofCheck, Mapping[str, Any]],
        **overrides: Any,
    ) -> HybridVerificationReceipt:
        """Pythonic wrapper around verify_hybrid_proof with normalized receipt output."""
        request = (
            check if isinstance(check, HybridProofCheck) else HybridProofCheck.from_mapping(check)
        )
        payload = request.to_api_kwargs()
        payload.update(overrides)
        result = self.verify_hybrid_proof(**payload)
        return HybridVerificationReceipt.from_api_result(result)

    def hybrid_backends(self) -> JsonDict:
        result = self.bridge.invoke_json("GetHybridBackends", {})
        if not result.get("success", False):
            raise VerificationError(result.get("message", "failed to list hybrid backends"))
        return result

    def aggregate(self, updates: Iterable[JsonDict]) -> JsonDict:
        payload = list(updates)
        result = self.bridge.invoke_json("AggregateUpdates", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "aggregation failed"))
        result.setdefault("count", len(payload))
        return result

    def aggregate_buffer(self, gradient_buffer: BufferLike) -> JsonDict:
        view = self.bridge.view(gradient_buffer)
        return {
            "success": True,
            "zero_copy": not view.readonly,
            "bytes": view.nbytes,
        }

    def stream_aggregate(
        self,
        gradient_stream: Iterable[Iterable[float]],
        *,
        format: str = "fp16",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        buf = GradientBuffer(max_norm=max_norm, format=format)
        count = 0
        for grad in gradient_stream:
            buf.add(grad)
            count += 1
        if count == 0:
            return {"success": True, "message": "empty stream", "count": 0}
        cg: CompressedGradient = buf.compress()
        result = cg.to_dict()
        result["success"] = True
        result["count"] = count
        return result

    def compress_gradients(
        self,
        gradients: Iterable[float],
        *,
        format: str = "auto",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        grads = list(gradients)
        _validate_gradient_count(len(grads))
        payload = {"gradients": grads, "format": format, "max_norm": max_norm}
        result = self.bridge.invoke_json("CompressGradients", payload)
        if result.get("success", False):
            return result

        profile = build_auto_tune_profile(len(grads))
        selected_format = format
        if selected_format == "auto":
            selected_format = profile.preferred_format

        if selected_format == "int8":
            raw, scale = quantize_int8(grads, max_norm)
        else:
            raw = fp32_to_fp16(grads)
            scale = 0.0

        original = len(grads) * 4
        return {
            "success": True,
            "message": "Gradients compressed (python fallback)",
            "format": selected_format,
            "autotuned": True,
            "backend": profile.selected_device.backend,
            "recommended_worker": profile.recommended_workers,
            "original_bytes": original,
            "compressed_bytes": len(raw),
            "compression_ratio": compression_ratio(original, len(raw)),
            "scale": scale,
            "data_b64": base64.b64encode(raw).decode(),
        }

    def compress_gradients_zero_copy(
        self,
        gradient_buffer: BufferLike,
        *,
        format: str = "auto",  # noqa: A002
        max_norm: float = 1.0,
    ) -> JsonDict:
        result = self.bridge.compress_gradients_zero_copy(
            gradient_buffer,
            format=format,
            max_norm=max_norm,
        )
        if not result.get("success", False):
            raise AggregationError(result.get("message", "zero-copy compression failed"))
        return result

    def device_info(self) -> JsonDict:
        result = self.bridge.invoke_json("GetDeviceInfo", {})
        if not result.get("success", False):
            devices = detect_devices()
            profile = build_auto_tune_profile(0, devices=devices)
            return {
                "success": True,
                "message": "Device enumeration complete (python fallback)",
                "data": {
                    "devices": [vars(d) for d in devices],
                    "autotune": profile.to_dict(),
                },
            }
        return result

    def auto_tune_profile(self, vector_length: int = 0) -> JsonDict:
        info = self.device_info()
        if info.get("success", False):
            data = info.get("data", {})
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except json.JSONDecodeError:
                    data = {}
            autotune = data.get("autotune")
            if isinstance(autotune, dict):
                return {
                    "success": True,
                    "message": "Auto-tune profile",
                    "data": autotune,
                }

        profile = build_auto_tune_profile(vector_length)
        return {
            "success": True,
            "message": "Auto-tune profile (python fallback)",
            "data": profile.to_dict(),
        }

    def metrics_snapshot(self) -> JsonDict:
        result = self.bridge.invoke_json("GetPrometheusMetrics", {})
        if not result.get("success", False):
            raise VerificationError(result.get("message", "metrics snapshot failed"))
        return result

    def bridge_transfer(
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
        if not isinstance(proof, str):
            proof = json.dumps(dict(proof), separators=(",", ":"))
        payload = {
            "source_chain": source_chain,
            "target_chain": target_chain,
            "asset": asset,
            "amount": amount,
            "sender": sender,
            "receiver": receiver,
            "nonce": nonce,
            "finality_depth": finality_depth,
            "proof": proof,
        }
        if route_policy is not None:
            payload["route_policy"] = dict(route_policy)
        if policy_manifest_path is not None:
            payload["policy_manifest_path"] = policy_manifest_path
        if policy_manifest is not None:
            payload["policy_manifest"] = dict(policy_manifest)
        if settle:
            payload["settle"] = True
        if settlement_minter is not None:
            payload["settlement_minter"] = settlement_minter
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("BridgeTransfer", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "bridge transfer failed"))
        return result

    def transfer_asset(
        self,
        intent: Union[BridgeTransferIntent, Mapping[str, Any]],
        **overrides: Any,
    ) -> BridgeTransferReceipt:
        """Pythonic wrapper around bridge_transfer with a typed transfer receipt."""
        request = (
            intent
            if isinstance(intent, BridgeTransferIntent)
            else BridgeTransferIntent.from_mapping(intent)
        )
        payload = request.to_api_kwargs()
        payload.update(overrides)
        result = self.bridge_transfer(**payload)
        return BridgeTransferReceipt.from_api_result(result)

    def mint_utility_coin(
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
        payload = {
            "actor": actor,
            "to": to,
            "amount": amount,
            "memo": memo,
        }
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if idempotency_key is not None:
            payload["idempotency_key"] = idempotency_key
        if nonce is not None:
            payload["nonce"] = nonce
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("MintUtilityCoin", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin mint failed"))
        return result

    def transfer_utility_coin(
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
        payload = {
            "from": from_account,
            "to": to_account,
            "amount": amount,
            "memo": memo,
        }
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if idempotency_key is not None:
            payload["idempotency_key"] = idempotency_key
        if nonce is not None:
            payload["nonce"] = nonce
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("TransferUtilityCoin", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin transfer failed"))
        return result

    def burn_utility_coin(
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
        payload = {
            "from": from_account,
            "amount": amount,
            "memo": memo,
        }
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if idempotency_key is not None:
            payload["idempotency_key"] = idempotency_key
        if nonce is not None:
            payload["nonce"] = nonce
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("BurnUtilityCoin", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin burn failed"))
        return result

    def utility_coin_balance(self, account: str) -> JsonDict:
        result = self.bridge.invoke_json("GetUtilityCoinBalance", {"account": account})
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin balance lookup failed"))
        return result

    def utility_coin_ledger(self) -> JsonDict:
        result = self.bridge.invoke_json("GetUtilityCoinLedger", {})
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin ledger lookup failed"))
        return result

    def backup_utility_coin_ledger(
        self,
        path: str,
        *,
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        payload: JsonDict = {"path": path}
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("BackupUtilityCoinLedger", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin backup failed"))
        return result

    def restore_utility_coin_ledger(
        self,
        path: str,
        *,
        auth_token: Optional[str] = None,
        role: Optional[str] = None,
    ) -> JsonDict:
        payload: JsonDict = {"path": path}
        if auth_token is not None:
            payload["auth_token"] = auth_token
        if role is not None:
            payload["role"] = role
        result = self.bridge.invoke_json("RestoreUtilityCoinLedger", payload)
        if not result.get("success", False):
            raise AggregationError(result.get("message", "utility coin restore failed"))
        return result

    def status(self, node_id: str) -> JsonDict:
        result = self.bridge.invoke_json("GetNodeStatus", {"node_id": node_id})
        if "status_data" not in result:
            result["status_data"] = result.get("data", {"node_id": node_id, "status": "running"})
        return result

    def load_wasm(
        self,
        module_path: Optional[str] = None,
        *,
        wasm_bytes: Optional[BufferLike] = None,
        wasm_b64: Optional[str] = None,
        module_sha256: Optional[str] = None,
        module_signature: Optional[str] = None,
        module_public_key: Optional[str] = None,
    ) -> JsonDict:
        payload: JsonDict = {}
        if module_path is not None:
            payload["module_path"] = module_path
        if wasm_bytes is not None:
            payload["wasm_b64"] = base64.b64encode(self.bridge.view(wasm_bytes).tobytes()).decode(
                "ascii"
            )
        elif wasm_b64 is not None:
            payload["wasm_b64"] = wasm_b64
        if module_sha256 is not None:
            payload["module_sha256"] = module_sha256
        if module_signature is not None:
            payload["module_signature"] = module_signature
        if module_public_key is not None:
            payload["module_public_key"] = module_public_key
        if not payload:
            raise InitializationError("load_wasm requires module_path, wasm_bytes, or wasm_b64")

        result = self.bridge.invoke_json("LoadWasmModule", payload)
        if not result.get("success", False):
            raise InitializationError(result.get("message", "wasm module loading failed"))

        data = result.get("data")
        if isinstance(data, str) and data:
            try:
                payload_data = json.loads(data)
            except json.JSONDecodeError:
                payload_data = None
            if isinstance(payload_data, dict):
                module_hash = payload_data.get("module_hash")
                module_path_out = payload_data.get("module_path")
                if isinstance(module_hash, str) and module_hash:
                    result["module_hash"] = module_hash
                if isinstance(module_path_out, str) and module_path_out:
                    result["module_path"] = module_path_out
        return result

    def attest(self, node_id: str) -> JsonDict:
        result = self.bridge.invoke_json("AttestNode", {"node_id": node_id})
        if not result.get("success", False):
            raise AttestationError(result.get("message", "attestation failed"))
        return result
