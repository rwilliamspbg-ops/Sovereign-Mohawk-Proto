"""Sovereign-Mohawk Python SDK

A Python interface to the MOHAWK federated learning runtime.
Provides high-level APIs for node management, zk-SNARK verification,
federated learning operations, and hardware-accelerated gradient compression.
"""

from .client import MohawkNode
from .async_client import AsyncMohawkNode
from .exceptions import (
    AggregationError,
    AttestationError,
    InitializationError,
    MohawkError,
    ProofDegenerateError,
    ProofPairingError,
    ProofStructureError,
    ProofTooShortError,
    VerificationError,
)
from .accelerator import (
    AutoTuneProfile,
    Backend,
    DeviceInfo,
    build_auto_tune_profile,
    detect_devices,
    recommend_gradient_format,
    select_device,
)
from .bridge import (
    RoutePolicy,
    CosmosIBCProof,
    EVMLogProof,
    build_route_policy_manifest,
    build_cosmos_ibc_proof,
    build_evm_log_proof,
)
from .gradient import GradientBuffer, CompressedGradient

__version__ = "2.0.1.Alpha"
__all__ = [
    # Core client
    "MohawkNode",
    "AsyncMohawkNode",
    # Exceptions
    "MohawkError",
    "InitializationError",
    "VerificationError",
    "ProofTooShortError",
    "ProofStructureError",
    "ProofPairingError",
    "ProofDegenerateError",
    "AggregationError",
    "AttestationError",
    # Accelerator
    "Backend",
    "DeviceInfo",
    "AutoTuneProfile",
    "detect_devices",
    "select_device",
    "recommend_gradient_format",
    "build_auto_tune_profile",
    # Gradient utilities
    "GradientBuffer",
    "CompressedGradient",
    # Bridge proof helpers
    "EVMLogProof",
    "CosmosIBCProof",
    "RoutePolicy",
    "build_evm_log_proof",
    "build_cosmos_ibc_proof",
    "build_route_policy_manifest",
]
