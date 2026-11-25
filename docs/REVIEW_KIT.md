# External review kit

A zero-budget review kit packages the Lean development and the two-host LAN
evidence into a single tarball with a SHA-256 manifest. The packaged snapshot
is generated outside the repository (it includes raw artifacts that should not
be version-controlled); this page documents how to build and verify it.

## Build

From the repo root on the Windows host, with the evidence directory at
`C:/Users/rwill/lan-multinode-artifacts/20261124-2230/`:

```bash
A=/c/Users/rwill/lan-multinode-artifacts/20261124-2230
K=$A/review-kit; S=$K/stage
rm -rf "$K"; mkdir -p "$S/lean" "$S/evidence"

# Formal sources: exclude the cached Mathlib oleans and all secrets.
tar --exclude='.lake' -cf - proofs | tar -xf - -C "$S/lean"
cp CHANGELOG.md docs/MAJOR_WIN_PLAN.md docs/FORMAL_RESULTS_SUMMARY.md \
   docs/EXTERNAL_AUDIT_SCOPE.md "$S/lean/"

# Evidence: report, network/observability/benchmark artifacts, compose overrides.
# Never copy certs/, certs-work/ or runtime-secrets/ into a review kit.
cp "$A"/final-report.* "$A"/phase0-inventory.md "$A"/phase5-network-perf.md \
   "$A"/topology.md "$A"/lan-*.yml "$S/evidence/"
for d in network observability phase6 logs results; do
  cp -r "$A/$d" "$S/evidence/"
done

cd "$S"
tar czf "$K/lean-development.tar.gz" lean
tar czf "$K/lan-evidence.tar.gz" evidence
cd "$K"
sha256sum README.md lean-development.tar.gz lan-evidence.tar.gz > SHA256SUMS
tar czf review-kit.tar.gz README.md SHA256SUMS lean-development.tar.gz lan-evidence.tar.gz
```

`README.md` in the kit is the reviewer-facing reading guide: it lists the
claims, the verification commands, the deliberately open associativity gap,
and the raw-evidence map.

## Verify

```bash
tar xzf review-kit.tar.gz
sha256sum -c SHA256SUMS
```

Then rebuild the Lean tree from source (`lake exe cache get`,
`lake build LeanFormalization`) and re-run `#print axioms` for any cited
declaration — the kit is evidence, not a substitute for rebuilding.

## Contents / exclusions

Included: `proofs/` without `.lake`, formal-status docs, the LAN final report
(Markdown + JSON), Phase 0/5/6 artifacts, Prometheus/Grafana exports, custom
network probe, compose overrides.

Excluded: private keys and certificates, Grafana/admin credentials, Docker
image tarballs, the Mathlib build cache. Anything excluded is regenerated
locally from the repository scripts and the pinned toolchain.
