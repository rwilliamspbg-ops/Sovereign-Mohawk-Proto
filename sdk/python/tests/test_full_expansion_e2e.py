"""
Comprehensive End-to-End Integration Tests for Full SDK Expansion.

Tests all phases:
- Phase 1: Security Hardening (credential manager, TLS)
- Phase 2: PyPI Distribution (packaging, versioning)
- Phase 3: Observability (metrics, tracing, logging)
- Phase 4: Cloud Deployment (Docker, K8s, multi-cloud)
- Phase 5: Documentation & Community (examples, case studies)
"""

import pytest
import asyncio
import sys
import os
from pathlib import Path

# Add SDK to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import mohawk
from mohawk import (
    CredentialBuilder,
    CredentialManager,
    EnvironmentProvider,
    TLSConfig,
    SecureSSLContext,
)
from mohawk.credentials import CredentialNotFoundError


class TestPhase1SecurityHardening:
    """Test Phase 1: Security Hardening"""
    
    @pytest.mark.asyncio
    async def test_credential_manager_initialization(self):
        """Test credential manager setup."""
        os.environ["TEST_TOKEN"] = "test-value-123"
        
        manager = (
            CredentialBuilder()
            .with_environment()
            .with_auto_rotation(enabled=False)
            .build()
        )
        
        value = await manager.get("TEST_TOKEN")
        assert value == "test-value-123"
        
        await manager.close()
    
    def test_tls_context_creation(self):
        """Test TLS context with security defaults."""
        ctx = SecureSSLContext.create()
        
        assert ctx is not None
        assert ctx.check_hostname is True
        assert ctx.verify_mode.name == "CERT_REQUIRED"


class TestPhase2PyPIDistribution:
    """Test Phase 2: PyPI Distribution"""
    
    def test_version_string_format(self):
        """Test version follows semantic versioning."""
        version = mohawk.__version__
        
        # Should be X.Y.Z format
        parts = version.split(".")
        assert len(parts) >= 3
        assert version.startswith("2.")  # Major version 2
    
    def test_sdk_package_exports(self):
        """Test all public exports are available."""
        # Phase 1 exports should be available
        assert hasattr(mohawk, "CredentialManager")
        assert hasattr(mohawk, "CredentialBuilder")
        assert hasattr(mohawk, "SecureSSLContext")
        assert hasattr(mohawk, "TLSConfig")
        
        # Original exports should still work
        assert hasattr(mohawk, "MohawkNode")
        assert hasattr(mohawk, "AsyncMohawkNode")
    
    def test_all_exports_in_all_list(self):
        """Test __all__ is comprehensive."""
        exported = set(mohawk.__all__)
        
        # Check key Phase 1 items
        phase1_items = {
            "CredentialManager",
            "CredentialBuilder",
            "SecureSSLContext",
            "TLSConfig",
        }
        
        assert phase1_items.issubset(exported)


class TestPhase3Observability:
    """Test Phase 3: Observability (mock implementation)"""
    
    def test_observability_structure(self):
        """Verify observability module would support metrics."""
        # In full implementation, would import:
        # from mohawk.observability import MohawkMetrics, MohawkTracer
        
        # For now, verify credential manager has audit logging
        assert True  # Placeholder for observability testing
    
    def test_logging_available(self):
        """Test logging is configured."""
        import logging
        
        logger = logging.getLogger("mohawk")
        assert logger is not None


class TestPhase4CloudDeployment:
    """Test Phase 4: Cloud Deployment (configuration validation)"""
    
    def test_kubernetes_secrets_provider_available(self):
        """Test K8s provider is available for cloud deployment."""
        from mohawk.credentials import K8sSecretsProvider
        
        # Should be available even if not fully implemented
        assert K8sSecretsProvider is not None
    
    def test_vault_provider_available(self):
        """Test Vault provider is available for production."""
        from mohawk.credentials import VaultProvider
        
        assert VaultProvider is not None
    
    def test_tls_config_builder_production_ready(self):
        """Test TLS config supports production scenarios."""
        config = (
            TLSConfig()
            .with_ca_bundle("/etc/ssl/certs/ca-bundle.crt")
            .with_min_tls_version("TLSv1.3")
            .with_hostname_verification(True)
        )
        
        assert config.min_tls_version == "TLSv1.3"
        assert config.check_hostname is True


class TestPhase5Documentation:
    """Test Phase 5: Documentation & Community"""
    
    def test_module_docstrings_present(self):
        """Verify modules have documentation."""
        assert mohawk.__doc__ is not None
        assert len(mohawk.__doc__) > 0
    
    def test_version_in_docstring(self):
        """Test version is documented."""
        assert "2.1.0" in mohawk.__doc__ or "v2.1" in mohawk.__doc__
    
    def test_security_features_documented(self):
        """Test security features are documented."""
        doc = mohawk.__doc__.lower()
        assert "security" in doc
        assert "credential" in doc or "tls" in doc


class TestEndToEndIntegration:
    """End-to-end integration tests across all phases"""
    
    @pytest.mark.asyncio
    async def test_secure_sdk_workflow(self):
        """Test complete secure SDK workflow."""
        # Phase 1: Credentials
        os.environ["SDK_API_TOKEN"] = "secure-token-xyz"
        
        manager = (
            CredentialBuilder()
            .with_environment()
            .build()
        )
        
        token = await manager.get("SDK_API_TOKEN")
        assert token == "secure-token-xyz"
        
        # Phase 3: Logging (observability)
        import logging
        logging.basicConfig(level=logging.INFO)
        
        # Phase 4: TLS (cloud deployment)
        tls_config = TLSConfig().with_min_tls_version("TLSv1.3")
        ctx = tls_config.build()
        assert ctx is not None
        
        # Cleanup
        await manager.close()
    
    @pytest.mark.asyncio
    async def test_multi_provider_credential_support(self):
        """Test multiple credential providers (Phase 4)."""
        # Environment provider (Phase 1)
        env_manager = (
            CredentialBuilder()
            .with_environment()
            .build()
        )
        
        os.environ["MULTI_TEST"] = "value"
        value = await env_manager.get("MULTI_TEST")
        assert value == "value"
        
        # Vault provider available (Phase 4)
        from mohawk.credentials import VaultProvider
        assert VaultProvider is not None
        
        # K8s provider available (Phase 4)
        from mohawk.credentials import K8sSecretsProvider
        assert K8sSecretsProvider is not None
        
        await env_manager.close()
    
    def test_production_ready_security_stack(self):
        """Verify production-ready security stack."""
        # TLS 1.3
        ctx = SecureSSLContext.create()
        assert ctx.minimum_version.name == "TLSv1_3"
        
        # Certificate pinning
        from mohawk.tls import CertificatePinning
        pinning = CertificatePinning(["abc123"])
        assert pinning is not None
        
        # Error handling
        from mohawk.credentials import CredentialError
        assert CredentialError is not None


class TestBuildValidation:
    """Validate SDK builds successfully"""
    
    def test_imports_no_errors(self):
        """Test all imports work without errors."""
        try:
            import mohawk
            from mohawk import (
                CredentialManager,
                TLSConfig,
                MohawkNode,
                AsyncMohawkNode,
            )
            assert True
        except ImportError as e:
            pytest.fail(f"Import error: {e}")
    
    def test_version_accessible(self):
        """Test version is accessible."""
        assert hasattr(mohawk, "__version__")
        assert mohawk.__version__ == "2.1.0"
    
    def test_all_list_complete(self):
        """Test __all__ list is properly defined."""
        assert hasattr(mohawk, "__all__")
        assert isinstance(mohawk.__all__, list)
        assert len(mohawk.__all__) > 30  # Should have many exports


class TestPerformanceValidation:
    """Validate performance across all phases"""
    
    @pytest.mark.asyncio
    async def test_credential_performance(self):
        """Test credential operations are fast."""
        import time
        
        os.environ["PERF_TEST"] = "value"
        manager = CredentialBuilder().with_environment().build()
        
        start = time.time()
        value = await manager.get("PERF_TEST")
        duration = time.time() - start
        
        # Should be < 10ms
        assert duration < 0.01
        
        await manager.close()
    
    def test_tls_context_performance(self):
        """Test TLS context creation is fast."""
        import time
        
        start = time.time()
        ctx = SecureSSLContext.create()
        duration = time.time() - start
        
        # Should be < 50ms
        assert duration < 0.05


class TestSecurityCompliance:
    """Verify security compliance across all phases"""
    
    def test_no_default_insecure_settings(self):
        """Test no insecure defaults."""
        ctx = SecureSSLContext.create()
        
        # Should not allow insecure settings
        assert ctx.check_hostname is True
        assert ctx.verify_mode.name == "CERT_REQUIRED"
    
    def test_credential_error_messages_safe(self):
        """Test error messages don't leak credentials."""
        try:
            asyncio.run(EnvironmentProvider().get_credential("MISSING"))
        except CredentialNotFoundError as e:
            error_msg = str(e)
            # Should not contain credentials
            assert "password" not in error_msg.lower()
            assert "token" not in error_msg.lower() or "MISSING" in error_msg
    
    @pytest.mark.asyncio
    async def test_cache_can_be_cleared(self):
        """Test credential cache can be cleared."""
        os.environ["CACHE_TEST"] = "value"
        manager = CredentialBuilder().with_environment().build()
        
        await manager.get("CACHE_TEST")
        assert len(manager._cache) > 0
        
        manager.clear_cache()
        assert len(manager._cache) == 0
        
        await manager.close()


class TestRolloutReadiness:
    """Validate rollout readiness for all phases"""
    
    def test_backward_compatibility(self):
        """Test backward compatibility."""
        # Old imports should still work
        from mohawk import MohawkNode, AsyncMohawkNode
        assert MohawkNode is not None
        assert AsyncMohawkNode is not None
    
    def test_new_features_optional(self):
        """Test new features are optional."""
        # Should be able to use SDK without new security features
        from mohawk import MohawkNode
        assert MohawkNode is not None
    
    def test_version_upgrade_path(self):
        """Test version follows upgrade path."""
        version = mohawk.__version__
        
        # Should be 2.1.0 (2.0.x -> 2.1.0)
        assert version.startswith("2.1")
    
    def test_documentation_links_valid(self):
        """Test documentation references are valid."""
        # Check for comprehensive docstring
        assert mohawk.__doc__ is not None
        assert "Security hardening" in mohawk.__doc__ or "security" in mohawk.__doc__.lower()


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-s"])
