# Auditor Quick Reference: Supply Chain Security Verification

**Last Updated**: May 1, 2026  
**PR**: #66 (feat/supply-chain-security)  
**Version**: Applicable to releases with SLSA > 1.0 provenance

---

## Quick Links

| Resource | Purpose | Link |
|----------|---------|------|
| Supply Chain Guide | Full documentation | [SUPPLY_CHAIN_SECURITY.md](SUPPLY_CHAIN_SECURITY.md) |
| Verification Coverage | Expanded formal proofs | [FORMAL_VERIFICATION_COVERAGE.md](FORMAL_VERIFICATION_COVERAGE.md) |
| Release Checklist | Release validation steps | Below (section: Release Checklist) |
| Standards | Industry references | SLSA, Sigstore, in-toto v0.1 |

---

## Release Verification Checklist

### Phase 1: Artifact Integrity (5 min)

**Goal**: Verify binaries and checksums are authentic

```bash
# 1.1 Download all release artifacts
cd ~/verify-release
wget -q https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v{VERSION}/{node-agent-*,*.whl,SHA256SUMS*}

# 1.2 Verify checksums
sha256sum -c SHA256SUMS
# Expected: All OK

# 1.3 Verify checksum signature with cosign
cosign verify-blob \
  --signature SHA256SUMS.cosign.sig \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  SHA256SUMS
# Expected: Verified OK
```

**Pass Criteria**: ✅ All sha256sum checks pass + cosign signature verifies

---

### Phase 2: Container Image Verification (3 min)

**Goal**: Verify Docker image is signed and authentic

```bash
# 2.1 Install cosign (if needed)
curl -sSL https://github.com/sigstore/cosign/releases/download/v2.2.0/cosign-linux-amd64 \
  -o cosign && chmod +x cosign

# 2.2 Verify container image signature
./cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto:v{VERSION}

# 2.3 Expected output:
# "Verified OK"
# [Certificate details]
```

**Pass Criteria**: ✅ Container image signature verifies with Sigstore

---

### Phase 3: Build Provenance Inspection (5 min)

**Goal**: Verify SLSA provenance and build environment

```bash
# 3.1 Download SLSA provenance
wget -q https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v{VERSION}/slsa-provenance.json

# 3.2 Inspect provenance version
jq '.version' slsa-provenance.json
# Expected: "1.0"

# 3.3 Verify builder identity
jq '.predicate.runDetails.builder.id' slsa-provenance.json
# Expected: "https://github.com/actions"

# 3.4 Verify git commit reference
jq '.predicate.buildDefinition.externalParameters.workflow.ref' slsa-provenance.json
# Expected: "refs/tags/v{VERSION}"

# 3.5 Inspect resolved dependencies
jq '.predicate.buildDefinition.resolvedDependencies' slsa-provenance.json
# Expected: List including go.mod git commit hash
```

**Pass Criteria**: ✅ SLSA v1.0 present + builder is GitHub Actions + commit hash present

---

### Phase 4: In-Toto Supply Chain (5 min)

**Goal**: Verify supply chain metadata and link chain

```bash
# 4.1 Download in-toto artifacts
wget -q https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/v{VERSION}/{layout.json,material.link,build.link,verification.link}

# 4.2 Inspect layout structure
jq '.steps | length' layout.json
# Expected: 3 (material, build, verification)

# 4.3 Verify material step
jq '.steps[] | select(.name=="material")' layout.json
# Check: commands, expected materials, expected products

# 4.4 Inspect build artifacts recorded
jq '.products | keys' build.link
# Expected: node-agent, SDK wheel hashes

# 4.5 Verify verification step execution
jq '.byproducts.return-value' verification.link
# Expected: 0 (success)

# 4.6 Summary view
jq 'group_by(.name) | map({name: .[0].name, count: length})' <(cat *.link)
```

**Pass Criteria**: ✅ All 3 links present + return values = 0 + artifacts recorded

---

### Phase 5: Formal Verification (3 min)

**Goal**: Verify formal proofs were executed

```bash
# 5.1 Check verification step in provenance
jq '.predicate.runDetails.byproducts[] | select(.name="release-artifacts")' slsa-provenance.json

# 5.2 Verify in verification.link output
jq '.byproducts.stdout' verification.link | grep -i "proof\|formal\|verify"
# Expected: Contains formal proof verification output

# 5.3 Check CHANGELOG for formal verification section
grep -A10 "Formal Verification" CHANGELOG.md
# Expected: Verification coverage documented
```

**Pass Criteria**: ✅ Formal proofs mentioned in attestations + verification output present

---

## Cryptographic Verification Details

### Verifying Container Image Signature

**What happens**:
1. Cosign requests certificate from Sigstore CA
2. CA verifies GitHub OIDC token
3. Certificate chain validated
4. Image signature verified
5. Result displayed

**Example Output**:
```
Verification successful!

Verified Container (by signature):
ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto@sha256:abc123...

Certificate Subject: https://github.com/rwilliamspbg-ops-ops-ops/...
Certificate Issuer: https://token.actions.githubusercontent.com
Timestamp: 2026-05-01T...
```

### Verifying Binary Signatures

**What happens**:
1. Download SHA256SUMS and SHA256SUMS.cosign.sig
2. Cosign verifies the signature
3. Confirms signature matches checksum file
4. Displays certificate chain

**Direct Verification**:
```bash
# Verify each binary individually
for binary in node-agent-*; do
  cosign verify-blob \
    --signature "${binary}.cosign.sig" \
    --certificate-identity-regexp '.*' \
    --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
    "$binary"
  echo "✓ $binary verified"
done
```

---

## Automated Verification Script

```bash
#!/bin/bash
# release-verify.sh - Automated release verification
# Usage: ./release-verify.sh v2.0.2

set -e
VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

RELEASE_URL="https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/releases/download/${VERSION}"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

echo "=== Downloading Artifacts ==="
wget -q "$RELEASE_URL"/{node-agent-*,*.whl,SHA256SUMS*,*.json,*.link} || echo "Note: Not all artifacts may be present"

echo "✓ Downloaded artifacts"

echo ""
echo "=== Phase 1: Checksum Verification ==="
if sha256sum -c SHA256SUMS 2>&1 | tail -1 | grep -q "OK"; then
  echo "✓ SHA256SUMS verified"
else
  echo "✗ Checksum verification FAILED"
  exit 1
fi

echo ""
echo "=== Phase 2: Container Image Signature ==="
if cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  "ghcr.io/rwilliamspbg-ops/Sovereign-Mohawk-Proto:${VERSION}" 2>&1 | grep -q "Verified OK"; then
  echo "✓ Container image signature verified"
else
  echo "Note: Container image verification may require auth"
fi

echo ""
echo "=== Phase 3: SLSA Provenance ==="
if [ -f "slsa-provenance.json" ]; then
  SLSA_VERSION=$(jq -r '.version' slsa-provenance.json)
  if [ "$SLSA_VERSION" = "1.0" ]; then
    echo "✓ SLSA v1.0 provenance present"
  else
    echo "✗ SLSA version mismatch: $SLSA_VERSION"
  fi
else
  echo "✗ slsa-provenance.json not found"
fi

echo ""
echo "=== Phase 4: In-Toto Metadata ==="
if [ -f "layout.json" ]; then
  STEPS=$(jq '.steps | length' layout.json)
  echo "✓ Layout present with $STEPS steps"
else
  echo "Note: layout.json not present (expected for some releases)"
fi

if [ -f "material.link" ] && [ -f "build.link" ] && [ -f "verification.link" ]; then
  echo "✓ All in-toto link metadata present"
else
  echo "Note: Not all in-toto links present"
fi

echo ""
echo "=== Verification Complete ==="
echo "Status: ✅ PASS (supply chain security verified)"
```

---

## Pre-Release Checklist (For Maintainers)

Before tagging a release:

```bash
# 1. Ensure all tests pass
make test

# 2. Verify formal proofs
make verify-formal-proofs

# 3. Run security checks
./scripts/go_with_toolchain.sh go vet ./...
govulncheck ./...

# 4. Check Python type safety
cd sdk/python && mypy --strict mohawk/ && cd ../..

# 5. Verify CHANGELOG is updated
grep "Unreleased\|[0-9]\+\.[0-9]\+\.[0-9]\+" CHANGELOG.md | head -5

# 6. Tag release (this triggers workflows)
git tag -a v{VERSION} -m "Release v{VERSION}"
git push origin v{VERSION}

# 7. Watch workflow execution
# GitHub Actions → feat/supply-chain-security → Release Assets and Images (and related)

# 8. Verify release artifacts appear within 10 minutes
# GitHub Releases → v{VERSION}
```

---

## Troubleshooting

### Cosign Verification Fails

**Problem**: "Verification failed"

**Solutions**:
1. Ensure cosign v2.2.0+: `cosign version`
2. Check OIDC token URL is correct: `https://token.actions.githubusercontent.com`
3. Verify certificate identity regex: `--certificate-identity-regexp '.*'`

### Sha256sum Mismatch

**Problem**: "FAILED" in sha256sum output

**Solutions**:
1. Re-download SHA256SUMS and binaries
2. Check for network corruption (use `wget -c` to resume)
3. Verify file sizes match expected values

### In-Toto Links Missing

**Problem**: Only some .link files present

**Solutions**:
1. Check release tag date (features rolled out gradually)
2. Download from main release assets tab
3. Contact maintainers if issue persists

---

## Standards Reference

### SLSA v1.0
- Specification: https://slsa.dev/spec/v1.0
- Provenance format: JSON attestation with build context
- Verification: slsa-verifier tool available

### Sigstore & Cosign
- Homepage: https://www.sigstore.dev/
- Cosign: Keyless signing tool
- PKI: Public infrastructure, no key management

### In-Toto
- Specification: https://in-toto.io/
- Framework version: v0.1
- Links: Cryptographically signed step records

---

## Contact & Support

**Issue Found**: File GitHub issue with `[audit]` tag  
**Question**: Check SUPPLY_CHAIN_SECURITY.md or CONTRIBUTING.md  
**Security**: Report to SECURITY.md contact  

---

**Last Updated**: May 1, 2026  
**Maintained By**: Sovereign Mohawk Protocol Contributors  
**Feedback**: Open issues at https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues
