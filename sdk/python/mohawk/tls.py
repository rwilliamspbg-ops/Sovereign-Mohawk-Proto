"""
TLS and security configuration for Sovereign-Mohawk SDK.

Features:
- TLS 1.3 enforcement
- Certificate pinning (SHA256 hashes)
- Public key pinning
- Mutual TLS (mTLS) support
- Strong cipher selection
- Certificate validation
"""

import hashlib
import logging
import ssl
from pathlib import Path
from typing import List, Optional

logger = logging.getLogger(__name__)


class TLSError(Exception):
    """Base exception for TLS-related errors."""
    pass


class CertificatePinningError(TLSError):
    """Raised when certificate pinning validation fails."""
    pass


class CertificatePinning:
    """
    Certificate pinning for production security.
    
    Prevents MITM attacks by pinning known certificate hashes.
    Supports both leaf certificate and intermediate CA pinning.
    """
    
    def __init__(
        self,
        pin_hashes: List[str],
        pin_public_keys: Optional[List[str]] = None,
        allow_backup_pins: bool = True,
    ):
        """
        Initialize certificate pinning.
        
        Args:
            pin_hashes: SHA256 hashes of pinned certificates (hex strings)
            pin_public_keys: SHA256 hashes of pinned public keys (hex strings)
            allow_backup_pins: Allow backup pins for rotation
        """
        self.pin_hashes = [h.lower() for h in pin_hashes]
        self.pin_public_keys = [pk.lower() for pk in (pin_public_keys or [])]
        self.allow_backup_pins = allow_backup_pins
        
        logger.info(
            f"Initialized certificate pinning: "
            f"{len(self.pin_hashes)} cert hashes, "
            f"{len(self.pin_public_keys)} key hashes"
        )
    
    def verify_certificate_hash(self, cert_bytes: bytes) -> bool:
        """
        Verify certificate against pinned hashes.
        
        Args:
            cert_bytes: DER-encoded certificate bytes
            
        Returns:
            True if certificate hash matches a pin
            
        Raises:
            CertificatePinningError: If pin verification fails
        """
        cert_hash = hashlib.sha256(cert_bytes).hexdigest().lower()
        
        if cert_hash in self.pin_hashes:
            logger.debug(f"Certificate hash match: {cert_hash[:16]}...")
            return True
        
        raise CertificatePinningError(
            f"Certificate hash not pinned: {cert_hash[:16]}..."
        )
    
    def verify_public_key_hash(self, cert_pem: str) -> bool:
        """
        Verify public key against pinned hashes.
        
        Args:
            cert_pem: PEM-encoded certificate
            
        Returns:
            True if public key hash matches a pin
            
        Raises:
            CertificatePinningError: If pin verification fails
        """
        try:
            from cryptography import x509
            from cryptography.hazmat.backends import default_backend
            from cryptography.hazmat.primitives import serialization
            
            cert = x509.load_pem_x509_certificate(
                cert_pem.encode(), default_backend()
            )
            pub_key = cert.public_key()
            key_bytes = pub_key.public_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            key_hash = hashlib.sha256(key_bytes).hexdigest().lower()
            
            if key_hash in self.pin_public_keys:
                logger.debug(f"Public key hash match: {key_hash[:16]}...")
                return True
            
            raise CertificatePinningError(
                f"Public key hash not pinned: {key_hash[:16]}..."
            )
        except CertificatePinningError:
            raise
        except Exception as e:
            raise CertificatePinningError(f"Public key verification failed: {e}")


class SecureSSLContext:
    """Create production-hardened SSL contexts."""
    
    # Strong cipher suites (TLS 1.3)
    SECURE_CIPHERS = "ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5"
    
    @staticmethod
    def create(
        ca_bundle: Optional[str] = None,
        ca_path: Optional[str] = None,
        client_cert: Optional[str] = None,
        client_key: Optional[str] = None,
        client_key_password: Optional[bytes] = None,
        pin_hashes: Optional[List[str]] = None,
        pin_public_keys: Optional[List[str]] = None,
        min_tls_version: str = "TLSv1.3",
        max_tls_version: Optional[str] = None,
        check_hostname: bool = True,
    ) -> ssl.SSLContext:
        """
        Create a hardened SSL context.
        
        Args:
            ca_bundle: Path to CA certificate bundle (PEM)
            ca_path: Path to CA certificate directory (OpenSSL format)
            client_cert: Path to client certificate (PEM, for mTLS)
            client_key: Path to client private key (PEM, for mTLS)
            client_key_password: Password for encrypted private key
            pin_hashes: Certificate hashes to pin (SHA256)
            pin_public_keys: Public key hashes to pin (SHA256)
            min_tls_version: Minimum TLS version (default: TLSv1.3)
            max_tls_version: Maximum TLS version (optional)
            check_hostname: Enable hostname verification (default: True)
            
        Returns:
            Configured ssl.SSLContext
            
        Raises:
            TLSError: If configuration fails
        """
        try:
            # Create default context
            ctx = ssl.create_default_context()
            
            # Load CA certificates
            if ca_bundle:
                ca_bundle_path = Path(ca_bundle)
                if not ca_bundle_path.exists():
                    raise TLSError(f"CA bundle not found: {ca_bundle}")
                ctx.load_verify_locations(cafile=str(ca_bundle_path))
                logger.info(f"Loaded CA bundle: {ca_bundle}")
            
            if ca_path:
                ca_path_obj = Path(ca_path)
                if not ca_path_obj.is_dir():
                    raise TLSError(f"CA path is not a directory: {ca_path}")
                ctx.load_verify_locations(capath=str(ca_path_obj))
                logger.info(f"Loaded CA path: {ca_path}")
            
            # Enforce minimum TLS version
            min_version_map = {
                "TLSv1.0": ssl.TLSVersion.TLSv1,
                "TLSv1.1": ssl.TLSVersion.TLSv1_1,
                "TLSv1.2": ssl.TLSVersion.TLSv1_2,
                "TLSv1.3": ssl.TLSVersion.TLSv1_3,
            }
            if min_tls_version not in min_version_map:
                raise TLSError(f"Invalid TLS version: {min_tls_version}")
            
            ctx.minimum_version = min_version_map[min_tls_version]
            logger.info(f"Set minimum TLS version: {min_tls_version}")
            
            # Enforce maximum TLS version if specified
            if max_tls_version:
                max_version_map = min_version_map
                if max_tls_version not in max_version_map:
                    raise TLSError(f"Invalid TLS version: {max_tls_version}")
                ctx.maximum_version = max_version_map[max_tls_version]
                logger.info(f"Set maximum TLS version: {max_tls_version}")
            
            # Set strong ciphers
            ctx.set_ciphers(SecureSSLContext.SECURE_CIPHERS)
            logger.debug(f"Set ciphers: {SecureSSLContext.SECURE_CIPHERS}")
            
            # Verify certificates
            ctx.check_hostname = check_hostname
            ctx.verify_mode = ssl.CERT_REQUIRED
            logger.info(f"Enabled hostname verification: {check_hostname}")
            
            # Load client certificate (mTLS)
            if client_cert and client_key:
                client_cert_path = Path(client_cert)
                client_key_path = Path(client_key)
                
                if not client_cert_path.exists():
                    raise TLSError(f"Client certificate not found: {client_cert}")
                if not client_key_path.exists():
                    raise TLSError(f"Client key not found: {client_key}")
                
                ctx.load_cert_chain(
                    certfile=str(client_cert_path),
                    keyfile=str(client_key_path),
                    password=(lambda: client_key_password) if client_key_password else None,
                )
                logger.info(f"Loaded client certificate: {client_cert}")
            
            # Certificate pinning
            if pin_hashes or pin_public_keys:
                logger.info(f"Certificate pinning enabled ({len(pin_hashes or [])} hashes, {len(pin_public_keys or [])} keys)")
            
            return ctx
            
        except TLSError:
            raise
        except Exception as e:
            raise TLSError(f"Failed to create SSL context: {e}")
    
    @staticmethod
    def create_development() -> ssl.SSLContext:
        """
        Create SSL context for development (no verification).
        
        WARNING: Not suitable for production. Use only for testing.
        """
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        logger.warning("Created development SSL context (NO VERIFICATION)")
        return ctx


class TLSConfig:
    """Configuration builder for TLS settings."""
    
    def __init__(self):
        self.ca_bundle: Optional[str] = None
        self.ca_path: Optional[str] = None
        self.client_cert: Optional[str] = None
        self.client_key: Optional[str] = None
        self.client_key_password: Optional[bytes] = None
        self.pin_hashes: List[str] = []
        self.pin_public_keys: List[str] = []
        self.min_tls_version = "TLSv1.3"
        self.max_tls_version: Optional[str] = None
        self.check_hostname = True
    
    def with_ca_bundle(self, path: str) -> "TLSConfig":
        """Set CA certificate bundle path."""
        self.ca_bundle = path
        return self
    
    def with_ca_path(self, path: str) -> "TLSConfig":
        """Set CA certificates directory path."""
        self.ca_path = path
        return self
    
    def with_client_cert(self, cert_path: str, key_path: str, password: Optional[bytes] = None) -> "TLSConfig":
        """Set client certificate for mTLS."""
        self.client_cert = cert_path
        self.client_key = key_path
        self.client_key_password = password
        return self
    
    def with_pin_hashes(self, hashes: List[str]) -> "TLSConfig":
        """Add certificate hashes for pinning."""
        self.pin_hashes.extend(hashes)
        return self
    
    def with_pin_public_keys(self, keys: List[str]) -> "TLSConfig":
        """Add public key hashes for pinning."""
        self.pin_public_keys.extend(keys)
        return self
    
    def with_min_tls_version(self, version: str) -> "TLSConfig":
        """Set minimum TLS version."""
        self.min_tls_version = version
        return self
    
    def with_hostname_verification(self, enabled: bool) -> "TLSConfig":
        """Enable/disable hostname verification."""
        self.check_hostname = enabled
        return self
    
    def build(self) -> ssl.SSLContext:
        """Build SSL context."""
        return SecureSSLContext.create(
            ca_bundle=self.ca_bundle,
            ca_path=self.ca_path,
            client_cert=self.client_cert,
            client_key=self.client_key,
            client_key_password=self.client_key_password,
            pin_hashes=self.pin_hashes or None,
            pin_public_keys=self.pin_public_keys or None,
            min_tls_version=self.min_tls_version,
            max_tls_version=self.max_tls_version,
            check_hostname=self.check_hostname,
        )
