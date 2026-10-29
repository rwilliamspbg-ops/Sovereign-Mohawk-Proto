# Outdated Information Audit (main branch)

## Go toolchain version mismatch

- `go.mod` declares: `go 1.27.3`
- Installed toolchain: `go version go1.27.3 windows/amd64`
- README.md:434 says "Go 1.25.9+"
- CONTRIBUTING.md:103 says "requires Go `1.25.9` from go.mod" (contradicts go.mod)
- DEPENDENCIES.md:49 lists "Go 1.25.9"
- docs/FORMAL_VERIFICATION_GUIDE.md references `go 1.25.9`
- docker/formal-verifier/Dockerfile uses `GO_VERSION=1.25.9`
- DOWNLOAD_GO.bat / INSTALL_DEPENDENCIES.bat / QUICK_START.bat reference 1.25.9 downloads

Recommendation: align either go.mod to 1.25.9 (if 1.27.3 is non-standard) or update docs/scripts to 1.27.3. Installed toolchain supports 1.27.3.

## Python SDK version

- VERSION: 2.1.0
- sdk/python mohawk __version__: 2.1.0
- check_version_sync: OK

## Other

- README benchmark TOOLROOT paths reference go1.25.9 toolchain; should match go.mod.

## Formal claims audit (2026-10-29)

Traceability matrix reviewed. Statuses:
- Row 1 BFT: fully_formalized (single-tier); hierarchical compositional claim disproven deterministically; probabilistic repair (Chernoff) closed at deployment scale.
- Row 2 RDP: surrogate_verified_with_gaussian_axiom; core composition closed (independent + adaptive); (ε,δ) conversion remains roadmap.
- Row 3 Communication: fully_formalized.
- Row 4 Liveness: model_verified.
- Row 5 Crypto: model_verified.
- Row 10 Chernoff: Phase 3b model.
- Row 11 Convergence: Surrogate verified.
- Rows 12-15: empirically_verified / model-level.
- Phase 4 PQC: structural + witnessed-hardness.

Grant-relevant caveat: several headline claims (hierarchical BFT resilience, convergence, liveness) are model/surrogate-verified or disproven at composition level; README/badges should not imply full formal proof. Recommend TRL framing and explicit "not proven" notes in proposal.
