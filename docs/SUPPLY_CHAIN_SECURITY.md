# Supply Chain Security & Verifiable Build Attestations

## Overview

As part of our journey to "excellent" / auditable GA level, Sovereign Mohawk Protocol now includes comprehensive supply chain security with SLSA provenance, cosign/Sigstore keyless signing, and in-toto supply chain metadata.

## What's New

### 1. SLSA Build Type 1 Provenance (`slsa-provenance-and-signing.yml`)

**SLSA (Supply Chain Levels for Software Artifacts)** provides industry-standard build provenance for all release artifacts.

#### Features:
- **Automated provenance generation** on every tagged release
- **Container image attestations** with SBOM (Software Bill of Materials)
- **Binary provenance** documenting compilation context and dependencies
- **Verifiable build metadata** including timestamps, commit SHAs, and builder identity

#### Included Artifacts:
```
slsa-provenance.json         # SLSA v1.0 provenance statement
SHA256SUMS                   # Checksums for all binaries
SHA256SUMS.cosign.sig        # Cosign signature on checksums
node-agent-*.cosign.sig      # Individual signatures for each binary
*.cosign.crt                 # Signing certificates
```

### 2. Sigstore Keyless Signing with Cosign

**Keyless signing** leverages GitHub's OIDC token to sign artifacts without managing long-lived keys.

#### Container Image Signing:
```bash
# Image is automatically signed during build
cosign verify --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto:v2.0.2
```

#### Binary Signing:
```bash
# Verify binary checksums
cosign verify-blob --signature SHA256SUMS.cosign.sig \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  SHA256SUMS
```

#### Why Keyless Signing?
- **No key management overhead** - Uses your GitHub identity
- **Automatic rotation** - New signing identity per workflow run
- **Transparent to users** - Certificate is automatically fetched from Sigstore
- **Standards-compliant** - Follows OpenID Connect standard

### 3. In-Toto Supply Chain Metadata (`in-toto-supply-chain.yml`)

**In-Toto** records and signs a chain of steps representing the entire supply chain from source to release.

#### Link Metadata Files:
- **layout.json** - Supply chain definition and policy
- **material.link** - Source code materials recording
- **build.link** - Build step with artifact hashes
- **verification.link** - Test and verification results

#### Supply Chain Steps:
```
Source Code → Material Recording
    ↓
Materials → Build Step
    ↓
Binaries → Verification Step
    ↓
Test Results → Release Publishing
```

### 4. What Actually Gates the Attestation

The `verification-step` job in `in-toto-supply-chain.yml` runs the Go test
suite, the Python SDK test suite, and `govulncheck`, and **must pass** for
the release to proceed — `generate-link-metadata` and
`publish-in-toto-attestations` both depend on this job via `needs:`, so a
real failure here blocks publication. (Previously each of these commands
was piped through `|| true`, which meant the job always reported success
regardless of whether tests or the vulnerability scan actually passed —
this has been fixed.)

#### Actually checked before an attestation is published:
- ✅ Go test suite (`go test ./...`)
- ✅ Python SDK test suite (`pytest sdk/python/tests/`)
- ✅ Go vulnerability scan (`govulncheck ./...`)

#### Not re-checked at tag time:
- **Lean theorem proofs** — enforced as a separate, required CI gate
  (`.github/workflows/verify-formal-proofs.yml`) on every change that
  touches proof files, before merge to `main`. This job has no
  Lean/Mathlib toolchain installed and does not re-run the proof suite;
  rebuilding it (8000+ jobs) on every tagged release would add hours to
  the release pipeline without checking anything new. See
  [proofs/FORMAL_TRACEABILITY_MATRIX.md](../proofs/FORMAL_TRACEABILITY_MATRIX.md)
  for the honest per-theorem scope of what's actually proven.
- **"Zero-knowledge proof validation"** — there is no ZK-SNARK verifier in
  this repo; `internal/proofs/verifier.go` does real signature/hash
  verification, not zero-knowledge proof verification. See
  [proofs/FORMAL_TRACEABILITY_MATRIX.md](../proofs/FORMAL_TRACEABILITY_MATRIX.md).

## Verification Instructions

### Verify Container Image

```bash
# Install cosign
curl -sSL https://github.com/sigstore/cosign/releases/download/v2.2.0/cosign-linux-amd64 \
  -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign

# Verify image signature
cosign verify --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto:v2.0.2
```

### Verify Release Artifacts

```bash
# Download release assets
cd ~/tmp && wget https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v2.0.2/{node-agent-*,*.whl,SHA256SUMS*}

# Verify checksums
sha256sum -c SHA256SUMS

# Verify checksum signature
cosign verify-blob --signature SHA256SUMS.cosign.sig \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  SHA256SUMS

# Verify individual binary signatures
cosign verify-blob --signature node-agent-linux-amd64.cosign.sig \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  node-agent-linux-amd64
```

### Inspect Provenance

```bash
# Download SLSA provenance
wget https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v2.0.2/slsa-provenance.json

# Inspect provenance statement
jq . slsa-provenance.json

# Verify with slsa-verifier (optional)
slsa-verifier verify-artifact slsa-provenance.json
```

### Inspect In-Toto Metadata

```bash
# Download in-toto artifacts
wget https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v2.0.2/{layout.json,*.link}

# Inspect supply chain definition
jq . layout.json

# Inspect individual steps
jq . material.link
jq . build.link
jq . verification.link

# Verify chain integrity (requires in-toto Python tools)
pip install in-toto-py
in-toto-verify --layout layout.json --link-dir . --step material
```

## Implementation Architecture

### Workflow Triggerss
- **Automatic**: Every tag matching `v*` pattern
- **Manual**: Via `workflow_dispatch` with optional dry-run mode

### Artifact Signing Flow
```
1. Code Checkout
   ↓
2. Build Artifacts
   ├─ Compile Go binaries (multi-platform)
   ├─ Build Python SDK wheel
   └─ Generate Docker images
   ↓
3. Generate Hashes
   ├─ SHA256SUMS
   └─ SHA512SUMS
   ↓
4. Sign with Cosign
   ├─ Individual binary signatures
   ├─ Checksum file signature
   └─ Container image signature
   ↓
5. Generate Provenance
   ├─ SLSA v1.0 statement
   └─ Container attestations
   ↓
6. Create In-Toto Chain
   ├─ Layout definition
   ├─ Material link
   ├─ Build link
   └─ Verification link
   ↓
7. Publish Release
   └─ All artifacts + signatures + attestations
```

## Security Properties

### Keyless Signing Benefits
- **No credential management**: Uses GitHub Actions OIDC token
- **Non-repudiation**: Signers cannot deny their signature
- **Transparent CA**: Uses public Sigstore instance
- **Automatic certificate lifecycle**: New cert per build

### SLSA Provenance Properties
- **Build environment transparency**: GitHub Actions runner details
- **Source material traceability**: Git commit hash included
- **Dependency transparency**: All resolved dependencies recorded
- **Immutable attestation**: Cryptographically signed

### In-Toto Chain Properties
- **Complete supply chain visibility**: Every step documented
- **Step-to-step verification**: Can verify at each stage
- **Material and product tracking**: Input/output hashes for each step
- **Policy enforcement**: Can reject non-conforming artifacts

## Auditor Verification Checklist

- [ ] All container images signed with Sigstore keyless
- [ ] All release binaries have individual cosign signatures
- [ ] SHA256SUMS file signed and verified
- [ ] SLSA provenance v1.0 present in release
- [ ] In-toto layout and link metadata present
- [ ] Go and Python test suites passed (gates attestation publish; formal
      proofs are gated separately, pre-merge, by `verify-formal-proofs.yml`)
- [ ] No security vulnerabilities in govulncheck scan
- [ ] Image digests match manifest references

## Future Enhancements

### Phase 2 (Planned)
- [ ] SLSA Build Type 3 with trusted builder
- [ ] Binary transparency log integration (Sigsum)
- [ ] Timestamp authority integration (RFC 3161)
- [ ] Automated compliance reporting

### Phase 3 (Planned)
- [ ] Build Policy as Code (CUE/OPA)
- [ ] Supply chain risk scoring
- [ ] Dependency vulnerability dashboard
- [ ] Formal verification dashboard

## References

- [SLSA Framework](https://slsa.dev/)
- [Sigstore & Cosign](https://www.sigstore.dev/)
- [in-toto Framework](https://in-toto.io/)
- [OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## Contributing Supply Chain Improvements

See [Contributing](../CONTRIBUTING.md) for how to contribute to supply chain security enhancements.
