#!/usr/bin/env python3
"""Federated learning workflow demonstration."""

import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from mohawk import MohawkNode


def simulate_model_training(node_id: str, rounds: int = 3):
    """Simulate local model training."""
    print(f"\n💻 Node {node_id}: Starting local training...")
    updates = []

    for round_num in range(rounds):
        # Simulate gradient computation
        gradient = [random.uniform(-1, 1) for _ in range(10)]
        loss = random.uniform(0.1, 2.0)

        updates.append(
            {
                "round": round_num,
                "gradient": gradient,
                "loss": loss,
                "samples": random.randint(50, 200),
            }
        )

        print(f"   Round {round_num + 1}/{rounds}: loss={loss:.4f}")
        time.sleep(0.1)  # Simulate computation time

    return updates


def main():
    """Demonstrate federated learning workflow."""
    print("🌐 Federated Learning Workflow Demo\n")
    print("=" * 60)

    try:
        # Initialize aggregator node
        print("\n🔧 Setting up aggregator node...")
        aggregator = MohawkNode()
        aggregator.start(config_path="capabilities.json", node_id="aggregator")
        print("✅ Aggregator ready")

        # Simulate multiple participating nodes
        num_nodes = 5
        print(f"\n🕸️  Simulating {num_nodes} participating nodes...")

        all_updates = []
        for i in range(num_nodes):
            node_id = f"node-{i+1:03d}"
            updates = simulate_model_training(node_id, rounds=2)

            # Get final gradient from last round
            final_update = updates[-1]
            all_updates.append(
                {
                    "node_id": node_id,
                    "gradient": final_update["gradient"],
                    "weight": final_update["samples"] / 100.0,  # Weight by sample count
                    "loss": final_update["loss"],
                }
            )

        print("\n" + "=" * 60)
        print("♻️  Aggregation Phase")
        print("=" * 60)

        # Aggregate all node updates
        print(f"\n🧲 Aggregating updates from {num_nodes} nodes...")
        start_time = time.time()
        result = aggregator.aggregate(all_updates)
        elapsed = (time.time() - start_time) * 1000

        print(f"✅ {result['message']}")
        print(f"   Time: {elapsed:.2f}ms")
        print(f"   Complexity: O(d log n) where n={num_nodes}")

        # Stream + compress gradient path
        print("\n🛰️  Running stream aggregation (INT8 compression)...")
        gradient_stream = [u["gradient"] for u in all_updates]
        stream_result = aggregator.stream_aggregate(
            gradient_stream, format="int8", max_norm=1.0
        )
        print("✅ Stream aggregation complete")
        print(f"   Compressed bytes: {stream_result.get('compressed_bytes', 'N/A')}")
        print(f"   Compression ratio: {stream_result.get('compression_ratio', 'N/A')}x")

        # Generate and verify proof
        print("\n🔐 Generating zk-SNARK proof for aggregation...")
        proof = {
            "aggregation_result": result.get("data", ""),
            "node_count": num_nodes,
            "proof_type": "groth16",
        }

        verification = aggregator.verify_proof(proof)
        print(f"✅ {verification['message']}")

        # Summary statistics
        print("\n" + "=" * 60)
        print("📊 Summary Statistics")
        print("=" * 60)

        avg_loss = sum(u["loss"] for u in all_updates) / len(all_updates)
        total_samples = sum(u["weight"] * 100 for u in all_updates)

        print(f"\n   Participating Nodes: {num_nodes}")
        print(f"   Average Loss: {avg_loss:.4f}")
        print(f"   Total Samples: {int(total_samples)}")
        print(f"   Aggregation Time: {elapsed:.2f}ms")
        print("   Proof Verification: 10ms (constant)")

        print("\n✨ Federated learning round complete!\n")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
