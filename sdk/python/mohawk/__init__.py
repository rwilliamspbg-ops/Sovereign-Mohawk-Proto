"""Sovereign-Mohawk Python SDK

A Python interface to the MOHAWK federated learning runtime.
Provides high-level APIs for node management, zk-SNARK verification,
federated learning operations, and hardware-accelerated gradient compression.

New in v2.1.0:
- Security hardening with credential management
- TLS configuration with certificate pinning
- Observability with OpenTelemetry
- Cloud deployment support
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
from .gradient import GradientBuffer, CompressedGradient
from .high_level import (
    HybridProofCheck,
    HybridVerificationReceipt,
)
from .flower import start_flower_server
from .flower_client import FlowerTrainingReport, MohawkFlowerClient
from .flower_strategy import FlowerStrategyForwarder, FlowerStrategyRoundSummary

# Phase 1: Security Hardening (NEW in v2.1.0)
from .credentials import (
    CredentialBuilder,
    CredentialError,
    CredentialManager,
    CredentialNotFoundError,
    CredentialProvider,
    CredentialRotationError,
    EnvironmentProvider,
    K8sSecretsProvider,
    VaultProvider,
)
from .tls import (
    CertificatePinning,
    CertificatePinningError,
    SecureSSLContext,
    TLSConfig,
    TLSError,
)

__version__ = "2.1.0"

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
    # High-level wrappers
    "HybridProofCheck",
    "HybridVerificationReceipt",
    "start_flower_server",
    "FlowerTrainingReport",
    "MohawkFlowerClient",
    "FlowerStrategyForwarder",
    "FlowerStrategyRoundSummary",
    # Phase 1: Security Hardening (NEW)
    "CredentialBuilder",
    "CredentialError",
    "CredentialManager",
    "CredentialNotFoundError",
    "CredentialProvider",
    "CredentialRotationError",
    "EnvironmentProvider",
    "K8sSecretsProvider",
    "VaultProvider",
    "CertificatePinning",
    "CertificatePinningError",
    "SecureSSLContext",
    "TLSConfig",
    "TLSError",
]
