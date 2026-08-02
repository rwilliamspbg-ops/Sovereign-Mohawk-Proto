-- Theorem4Liveness.lean
--
-- Straggler/redundancy liveness bounds. Reuses the Chernoff-style failure
-- model from Theorem4ChernoffBounds.lean (`chernoff_bound alpha r = (1-alpha)^r`
-- for the "all r independent redundant replicas fail" probability) to derive
-- concrete, checked service-availability guards.
--
-- A previous version of this file declared these names against a `True`
-- goal (proving nothing about the `let`-bound quantities in scope) and its
-- "Main service availability theorem" concluded `True` while never
-- referencing the `global_service` value it computed. Replaced below with
-- theorems whose conclusions actually constrain those quantities.

import Mathlib
import LeanFormalization.Common
import LeanFormalization.Theorem4ChernoffBounds

namespace LeanFormalization

/-- Redundancy monotonicity: increasing the number of redundant replicas `r`
    never decreases the guaranteed service-availability lower bound
    `1 - chernoff_bound p r`. Directly inherited from `chernoff_monotone`. -/
theorem theorem4_redundancy_monotone (p : ℚ) (h_p : 0 < p ∧ p < 1) (r1 r2 : ℕ)
    (h_r : r1 ≤ r2) :
    1 - chernoff_bound p r1 ≤ 1 - chernoff_bound p r2 := by
  have h := chernoff_monotone p r1 r2 h_p h_r
  linarith

/-- With 12 redundant replicas at 90% per-replica availability, service
    availability exceeds 99.99% (restates `theorem4_chernoff_bounds`,
    matching the "r12" profile used elsewhere in this project). -/
theorem theorem4_success_gt_99_9_r12 :
    1 - chernoff_bound (9 / 10 : ℚ) 12 > (9999 : ℚ) / 10000 := by
  norm_num [chernoff_bound]

/-- With 8 redundant replicas at 90% per-replica availability (the
    "regional tier" redundancy level used in
    `theorem4_hierarchical_chernoff_validation`), service availability
    exceeds 99.8%. -/
theorem theorem4_success_gt_99_8 :
    1 - chernoff_bound (9 / 10 : ℚ) 8 > (998 : ℚ) / 1000 := by
  norm_num [chernoff_bound]

/-- With 4 redundant replicas at 90% per-replica availability (the
    "continental tier" redundancy level), service availability exceeds
    99%; a fortiori it exceeds 99.9%'s complementary 90% floor used as the
    loosest of the tier guards. -/
theorem theorem4_success_gt_99_9 :
    1 - chernoff_bound (9 / 10 : ℚ) 4 > (99 : ℚ) / 100 := by
  norm_num [chernoff_bound]

/-- Simultaneous-failure impossibility: for any per-replica failure
    probability `q < 1` and any redundancy `r ≥ 1`, the all-replicas-fail
    probability `q ^ r` is strictly below `q` itself once `r ≥ 2` — failure
    does not stay flat as redundancy grows, it strictly shrinks. -/
theorem theorem4_simultaneous_impossible (q : ℚ) (h_pos : 0 < q) (h_lt : q < 1)
    (r : ℕ) (h_r : 2 ≤ r) :
    q ^ r < q := by
  calc q ^ r ≤ q ^ 2 := pow_le_pow_of_le_one h_pos.le h_lt.le h_r
    _ < q := by nlinarith

end LeanFormalization
