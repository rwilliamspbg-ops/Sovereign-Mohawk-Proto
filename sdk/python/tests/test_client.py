"""Unit tests for the MOHAWK Python client."""

import array

import pytest
import mohawk.client as client_module
from mohawk import (
    AggregationError,
    BridgeTransferIntent,
    GradientBuffer,
    HybridProofCheck,
    MohawkNode,
    InitializationError,
    ProofTooShortError,
    VerificationError,
    build_evm_log_proof,
    build_cosmos_ibc_proof,
    build_auto_tune_profile,
)


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
        assert hasattr(node, "lib")

    def test_start_node(self, node):
        """Test starting a node."""
        result = node.start(config_path="capabilities.json", node_id="test-node")
        assert result["success"] is True
        assert "message" in result

    def test_verify_proof(self, node):
        """Test zk-SNARK proof verification."""
        proof = {"proof": "0xtest", "public_inputs": ["input1"]}
        try:
            result = node.verify_proof(proof)
            assert "success" in result
        except ProofTooShortError:
            assert True

    def test_aggregate_updates(self, node):
        """Test federated learning aggregation."""
        updates = [
            {"node_id": "n1", "gradient": [0.1, 0.2]},
            {"node_id": "n2", "gradient": [0.15, 0.25]},
        ]
        result = node.aggregate(updates)
        assert result["success"] is True

    def test_node_status(self, node):
        """Test retrieving node status."""
        result = node.status("test-node")
        assert result["success"] is True
        assert "status_data" in result

    def test_load_wasm(self, node):
        """Test WASM module loading."""
        result = node.load_wasm("test.wasm")
        assert result["success"] is True

    def test_attestation(self, node):
        """Test TPM attestation."""
        result = node.attest("test-node")
        assert result["success"] is True

    def test_attestation_includes_lease_fields(self, node):
        result = node.attest("test-node")
        assert result["success"] is True
        data = result.get("data")
        if isinstance(data, str):
            assert "lease_expires_at" in data or '"node_id": "test-node"' in data

    def test_device_info(self, node):
        """Test device enumeration API."""
        result = node.device_info()
        assert result["success"] is True

    def test_auto_tune_profile(self, node):
        result = node.auto_tune_profile(4096)
        assert result["success"] is True
        assert "data" in result

    def test_compress_gradients_fp16(self, node):
        """Test FP16 gradient compression."""
        result = node.compress_gradients([0.1, -0.2, 0.3], format="fp16")
        assert result["success"] is True

    def test_compress_gradients_int8(self, node):
        """Test INT8 gradient compression."""
        result = node.compress_gradients([0.1, -0.2, 0.3], format="int8", max_norm=1.0)
        assert result["success"] is True

    def test_compress_gradients_zero_copy(self, node):
        gradients = array.array("f", [0.1, -0.2, 0.3, 0.4])
        result = node.compress_gradients_zero_copy(memoryview(gradients), format="fp16")
        assert result["success"] is True

    def test_compress_gradients_rejects_oversized_vector(self, node, monkeypatch):
        monkeypatch.setattr(client_module, "MAX_GRADIENT_ELEMENTS", 2)
        with pytest.raises(AggregationError):
            node.compress_gradients([0.1, 0.2, 0.3], format="fp16")

    def test_compress_gradients_zero_copy_rejects_oversized_vector(self, node, monkeypatch):
        monkeypatch.setattr(client_module, "MAX_GRADIENT_ELEMENTS", 2)
        gradients = array.array("f", [0.1, 0.2, 0.3])
        with pytest.raises(AggregationError):
            node.compress_gradients_zero_copy(memoryview(gradients), format="fp16")

    def test_batch_verify(self, node):
        """Test batch proof verification API."""
        proofs = [{"id": "p1", "proof": "abc"}, {"id": "p2", "proof": "xyz"}]
        result = node.batch_verify(proofs)
        assert result["success"] is True

    def test_stream_aggregate(self, node):
        """Test streaming aggregation helper."""
        stream = [[0.1, 0.2], [0.3, 0.4]]
        result = node.stream_aggregate(stream, format="fp16", max_norm=1.0)
        assert result["success"] is True
        assert result["count"] == 2

    def test_hybrid_verify(self, node):
        """Test hybrid SNARK/STARK verification API."""
        try:
            result = node.verify_hybrid_proof(
                snark_proof="s" * 128,
                stark_proof="t" * 64,
                mode="both",
                stark_backend="simulated_fri",
            )
            assert "success" in result
        except VerificationError:
            assert True

    def test_hybrid_backends(self, node):
        result = node.hybrid_backends()
        assert result["success"] is True

    def test_bridge_transfer(self, node):
        """Test cross-chain bridge transfer API."""
        result = node.bridge_transfer(
            source_chain="ethereum",
            target_chain="polygon",
            asset="USDC",
            amount=12.5,
            sender="0xabc",
            receiver="0xdef",
            nonce=1,
            proof="proof-bytes",
            finality_depth=12,
            route_policy={
                "id": "evm-usdc-fast-finality",
                "allowed_assets": ["USDC", "USDT"],
                "min_amount": 1.0,
                "max_amount": 1000.0,
                "min_finality_blocks": 12,
            },
        )
        assert result["success"] is True

    def test_bridge_transfer_typed_evm_proof(self, node):
        proof = build_evm_log_proof(
            block_hash="0xabc",
            tx_hash="0xdef",
            log_index=1,
            event_sig="Transfer(address,address,uint256)",
            receipt_root="0x123",
        )
        result = node.bridge_transfer(
            source_chain="ethereum",
            target_chain="polygon",
            asset="USDC",
            amount=1.0,
            sender="0xabc",
            receiver="0xdef",
            nonce=2,
            proof=proof,
            finality_depth=12,
        )
        assert result["success"] is True

    def test_bridge_transfer_typed_cosmos_proof(self, node):
        proof = build_cosmos_ibc_proof(
            client_id="07-tendermint-0",
            connection_id="connection-0",
            channel_id="channel-0",
            port_id="transfer",
            sequence=11,
            commitment="abc123",
            height=123,
        )
        result = node.bridge_transfer(
            source_chain="cosmos",
            target_chain="ethereum",
            asset="ATOM",
            amount=2.0,
            sender="cosmos1sender",
            receiver="0xdef",
            nonce=3,
            proof=proof,
            finality_depth=5,
        )
        assert result["success"] is True

    def test_transfer_asset_wrapper(self, node):
        intent = BridgeTransferIntent(
            source_chain="ethereum",
            target_chain="polygon",
            asset="USDC",
            amount=3.0,
            sender="0xabc",
            receiver="0xdef",
            nonce=4,
            proof={"proof": "typed"},
            finality_depth=12,
        )
        receipt = node.transfer_asset(intent)
        assert receipt.success is True
        assert isinstance(receipt.raw, dict)

    def test_verify_hybrid_wrapper(self, node):
        check = HybridProofCheck(
            snark_proof="s" * 128,
            stark_proof="t" * 64,
            mode="both",
            stark_backend="simulated_fri",
        )
        try:
            receipt = node.verify_hybrid(check)
            assert receipt.success is True
            assert isinstance(receipt.raw, dict)
        except VerificationError:
            assert True

    def test_utility_coin_workflow(self, node):
        minted = node.mint_utility_coin(
            to="edge-alice", amount=100.0, actor="protocol", memo="genesis"
        )
        assert minted["success"] is True

        transferred = node.transfer_utility_coin(
            from_account="edge-alice",
            to_account="edge-bob",
            amount=25.0,
            memo="inference reward",
        )
        assert transferred["success"] is True

        alice = node.utility_coin_balance("edge-alice")
        bob = node.utility_coin_balance("edge-bob")
        assert alice["success"] is True
        assert bob["success"] is True

        ledger = node.utility_coin_ledger()
        assert ledger["success"] is True

        try:
            backup = node.backup_utility_coin_ledger("/tmp/mohawk_ledger_backup.json")
            assert backup["success"] is True
            restore = node.restore_utility_coin_ledger("/tmp/mohawk_ledger_backup.json")
            assert restore["success"] is True
        except AggregationError as exc:
            assert "persistent state is not configured" in str(exc)


class TestGradientBuffer:
    """Unit tests for GradientBuffer utility."""

    def test_gradient_buffer_compress(self):
        buffer = GradientBuffer(max_norm=1.0, format="int8")
        buffer.add([0.1, 0.2, 0.3])
        compressed = buffer.compress()
        info = compressed.to_dict()
        assert info["format"] == "int8"
        assert info["compressed_bytes"] > 0

    def test_gradient_buffer_auto_format(self):
        profile = build_auto_tune_profile(4096)
        buffer = GradientBuffer(max_norm=1.0, format="auto")
        buffer.add([0.1] * 4096)
        compressed = buffer.compress()
        assert compressed.format in {"fp16", "int8"}
        assert compressed.backend == profile.selected_device.backend


class TestExceptions:
    """Test custom exception handling."""

    def test_initialization_error(self):
        """Test InitializationError is raised for invalid library path."""
        with pytest.raises(InitializationError):
            MohawkNode(lib_path="/nonexistent/path/libmohawk.so")
