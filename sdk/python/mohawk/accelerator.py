"""Hardware accelerator detection and gradient quantization for the MOHAWK Python SDK.

This module provides Python-side hardware awareness that mirrors the Go
``internal/accelerator`` package. When numpy is available it uses vectorised
FP16/INT8 conversion; otherwise it falls back to pure-Python struct packing.
"""

from __future__ import annotations

import platform
import math
import struct
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple, cast

__all__ = [
    "Backend",
    "DeviceInfo",
    "AutoTuneProfile",
    "detect_devices",
    "select_device",
    "recommend_gradient_format",
    "build_auto_tune_profile",
    "fp32_to_fp16",
    "fp16_to_fp32",
    "quantize_int8",
    "dequantize_int8",
    "compression_ratio",
    "l2_norm",
]

try:
    import numpy as np  # type: ignore

    _HAS_NUMPY = True
except ImportError:
    np = None  # type: ignore
    _HAS_NUMPY = False


# ---------------------------------------------------------------------------
# Backend constants
# ---------------------------------------------------------------------------


class Backend:
    CPU = "cpu"
    CUDA = "cuda"
    METAL = "metal"
    NPU = "npu"


@dataclass
class DeviceInfo:
    backend: str
    name: str
    index: int = 0
    simd_width: int = 0  # bits: 128 / 256 / 512
    memory_mb: int = 0


@dataclass
class AutoTuneProfile:
    selected_device: DeviceInfo
    preferred_format: str
    recommended_workers: int
    detected_devices: List[DeviceInfo]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "selected_device": vars(self.selected_device),
            "preferred_format": self.preferred_format,
            "recommended_workers": self.recommended_workers,
            "detected_devices": [vars(d) for d in self.detected_devices],
        }


# ---------------------------------------------------------------------------
# Device detection
# ---------------------------------------------------------------------------


def detect_devices() -> List[DeviceInfo]:
    """Enumerate compute devices available on this host.

    Returns a list that always starts with the CPU entry; CUDA and Metal
    entries are appended when the corresponding hardware is detected.
    """
    devices: List[DeviceInfo] = [_cpu_device()]
    devices.extend(_cuda_devices())
    devices.extend(_npu_devices())
    if _has_metal():
        devices.append(
            DeviceInfo(
                backend=Backend.METAL,
                name="Apple Metal (GPU/ANE)",
                simd_width=128,
            )
        )
    return devices


def _cpu_device() -> DeviceInfo:
    arch = platform.machine().lower()
    simd = _detect_simd_width(arch)
    return DeviceInfo(
        backend=Backend.CPU,
        name=f"CPU ({arch})",
        simd_width=simd,
    )


def _detect_simd_width(arch: str) -> int:
    if _HAS_NUMPY:
        # numpy exposes the highest SIMD level compiled in via __cpu_features__
        features = getattr(np, "__cpu_features__", {})
        if features.get("AVX512F"):
            return 512
        if features.get("AVX2"):
            return 256
        if features.get("SSE2"):
            return 128
    if "arm" in arch or "aarch64" in arch:
        return 128  # NEON
    return 64


def _cuda_devices() -> List[DeviceInfo]:
    """Try to detect CUDA GPUs via nvidia-smi."""
    devices: List[DeviceInfo] = []
    try:
        out = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,memory.total",
                "--format=csv,noheader,nounits",
            ],
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).decode()
        for idx, line in enumerate(out.strip().splitlines()):
            parts = [p.strip() for p in line.split(",")]
            name = parts[0] if parts else f"NVIDIA GPU {idx}"
            mem_mb = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
            devices.append(
                DeviceInfo(
                    backend=Backend.CUDA,
                    name=name,
                    index=idx,
                    memory_mb=mem_mb,
                )
            )
    except Exception:
        pass
    return devices


def _npu_devices() -> List[DeviceInfo]:
    devices: List[DeviceInfo] = []
    force = str(_env("MOHAWK_NPU_AVAILABLE", "")).strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
    if force:
        devices.append(DeviceInfo(backend=Backend.NPU, name="Generic NPU", simd_width=128))
        return devices

    for candidate in ("/dev/apex_0", "/dev/npu0", "/dev/accel/npu0"):
        try:
            with open(candidate, "rb"):
                pass
            devices.append(
                DeviceInfo(backend=Backend.NPU, name=f"NPU ({candidate})", simd_width=128)
            )
            break
        except Exception:
            continue
    return devices


def _has_metal() -> bool:
    return sys.platform == "darwin"


def select_device(devices: Optional[List[DeviceInfo]] = None) -> DeviceInfo:
    available = devices if devices is not None else detect_devices()
    if not available:
        return _cpu_device()

    preferred = str(_env("MOHAWK_ACCELERATOR_BACKEND", "")).strip().lower()
    if preferred and preferred != "auto":
        for device in available:
            if device.backend == preferred:
                return device

    priority = {
        Backend.NPU: 400,
        Backend.CUDA: 300,
        Backend.METAL: 250,
        Backend.CPU: 100,
    }

    def score(device: DeviceInfo) -> int:
        return (
            priority.get(device.backend, 0)
            + (device.simd_width // 8)
            + (device.memory_mb // 1024)
            + (50 if device.backend != Backend.CPU else 0)
        )

    return max(available, key=score)


def recommend_gradient_format(device: DeviceInfo, vector_length: int) -> str:
    forced = str(_env("MOHAWK_GRADIENT_FORMAT", "")).strip().lower()
    if forced in {"fp16", "int8"}:
        return forced
    if vector_length >= 2048 and device.backend in {Backend.CUDA, Backend.NPU}:
        return "int8"
    return "fp16"


def recommend_workers(device: DeviceInfo) -> int:
    override = str(_env("MOHAWK_ACCELERATOR_WORKERS", "")).strip()
    if override.isdigit() and int(override) > 0:
        return int(override)
    cpu_count = _cpu_count()
    if device.backend == Backend.NPU:
        return max(2, cpu_count * 2)
    if device.backend in {Backend.CUDA, Backend.METAL}:
        return max(2, cpu_count)
    return max(1, cpu_count)


def build_auto_tune_profile(
    vector_length: int, devices: Optional[List[DeviceInfo]] = None
) -> AutoTuneProfile:
    available = devices if devices is not None else detect_devices()
    selected = select_device(available)
    return AutoTuneProfile(
        selected_device=selected,
        preferred_format=recommend_gradient_format(selected, vector_length),
        recommended_workers=recommend_workers(selected),
        detected_devices=available,
    )


def _env(name: str, default: str) -> str:
    import os

    return os.getenv(name, default)


def _cpu_count() -> int:
    import os

    return max(1, os.cpu_count() or 1)


# ---------------------------------------------------------------------------
# Quantization helpers
# ---------------------------------------------------------------------------


def fp32_to_fp16(values: List[float]) -> bytes:
    """Convert a list of float32 values to IEEE 754 FP16 bytes (little-endian).

    Uses numpy when available for vectorised conversion; otherwise falls
    back to the struct module (slower but dependency-free).
    """
    if _HAS_NUMPY:
        arr = np.array(values, dtype=np.float32)
        return arr.astype(np.float16).tobytes()
    # Pure-Python path: pack as fp32, manually downcast bit patterns.
    out = bytearray(len(values) * 2)
    for i, v in enumerate(values):
        bits = struct.unpack(">I", struct.pack(">f", v))[0]
        sign = (bits >> 16) & 0x8000
        raw_exp = ((bits >> 23) & 0xFF) - 127 + 15
        mantissa = bits & 0x7FFFFF
        if raw_exp <= 0:
            h = sign | (mantissa >> 13) if raw_exp >= -10 else sign
        elif raw_exp >= 31:
            h = sign | 0x7C00
        else:
            h = sign | (raw_exp << 10) | (mantissa >> 13)
        struct.pack_into("<H", out, i * 2, h & 0xFFFF)
    return bytes(out)


def fp16_to_fp32(data: bytes) -> List[float]:
    """Convert IEEE 754 FP16 bytes back to float32 values."""
    if _HAS_NUMPY:
        arr = np.frombuffer(data, dtype=np.float16)
        return cast(List[float], arr.astype(np.float32).tolist())
    n = len(data) // 2
    result: List[float] = []
    for i in range(n):
        h = struct.unpack_from("<H", data, i * 2)[0]
        sign = (h & 0x8000) >> 15
        exp = (h >> 10) & 0x1F
        mant = h & 0x3FF
        if exp == 0:
            val = ((-1) ** sign) * (2**-14) * (mant / 1024.0)
        elif exp == 31:
            val = float("inf") if mant == 0 else float("nan")
            val = -val if sign else val
        else:
            val = ((-1) ** sign) * (2 ** (exp - 15)) * (1 + mant / 1024.0)
        result.append(val)
    return result


def quantize_int8(values: List[float], max_norm: Optional[float] = None) -> Tuple[bytes, float]:
    """Symmetric uniform INT8 quantization to [-127, 127].

    Returns ``(quantized_bytes, scale)`` where scale is needed for
    dequantization. Reduces wire size by ~75 % vs FP32.
    """
    if _HAS_NUMPY:
        arr = np.array(values, dtype=np.float32)
        if max_norm is None or max_norm <= 0:
            max_norm = float(np.linalg.norm(arr)) or 1.0
        scale = max_norm / 127.0
        quantized = np.clip(np.round(arr / scale), -127, 127).astype(np.int8)
        return quantized.tobytes(), scale

    if max_norm is None or max_norm <= 0:
        max_norm = l2_norm(values) or 1.0
    scale = max_norm / 127.0
    out = bytearray(len(values))
    for i, v in enumerate(values):
        q = int(round(v / scale))
        q = max(-127, min(127, q))
        out[i] = q & 0xFF  # store as unsigned byte; receiver reinterprets
    return bytes(out), scale


def dequantize_int8(data: bytes, scale: float) -> List[float]:
    """Recover float32 values from INT8 quantized bytes + scale."""
    if _HAS_NUMPY:
        arr = np.frombuffer(data, dtype=np.int8)
        return cast(List[float], (arr.astype(np.float32) * scale).tolist())
    out: List[float] = []
    for b in data:
        # reinterpret unsigned byte as signed int8
        signed = b if b < 128 else b - 256
        out.append(signed * scale)
    return out


def compression_ratio(original_bytes: int, compressed_bytes: int) -> float:
    """Return the ratio of original to compressed size (higher = better)."""
    if compressed_bytes == 0:
        return 1.0
    return original_bytes / compressed_bytes


def l2_norm(values: List[float]) -> float:
    """Compute the ℓ₂ norm of a float vector."""
    total = 0.0
    for value in values:
        total += value * value
    return math.sqrt(total)
