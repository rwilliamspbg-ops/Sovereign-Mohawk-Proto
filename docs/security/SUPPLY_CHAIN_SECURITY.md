# Supply Chain Security — Sovereign Mohawk

**Status**: Real content as of 2026-11-04; verified against commit `9d9181a22`.

## 1. Scope

Covers artifact integrity, container image signing, SLSA provenance, in-toto
metadata, and dependency hygiene for releases of the Sovereign Mohawk runtime.

## 2. Mechanisms in place

- **Checksums**: `SHA256SUMS` published per release.
- **Image signing**: cosign (Sigstore) keyless signing of container images.
- **SLSA provenance**: v1.0 attestation generated in CI
  (`security-supply-chain.yml`, `in-toto-supply-chain.yml`).
- **in-toto**: layout with material / build / verification steps.
- **Dependency scanning**: `govulncheck`, `trivy-fs`, `dependency-review`,
  Dependabot.
- **Secret scanning**: GitHub secret scanning + push protection.
- **CodeQL**: `codeql-analysis.yml` (Go + Python).
- **Action pinning**: `workflow-action-pin-check.yml` enforces pinned actions.

## 3. Verification procedure

Full step-by-step verification is in
`docs/AUDITOR_QUICK_REFERENCE.md` (Phases 1-5). Summary:

```bash
# Checksums
sha256sum -c SHA256SUMS

# Container image
cosign verify --certificate-identity 'https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/.github/workflows/<release-workflow>.yml@refs/tags/<version>' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto:<version>

# SLSA provenance
jq '.version' slsa-provenance.json   # expect "1.0"

# Automated
./scripts/...  # see AUDITOR_QUICK_REFERENCE.md automated script
```

## 4. Dependency hygiene

- `go.mod` / `go.sum` pinned; `go mod verify` in CI.
- Python SDK: `sdk/python/` with its own lockfile.
- Helm charts: `deploy/helm/`.
- Update cadence: Dependabot PRs reviewed before merge; security advisories
  trigger `security-scanning.yml`.

## 5. Open items

- Automated cert rotation schedule is documented but not yet wired to CI
  (see `INCIDENT_RESPONSE.md` 4.4).
- SLSA level target: currently Level 2 (provenance); Level 3 (hardened build)
  is a roadmap item.

## 6. Cross-references

- Auditor quick reference: `docs/AUDITOR_QUICK_REFERENCE.md`
- Incident response: `docs/security/INCIDENT_RESPONSE.md`
- Threat model: `docs/security/THREAT_MODEL.md`
- Root security policy: `SECURITY.md`
