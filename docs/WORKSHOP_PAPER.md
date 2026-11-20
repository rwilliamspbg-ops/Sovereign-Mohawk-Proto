# Machine-Checked Disproof of Deterministic Hierarchical Composition in Federated Learning, and a Rational Chernoff Repair

**Sovereign-Mohawk-Proto** — companion short paper to *Sovereign-Mohawk: Machine-Checked Hierarchical Byzantine Resilience and Probabilistic Composition for Federated Learning* (`docs/ACADEMIC_PAPER.md`).

**Format:** workshop / short conference paper (6 pages). Two results, both fully kernel-checked in Lean 4 + Mathlib.

---

### Abstract

Hierarchical federated learning is widely described as *composing* per-tier Byzantine filters into a global resilience guarantee: if every committee satisfies an honest-majority guard, the network tolerates a global Byzantine fraction below one half. We show this is false, and we show how to repair it.

1. **Disproof.** We give a machine-checked counterexample to deterministic hierarchical composition. A two-tier tree with $N = 5$ leaves and two committees — one with $2$ honest / $1$ Byzantine, one with $0$ honest / $2$ Byzantine — passes the local guard at *every* aggregator (the root computes a safe weight of $3$ against $5$ leaves), while the global Byzantine fraction is $3/5 = 60\% > 50\%$. The proof is `hierarchical_composition_counterexample` in `LeanFormalization/Theorem1BFT.lean` and is discharged by `decide`; `#print axioms` reports **no axioms**.
2. **Repair.** We replace deterministic assignment with i.i.d. Bernoulli committee assignment and bound the failure probability by a **rational** Chernoff bound that never leaves $\mathbb{Q}$: for any rational base $z \ge 1$,
$$\mathrm{binomialTail}(n,k,p) \;\le\; \frac{(1-p+pz)^n}{z^k}.$$
At the deployment parameters ($T = 200$ committees, $c = 50{,}000$ leaves, $p = 1/10$, threshold $k = 25{,}000$, base $z = 2$) the Markov bound is the vacuous number $40$, while the Chernoff bound is at most $200/10^{1000} \approx 2 \times 10^{-998}$. The deployment-scale inequality is closed by an exponent-reduction argument ($1000$th powers) and `norm_num`, **without `native_decide`**, so the entire development is kernel-checked. Every theorem we cite depends only on `[propext, Classical.choice, Quot.sound]`.

---

## 1. Introduction

A hierarchical FL deployment partitions participants into committees, aggregates within each committee, then aggregates committee outputs at higher tiers. The natural security argument is inductive: each committee applies a Byzantine-robust filter that is safe whenever the committee has an honest majority, therefore the whole tree is safe whenever every committee has an honest majority.

That argument is the *compositional fallacy*. Section 3 shows it is not merely informal but formally false. Section 4 replaces it with a probabilistic statement that is true and machine-checked.

**Contributions.**

- A formal definition of the recursive credit a parent aggregator assigns to a child committee (`HTree.safeLeafWeight`), and a machine-checked counterexample showing the induced root guard can pass while the global Byzantine fraction exceeds $1/2$ (Section 3).
- A first-principles Lean proof of the binomial mean, an exact rational Chernoff tail bound generic in the base $z$, and a deployment-scale instance closed by exponent reduction rather than trusted reflection (Section 4).
- An explicit statement of what is *not* proved: the bound is conditional on i.i.d. Bernoulli assignment, and no deployment-scale empirical validation is claimed (Section 5).

---

## 2. Model

**Hierarchy.** A deployment is a tree. Leaves are participants, each honest or Byzantine; internal nodes are aggregators. Write $n$ for the leaf count and $f$ for the Byzantine leaf count of a subtree.

**Local guard.** At one aggregator receiving $n$ candidate updates with $f$ Byzantine, the single-tier guard is
$$\mathcal{G}_{\text{local}}(n,f) \;\equiv\; (2f < n) \;\wedge\; (9f < 5n).$$
The first conjunct is strict honest majority; the second is the per-tier $5/9$ profile arithmetic checked for concrete configurations. It is a *per-tier, guard-conditional* fact.

**Credited weight.** This is the mechanism the fallacy hides. A parent aggregator receives one filtered vector per child and cannot inspect the child's interior. We model the credit it assigns:
$$\mathrm{safeLeafWeight}(t) \;=\; \begin{cases} 0 & t \text{ a Byzantine leaf} \\ 1 & t \text{ an honest leaf} \\ \sum_{c \,\in\, \mathrm{children}(t)} \mathrm{credit}(c) & t \text{ an internal node} \end{cases}$$
where
$$\mathrm{credit}(c) \;=\; \begin{cases} \mathrm{totalLeaves}(c) & \text{if } 2\cdot\mathrm{safeLeafWeight}(c) > \mathrm{totalLeaves}(c) \\ 0 & \text{otherwise.} \end{cases}$$
A child that passes its own guard is credited with its **entire** leaf count; a child that fails is credited with zero. The root is declared safe when $2 \cdot \mathrm{safeLeafWeight}(\mathrm{root}) > \mathrm{totalLeaves}(\mathrm{root})$.

---

## 3. The Composition Fallacy is False

### 3.1 The counterexample

Take two committees and a root:

| node | leaves | Byzantine | honest | local guard | credited weight |
|---|---|---|---|---|---|
| $A$ | 3 | 1 | 2 | $2\cdot2 > 3$ ✓ | 3 |
| $B$ | 2 | 2 | 0 | $2\cdot0 > 2$ ✗ | 0 |
| root | 5 | 3 | 2 | $2\cdot3 > 5$ ✓ | 3 |

Committee $A$ passes and is credited all $3$ of its leaves, including the one Byzantine leaf it absorbed. Committee $B$ fails and is discarded. The root sees safe weight $3$ out of $5$ and declares itself safe — while the tree as a whole is $60\%$ Byzantine. The parent's inability to distinguish "$100\%$ honest" from "$49\%$ Byzantine" is the entire vulnerability.

### 3.2 Machine-checked formalization

The tree, the credit function and the guard are defined in `LeanFormalization/Theorem1BFT.lean`:

```lean
inductive HTree where
  | leaf (byzantine : Bool)
  | node (children : List HTree)

mutual
def HTree.totalLeaves : HTree → Nat
  | .leaf _ => 1
  | .node cs => HTree.totalLeavesList cs
def HTree.totalLeavesList : List HTree → Nat
  | [] => 0
  | c :: cs => c.totalLeaves + HTree.totalLeavesList cs
end

mutual
def HTree.byzantineLeaves : HTree → Nat
  | .leaf b => if b then 1 else 0
  | .node cs => HTree.byzantineLeavesList cs
def HTree.byzantineLeavesList : List HTree → Nat
  | [] => 0
  | c :: cs => c.byzantineLeaves + HTree.byzantineLeavesList cs
end

mutual
def HTree.safeLeafWeight : HTree → Nat
  | .leaf b => if b then 0 else 1
  | .node cs => HTree.safeLeafWeightList cs
def HTree.safeLeafWeightList : List HTree → Nat
  | [] => 0
  | c :: cs =>
      (if 2 * c.safeLeafWeight > c.totalLeaves then c.totalLeaves else 0)
      + HTree.safeLeafWeightList cs
end

def HTree.safe (t : HTree) : Prop := 2 * t.safeLeafWeight > t.totalLeaves
def HTree.fractionSafe (t : HTree) : Prop := 2 * t.byzantineLeaves < t.totalLeaves
```

The counterexample and its machine-checked disproof:

```lean
def hierarchical_counterexample_A : HTree := .node [.leaf false, .leaf false, .leaf true]
def hierarchical_counterexample_B : HTree := .node [.leaf true, .leaf true]
def hierarchical_counterexample_Root : HTree := .node [hierarchical_counterexample_A,
                                                        hierarchical_counterexample_B]

theorem hierarchical_counterexample_A_safe : hierarchical_counterexample_A.safe := by
  unfold HTree.safe; decide

theorem hierarchical_counterexample_B_not_safe : ¬ hierarchical_counterexample_B.safe := by
  unfold HTree.safe; decide

theorem hierarchical_counterexample_Root_safe : hierarchical_counterexample_Root.safe := by
  unfold HTree.safe; decide

/-- The local guard holds at the root while the global Byzantine fraction exceeds 1/2. -/
theorem hierarchical_composition_counterexample :
    hierarchical_counterexample_Root.safe ∧
    ¬ (2 * hierarchical_counterexample_Root.byzantineLeaves
        < hierarchical_counterexample_Root.totalLeaves) := by
  refine ⟨hierarchical_counterexample_Root_safe, ?_⟩
  unfold hierarchical_counterexample_Root
         hierarchical_counterexample_A
         hierarchical_counterexample_B
  decide
```

`#print axioms hierarchical_composition_counterexample` reports **"does not depend on any axioms"**: the disproof is a pure decision procedure on finite data, not an assumption.

### 3.3 What the counterexample does and does not show

It refutes the *deterministic* composition claim as stated. It does not show that hierarchical FL is unusable: it shows that the guard must be applied to a quantity the parent can actually verify about the child's interior, or that assignment must be randomized so that no adversary can *choose* which subtree is sacrificed. Section 4 takes the second route.

---

## 4. Probabilistic Repair: Rational Chernoff Bounds

### 4.1 Randomized assignment model

Assign participants to $T$ committees of capacity $c$ by independent Bernoulli trials with parameter $p = \Pr[\text{Byzantine}]$. The Byzantine count $X$ in a committee is $\mathrm{Bin}(c,p)$, and
$$\mathrm{binomialTail}(c,k,p) = \sum_{j=k}^{c} \binom{c}{j} p^j (1-p)^{c-j}.$$
By Boole's inequality the hierarchy fails with probability at most
$$P_{\text{fail}} \;\le\; 1 - (1 - \mathrm{binomialTail}(c,k,p))^{T} \;\le\; T \cdot \mathrm{binomialTail}(c,k,p).$$

### 4.2 Binomial mean, from first principles

Mathlib's distribution library does not ship a constructive $\mathbb{E}[\mathrm{Bin}(n,p)] = np$, so we prove it from the absorption identity and the binomial theorem:

```lean
theorem binomial_mean (n : ℕ) (p : ℚ) :
    ∑ i ∈ Finset.range (n + 1),
      (i : ℚ) * ((n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i)) = (n : ℚ) * p
```

### 4.3 Markov is vacuous at scale

Markov's inequality gives $\Pr[X \ge k] \le cp/k$, hence $P_{\text{fail}} \le T \cdot cp/k$. At $T = 200$, $c = 50{,}000$, $p = 0.10$, $k = 25{,}000$:
$$200 \cdot \frac{50{,}000 \times 0.10}{25{,}000} = 40.$$
A probability bound of $40$ is vacuous. Both facts are machine-checked:
```lean
theorem probabilistic_bound_too_loose_at_deployment_scale :
    (200 : ℚ) * (50000 : ℚ) * (1 / 10) / 25000 = 40 := by norm_num
```

### 4.4 The rational Chernoff bound

To get exponential decay without importing transcendental real analysis into the kernel, we work entirely in $\mathbb{Q}$ with an arbitrary rational base $z \ge 1$.

> **Definition (rational Chernoff function).**
> $$\mathrm{chernoffBoundZ}(n,k,p,z) \;=\; \frac{(1 - p + pz)^n}{z^k}.$$

> **Theorem (rational Chernoff tail bound).** For $n,k \in \mathbb{N}$, $p \in \mathbb{Q}$ with $0 \le p \le 1$, and $z \in \mathbb{Q}$ with $z \ge 1$:
> $$\mathrm{binomialTail}(n,k,p) \;\le\; \mathrm{chernoffBoundZ}(n,k,p,z).$$

*Proof.* Weight the tail by $z^k \le z^i$ for $i \ge k$:
$$z^k \sum_{i=k}^{n} \binom{n}{i} p^i (1-p)^{n-i} \le \sum_{i=k}^{n} z^i \binom{n}{i} p^i (1-p)^{n-i} \le \sum_{i=0}^{n} \binom{n}{i} (pz)^i (1-p)^{n-i} = (1-p+pz)^n,$$
using `Finset.sum_le_sum` for the first inequality and `add_pow` for the last identity. Divide by $z^k > 0$. $\blacksquare$

```lean
def chernoffBoundZ (n k : ℕ) (p z : ℚ) : ℚ := (1 - p + p * z) ^ n / z ^ k

theorem binomialTail_le_chernoffBoundZ (n k : ℕ) (p z : ℚ)
    (hz : 1 ≤ z) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    binomialTail n k p ≤ chernoffBoundZ n k p z
```

### 4.5 Deployment-scale certification, kernel-checked

At $c = 50{,}000$, $k = 25{,}000$, $p = 1/10$, $z = 2$:
$$\mathrm{chernoffBoundZ} = \frac{(11/10)^{50000}}{2^{25000}}.$$
Evaluated naively this is a rational with over $5{,}000$ decimal digits in numerator and denominator, and `norm_num` does not decide it in reasonable time. The proof avoids that blow-up: both sides of
$$\frac{(11/10)^{50000}}{2^{25000}} \le \frac{1}{10^{1000}}$$
are $1000$th powers, so `pow_le_pow_iff_left₀` reduces the goal to $\frac{(11/10)^{50}}{2^{25}} \le \frac{1}{10}$, i.e. $11^{50} \le 2^{74} \cdot 5^{49}$ — a 53-digit versus 57-digit integer comparison that `norm_num` decides outright.

```lean
theorem chernoffBoundZ_deployment_scale_tiny :
    chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 ≤ 1 / 10 ^ 1000 := by
  unfold chernoffBoundZ
  have hbase : (1 - 1/10 + (1/10 : ℚ) * 2) = 11/10 := by norm_num
  rw [hbase]
  rw [show (50000 : ℕ) = 50 * 1000 by norm_num,
      show (25000 : ℕ) = 25 * 1000 by norm_num]
  rw [pow_mul, pow_mul, ← div_pow]
  rw [show (1 : ℚ) / 10 ^ 1000 = (1/10) ^ 1000 by norm_num [div_pow]]
  rw [pow_le_pow_iff_left₀ (by positivity) (by positivity) (by norm_num)]
  have hkey : (11 : ℚ) ^ 50 ≤ 2 ^ 74 * 5 ^ 49 := by norm_num
  have h1 : (11/10 : ℚ)^50 / 2^25 = 11^50 / (2^75 * 5^50) := by
    rw [div_pow, div_div]
    have h10 : (10 : ℚ) ^ 50 = 2^50 * 5^50 := by
      rw [show (10 : ℚ) = 2 * 5 by norm_num, mul_pow]
    rw [h10]; ring
  rw [h1]
  rw [div_le_iff₀ (by positivity : (0 : ℚ) < 2^75 * 5^50)]
  ring_nf; norm_num

/-- Failure probability of randomized committee assignment at deployment scale. -/
theorem chernoff_hierarchical_bound_deployment_scale :
    1 - (1 - binomialTail 50000 25000 (1/10 : ℚ)) ^ 200 ≤ (200 : ℚ) / 10 ^ 1000 := by
  have h := chernoff_hierarchical_bound 200 50000 25000 (1/10 : ℚ) 2
    (by norm_num) (by norm_num) (by norm_num)
  have hbound := chernoffBoundZ_deployment_scale_tiny
  calc 1 - (1 - binomialTail 50000 25000 (1/10 : ℚ)) ^ 200
      ≤ (200 : ℚ) * chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 := h
    _ ≤ (200 : ℚ) * (1 / 10 ^ 1000) := by nlinarith [hbound]
    _ = (200 : ℚ) / 10 ^ 1000 := by ring
```

So $P_{\text{fail}} \le 200/10^{1000} \approx 2 \times 10^{-998}$. An earlier revision of this result closed the deployment-scale goal with `native_decide` on the unfolded $\sim$5000-digit rationals; the exponent reduction above removes that toolchain trust. `#print axioms` on every theorem cited here reports exactly `[propext, Classical.choice, Quot.sound]` (and `hierarchical_composition_counterexample` reports none).

---

## 5. Scope and Limitations

Stated plainly, because the strength of a machine-checked claim is exactly the strength of its hypotheses.

- **The counterexample is about deterministic composition.** It shows the guard $\mathcal{G}_{\text{local}}$ applied tier-by-tier does not imply a global fraction bound. It does not show hierarchical FL is impossible; it shows the parent must not credit a child's full weight on the child's self-report.
- **The Chernoff bound is conditional on i.i.d. Bernoulli assignment.** It bounds $\Pr[\text{some committee exceeds } k]$ under independent random placement. It says nothing about an adversary who *chooses* placement — which is precisely the adversary the counterexample exploits. Randomization is a mitigation under a stated model, not a proof against adaptive placement.
- **No deployment-scale empirical validation.** $200$ committees of $50{,}000$ leaves is $10^7$ participants; the bound is an analytic result, not a measurement.
- **The base $z$ is a free parameter.** $z = 2$ is chosen for the deployment instance; the bound is generic in $z \ge 1$.
- **Related surrogates.** The ZK circuit refinement in this repository uses a structural verification-key model and a parameterized MiMC constant list; those surrogates are documented as such and are not part of the two results above. See `docs/EXTERNAL_AUDIT_SCOPE.md` §3.3.

---

## 6. Conclusion

Deterministic hierarchical composition of per-tier Byzantine filters is not sound: a five-leaf, two-committee tree passes every local guard while being $60\%$ Byzantine, and this is machine-checked with no axioms. Randomizing assignment restores a provable bound, and the resulting Chernoff inequality — at most $2 \times 10^{-998}$ at the $10^7$-participant design scale — is machine-checked in $\mathbb{Q}$ with no `native_decide`. The two results are complementary: one closes a plausible but false line of argument, the other supplies a true replacement with explicit hypotheses.

---

## References

1. L. Lamport, R. Shostak, M. Pease. *The Byzantine Generals Problem.* 1982.
2. P. Kairouz et al. *Advances and Open Problems in Federated Learning.* 2021.
3. S. Bubeck, N. Cesa-Bianchi. *Regret Analysis of Stochastic and Nonstochastic Multi-armed Bandit Problems.* 2012.
4. I. Mironov. *Rényi Differential Privacy.* 2017.
5. The Mathlib Community. *The Lean Mathematical Library.* 2024.
6. Sovereign-Mohawk-Proto. *Sovereign-Mohawk: Machine-Checked Hierarchical Byzantine Resilience and Probabilistic Composition for Federated Learning.* `docs/ACADEMIC_PAPER.md` (full paper).

---

## Appendix A. Reproduction

```bash
cd proofs
lake build LeanFormalization.Theorem1BFT        # counterexample + Chernoff development
```

Axiom audit of the two headline results:

```bash
cd proofs
cat > /tmp/axioms.lean <<'EOF'
import LeanFormalization
open LeanFormalization
#print axioms hierarchical_composition_counterexample
#print axioms binomial_mean
#print axioms binomialTail_le_chernoffBoundZ
#print axioms chernoffBoundZ_deployment_scale_tiny
#print axioms chernoff_hierarchical_bound_deployment_scale
EOF
lake env lean /tmp/axioms.lean
```

Expected: `hierarchical_composition_counterexample` — *does not depend on any axioms*; the remaining four — `[propext, Classical.choice, Quot.sound]`.

Repository status: the Lean development is sorry-free and free of `axiom` declarations; the only explicit hypotheses in the development are `FloatOrderLaws` and `Fact (Nat.Prime dlL)` (see `docs/LEAN_AXIOM_AUDIT_AND_REMOVAL_PLAN.md`), neither of which is used by the results in this paper.

Full traceability: `proofs/FORMAL_TRACEABILITY_MATRIX.md` row 1 (both results, their definitions and their deployment-scale instances).
