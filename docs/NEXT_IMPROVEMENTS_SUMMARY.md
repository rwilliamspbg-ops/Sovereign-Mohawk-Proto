# Next Improvements — Executive Summary
## Sovereign-Mohawk

**Status:** Formalization phase 2 complete → Phase 3b entry point identified  
**Prepared:** 2026-04-19

---

## Top 3 High-Impact Improvements (Next 8 Weeks)

### 1. Phase 3b Probabilistic Formalization (P1)
**What:** Formalize Chernoff bounds and real-valued convergence in Lean  
**Why:** Current proofs use concrete arithmetic; Phase 3 requires probabilistic tail bounds  
**Impact:** Closes theoretical gap before mainnet v1.0.0 GA  
**Effort:** 8-10 days  
**Quick Win:** Chernoff bounds for Theorem 4 (3-4 days)

### 2. Formal Proof CI/CD Hardening (P2)
**What:** Add proof regression detection, coverage dashboards, theorem dependency audits  
**Why:** Prevent accidental placeholder commits, detect proof brittleness early  
**Impact:** Zero placeholder-related failures post-merge  
**Effort:** 5-7 days  
**Quick Win:** Proof metrics extraction + regression check (2 days)

### 3. Runtime Test Coverage Expansion (P3)
**What:** Add property-based testing and 10M-node simulation integration tests  
**Why:** Catch edge cases formal proofs assume away  
**Impact:** 90%+ runtime coverage for all formal claims  
**Effort:** 7-10 days  
**Quick Win:** Property-based Multi-Krum tests (2 days)

---

## Quick Wins (Start Today, 3 Days Total)

1. **Proof Strategy Docstrings** (1 day)  
   → Add inline comments explaining proof approach to each Lean file
   → Unblocks next contributor

2. **Runtime Health Metrics Dashboard** (1 day)  
   → Instrument `mohawk_bft_resilience_estimate`, `mohawk_rdp_composition_current`, etc.
   → Operators can see formal claims validated in real-time

3. **Contributing to Lean Proofs Playbook** (1 day)  
   → Write step-by-step guide for adding new theorem
   → Template + example = faster community contributions

---

## By Priority

| Priority | Area | Impact | Effort | Timeline |
|----------|------|--------|--------|----------|
| **P1** | Phase 3b theorems (Chernoff, convergence) | Closes phase gate | 8-10d | Week 1-2 |
| **P2** | Proof CI/CD regression gates | Zero bad commits | 5-7d | Week 1-2 |
| **P3** | Test coverage expansion | Edge case safety | 7-10d | Week 2-3 |
| **P4** | Production metrics + playbooks | Operator confidence | 6-8d | Week 3-4 |
| **P5** | Lean contribution docs | Community velocity | 4-6d | Week 1-2 (parallelize) |
| **P6** | CI/CD consolidation | Faster feedback | 4-5d | Week 4 |
| **P7** | Proof attestation tokens | Runtime trust | 5-7d | Week 5+ |
| **P8** | Formal proof hub page | Knowledge transfer | 4-5d | Week 4-5 |
| **P9** | Scale regression gates | 10M readiness | 5-7d | Week 5+ |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Real-valued Lean proofs exceed Mathlib.Analysis capability | Phase 3b blocked | Start P1 early; engage Lean community if stuck |
| CI pipeline grows too complex | Slow pre-merge feedback | Parallelize workflows; target <10 min total |
| Runtime test scale (10M sim) takes >30 min | CI timeout | Profile aggregator; parallelize nodes |
| Operator adoption blocked by confusing metrics | Production drift | Simplify dashboard; add runbook links to alerts |

---

## Success Metrics (End of Phase 3b)

- [ ] 54 → 58+ theorems (Chernoff + convergence ≥4 new)
- [ ] 100% proof CI coverage (no placeholders ever merge)
- [ ] 90%+ runtime test coverage (edge cases + properties)
- [ ] Live operator dashboards show all formal claims validated
- [ ] v1.0.0 GA release with proof attestation tokens
- [ ] 3+ community Lean contributions (playbook effective)

---

## Resource Requirements

- **Lean Expertise:** 1 FTE (P1 formalization + P2 complexity audits)
- **DevOps:** 0.5 FTE (CI/CD P2, P6, cross-workflow orchestration)
- **QA:** 0.5 FTE (P3 testing expansion, P9 scale benchmarks)
- **Backend:** 0.5 FTE (P4 metrics + P7 attestation endpoints)
- **Docs:** 0.25 FTE (P5 playbooks, P8 hub page)

**Total:** ~3 FTE over 8-10 weeks

---

## Recommendation

**Start with P1 + P2 + P5 in parallel (week 1-2):**
- P1 unblocks Phase 3 → mainnet readiness
- P2 prevents regressions as work continues
- P5 enables community contributions to reduce P1 load

**Then execute P3 + P4 (week 3-4)** → production confidence  
**Follow with P6 + P8 (week 4-5)** → operational excellence

---

See `docs/NEXT_IMPROVEMENTS_ROADMAP.md` for detailed task breakdown.
