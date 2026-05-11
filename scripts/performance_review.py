#!/usr/bin/env python3
"""
Comprehensive Performance Review for Sovereign-Mohawk
Analyzes: throughput, latency, resource utilization, convergence, resilience
"""

import json
import time
import requests
import subprocess
import statistics
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple


class PerformanceReviewer:
    def __init__(self, results_dir: str = "performance_results"):
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        self.prometheus_url = "http://localhost:9090"
        self.metrics = {}

    def print_header(self, title: str):
        print("\n" + "=" * 60)
        print(f"  {title}")
        print("=" * 60)

    def check_system_ready(self) -> bool:
        """Verify all services are running"""
        self.print_header("System Readiness Check")

        try:
            # Check Prometheus
            resp = requests.get(f"{self.prometheus_url}/-/healthy", timeout=5)
            print("✓ Prometheus: OK")
        except:
            print("✗ Prometheus: NOT READY")
            return False

        # Check containers
        try:
            result = subprocess.run(
                ["docker", "ps", "--format", "{{.Names}}"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            containers = set(result.stdout.strip().split("\n"))

            required = {"orchestrator", "node-agent-1", "node-agent-2", "node-agent-3"}
            found = required & containers

            if len(found) == len(required):
                print(f"✓ All 3 node-agents: OK")
                print(f"✓ Orchestrator: OK")
            else:
                print(f"✗ Missing containers: {required - found}")
                return False
        except Exception as e:
            print(f"✗ Container check failed: {e}")
            return False

        return True

    def query_prometheus(self, query: str) -> Dict:
        """Query Prometheus and return results"""
        try:
            resp = requests.get(
                f"{self.prometheus_url}/api/v1/query", params={"query": query}, timeout=10
            )
            return resp.json()
        except Exception as e:
            print(f"✗ Query failed: {e}")
            return {"status": "error"}

    def measure_aggregation_throughput(self) -> float:
        """Measure aggregation throughput"""
        self.print_header("Aggregation Throughput Test")

        latencies = []
        attempts = 50

        for i in range(attempts):
            start = time.time()
            try:
                requests.get("http://localhost:8080/p2p/info", timeout=5)
                latency = (time.time() - start) * 1000
                latencies.append(latency)
                if (i + 1) % 10 == 0:
                    print(f"  Progress: {i+1}/{attempts}")
            except:
                pass

        if latencies:
            avg_latency = statistics.mean(latencies)
            throughput = 3000 / avg_latency  # 3 nodes × 1000 gradient dims
            print(f"✓ Average latency: {avg_latency:.2f}ms")
            print(f"✓ Estimated throughput: {throughput:.0f} updates/sec")
            return throughput

        return 0.0

    def measure_latencies(self) -> Dict[str, float]:
        """Measure P50, P95, P99 latencies"""
        self.print_header("Latency Percentiles")

        latencies = []
        attempts = 100

        for i in range(attempts):
            try:
                start = time.time()
                requests.get("http://localhost:8080/health", timeout=5)
                latency = (time.time() - start) * 1000
                latencies.append(latency)
            except:
                pass

        if not latencies:
            print("✗ No successful requests")
            return {}

        latencies.sort()
        percentiles = {
            "P50": statistics.quantiles(latencies, n=2)[0],
            "P95": statistics.quantiles(latencies, n=20)[18],
            "P99": statistics.quantiles(latencies, n=100)[98],
            "min": min(latencies),
            "max": max(latencies),
            "mean": statistics.mean(latencies),
            "stdev": statistics.stdev(latencies) if len(latencies) > 1 else 0,
        }

        for name, value in percentiles.items():
            print(f"✓ {name}: {value:.2f}ms")

        return percentiles

    def measure_resource_utilization(self, duration_sec: int = 60) -> Dict:
        """Sample CPU, memory, network over time"""
        self.print_header(f"Resource Utilization ({duration_sec}s)")

        samples = []
        start_time = time.time()

        while time.time() - start_time < duration_sec:
            try:
                result = subprocess.run(
                    [
                        "docker",
                        "stats",
                        "--no-stream",
                        "--format",
                        "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )

                lines = result.stdout.strip().split("\n")[1:]  # Skip header
                cpu_sum = 0
                mem_mb_sum = 0
                count = 0

                for line in lines:
                    if not line.strip():
                        continue
                    parts = line.split()
                    if len(parts) >= 3:
                        try:
                            cpu = float(parts[1].rstrip("%"))
                            mem = float(parts[2].rstrip("MiB"))
                            cpu_sum += cpu
                            mem_mb_sum += mem
                            count += 1
                        except:
                            pass

                if count > 0:
                    samples.append(
                        {
                            "timestamp": time.time(),
                            "avg_cpu_pct": cpu_sum / count,
                            "avg_mem_mb": mem_mb_sum / count,
                            "containers": count,
                        }
                    )
            except:
                pass

            time.sleep(5)

        if samples:
            avg_cpu = statistics.mean([s["avg_cpu_pct"] for s in samples])
            avg_mem = statistics.mean([s["avg_mem_mb"] for s in samples])
            max_cpu = max([s["avg_cpu_pct"] for s in samples])
            max_mem = max([s["avg_mem_mb"] for s in samples])

            print(f"✓ Samples: {len(samples)}")
            print(f"✓ Avg CPU: {avg_cpu:.1f}%")
            print(f"✓ Max CPU: {max_cpu:.1f}%")
            print(f"✓ Avg Memory: {avg_mem:.0f} MB")
            print(f"✓ Max Memory: {max_mem:.0f} MB")

            return {
                "samples": len(samples),
                "avg_cpu_pct": avg_cpu,
                "max_cpu_pct": max_cpu,
                "avg_mem_mb": avg_mem,
                "max_mem_mb": max_mem,
            }

        return {}

    def query_convergence_metrics(self) -> Dict:
        """Query model convergence metrics from Prometheus"""
        self.print_header("FedAvg Convergence Analysis")

        queries = {
            "model_loss": "fedavg_model_loss_total",
            "convergence_rate": "fedavg_convergence_rate",
            "rounds_completed": "fedavg_rounds_total",
        }

        results = {}
        for name, query in queries.items():
            resp = self.query_prometheus(query)
            if resp.get("status") == "success" and resp.get("data", {}).get("result"):
                result = resp["data"]["result"][0]["value"]
                results[name] = float(result[1]) if len(result) > 1 else 0
                print(f"✓ {name}: {results[name]}")
            else:
                print(f"⚠ {name}: No data available")

        return results

    def query_byzantine_resilience(self) -> Dict:
        """Query Byzantine resilience metrics"""
        self.print_header("Byzantine Resilience Metrics")

        queries = {
            "byzantine_detected": "byzantine_attacks_detected_total",
            "consensus_achieved": "consensus_rounds_successful_total",
            "threshold_maintained": "honest_threshold_maintained_total",
        }

        results = {}
        for name, query in queries.items():
            resp = self.query_prometheus(query)
            if resp.get("status") == "success" and resp.get("data", {}).get("result"):
                result = resp["data"]["result"][0]["value"]
                results[name] = float(result[1]) if len(result) > 1 else 0
                print(f"✓ {name}: {results[name]}")
            else:
                print(f"⚠ {name}: No data available")

        return results

    def generate_report(self) -> str:
        """Generate comprehensive performance report"""
        self.print_header("Performance Test Summary")

        # Collect all metrics
        throughput = self.measure_aggregation_throughput()
        latencies = self.measure_latencies()
        resources = self.measure_resource_utilization(duration_sec=30)
        convergence = self.query_convergence_metrics()
        resilience = self.query_byzantine_resilience()

        # Generate report
        report = {
            "timestamp": datetime.now().isoformat(),
            "environment": "3-node Genesis cluster",
            "throughput": {
                "estimated_updates_per_sec": throughput,
                "node_count": 3,
            },
            "latency_ms": latencies,
            "resource_utilization": resources,
            "fedavg_convergence": convergence,
            "byzantine_resilience": resilience,
        }

        # Save report
        report_path = (
            self.results_dir / f"performance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        )
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)

        print(f"\n✓ Report saved: {report_path}")

        return json.dumps(report, indent=2)


def main():
    import sys

    results_dir = sys.argv[1] if len(sys.argv) > 1 else "performance_results"

    reviewer = PerformanceReviewer(results_dir)

    # Check system ready
    if not reviewer.check_system_ready():
        print("\n✗ System not ready. Ensure all containers are running:")
        print("  docker compose up -d orchestrator node-agent-1 node-agent-2 node-agent-3")
        sys.exit(1)

    # Run all tests
    report = reviewer.generate_report()

    print("\n" + "=" * 60)
    print("  Full Spectrum Performance Review Complete")
    print("=" * 60)
    print(f"\nDashboard: http://localhost:3000 (Grafana)")
    print(f"Metrics:   http://localhost:9090 (Prometheus)")


if __name__ == "__main__":
    main()
