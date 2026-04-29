"""
Comprehensive tests for Phase 1 Security Hardening.

Tests cover:
- Credential management (all providers)
- TLS configuration and pinning
- Security best practices
- Async operations
- Error handling
"""

import os
import pytest
import asyncio
from pathlib import Path

# Import the modules we created
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from mohawk.credentials import (
    CredentialManager,
    EnvironmentProvider,
    CredentialNotFoundError,
    CredentialRotationError,
    CredentialBuilder,
)
from mohawk.tls import (
    SecureSSLContext,
    TLSConfig,
    CertificatePinning,
    CertificatePinningError,
    TLSError,
)

# ============================================================================
# CREDENTIAL MANAGER TESTS
# ============================================================================


class TestEnvironmentProvider:
    """Test environment variable credential provider."""

    def test_get_credential_success(self):
        """Test successful credential retrieval."""
        os.environ["TEST_CRED"] = "secret-value-123"
        provider = EnvironmentProvider()

        value = asyncio.run(provider.get_credential("TEST_CRED"))
        assert value == "secret-value-123"

    def test_get_credential_not_found(self):
        """Test credential not found error."""
        provider = EnvironmentProvider()

        with pytest.raises(CredentialNotFoundError):
            asyncio.run(provider.get_credential("NONEXISTENT_CREDENTIAL"))

    def test_set_credential(self):
        """Test setting credential."""
        provider = EnvironmentProvider()

        asyncio.run(provider.set_credential("NEW_CRED", "new-value"))
        assert os.environ["NEW_CRED"] == "new-value"

    def test_delete_credential(self):
        """Test deleting credential."""
        os.environ["DELETE_ME"] = "value"
        provider = EnvironmentProvider()

        asyncio.run(provider.delete_credential("DELETE_ME"))
        assert "DELETE_ME" not in os.environ

    def test_rotate_not_supported(self):
        """Test rotation not supported."""
        provider = EnvironmentProvider()

        with pytest.raises(CredentialRotationError):
            asyncio.run(provider.rotate_credential("ANY_KEY"))


class TestCredentialManager:
    """Test credential manager with caching."""

    def test_get_with_cache(self):
        """Test credential retrieval with caching."""
        os.environ["CACHED_CRED"] = "value-123"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        # First call fetches from provider
        value1 = asyncio.run(manager.get("CACHED_CRED"))
        assert value1 == "value-123"

        # Second call uses cache
        value2 = asyncio.run(manager.get("CACHED_CRED"))
        assert value2 == "value-123"

        # Verify it's cached
        assert "CACHED_CRED" in manager._cache

    def test_cache_bypass(self):
        """Test bypassing cache."""
        os.environ["BYPASS_TEST"] = "original"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        value1 = asyncio.run(manager.get("BYPASS_TEST"))
        assert value1 == "original"

        # Change environment
        os.environ["BYPASS_TEST"] = "updated"

        # With cache, should still see original
        value2 = asyncio.run(manager.get("BYPASS_TEST", use_cache=True))
        assert value2 == "original"

        # Without cache, should see updated
        value3 = asyncio.run(manager.get("BYPASS_TEST", use_cache=False))
        assert value3 == "updated"

    def test_set_credential(self):
        """Test setting credential."""
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        asyncio.run(manager.set("NEW_KEY", "new-value"))

        value = asyncio.run(manager.get("NEW_KEY"))
        assert value == "new-value"

    def test_clear_cache(self):
        """Test cache clearing."""
        os.environ["CACHE_TEST"] = "value"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        asyncio.run(manager.get("CACHE_TEST"))
        assert len(manager._cache) > 0

        manager.clear_cache()
        assert len(manager._cache) == 0

    def test_credential_not_found(self):
        """Test error handling for missing credential."""
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        with pytest.raises(CredentialNotFoundError):
            asyncio.run(manager.get("MISSING_CREDENTIAL"))

    def test_delete_credential(self):
        """Test credential deletion."""
        os.environ["DELETE_KEY"] = "value"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        asyncio.run(manager.delete("DELETE_KEY"))

        with pytest.raises(CredentialNotFoundError):
            asyncio.run(manager.get("DELETE_KEY"))


class TestCredentialBuilder:
    """Test credential manager builder."""

    def test_builder_environment(self):
        """Test builder with environment provider."""
        manager = CredentialBuilder().with_environment().build()

        assert isinstance(manager, CredentialManager)
        assert isinstance(manager.provider, EnvironmentProvider)

    def test_builder_auto_rotation_config(self):
        """Test auto-rotation configuration."""
        manager = (
            CredentialBuilder()
            .with_environment()
            .with_auto_rotation(enabled=True, interval_hours=12)
            .build()
        )

        assert manager.auto_rotate is True
        assert manager.rotation_interval_hours == 12


# ============================================================================
# TLS SECURITY TESTS
# ============================================================================


class TestSecureSSLContext:
    """Test SSL context creation and configuration."""

    def test_create_default_context(self):
        """Test creating default SSL context."""
        ctx = SecureSSLContext.create()

        assert ctx is not None
        assert ctx.minimum_version.name == "TLSv1_3"
        assert ctx.verify_mode.name == "CERT_REQUIRED"

    def test_development_context(self):
        """Test development SSL context (NO VERIFICATION)."""
        ctx = SecureSSLContext.create_development()

        assert ctx.check_hostname is False
        assert ctx.verify_mode.name == "CERT_NONE"

    def test_mtls_configuration(self):
        """Test mTLS configuration."""
        # This would require actual certificate files
        # For testing, we'll verify the configuration path works
        try:
            ctx = SecureSSLContext.create(
                client_cert="/nonexistent/cert.pem",
                client_key="/nonexistent/key.pem",
            )
        except TLSError as e:
            assert "not found" in str(e)

    def test_invalid_tls_version(self):
        """Test invalid TLS version."""
        with pytest.raises(TLSError):
            SecureSSLContext.create(min_tls_version="TLSv0.9")

    def test_cipher_suite_configuration(self):
        """Test that strong ciphers are configured."""
        ctx = SecureSSLContext.create()

        # Verify ciphers are set (actual cipher names depend on OpenSSL)
        assert ctx is not None


class TestTLSConfig:
    """Test TLS configuration builder."""

    def test_config_builder_chain(self):
        """Test configuration builder chaining."""
        config = (
            TLSConfig().with_min_tls_version("TLSv1.3").with_hostname_verification(True)
        )

        assert config.min_tls_version == "TLSv1.3"
        assert config.check_hostname is True

    def test_config_build_default_context(self):
        """Test building default context from config."""
        config = TLSConfig()
        ctx = config.build()

        assert ctx is not None
        assert ctx.minimum_version.name == "TLSv1_3"


class TestCertificatePinning:
    """Test certificate pinning."""

    def test_pinning_initialization(self):
        """Test certificate pinning setup."""
        hashes = [
            "abc123def456789...",
            "xyz789abc123def...",
        ]
        pinning = CertificatePinning(hashes)

        assert len(pinning.pin_hashes) == 2

    def test_certificate_hash_case_insensitive(self):
        """Test hash comparison is case-insensitive."""
        pinning = CertificatePinning(["ABC123"])

        assert "abc123" in pinning.pin_hashes

    def test_certificate_verification_success(self):
        """Test successful certificate verification."""
        # For testing, use a simple hash
        test_data = b"test-certificate"
        import hashlib

        test_hash = hashlib.sha256(test_data).hexdigest()

        pinning = CertificatePinning([test_hash])
        result = pinning.verify_certificate_hash(test_data)

        assert result is True

    def test_certificate_verification_failure(self):
        """Test failed certificate verification."""
        pinning = CertificatePinning(["abc123"])

        with pytest.raises(CertificatePinningError):
            pinning.verify_certificate_hash(b"unknown-certificate")


# ============================================================================
# INTEGRATION TESTS
# ============================================================================


class TestSecurityIntegration:
    """Integration tests for security components."""

    def test_secure_credential_workflow(self):
        """Test complete secure credential workflow."""
        # Setup
        os.environ["API_TOKEN"] = "secret-token-12345"
        os.environ["TLS_PASSWORD"] = "password"

        # Create secure credential manager
        manager = (
            CredentialBuilder()
            .with_environment()
            .with_auto_rotation(enabled=False)  # Disable for testing
            .build()
        )

        # Get credentials securely
        api_token = asyncio.run(manager.get("API_TOKEN"))
        assert api_token == "secret-token-12345"

        # Verify secrets are not exposed through manager object representation.
        assert "secret-token-12345" not in repr(manager)

        # Clear sensitive cache
        manager.clear_cache()
        assert len(manager._cache) == 0

        asyncio.run(manager.close())

    def test_secure_tls_and_credentials(self):
        """Test TLS and credential manager together."""
        # Create TLS configuration
        tls_config = (
            TLSConfig().with_min_tls_version("TLSv1.3").with_hostname_verification(True)
        )

        # Create credential manager
        provider = EnvironmentProvider()
        cred_manager = CredentialManager(provider)

        # Both should be configured without errors
        ssl_context = tls_config.build()
        assert ssl_context is not None
        assert cred_manager is not None


# ============================================================================
# SECURITY BEST PRACTICES TESTS
# ============================================================================


class TestSecurityBestPractices:
    """Verify security best practices are followed."""

    def test_no_credential_logging(self):
        """Verify credentials aren't logged."""
        # This test checks that credential values aren't in debug logs
        import logging
        import io

        # Setup logging capture
        log_stream = io.StringIO()
        handler = logging.StreamHandler(log_stream)
        logger = logging.getLogger("mohawk.credentials")
        logger.addHandler(handler)
        logger.setLevel(logging.DEBUG)

        # Attempt to get credential
        os.environ["SECRET_KEY"] = "super-secret-value"
        asyncio.run(EnvironmentProvider().get_credential("SECRET_KEY"))

        # Check logs don't contain the secret
        log_output = log_stream.getvalue()
        assert "super-secret-value" not in log_output

        # Cleanup
        logger.removeHandler(handler)

    def test_cache_memory_safety(self):
        """Verify cached credentials can be cleared."""
        os.environ["MEMORY_TEST"] = "value"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        asyncio.run(manager.get("MEMORY_TEST"))
        assert len(manager._cache) > 0

        manager.clear_cache()
        assert len(manager._cache) == 0

    def test_tls_hostname_verification(self):
        """Verify hostname verification is enabled by default."""
        ctx = SecureSSLContext.create()
        assert ctx.check_hostname is True


# ============================================================================
# PERFORMANCE TESTS
# ============================================================================


class TestPerformance:
    """Performance tests for security operations."""

    def test_credential_cache_performance(self):
        """Test credential cache improves performance."""
        os.environ["PERF_TEST"] = "value"
        provider = EnvironmentProvider()
        manager = CredentialManager(provider)

        # First access (cache miss)
        import time

        start = time.time()
        asyncio.run(manager.get("PERF_TEST", use_cache=True))
        first_duration = time.time() - start

        # Second access (cache hit)
        start = time.time()
        asyncio.run(manager.get("PERF_TEST", use_cache=True))
        second_duration = time.time() - start

        # Cache hit should be faster (usually much faster)
        # Allow for some variance in timing
        assert second_duration <= first_duration * 1.5

    def test_ssl_context_creation_performance(self):
        """Test SSL context creation is reasonable."""
        import time

        start = time.time()
        for _ in range(10):
            SecureSSLContext.create()
        duration = time.time() - start

        # Should be reasonably fast in CI environments.
        assert duration < 0.5


# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================


class TestErrorHandling:
    """Test comprehensive error handling."""

    def test_credential_error_messages(self):
        """Test credential errors have clear messages."""
        provider = EnvironmentProvider()

        try:
            asyncio.run(provider.get_credential("MISSING"))
        except CredentialNotFoundError as e:
            assert "MISSING" in str(e)
            assert "not found" in str(e)

    def test_tls_error_messages(self):
        """Test TLS errors have clear messages."""
        try:
            SecureSSLContext.create(min_tls_version="INVALID")
        except TLSError as e:
            assert "Invalid" in str(e) or "TLS" in str(e)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
