import hashlib
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization

def verify_mohawk_node(quote_data, signature, public_key_pem, golden_hash, nonce):
    """
    Verifies that the node is untampered.
    """
    # 1. Load the Trusted Public Key of the TPM
    public_key = serialization.load_pem_public_key(public_key_pem)

    # 2. Verify the Hardware Signature
    try:
        public_key.verify(
            signature,
            quote_data + nonce, # Validates freshness via nonce
            padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
            hashes.SHA256()
        )
    except Exception:
        return False, "INVALID_SIGNATURE: TPM signature verification failed."

    # 3. Extract the Binary Hash from the Quote and compare to Golden Hash
    # (Simplified for demonstration: in production, parse the TPMT_HA structure)
    if hashlib.sha256(quote_data).hexdigest() != golden_hash:
        return False, "TAMPERED_BINARY: Node is not running the approved AOT core."

    return True, "VERIFIED: Node is secure and compliant."

# Usage Example:
# is_safe, msg = verify_mohawk_node(node_quote, node_sig, tpm_pub, "a1b2c3...", b"random_nonce")
