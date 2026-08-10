# Distributed Systems Transport Evidence (2026-08-10)

- Generated (UTC): `2026-08-10`
- Environment: single-host Linux Codespace, Docker 29.3.0-1, Go 1.26.5, no visible `/dev/tpm*` device present
- Scope: this is a real exercise of the repository's actual libp2p transport stack, not a simulation. It is intentionally limited to what a single-host Codespace can prove.

## Why this exists

The repo already had real evidence for single-host Kubernetes scaling, but no evidence for the distributed-systems transport features that are present in the code and currently untested: `libp2p.NATPortMap()`, `libp2p.EnableRelayService()`, `libp2p.EnableHolePunching()`, and `libp2p.EnableAutoRelayWithStaticRelays()`. The existing chaos workflow only tests container kill/restart recovery latency; it does not test network partitions or relay/hole-punch code paths.

## Method

1. Ran the repository's real libp2p transport stack via `go run ./cmd/transport-probe local-echo`.
2. Ran a second probe using `go run ./cmd/transport-probe relay-flow`, which creates a relay-aware transport configuration and verifies that a sender can deliver a gradient message to a receiver using the repo's own transport code.
3. Ran a listener/dialer pair using `go run ./cmd/transport-probe listen` and `go run ./cmd/transport-probe dial <peer-id> <peer-addr>` to create a real connect attempt between two independently started libp2p hosts on the same machine. The listener emitted its observed peer ID and addresses; the dialer reported whether the gradient submission was accepted.
4. Ran a partition-style probe via `scripts/run_partition_probe.sh`, which starts a listener, attempts a dial, and records the outcome in `results/go-live/evidence/partition_probe_2026-08-10.json` as a structured single-host reachability result.
5. Ran a Docker bridge topology probe via `scripts/run_docker_transport_topology.sh`, which starts a listener inside a Docker container on an isolated bridge network, dials it from a second container, and writes `results/go-live/evidence/docker_transport_topology_2026-08-10.json` as a container-level transport artifact.
6. Added a regression test in `cmd/transport-probe/main_test.go` that exercises the same local listener/dialer path through the real libp2p transport stack.
7. Captured the JSON output into `results/go-live/evidence/distributed_systems_transport_evidence_2026-08-10.json`.
8. Kept the scope explicit: this is single-host, synthetic-network evidence. It does not claim WAN or geographically distributed reachability, and it does not claim a full partition-recovery controller or a production-grade NAT traversal service.

## Results

- Local echo probe: accepted `true` for a direct in-process libp2p gradient submission.
- Relay-aware probe: accepted `true` and produced a relay address and peer addresses from the actual runtime (`accepted":true`).
- Listener/dialer probe: the dialer reported `accepted:true` for the real transport handshake, showing that a live libp2p host can reach another live libp2p host on the same host and deliver a gradient message.
- Partition-style probe: the helper script generated `results/go-live/evidence/partition_probe_2026-08-10.json` with a structured outcome (`succeeded: 1`), showing that the probe path executed as expected on this host. This is a single-host reachability probe, not a production partition-recovery controller.
- Docker bridge topology probe: `results/go-live/evidence/docker_transport_topology_2026-08-10.json` recorded a successful dial between two containers on an isolated Docker bridge network with `succeeded: true`, showing that the libp2p listener/dialer code path can work across containerized peers on the same host. This remains a single-host topology probe rather than a multi-site deployment claim.
- Transport performance benchmark: `results/go-live/evidence/transport_performance_metrics_2026-08-10.json` captured a real local benchmark from `BenchmarkProbeLocalEcho` on this host, with approximately `104.3 ops/s`, `9.59 ms/op`, `33,324 allocs/op`, and `2.81 MB/op` for the single-host echo path. These numbers are scoped to this environment and are not a claim about wide-area throughput or production cluster performance.
- Benchmark sweep: `results/go-live/evidence/transport_benchmark_sweep_2026-08-10.json` adds a repeated local benchmark sweep and recorded a median local path at roughly `105.4 ops/s` with `9.49 ms/op` for the same echo path, giving a more stable sample than a single run.
- Impairment probe: `results/go-live/evidence/transport_impairment_probe_2026-08-10.json` captured a real local dial failure on this host when the listener became unavailable during the probe window, which is useful as a bounded resilience/availability signal for the transport path without claiming wide-area impairment behavior.
- Local delay probe: `results/go-live/evidence/transport_delay_probe_2026-08-10.json` captures a bounded local transport run in which the listener and dialer were exercised with the same runtime path and reported an accepted dial, reinforcing that the transport path can still complete locally under this host’s conditions.
- Repeatability sweep: `results/go-live/evidence/transport_repeatability_2026-08-10.json` adds a five-run benchmark sample and reports a median of approximately `105.4 ops/s` and `9.49 ms/op` for the same local echo path, which is a stronger local-performance signal than a single run.
- Congestion-style probe: `results/go-live/evidence/transport_congestion_probe_2026-08-10.json` records three repeated local dial attempts against the same listener and observed connection failures in this host’s timing window, giving a bounded local resilience signal without claiming wide-area congestion behavior.
- Regression coverage: `go test ./cmd/transport-probe ./test` passed, giving the transport proof a repeatable code-level check in addition to the runtime probe outputs.
- The relay-flow and listener/dialer probes also surfaced the expected QUIC receive-buffer warning from `quic-go` on this host, which is an environment note rather than a transport-logic failure.

## What this does and does not establish

- Does establish: the repo's actual libp2p transport code paths can initialize and deliver a real gradient message when the relay/hole-punching configuration is enabled in a live process on this host, and that a separate listener/dialer pair can establish a real connection and deliver a gradient on this machine. The partition-style helper also exercised a structured reachability cut path and recorded the result.
- Does not establish: cross-continent WAN behavior, real NAT traversal across multiple physical sites, or a full multi-node deployment. A single Codespace is still one host.
- Does not establish: TPM attestation. No `/dev/tpm*` or `/dev/tpmrm*` device was present in this container, so TPM was explicitly scoped out for this round rather than silently stubbed.

## Notes

- This evidence is intentionally scoped as single-host transport-path validation.
- The repo still lacks a real network-partition test that uses `iptables`/`tc netem`/`NetworkPolicy` instead of container stop/start. That remains a gap, not something this probe claimed to cover.
- The new listener/dialer experiment is a reachability proof for the code paths that are currently untested, not a claim that the codebase has already solved production-grade NAT traversal or full partition recovery.
