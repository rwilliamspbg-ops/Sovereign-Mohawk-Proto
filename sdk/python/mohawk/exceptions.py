"""Custom exceptions for the MOHAWK Python SDK."""


class MohawkError(Exception):
    """Base exception for all MOHAWK SDK errors."""
    pass


class InitializationError(MohawkError):
    """Raised when node initialization fails."""
    pass


class VerificationError(MohawkError):
    """Raised when zk-SNARK proof verification fails."""
    pass


class AggregationError(MohawkError):
    """Raised when federated learning aggregation fails."""
    pass


class AttestationError(MohawkError):
    """Raised when TPM attestation fails."""
    pass
