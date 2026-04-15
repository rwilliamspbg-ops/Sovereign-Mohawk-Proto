"""Gradient buffering, compression, and streaming utilities for the MOHAWK SDK.

Provides a :class:`GradientBuffer` that accumulates per-parameter gradient
updates, compresses them via FP16 or INT8 quantization, and dispatches them
as a single wire payload. Designed for zero-copy integration with the
:class:`~mohawk.client.ZeroCopyBridge` ctypes layer.
"""

from __future__ import annotations

import struct
from typing import Any, Dict, Iterable, List, Optional

from .accelerator import (
    Backend,
    DeviceInfo,
    compression_ratio,
    detect_devices,
    fp16_to_fp32,
    fp32_to_fp16,
    l2_norm,
    quantize_int8,
    recommend_gradient_format,
    select_device,
)

__all__ = [
    "GradientBuffer",
    "pack_gradient_message",
    "unpack_gradient_message",
]

_DEFAULT_MAX_NORM = 1.0


class GradientBuffer:
    """Accumulates gradient updates and compresses them for network transmission.

    Parameters
    ----------
    max_norm:
        ℓ₂ clipping threshold applied before quantization (Theorem 3).
    format:
        ``"fp16"`` (default, 2 B/param) or ``"int8"`` (1 B/param).
    """

    def __init__(
        self,
        max_norm: float = _DEFAULT_MAX_NORM,
        format: str = "fp16",  # noqa: A002
    ) -> None:
        self.max_norm = max_norm
        self.format = format
        self._gradients: List[List[float]] = []
        self._device: Optional[DeviceInfo] = None

    @property
    def device(self) -> DeviceInfo:
        if self._device is None:
            devices = detect_devices()
            self._device = select_device(devices)
        return self._device

    def add(self, gradient: Iterable[float]) -> None:
        """Append one gradient vector to the buffer."""
        self._gradients.append(list(gradient))

    def __len__(self) -> int:
        return len(self._gradients)

    def flush(self) -> Dict[str, Any]:
        """Average, clip, compress, and clear the accumulated gradients.

        Returns a dict suitable for passing to the Go bridge's
        ``CompressGradients`` export.
        """
        if not self._gradients:
            return {"gradients": [], "format": self.format, "max_norm": self.max_norm}

        # Average all accumulated gradients.
        n = len(self._gradients)
        dim = len(self._gradients[0])
        avg = [sum(g[i] for g in self._gradients) / n for i in range(dim)]

        # ℓ₂ clip to max_norm.
        norm = l2_norm(avg)
        if norm > self.max_norm:
            scale = self.max_norm / norm
            avg = [v * scale for v in avg]

        self._gradients.clear()
        return {
            "gradients": avg,
            "format": self.format,
            "max_norm": self.max_norm,
        }

    def compress(self) -> "CompressedGradient":
        """Flush and compress into a :class:`CompressedGradient` object."""
        payload = self.flush()
        grads = payload["gradients"]
        original_bytes = len(grads) * 4  # FP32

        selected_format = self.format
        if selected_format == "auto":
            selected_format = recommend_gradient_format(self.device, len(grads))

        if selected_format == "int8":
            raw, scale = quantize_int8(grads, self.max_norm)
        else:
            raw = fp32_to_fp16(grads)
            scale = 0.0

        ratio = compression_ratio(original_bytes, len(raw))
        return CompressedGradient(
            data=raw,
            format=selected_format,
            original_bytes=original_bytes,
            scale=scale,
            compression_ratio=ratio,
            backend=self.device.backend,
        )


class CompressedGradient:
    """Immutable compressed gradient payload ready for network dispatch."""

    __slots__ = (
        "data",
        "format",
        "original_bytes",
        "scale",
        "compression_ratio",
        "backend",
    )

    def __init__(
        self,
        data: bytes,
        format: str,  # noqa: A002
        original_bytes: int,
        scale: float,
        compression_ratio: float,
        backend: str,
    ) -> None:
        self.data = data
        self.format = format
        self.original_bytes = original_bytes
        self.scale = scale
        self.compression_ratio = compression_ratio
        self.backend = backend

    def to_dict(self) -> Dict[str, Any]:
        import base64

        return {
            "format": self.format,
            "original_bytes": self.original_bytes,
            "compressed_bytes": len(self.data),
            "compression_ratio": self.compression_ratio,
            "scale": self.scale,
            "backend": self.backend,
            "data_b64": base64.b64encode(self.data).decode(),
        }

    def decompress(self) -> List[float]:
        """Decompress back to float32 values."""
        if self.format == "int8":
            from .accelerator import dequantize_int8

            return dequantize_int8(self.data, self.scale)
        return fp16_to_fp32(self.data)


# ---------------------------------------------------------------------------
# Wire-format helpers (fixed-header binary framing)
# ---------------------------------------------------------------------------
#
# Frame layout (little-endian):
#  [4B] magic = 0x4D484B47  ("MHKG")
#  [1B] format: 0 = fp16, 1 = int8
#  [4B] element count (uint32)
#  [8B] scale (float64)  -- 0 for fp16
#  [NB] payload bytes
#
_MAGIC = 0x4D484B47
_HEADER_FMT = "<IBIId"  # magic, format_byte, count, _pad, scale
_HEADER_SIZE = struct.calcsize(_HEADER_FMT)


def pack_gradient_message(cg: CompressedGradient) -> bytes:
    """Serialise a CompressedGradient to a binary wire frame."""
    fmt_byte = 1 if cg.format == "int8" else 0
    count = cg.original_bytes // 4
    header = struct.pack(_HEADER_FMT, _MAGIC, fmt_byte, count, 0, cg.scale)
    return header + cg.data


def unpack_gradient_message(frame: bytes) -> CompressedGradient:
    """Deserialise a binary wire frame into a CompressedGradient."""
    if len(frame) < _HEADER_SIZE:
        raise ValueError(f"frame too short: {len(frame)} < {_HEADER_SIZE}")
    magic, fmt_byte, count, _, scale = struct.unpack_from(_HEADER_FMT, frame)
    if magic != _MAGIC:
        raise ValueError(f"invalid magic: 0x{magic:08X}")
    payload = frame[_HEADER_SIZE:]
    fmt = "int8" if fmt_byte else "fp16"
    return CompressedGradient(
        data=payload,
        format=fmt,
        original_bytes=count * 4,
        scale=scale,
        compression_ratio=compression_ratio(count * 4, len(payload)),
        backend=Backend.CPU,
    )
