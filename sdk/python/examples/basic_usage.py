#!/usr/bin/env python3
"""Basic usage example for the Sovereign-Mohawk Python SDK."""

import sys
import json
from pathlib import Path

# Add parent directory to path for local development
sys.path.insert(0, str(Path(__file__).parent.parent))

from mohawk import MohawkNode, InitializationError


def main():
    """Demonstrate basic SDK functionality."""
    print("🦅 Sovereign-Mohawk Python SDK - Basic Usage Example\n")
    
    try:
        # Initialize the node
        print("🔧 Initializing MOHAWK node...")
        node = MohawkNode()
        
        # Start the node
        print("▶️  Starting node...")
        result = node.start(
            config_path="capabilities.json",
            node_id="demo-node-001"
        )
        print(f"✅ {result['message']}")
        print(f"   Data: {result.get('data', 'N/A')}\n")
        
        # Check node status
        print("📊 Checking node status...")
        status = node.status("demo-node-001")
        if 'status_data' in status:
            print(f"✅ Node Status:")
            for key, value in status['status_data'].items():
                print(f"   {key}: {value}")
        print()
        
        # Verify a sample zk-SNARK proof
        print("🔐 Verifying zk-SNARK proof...")
        proof = {
            "proof": "0x1234567890abcdef",
            "public_inputs": ["input1", "input2"],
            "curve": "bn254"
        }
        verification = node.verify_proof(proof)
        print(f"✅ {verification['message']}")
        print(f"   Result: {verification.get('data', 'N/A')}\n")
        
        # Aggregate federated learning updates
        print("🧠 Aggregating FL updates...")
        updates = [
            {
                "node_id": "node-001",
                "gradient": [0.1, 0.2, 0.3, 0.4],
                "weight": 1.0
            },
            {
                "node_id": "node-002",
                "gradient": [0.15, 0.25, 0.35, 0.45],
                "weight": 0.8
            },
            {
                "node_id": "node-003",
                "gradient": [0.12, 0.22, 0.32, 0.42],
                "weight": 1.2
            },
        ]
        aggregation = node.aggregate(updates)
        print(f"✅ {aggregation['message']}")
        print(f"   Result: {aggregation.get('data', 'N/A')}\n")
        
        # Load a WASM module
        print("🧱 Loading WASM module...")
        wasm_result = node.load_wasm("wasm-modules/fl_task/target/wasm32-wasi/release/fl_task.wasm")
        print(f"✅ {wasm_result['message']}")
        print(f"   Module: {wasm_result.get('data', 'N/A')}\n")
        
        # Perform TPM attestation
        print("🛡️  Performing TPM attestation...")
        attestation = node.attest("demo-node-001")
        print(f"✅ {attestation['message']}")
        print(f"   Data: {attestation.get('data', 'N/A')}\n")
        
        print("✨ All operations completed successfully!")
        
    except InitializationError as e:
        print(f"❌ Initialization failed: {e}")
        print("\n💡 Make sure you've built the Go library first:")
        print("   cd ../../..")
        print("   make build-python-lib")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
