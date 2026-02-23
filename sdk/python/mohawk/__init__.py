"""Sovereign-Mohawk Python SDK

A Python interface to the MOHAWK federated learning runtime.
Provides high-level APIs for node management, zk-SNARK verification,
and federated learning operations.
"""

from .client import MohawkNode
from .exceptions import MohawkError, VerificationError, InitializationError

__version__ = "0.1.0"
__all__ = ["MohawkNode", "MohawkError", "VerificationError", "InitializationError"]
