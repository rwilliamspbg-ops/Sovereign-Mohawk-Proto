"""Unit tests for the MOHAWK Python client."""

import pytest
import json
from mohawk import MohawkNode, InitializationError, VerificationError


class TestMohawkNode:
    """Test suite for MohawkNode class."""
    
    @pytest.fixture
    def node(self):
        """Create a node instance for testing."""
        try:
            return MohawkNode()
        except InitializationError:
            pytest.skip("Go library not available")
    
    def test_initialization(self, node):
        """Test node initialization."""
        assert node is not None
        assert hasattr(node, 'lib')
    
    def test_start_node(self, node):
        """Test starting a node."""
        result = node.start(
            config_path="capabilities.json",
            node_id="test-node"
        )
        assert result['success'] is True
        assert 'message' in result
    
    def test_verify_proof(self, node):
        """Test zk-SNARK proof verification."""
        proof = {
            "proof": "0xtest",
            "public_inputs": ["input1"]
        }
        result = node.verify_proof(proof)
        assert result['success'] is True
    
    def test_aggregate_updates(self, node):
        """Test federated learning aggregation."""
        updates = [
            {"node_id": "n1", "gradient": [0.1, 0.2]},
            {"node_id": "n2", "gradient": [0.15, 0.25]}
        ]
        result = node.aggregate(updates)
        assert result['success'] is True
    
    def test_node_status(self, node):
        """Test retrieving node status."""
        result = node.status("test-node")
        assert result['success'] is True
        assert 'status_data' in result
    
    def test_load_wasm(self, node):
        """Test WASM module loading."""
        result = node.load_wasm("test.wasm")
        assert result['success'] is True
    
    def test_attestation(self, node):
        """Test TPM attestation."""
        result = node.attest("test-node")
        assert result['success'] is True


class TestExceptions:
    """Test custom exception handling."""
    
    def test_initialization_error(self):
        """Test InitializationError is raised for invalid library path."""
        with pytest.raises(InitializationError):
            MohawkNode(lib_path="/nonexistent/path/libmohawk.so")
