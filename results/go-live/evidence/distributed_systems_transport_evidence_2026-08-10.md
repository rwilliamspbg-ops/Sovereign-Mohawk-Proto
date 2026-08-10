# Distributed Systems Transport Evidence (2026-08-10)

- Generated (UTC): `2026-08-10`
- Original environment: single-host Linux Codespace, Docker 29.3.0-1, Go 1.26.5, no visible `/dev/tpm*` device present
- Independently re-verified (2026-08-10, same day, PR review pass): single-host Windows 11 (`Windows-11-10.0.26200-SP0`), Go 1.26.5. See "Cross-platform re-verification" below — this second pass found and fixed real portability bugs, regenerated every previously-uncommitted artifact for real, and surfaced one genuine new platform-specific finding.
- Scope: this is a real exercise of the repository's actual libp2p transport stack, not a simulation. It is intentionally limited to what a single host can prove.

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

The four tests below are from the original Codespace run and are captured verbatim in `results/go-live/evidence/distributed_systems_transport_evidence_2026-08-10.json`, left unchanged by the re-verification pass:

- Local echo probe: accepted `true` for a direct in-process libp2p gradient submission.
- Relay-aware probe: accepted `true` and produced a relay address and peer addresses from the actual runtime (`accepted":true`).
- Listener/dialer probe: the dialer reported `accepted:true` for the real transport handshake, showing that a live libp2p host can reach another live libp2p host on the same host and deliver a gradient message.

The remaining items below were re-run for real on the Windows re-verification pass (see "Cross-platform re-verification"); numbers reflect that host, not the original Codespace, and are cited from the actual committed JSON rather than restated from memory:

- Partition-style probe: `results/go-live/evidence/partition_probe_2026-08-10.json` — `succeeded: 1` (after fixing a real path-mangling bug in `scripts/run_partition_probe.sh`; see below).
- Docker bridge topology probe: `results/go-live/evidence/docker_transport_topology_2026-08-10.json` — the committed run **failed** (`succeeded: false`, `i/o timeout` dialing the container's bridge address). This was **flaky across repeated attempts on this host**: across several consecutive re-runs, results alternated between `connection refused`, `i/o timeout`, and one clean success — the artifact committed here happens to be a failing run, not a cherry-picked success, so the raw result is reported as-is rather than substituted with a later successful attempt. This is likely specific to Docker Desktop's virtualized network backend on Windows (a plausible sibling finding to the disk-I/O ceiling documented in `k8s_scale_deployment_test_2026-08-10.md`), not a claim about the transport code's correctness, which the in-process tests above already establish.
- Transport performance benchmark: `results/go-live/evidence/transport_performance_metrics_2026-08-10.json` — `29.4 ops/s`, `34.0 ms/op`, `36,124 allocs/op`, `3.67 MB/op` for `BenchmarkProbeLocalEcho` on Windows. (The original Codespace run did not commit a comparable timed benchmark artifact, so no Windows-vs-Codespace speed comparison is claimed here — only the Windows-host number itself, which is real and reproducible on this host.)
- Benchmark sweep: `results/go-live/evidence/transport_benchmark_sweep_2026-08-10.json` — a single sweep run at `28.4 ops/s`, `35.3 ms/op`.
- Repeatability sweep: `results/go-live/evidence/transport_repeatability_2026-08-10.json` — five runs, median `29.8 ops/s` / `33.6 ms/op`, range `28.2-30.0 ops/s`.
- Local delay probe: `results/go-live/evidence/transport_delay_probe_2026-08-10.json` — `accepted: true` (after fixing the same path-mangling bug class as the partition probe).
- Impairment probe: `results/go-live/evidence/transport_impairment_probe_2026-08-10.json` — dial failed (`accepted: false`, `connectex: ... actively refused`). See "Genuine new finding" below — this is not the path-mangling bug that affected the partition/delay probes.
- Congestion-style probe: `results/go-live/evidence/transport_congestion_probe_2026-08-10.json` — all 3 of 3 repeated dial attempts failed the same way as the impairment probe.
- Regression coverage: `go test ./cmd/transport-probe ./test` passed on both the original Codespace and the Windows re-verification host, giving the transport proof a repeatable code-level check independent of either host's runtime probe results.
- The relay-flow and listener/dialer probes also surfaced the expected QUIC receive-buffer warning from `quic-go` on the original Codespace host, which is an environment note rather than a transport-logic failure; this warning does not reproduce on Windows since QUIC UDP buffer sizing is a Linux-specific `sysctl` concern.

## Cross-platform re-verification (2026-08-10, PR review pass)

The original PR referenced 8 evidence files above that were never actually committed — only `distributed_systems_transport_evidence_2026-08-10.json` (the 4 in-process tests) existed in the repository, so every link to the other 8 broke CI's `markdown-link-check`. Rather than just delete the broken links, this pass re-ran every collection script for real on an independent host (Windows, not the original Linux Codespace) and committed genuine artifacts, which also surfaced real bugs in the collection scripts themselves:

- **Portability bug**: `scripts/collect_transport_congestion_probe.sh`, `scripts/collect_transport_repeatability.sh`, and `scripts/collect_transport_sprint_evidence.sh` (2 call sites) hardcoded `/workspaces/Sovereign-Mohawk-Proto` as the repo root instead of using the already-computed `$ROOT_DIR`, so they only ever worked inside that exact Codespace. Fixed to accept the root path as an argument.
- **Environment-detection bug**: all 6 `collect_*.sh` scripts and `collect_distributed_systems_evidence.sh` hardcoded `"os": "Ubuntu 24.04.4 LTS"` (and, in the latter, `"docker": "29.3.0-1"` and `"tpm_devices": []`) into their JSON output instead of detecting it, so the environment field would have been silently wrong on any host other than the original Codespace. Fixed to use Python's `platform.platform()` (or real `uname -a`/`docker --version`/`go version`/`/dev/tpm*` glob detection in the bash-heredoc case) instead.
- **Windows/Git-Bash path-mangling bug** (the actual root cause of the partition-probe and delay-probe failures on the first re-verification attempt): `scripts/run_partition_probe.sh`, `scripts/collect_transport_delay_probe.sh`, `scripts/collect_distributed_systems_evidence.sh`, and `scripts/run_docker_transport_topology.sh` all pass a raw libp2p multiaddr string (e.g. `/ip4/10.0.0.87/tcp/53985`) as a bare command-line argument to `go run`/`python3`/`docker run`. Git Bash's MSYS layer auto-converts any bare argument starting with `/` as if it were a Unix path needing translation to a Windows path, corrupting the address before the receiving program ever sees it (observed corrupted form: `C:/Program Files/Git/ip4/...`). Fixed with scoped `MSYS2_ARG_CONV_EXCL="/ip4"` (preferred — excludes only the multiaddr-shaped arguments, leaving real file-path arguments converted normally) or scoped `MSYS_NO_PATHCONV=1` (for the Docker bind-mount case, where the corrupted argument was a `-w` flag, not a multiaddr) on exactly the affected command, never exported for the whole script. This class of bug does not exist on Linux/the original Codespace; it is a Windows-only Git Bash compatibility fix.
- **Genuine new finding (not a bug in this repo)**: after all of the above fixes, `scripts/collect_transport_congestion_probe.sh` and the impairment-probe half of `scripts/collect_transport_sprint_evidence.sh` still fail 100% of dial attempts (4/4 across both) on this Windows host with `connectex: ... actively refused`, while `scripts/run_partition_probe.sh` and `scripts/collect_transport_delay_probe.sh` succeed reliably (2/2) once their path-mangling bug is fixed. The distinguishing factor is not Windows itself — both pairs run on the same host — but *how the listener process is managed*: the failing pair starts the listener via Python's `subprocess.Popen` and reads its stdout with `.read()`; the succeeding pair starts it as a bash background job (`&`) and reads its log file directly. The exact mechanism was not isolated within this review's scope (a plausible candidate is Windows Firewall treating each `go run`-compiled ephemeral binary as an unrecognized program, but this was not confirmed via firewall logs). This is reported as an honest, reproducible, Windows-specific methodology finding, not resolved further here.

## What this does and does not establish

- Does establish: the repo's actual libp2p transport code paths can initialize and deliver a real gradient message when the relay/hole-punching configuration is enabled in a live process, and that a separate listener/dialer pair can establish a real connection and deliver a gradient — reproduced independently on two different hosts (Linux Codespace, Windows). The partition-style and Docker-topology helpers also exercised structured reachability-cut and container-to-container paths and recorded real results, including real failures where they occurred.
- Does not establish: cross-continent WAN behavior, real NAT traversal across multiple physical sites, or a full multi-node deployment. A single host is still one host, regardless of which OS.
- Does not establish: TPM attestation. No `/dev/tpm*` or `/dev/tpmrm*` device was present on either the original Codespace or the Windows re-verification host, so TPM was explicitly scoped out for this round rather than silently stubbed.
- Does not establish: that the Python-`subprocess.Popen`-managed listener pattern (congestion/impairment probes) is reliable on Windows — it consistently failed there. Does not claim this reflects a defect in the transport code itself, since the same underlying `network.NewHost`/`SendGradientWithKEX` calls succeed reliably via every other invocation pattern tested on the same host.

## Notes

- This evidence is intentionally scoped as single-host transport-path validation.
- The repo still lacks a real network-partition test that uses `iptables`/`tc netem`/`NetworkPolicy` instead of container stop/start. That remains a gap, not something this probe claimed to cover.
- The new listener/dialer experiment is a reachability proof for the code paths that are currently untested, not a claim that the codebase has already solved production-grade NAT traversal or full partition recovery.
