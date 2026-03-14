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


class ProofTooShortError(VerificationError):
    """Raised when the proof bytes are below the minimum BN254 Groth16 wire size (128 bytes)."""

    pass


class ProofStructureError(VerificationError):
    """Raised when proof bytes do not parse as valid BN254 G1/G2 curve points."""

    pass


class ProofPairingError(VerificationError):
    """Raised when the four-pairing Groth16 equation check fails (pairing = 1 violated)."""

    pass


class ProofDegenerateError(VerificationError):
    """Raised when a proof point is the identity (point at infinity)."""

    pass


class AggregationError(MohawkError):
    """Raised when federated learning aggregation fails."""

    pass


class AttestationError(MohawkError):
    """Raised when TPM attestation fails."""

    pass


# Map Go error_code strings to Python exception classes.
_ERROR_CODE_MAP: dict = {
    "PROOF_TOO_SHORT": ProofTooShortError,
    "PROOF_POINT_INVALID": ProofStructureError,
    "PROOF_DEGENERATE": ProofDegenerateError,
    "PROOF_PAIRING_FAILED": ProofPairingError,
    "PROOF_LATENCY_EXCEEDED": VerificationError,
    "PROOF_INVALID": VerificationError,
    "PROOF_PARSE_ERROR": VerificationError,
}


def verification_error_for_code(code: str, message: str) -> VerificationError:
    """Return the most specific VerificationError subclass for a Go error_code."""
    cls = _ERROR_CODE_MAP.get(code, VerificationError)
    return cls(message)
