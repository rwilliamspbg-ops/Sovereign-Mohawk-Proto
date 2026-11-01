# Plan: Elevate Tests to High-Value Audit Evidence

## Phase 1 — Strengthen fuzz oracles (no panics → correctness)
1. thresholdagg: assert round-trip equality (Marshal→Unmarshal deep-equal), reject negative/empty values where invalid, length invariants.
2. manifest: assert invalid JSON rejected, required fields enforced, signature round-trip.
3. zkproof: assert tampered proofData rejected, wrong salt rejected, valid commitment accepted (seeded).
4. rdp: assert RecordShardStep monotonic epsilon, no NaN/Inf, budget enforcement.
5. scheduler: assert total allocation ≤ sum available, winner has min price, failure on no eligible bids.

## Phase 2 — Expand property suite (gopter)
- Multi-bid auctions (2-5 bids), random ordering invariance.
- Edge cases: zero/negative units, NPU required, trust thresholds.
- Total allocation ≤ sum available; clearing price ≤ min winning price.
- Determinism: same inputs → same allocation.

## Phase 3 — Stress race hardening
- Scope to concurrency-sensitive packages only (router, thresholdagg, tpm, transport).
- Use go test -c + stress tool with focused -test.run.
- Upload race report + failing test name artifact.
- Quarantine/fix TestGetVerifiedQuoteLeaseCache separately.

## Phase 4 — Mutation score tracking
- Parse gremlins output, publish score as PR comment / artifact trend.
- Set non-blocking baseline threshold; fail only on regression below baseline.

## Phase 5 — Corpus & reproducibility
- Commit seed corpora from smoke runs into testdata/fuzz/.
- Nightly deep-fuzz uploads corpus deltas; merge back via PR.

## Deliverables
- Updated fuzz targets with semantic assertions.
- Expanded property tests.
- Scoped stress-race workflow + artifact upload.
- Mutation score tracking script.
- Updated scope doc.

## Success criteria
- All fuzz targets assert correctness, not just no-panic.
- Property suite ≥10 properties, ≥500 cases each.
- Stress race green or quarantined with tracked issue.
- Mutation score reported and trended.
