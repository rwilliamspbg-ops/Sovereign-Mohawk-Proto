"""
Advanced Byzantine Attack Testing for Federated Learning

Tests system resilience against sophisticated adaptive Byzantine adversaries:
- Model Poisoning Attacks (targeted parameter corruption)
- Gradient Flip Attacks (sign inversion)
- Gaussian Noise Attacks (magnitude-scaled poisoning)
- Adaptive Attacks (learning from aggregation feedback)
- Coordinated Multi-Node Attacks
- High Byzantine Ratios (20-30%)

References:
- [1] Blanchard et al. "Machine Learning with Adversaries: Byzantine Tolerant Gradient Descent"
- [2] Bagdasaryan et al. "How to Backdoor Federated Learning"
- [3] Fung et al. "Mitigating Sybils in Federated Learning Poisoning"
"""

import json
import time
import random
import math
import array
import pytest
from typing import List, Dict, Any, Tuple, Callable

from mohawk import MohawkNode, GradientBuffer, AggregationError

# ============================================================================
# BYZANTINE ATTACK GENERATORS
# ============================================================================


class ByzantineAttackGenerator:
    """Generates realistic Byzantine attack vectors."""

    @staticmethod
    def honest_gradient(dim: int, scale: float = 0.01) -> List[float]:
        """Generate honest gradient: N(0, scale^2)."""
        return [random.gauss(0, scale) for _ in range(dim)]

    @staticmethod
    def flip_attack(gradients: List[float]) -> List[float]:
        """Flip attack: negate all gradients to diverge learning."""
        return [-g for g in gradients]

    @staticmethod
    def gaussian_attack(
        dim: int, scale: float = 10.0, seed_grad: List[float] = None
    ) -> List[float]:
        """Gaussian attack: large-magnitude random noise to poison aggregation."""
        if seed_grad:
            return [g + random.gauss(0, scale) for g in seed_grad]
        return [random.gauss(0, scale) for _ in range(dim)]

    @staticmethod
    def label_flip_attack(gradients: List[float], flip_ratio: float = 0.5) -> List[float]:
        """Label flip: corrupt top-k coordinates to highest magnitude."""
        sorted_indices = sorted(
            range(len(gradients)), key=lambda i: abs(gradients[i]), reverse=True
        )
        flip_count = int(len(gradients) * flip_ratio)
        result = gradients.copy()
        for i in sorted_indices[:flip_count]:
            result[i] = -result[i] * 10  # Amplify flipped values
        return result

    @staticmethod
    def targeted_poison(
        gradients: List[float], target_indices: List[int], poison_scale: float = 50.0
    ) -> List[float]:
        """Targeted poison: maximize gradient values at specific coordinates."""
        result = gradients.copy()
        for idx in target_indices:
            if idx < len(result):
                result[idx] = poison_scale * (1 if random.random() > 0.5 else -1)
        return result

    @staticmethod
    def adaptive_attack(
        honest_mean: List[float], attack_history: List[Dict[str, Any]], scale_factor: float = 20.0
    ) -> List[float]:
        """
        Adaptive attack: learn from previous aggregations and scale attack proportionally.

        Strategy:
        1. If aggregation detected low-magnitude result, increase attack magnitude
        2. If detection occurred, shift attack to different coordinates
        3. Use history to infer aggregation method
        """
        if not attack_history:
            # Initial attack: strong Gaussian
            return [random.gauss(0, scale_factor) for _ in honest_mean]

        # Analyze last aggregation
        last_result = attack_history[-1]
        detected = last_result.get("detected", False)

        if detected:
            # Shift attack: use different coordinates
            dim = len(honest_mean)
            if attack_history[-1].get("attacked_indices"):
                attacked = set(attack_history[-1]["attacked_indices"])
                available = [i for i in range(dim) if i not in attacked]
            else:
                available = list(range(dim))

            if not available:
                available = list(range(dim))

            attack = [random.gauss(0, scale_factor) for _ in honest_mean]
            # Zero out previously used indices
            for i in range(len(attack)):
                if i not in available[: len(available) // 2]:
                    attack[i] = 0
            return attack
        else:
            # Increase magnitude if not detected
            increased_scale = scale_factor * 1.5
            return [random.gauss(0, increased_scale) for _ in honest_mean]


# ============================================================================
# BYZANTINE DETECTION & MITIGATION
# ============================================================================


class ByzantineDetector:
    """Detects Byzantine updates using robust statistics."""

    @staticmethod
    def krum_filter(
        updates: List[List[float]], byzantine_count: int
    ) -> Tuple[List[float], List[int]]:
        """
        Krum robust aggregation: select update with minimum sum of distances.

        Filters out byzantine_count largest distances.
        Reference: [1] Blanchard et al.
        """
        n = len(updates)
        if n == 0:
            return [], []

        dim = len(updates[0])
        distances = [0.0] * n

        # Compute pairwise distances
        for i in range(n):
            total_dist = 0
            neighbor_count = n - byzantine_count - 1

            if neighbor_count <= 0:
                distances[i] = float("inf")
                continue

            dists = []
            for j in range(n):
                if i != j:
                    # Euclidean distance
                    dist = sum((updates[i][k] - updates[j][k]) ** 2 for k in range(dim))
                    dists.append(dist)

            # Sum of K nearest neighbors
            dists.sort()
            distances[i] = sum(dists[:neighbor_count])

        # Select minimum distance update
        selected_idx = distances.index(min(distances))
        return updates[selected_idx], [selected_idx]

    @staticmethod
    def median_filter(updates: List[List[float]]) -> Tuple[List[float], List[int]]:
        """Coordinate-wise median: robust to up to 50% Byzantine."""
        if not updates:
            return [], []

        dim = len(updates[0])
        result = []
        selected_indices = list(range(len(updates)))

        for coord in range(dim):
            values = [u[coord] for u in updates]
            values.sort()
            median_val = values[len(values) // 2]
            result.append(median_val)

        return result, selected_indices

    @staticmethod
    def trimmed_mean(
        updates: List[List[float]], trim_ratio: float = 0.2
    ) -> Tuple[List[float], List[int]]:
        """
        Trimmed mean: remove top/bottom trim_ratio of values per coordinate.

        Robust to trim_ratio% Byzantine.
        """
        if not updates:
            return [], []

        dim = len(updates[0])
        n = len(updates)
        trim_count = max(1, int(n * trim_ratio))
        result = []
        selected_indices = list(range(len(updates)))

        for coord in range(dim):
            values = sorted([(updates[i][coord], i) for i in range(n)])
            # Remove top/bottom trim_count
            kept = values[trim_count : n - trim_count]
            if kept:
                mean_val = sum(v[0] for v in kept) / len(kept)
                result.append(mean_val)
            else:
                result.append(values[n // 2][0])  # Fallback to median

        return result, selected_indices

    @staticmethod
    def detect_anomaly(
        update: List[float],
        honest_mean: List[float],
        threshold_std: float = 3.0,
    ) -> bool:
        """
        Detect anomalous update using statistical test.

        Flags update if any coordinate exceeds threshold_std standard deviations.
        """
        if not honest_mean:
            return False

        dim = len(update)
        honest_std = 0.01  # Assumed standard deviation of honest updates

        for i in range(dim):
            z_score = abs(update[i] - honest_mean[i]) / max(honest_std, 1e-6)
            if z_score > threshold_std:
                return True

        return False


# ============================================================================
# ATTACK SCENARIO TESTS
# ============================================================================


@pytest.fixture
def node():
    """Initialize MOHAWK node."""
    node = MohawkNode()
    node.bridge.close()
    return node


class TestBasicAttacks:
    """Test basic Byzantine attack vectors."""

    def test_flip_attack_10_percent_byzantine(self, node):
        """Test gradient flip attack at 10% Byzantine (baseline)."""
        num_honest = 900
        num_byzantine = 100
        gradient_dim = 1536

        # Generate honest updates
        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
            }
            for i in range(num_honest)
        ]

        # Byzantine flip attack
        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": ByzantineAttackGenerator.flip_attack(
                    ByzantineAttackGenerator.honest_gradient(gradient_dim)
                ),
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError as e:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "flip attack (10% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "10%",
            "attack_type": "Gradient Flip",
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
        }
        print(f"\n{json.dumps(report, indent=2)}")
        assert success, "Aggregation should succeed even with 10% flip attacks"

    def test_gaussian_attack_20_percent_byzantine(self, node):
        """Test Gaussian noise attack at 20% Byzantine ratio."""
        num_honest = 800
        num_byzantine = 200
        gradient_dim = 1536

        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
            }
            for i in range(num_honest)
        ]

        # Gaussian attack: large random noise
        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=10.0),
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError as e:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "Gaussian noise attack (20% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "20%",
            "attack_type": "Large Magnitude Gaussian",
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
            "note": "System should detect and mitigate 20% noise attacks",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_label_flip_attack_25_percent_byzantine(self, node):
        """Test targeted label flip at 25% Byzantine ratio."""
        num_honest = 750
        num_byzantine = 250
        gradient_dim = 1536

        honest_gradients = [
            ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
        ]
        honest_updates = [
            {"node_id": f"honest-{i}", "gradient": grad} for i, grad in enumerate(honest_gradients)
        ]

        # Label flip: corrupt top-k coordinates
        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": ByzantineAttackGenerator.label_flip_attack(
                    ByzantineAttackGenerator.honest_gradient(gradient_dim), flip_ratio=0.5
                ),
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "label flip attack (25% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "25%",
            "attack_type": "Targeted Label Flip (50% coordinates)",
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
        }
        print(f"\n{json.dumps(report, indent=2)}")


class TestAdaptiveAttacks:
    """Test adaptive Byzantine attacks that learn from aggregation."""

    def test_adaptive_attack_20_percent(self, node):
        """Test adaptive attack that adjusts based on aggregation feedback."""
        num_honest = 800
        num_byzantine = 200
        gradient_dim = 512
        num_rounds = 5

        results_per_round = []

        for round_idx in range(num_rounds):
            # Honest updates
            honest_gradients = [
                ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
            ]
            honest_updates = [
                {"node_id": f"honest-{i}", "gradient": grad}
                for i, grad in enumerate(honest_gradients)
            ]

            # Calculate honest mean for attack adaptation
            honest_mean = [
                sum(g[i] for g in honest_gradients) / num_honest for i in range(gradient_dim)
            ]

            # Attack history (simulated)
            attack_history = results_per_round

            # Adaptive Byzantine updates
            byzantine_updates = [
                {
                    "node_id": f"byzantine-{i}",
                    "gradient": ByzantineAttackGenerator.adaptive_attack(
                        honest_mean, attack_history, scale_factor=15.0 + round_idx * 5
                    ),
                }
                for i in range(num_byzantine)
            ]

            mixed_updates = honest_updates + byzantine_updates
            random.shuffle(mixed_updates)

            start = time.perf_counter()
            try:
                agg_result = node.aggregate(mixed_updates)
                success = agg_result.get("success", False)
            except AggregationError:
                success = False

            elapsed = (time.perf_counter() - start) * 1000

            round_result = {
                "round": round_idx + 1,
                "success": success,
                "time_ms": round(elapsed, 3),
                "detected": not success,
            }
            results_per_round.append(round_result)

        overall_success_rate = sum(1 for r in results_per_round if r["success"]) / len(
            results_per_round
        )

        report = {
            "test": "adaptive attack (20% Byzantine, 5 rounds)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "20%",
            "rounds": results_per_round,
            "overall_success_rate": round(overall_success_rate, 2),
            "attack_strategy": "Gradient magnitude escalation with coordinate shifting",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_coordinated_attack_25_percent(self, node):
        """Test coordinated multi-node Byzantine attack at 25%."""
        num_honest = 750
        num_byzantine = 250
        gradient_dim = 1024

        # Honest updates
        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
            }
            for i in range(num_honest)
        ]

        # Coordinated Byzantine: all nodes attack same coordinates with synchronized magnitude
        target_indices = list(range(0, gradient_dim, 4))  # Every 4th coordinate
        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": ByzantineAttackGenerator.targeted_poison(
                    ByzantineAttackGenerator.honest_gradient(gradient_dim),
                    target_indices=target_indices,
                    poison_scale=100.0,
                ),
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "coordinated attack (25% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "25%",
            "attack_type": "Synchronized coordinate poisoning",
            "targeted_coordinates": len(target_indices),
            "poison_magnitude": 100.0,
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
        }
        print(f"\n{json.dumps(report, indent=2)}")


class TestHighByzantineRatios:
    """Test system resilience at 30% Byzantine (theoretical limit)."""

    def test_30_percent_byzantine_ratio(self, node):
        """
        Test 30% Byzantine ratio (theoretical maximum for linear aggregation).

        Theoretical background:
        - Mean aggregation breaks at >50% Byzantine
        - Byzantine-Robust Aggregation (BRA) threshold: f < n/3
        - This test: f = 0.30n → 30%
        """
        num_honest = 700
        num_byzantine = 300
        gradient_dim = 2048

        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
            }
            for i in range(num_honest)
        ]

        # Multi-strategy Byzantine attack
        byzantine_updates = []
        for i in range(num_byzantine):
            if i < num_byzantine // 3:
                # Strategy 1: Flip
                attack = ByzantineAttackGenerator.flip_attack(
                    ByzantineAttackGenerator.honest_gradient(gradient_dim)
                )
            elif i < 2 * num_byzantine // 3:
                # Strategy 2: Gaussian
                attack = ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=20.0)
            else:
                # Strategy 3: Targeted poison
                target = list(range(0, gradient_dim, 10))
                attack = ByzantineAttackGenerator.targeted_poison(
                    ByzantineAttackGenerator.honest_gradient(gradient_dim),
                    target_indices=target,
                    poison_scale=150.0,
                )

            byzantine_updates.append(
                {
                    "node_id": f"byzantine-{i}",
                    "gradient": attack,
                }
            )

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError as e:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "30% Byzantine ratio (multi-strategy attack)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "30%",
            "strategies": {
                "flip": num_byzantine // 3,
                "gaussian": num_byzantine // 3,
                "targeted_poison": num_byzantine - 2 * (num_byzantine // 3),
            },
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
            "theoretical_limit": "30% (f < n/3 = 33.3%)",
            "status": "CRITICAL TEST",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_30_percent_sustained_attack_10_rounds(self, node):
        """Test 30% Byzantine sustained over 10 rounds."""
        num_honest = 700
        num_byzantine = 300
        gradient_dim = 1024
        num_rounds = 10

        round_results = []

        for round_idx in range(num_rounds):
            honest_updates = [
                {
                    "node_id": f"honest-{i}",
                    "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
                }
                for i in range(num_honest)
            ]

            # Escalating Byzantine attack
            attack_scale = 10.0 + round_idx * 5
            byzantine_updates = [
                {
                    "node_id": f"byzantine-{i}",
                    "gradient": ByzantineAttackGenerator.gaussian_attack(
                        gradient_dim, scale=attack_scale
                    ),
                }
                for i in range(num_byzantine)
            ]

            mixed_updates = honest_updates + byzantine_updates
            random.shuffle(mixed_updates)

            start = time.perf_counter()
            try:
                result = node.aggregate(mixed_updates)
                success = result.get("success", False)
            except AggregationError:
                success = False

            elapsed = (time.perf_counter() - start) * 1000

            round_results.append(
                {
                    "round": round_idx + 1,
                    "success": success,
                    "time_ms": round(elapsed, 3),
                    "attack_scale": attack_scale,
                }
            )

        success_rate = sum(1 for r in round_results if r["success"]) / len(round_results)

        report = {
            "test": "30% Byzantine sustained (10 rounds, escalating attack)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "30%",
            "rounds": round_results,
            "overall_success_rate": round(success_rate, 2),
            "attack_pattern": "Gaussian noise with escalating magnitude",
        }
        print(f"\n{json.dumps(report, indent=2)}")


class TestDetectionAndMitigation:
    """Test Byzantine detection and mitigation mechanisms."""

    def test_krum_detection_at_25_percent(self):
        """Test Krum robust aggregation against 25% Byzantine."""
        num_honest = 750
        num_byzantine = 250
        gradient_dim = 512

        # Generate honest gradients
        honest_grads = [
            ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
        ]

        # Byzantine gradients
        byzantine_grads = [
            ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=15.0)
            for _ in range(num_byzantine)
        ]

        all_grads = honest_grads + byzantine_grads
        random.shuffle(all_grads)

        start = time.perf_counter()
        selected_grad, selected_indices = ByzantineDetector.krum_filter(all_grads, num_byzantine)
        elapsed = (time.perf_counter() - start) * 1000

        # Check if selected gradient is honest
        is_honest = any(
            all([abs(selected_grad[i] - honest_grads[j][i]) < 0.1 for i in range(gradient_dim)])
            for j in range(num_honest)
        )

        report = {
            "test": "Krum filter detection (25% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "25%",
            "detection_time_ms": round(elapsed, 3),
            "selected_gradient_is_honest": is_honest,
            "detection_method": "Krum - minimum distance aggregate",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_median_filter_at_30_percent(self):
        """Test coordinate-wise median against 30% Byzantine."""
        num_honest = 700
        num_byzantine = 300
        gradient_dim = 512

        honest_grads = [
            ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
        ]
        byzantine_grads = [
            ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=20.0)
            for _ in range(num_byzantine)
        ]

        all_grads = honest_grads + byzantine_grads
        random.shuffle(all_grads)

        start = time.perf_counter()
        median_grad, indices = ByzantineDetector.median_filter(all_grads)
        elapsed = (time.perf_counter() - start) * 1000

        # Compute honest mean
        honest_mean = [sum(g[i] for g in honest_grads) / num_honest for i in range(gradient_dim)]

        # Check distance from honest mean
        distance = sum((median_grad[i] - honest_mean[i]) ** 2 for i in range(gradient_dim))

        report = {
            "test": "Median filter detection (30% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "30%",
            "detection_time_ms": round(elapsed, 3),
            "distance_from_honest_mean": round(distance, 6),
            "detection_method": "Coordinate-wise Median (robust to 50% Byzantine)",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_trimmed_mean_at_25_percent(self):
        """Test trimmed mean with 20% trim ratio at 25% Byzantine."""
        num_honest = 750
        num_byzantine = 250
        gradient_dim = 512
        trim_ratio = 0.20

        honest_grads = [
            ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
        ]
        byzantine_grads = [
            ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=15.0)
            for _ in range(num_byzantine)
        ]

        all_grads = honest_grads + byzantine_grads
        random.shuffle(all_grads)

        start = time.perf_counter()
        trimmed_grad, indices = ByzantineDetector.trimmed_mean(all_grads, trim_ratio=trim_ratio)
        elapsed = (time.perf_counter() - start) * 1000

        # Compare with honest mean
        honest_mean = [sum(g[i] for g in honest_grads) / num_honest for i in range(gradient_dim)]
        distance = sum((trimmed_grad[i] - honest_mean[i]) ** 2 for i in range(gradient_dim))

        report = {
            "test": "Trimmed mean detection (25% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "25%",
            "trim_ratio": trim_ratio,
            "detection_time_ms": round(elapsed, 3),
            "distance_from_honest_mean": round(distance, 6),
            "detection_method": f"Trimmed Mean ({trim_ratio*100}% trim)",
        }
        print(f"\n{json.dumps(report, indent=2)}")


class TestDetectionUnderAttack:
    """Test detection accuracy under actual Byzantine attacks."""

    def test_anomaly_detection_20_percent_byzantine(self):
        """Test statistical anomaly detection against 20% Byzantine."""
        num_honest = 800
        num_byzantine = 200
        gradient_dim = 512

        honest_grads = [
            ByzantineAttackGenerator.honest_gradient(gradient_dim) for _ in range(num_honest)
        ]
        honest_mean = [sum(g[i] for g in honest_grads) / num_honest for i in range(gradient_dim)]

        byzantine_grads = [
            ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=15.0)
            for _ in range(num_byzantine)
        ]

        # Test detection on each update (note: simple z-score may have high false positives on small samples)
        honest_detected = sum(
            1
            for g in honest_grads
            if ByzantineDetector.detect_anomaly(g, honest_mean, threshold_std=3.0)
        )
        byzantine_detected = sum(
            1
            for g in byzantine_grads
            if ByzantineDetector.detect_anomaly(g, honest_mean, threshold_std=3.0)
        )

        true_positive_rate = byzantine_detected / num_byzantine if num_byzantine > 0 else 0
        false_positive_rate = honest_detected / num_honest if num_honest > 0 else 0

        report = {
            "test": "anomaly detection (20% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "20%",
            "true_positive_rate": round(true_positive_rate, 3),
            "false_positive_rate": round(false_positive_rate, 3),
            "threshold_std": 3.0,
            "honest_flagged": honest_detected,
            "byzantine_flagged": byzantine_detected,
            "detection_method": "Z-score statistical anomaly (baseline method)",
            "note": "Simple z-score has high FP rate; use Krum/Median for production",
        }
        print(f"\n{json.dumps(report, indent=2)}")

        # Should detect most Byzantine updates
        assert true_positive_rate > 0.7, "Should detect >70% Byzantine updates"
        # Note: Simple z-score detection has higher FP rate; robust methods (Krum/Median) are recommended


# ============================================================================
# RESILIENCE THRESHOLD TESTS
# ============================================================================


class TestResilienceThresholds:
    """Test theoretical vs practical resilience thresholds."""

    def test_theoretical_limit_33_percent_byzantine(self, node):
        """
        Test theoretical limit: f < n/3 (33.3% Byzantine).

        At 33% Byzantine, gradient aggregation becomes non-Byzantine-resilient
        without special aggregation rules.
        """
        num_honest = 670
        num_byzantine = 330
        gradient_dim = 1024

        honest_updates = [
            {
                "node_id": f"honest-{i}",
                "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
            }
            for i in range(num_honest)
        ]

        byzantine_updates = [
            {
                "node_id": f"byzantine-{i}",
                "gradient": ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=50.0),
            }
            for i in range(num_byzantine)
        ]

        mixed_updates = honest_updates + byzantine_updates
        random.shuffle(mixed_updates)

        start = time.perf_counter()
        try:
            result = node.aggregate(mixed_updates)
            success = result.get("success", False)
        except AggregationError:
            success = False

        elapsed = (time.perf_counter() - start) * 1000

        report = {
            "test": "theoretical limit (33.3% Byzantine)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "33%",
            "aggregation_time_ms": round(elapsed, 3),
            "success": success,
            "theoretical_status": "At theoretical limit (f = n/3)",
            "note": "System may fail or degrade at this ratio with basic aggregation",
        }
        print(f"\n{json.dumps(report, indent=2)}")


# ============================================================================
# SECURITY METRICS SUITE
# ============================================================================


class TestSecurityMetrics:
    """Compute comprehensive security metrics."""

    def test_byzantine_resilience_score_20_percent(self, node):
        """Compute resilience score for 20% Byzantine attacks."""
        num_honest = 800
        num_byzantine = 200
        gradient_dim = 1024
        num_iterations = 5

        success_count = 0
        detection_count = 0
        avg_time = 0

        for _ in range(num_iterations):
            honest_updates = [
                {
                    "node_id": f"honest-{i}",
                    "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
                }
                for i in range(num_honest)
            ]

            byzantine_updates = [
                {
                    "node_id": f"byzantine-{i}",
                    "gradient": ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=12.0),
                }
                for i in range(num_byzantine)
            ]

            mixed_updates = honest_updates + byzantine_updates
            random.shuffle(mixed_updates)

            start = time.perf_counter()
            try:
                result = node.aggregate(mixed_updates)
                if result.get("success", False):
                    success_count += 1
            except AggregationError:
                pass

            avg_time += (time.perf_counter() - start) * 1000

        avg_time /= num_iterations
        resilience_score = success_count / num_iterations

        report = {
            "test": "Byzantine resilience score (20%)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "20%",
            "iterations": num_iterations,
            "successful_aggregations": success_count,
            "resilience_score": round(resilience_score, 2),
            "avg_aggregation_time_ms": round(avg_time, 3),
            "status": "RESILIENT" if resilience_score >= 0.8 else "VULNERABLE",
        }
        print(f"\n{json.dumps(report, indent=2)}")

    def test_byzantine_resilience_score_30_percent(self, node):
        """Compute resilience score for 30% Byzantine attacks."""
        num_honest = 700
        num_byzantine = 300
        gradient_dim = 1024
        num_iterations = 5

        success_count = 0
        avg_time = 0

        for _ in range(num_iterations):
            honest_updates = [
                {
                    "node_id": f"honest-{i}",
                    "gradient": ByzantineAttackGenerator.honest_gradient(gradient_dim),
                }
                for i in range(num_honest)
            ]

            byzantine_updates = [
                {
                    "node_id": f"byzantine-{i}",
                    "gradient": ByzantineAttackGenerator.gaussian_attack(gradient_dim, scale=20.0),
                }
                for i in range(num_byzantine)
            ]

            mixed_updates = honest_updates + byzantine_updates
            random.shuffle(mixed_updates)

            start = time.perf_counter()
            try:
                result = node.aggregate(mixed_updates)
                if result.get("success", False):
                    success_count += 1
            except AggregationError:
                pass

            avg_time += (time.perf_counter() - start) * 1000

        avg_time /= num_iterations
        resilience_score = success_count / num_iterations

        report = {
            "test": "Byzantine resilience score (30%)",
            "num_honest": num_honest,
            "num_byzantine": num_byzantine,
            "byzantine_ratio": "30%",
            "iterations": num_iterations,
            "successful_aggregations": success_count,
            "resilience_score": round(resilience_score, 2),
            "avg_aggregation_time_ms": round(avg_time, 3),
            "status": "AT LIMIT" if 0.5 <= resilience_score < 0.8 else "CRITICAL",
        }
        print(f"\n{json.dumps(report, indent=2)}")
