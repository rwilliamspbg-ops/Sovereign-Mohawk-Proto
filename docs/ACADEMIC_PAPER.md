# Sovereign-Mohawk: Machine-Checked Hierarchical Byzantine Resilience and Probabilistic Composition for Federated Learning

**Ryan Williams**  
*Sovereign Mohawk Proto LLC, Seattle, WA, USA*  
Email: `contact@sovereign-mohawk.org`  
Repository: [https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)

**IEEE Transactions on Dependable and Secure Computing (TDSC)** / **IEEE Symposium on Security and Privacy (S&P)** Standards Manuscript  
*Target Length: 12--14 Pages (IEEE Double-Column Equivalent)*

---

### Abstract
Federated learning (FL) at scale requires aggregating model updates across multi-tier topologies while tolerating adversarial participants. A pervasive foundational assumption in hierarchical FL design is compositional safety: if every local aggregation tier enforces an honest-majority guard (e.g., Multi-Krum), the overall network inherits global Byzantine fault tolerance. In this paper, we present **Sovereign-Mohawk**, an FL architecture and Lean 4 formal development that refutes and repairs this assumption.

First, we present a machine-checked negative result: a concrete counterexample in Lean 4 showing that naive deterministic composition of per-tier Multi-Krum guards fails, allowing a 60% global Byzantine leaf fraction to pass local filters under concentrated placement. Second, we formalize a probabilistic repair proving that under explicit i.i.d. Bernoulli committee sampling, the probability of any tier exceeding its Byzantine filtering threshold is strictly bounded by a Chernoff bound over rationals, verified in Lean 4 for $T = 200$ committees and $c = 50,000$ leaves per committee ($P_{\text{fail}} \le 200 \times 10^{-1000} \approx 2 \times 10^{-998}$). Third, we formalize eight core theoretical developments, including Rényi Differential Privacy (RDP) with constructivist rational logarithmic bounds, logarithmic path-depth routing, MiMC permutation polynomials over BN254 scalar fields, Robbins-Siegmund supermartingale convergence, and post-quantum cryptographic (PQC) dual-signature migration non-hijack guarantees. We further machine-check the Edwards–Montgomery–Weierstrass addition-law bridge (including the $x_3=0$ torsion case and twisted-Edwards completeness), and prove associativity of the concrete Ed25519 affine law **conditionally**, with every remaining hypothesis stated explicitly. Fourth, we couple these formal artifacts with an industrial Go production runtime and evaluate the system across multi-node Kubernetes-in-Docker (Kind) clusters (up to 500 pods), CI swarm matrices (500–1,500 nodes), and a 1,000-node simulator target under safe (10% Byzantine) and edge (35% Byzantine) adversarial regimes, demonstrating microsecond aggregation overhead ($30.63\ \mu\text{s}$), sub-400ms round latency (373 ms at 1,500 nodes), and minimal accuracy impact (1.8% gap vs. clean baseline). **Scope caveat:** the Lean development is axiom-free and sorry-free, but its results are machine-checked *about stated models and hypotheses*; the Go↔Lean correspondence is checked empirically (pinned `#eval` vectors, replayed traces), never by a machine-checked cross-language equality, because Lean cannot invoke Go source. Per-claim status is recorded in `proofs/FORMAL_TRACEABILITY_MATRIX.md` and
defined by the claim-status taxonomy of §3, which separates results proved
about a model from results measured against the runtime.

**Index Terms:** Federated Learning, Byzantine Fault Tolerance, Formal Verification, Interactive Theorem Proving, Lean 4, Hierarchical Aggregation, Differential Privacy, Zero-Knowledge Proofs, Post-Quantum Cryptography.

---

## 1. Introduction

Federated Learning (FL) enables distributed entities to collaboratively train shared machine learning models without centralizing proprietary training datasets [1]. As FL scales to global deployment environments encompassing millions of heterogeneous devices, system architects encounter what we term the **Trust-Scale Paradox**: larger node populations geometrically increase the probability of encountering Byzantine faults, intentional model poisoning attacks, and network partitioning, while the processing and cryptographic verification overhead of aggregation must remain strictly sub-linear in total participant count.

To mitigate network congestion and distributed communication bottlenecks, modern large-scale FL architectures organize participants into multi-tier topological hierarchies (e.g., Device Edge $\to$ Regional Aggregator $\to$ Continental Gateway $\to$ Global Orchestrator) [8], [9]. A ubiquitous assumption in the hierarchical FL literature is *compositional safety*: if every individual aggregation node enforces a localized Byzantine filter (such as Multi-Krum [2]), the entire network structure is assumed to inherit global Byzantine fault tolerance up to the per-tier tolerance threshold.

```
+--------------------------------------------------------------------------------------------------+
|                                     THE TRUST-SCALE PARADOX                                      |
|                                                                                                  |
|   Scale: Millions of Edge Nodes ------> Geometric Explosion of Byzantine Failure Risk           |
|                                         & Strategic Adversarial Collusion                        |
|                                                                                                  |
|   Resource Constraints -----------> Aggregation, Cryptographic Attestation, and Privacy          |
|                                     Accounting MUST Remain Strictly Sub-Linear: O(d log n)       |
+--------------------------------------------------------------------------------------------------+
```

### 1.1 The Compositional Fallacy in Hierarchical FL
In this work, we demonstrate that this pervasive assumption is fundamentally flawed. In a hierarchical aggregation tree, parent nodes only observe the aggregated vector summaries emitted by child nodes; they cannot directly audit the inner constituent gradients of individual edge devices. If an adversary strategically concentrates corrupt workers into specific sub-clusters, intermediate aggregation tiers can satisfy their local honest-majority filters while the global fraction of Byzantine workers drastically exceeds the theoretical safety threshold. Consequently, deterministic localized filtering guarantees do *not* compose inductively across tiers.

To establish this result beyond mathematical doubt, we leverage interactive theorem proving in Lean 4 [19]. We construct a machine-checked counterexample demonstrating that a two-tier hierarchy enforcing strict per-tier weighted majority guards allows a 60% global Byzantine leaf population to subvert the system. This negative result disproves deterministic hierarchical composition for the credited-weight guard the system actually uses; no per-tier threshold fixes the gap, because it is structural.

### 1.2 Probabilistic Repair and Multi-Faceted Verification
To restore provable system-wide security, we formalize a machine-checked *probabilistic repair*. Rather than permitting static or adversarial participant placement, nodes are assigned to aggregation committees via an explicit independently and identically distributed (i.i.d.) Bernoulli process. Under this random assignment model, we prove that the probability of any aggregation committee violating its local Byzantine threshold decays exponentially. While standard pen-and-paper proofs invoke continuous moment-generating functions and Kullback-Leibler (KL) divergences, such transcendental machinery introduces non-computability and floating-point soundless hazards in formal logic. We solve this by formalizing an exact rational Chernoff bound at arbitrary rational base $z \ge 1$ entirely over $\mathbb{Q}$. Reducing the goal modulo its common $1000$th power and deciding the remaining $11^{50} \le 2^{74} \cdot 5^{49}$ by exact rational arithmetic, we certify that for a global system of 10 million nodes divided into $T = 200$ committees of $c = 50,000$ leaves under a 10% global Byzantine adversary, the failure probability across the entire hierarchy is strictly upper-bounded by $200 \times 10^{-1000} \approx 2 \times 10^{-998}$.

We embody these mathematical insights within **Sovereign-Mohawk**, an industrial-grade federated learning architecture that pairs a scope-labelled Lean 4 formal development with a high-performance Go production runtime. The system integrates multi-tier Rényi Differential Privacy (RDP) accounting with verified rational logarithm bounds, flat Groth16 zero-knowledge proofs over MiMC hash commitments, Robbins-Siegmund supermartingale convergence lemmas, and post-quantum cryptographic (PQC) dual-signature migration non-hijack invariants.

### 1.3 Core Contributions
This paper makes eight core contributions spanning formal verification, cryptographic architecture, and empirical systems evaluation:
1. **Machine-Checked Disproof of Composition (Theorem 1):** We formalize an inductive tree structure (`HTree`) and construct a machine-checked counterexample in Lean 4 proving that *weighted* per-tier honest-majority guards do not compose deterministically (the counterexample uses the actual `HTree.safe` credited-weight predicate; it does not refute every conceivable per-tier rule), permitting a 60% Byzantine leaf fraction.
2. **Exact Rational Chernoff Repair (Theorem 1):** We prove the binomial mean from first principles in Lean 4 and establish an exponential rational Chernoff tail bound. We formally prove why polynomial Markov bounds fail at scale ($40 > 1$) and certify that the Chernoff bound bounds hierarchical failure probability below $200 \times 10^{-1000}$ **under the explicit i.i.d. Bernoulli committee-assignment model** — the scope of the result, not a guarantee about adversarial placement. We additionally attach that bound to the runtime's actual precondition: `guardThreshold c = (c-1)/2` is proved to be exactly the failure point of `n > 2f + 2`, giving a protocol-level bound on the probability that any committee refuses to run Multi-Krum.
3. **Constructivist RDP Accounting (Theorem 2):** We formalize Rényi Differential Privacy tensorization over independent mechanisms and solve the constructive non-computability of $\ln(z)$ by proving a two-sided rational sandwich bound in Lean 4, enabling exact $(\epsilon, \delta)$-DP verification.
4. **Wire-Format Refinement and Communication Depth (Theorem 3):** We prove an $O(d \log n)$ path-depth complexity bound and check a **formula-level** correspondence between the Lean 4 transport model and Go's IEEE-754 gradient serialization in CI — there is no machine-checked cross-language equivalence, because Lean cannot invoke Go source.
5. **MiMC Permutation and zk-SNARK Verifiability (Theorem 5):** We prove that the MiMC round polynomial $x \mapsto (x + k + c)^5$ is injective under explicit `Nat.Prime` / `Nat.Coprime` hypotheses (the only concrete instantiation is a small-prime sanity check; BN254 exponent coprimality is discharged concretely, with `Nat.Prime r` left as an explicit hypothesis), and formalize an $O(1)$ scale-invariant Groth16 verifier cost **model** — a constant operation count, not a soundness proof. In addition, we give a **proper reduction for the Schnorr/Ed25519 identification protocol** (`SchnorrReduction.lean`): special soundness (two accepting transcripts with the same commitment and different challenges recover the key), honest-verifier zero-knowledge, and a forger-implies-discrete-log reduction modulo an explicit forking-lemma hypothesis. A full Groth16/q-SDH formalization remains out of reach: Mathlib has no pairing or computational-hardness machinery. Separately, we prove the Edwards→Montgomery→Weierstrass addition-law bridge over an arbitrary field (§12, matrix row 47): the $x_3=0$ torsion case, twisted-Edwards completeness under `IsSquare (-1)` and nonsquare $d$, and a conditional associativity theorem for the concrete `affineAdd`.
6. **Robbins-Siegmund Stochastic Convergence (Theorem 6):** We formalize non-IID SGD descent inequalities and machine-check the Robbins-Siegmund almost-supermartingale lemma, as a **deterministic** limit statement about nonnegative almost-supermartingales; stochastic convergence is a corollary under the model's conditions, not a theorem about the deployed optimizer.
7. **PQC Migration Non-Hijack Invariants (Theorems 7 & 8):** We formalize a UF-CMA adversarial game and verify *structural* invariants of state ledger transitions across cutover epochs; the named theorems are conditional on UF-CMA hardness and on witnessed acceptance.
8. **Grounded Swarm Evaluation & Traceability:** We evaluate the Go runtime across single-host Kind Kubernetes clusters (up to 500 pods), CI swarm matrices (500–1,500 nodes), and a 1,000-node simulator target under safe (10% Byzantine) and edge (35% Byzantine) attacks, demonstrating $30.63\ \mu\text{s}$ Multi-Krum execution, 86.4% CIFAR-10 accuracy (1.8% gap vs. clean), and sub-400ms round latencies. Claims are tracked in an automated CI traceability matrix that records each claim's status — including those that are surrogates or empirical rather than fully formalized.

---

## 2. System Architecture and Threat Model

### 2.1 Four-Tier Topological Hierarchy
Sovereign-Mohawk structures participant devices into a four-tier aggregation tree parameterized by branching factor $b = 10$, designed to scale to an operational capacity of $10^7$ edge participants:

```
[Tier 4: Global Orchestrator] (N=1, Commits state to ledger, finalizes theta_{t+1})
                 ^
                 | (20 Continental Streams)
[Tier 3: Continental Gateways] (N=20, Verifies Groth16 proofs over MiMC commitments)
                 ^
                 | (10 Regional Streams per Gateway)
[Tier 2: Regional Aggregators] (N=200, Executes Multi-Krum filtering over c=50,000 leaves)
                 ^
                 | (50,000 Edge Gradient Vectors per Regional Committee)
[Tier 1: Edge Device Population] (N=10,000,000, Local SGD, RDP Gaussian Noise, Paillier/FP32)
```

* **Tier 1 (Edge Devices, $L_1$):** Millions of edge nodes execute local stochastic gradient descent (SGD) over private data shards. Nodes apply local differential privacy noise and homomorphically encrypt or compress gradient updates. Synchrony bound $\Delta_1 = 30\text{ s}$.
* **Tier 2 (Regional Aggregators, $L_2$):** Aggregators collect gradient batches from local edge clusters ($c = 50,000$), execute Multi-Krum Byzantine filtering, and compute intermediate aggregated vectors. Synchrony bound $\Delta_2 = 150\text{ s}$.
* **Tier 3 (Continental Gateways, $L_3$):** Gateways perform cross-regional aggregation, verifying succinct zero-knowledge validity proofs (Groth16/BN254) submitted by Tier 2 aggregators. Synchrony bound $\Delta_3 = 600\text{ s}$.
* **Tier 4 (Global Orchestrator, $L_4$):** The root orchestrator synthesizes continental updates into the new global model parameter vector $\theta_{t+1}$ and commits the round state to an append-only token ledger.

| Tier Level | Nominal Count | Fan-in ($b$) | Sync Bound ($\Delta$) | Cryptographic / Statistical Primitive |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 ($L_1$ Edge)** | $10,000,000$ | --- | $30\text{ s}$ | Gaussian RDP ($\sigma^2$), Local Clipping |
| **Tier 2 ($L_2$ Regional)** | $200$ | $50,000$ | $150\text{ s}$ | Multi-Krum ($2f < n$), Paillier-2048 |
| **Tier 3 ($L_3$ Continental)** | $20$ | $10$ | $600\text{ s}$ | Groth16/BN254 Pairing, MiMC-5 Hash |
| **Tier 4 ($L_4$ Global)** | $1$ | $20$ | Eventual | Hybrid X25519-ML-KEM-768, XMSS Ledger |

*Table 1: Four-Tier Topological Parameters, Capacities, and Security Controls.*

### 2.2 Network and Adversary Model
We adopt the partially synchronous network model of Dwork, Lynch, and Stockmeyer [3], assuming a Global Stabilization Time (GST) after which message delivery delays between honest nodes are strictly bounded by tier-specific thresholds $\Delta_t$.

> **Definition 1 ($(f, d)$-Byzantine Adversary):** An adversary controls up to $f$ participant nodes across the network and may arbitrarily delay up to $d$ honest messages per tier by at most $\Delta_{\text{adv}}$. Corrupted Byzantine nodes may deviate arbitrarily from the protocol:
> 1. *State Manipulation:* Injecting malicious gradient vectors designed to maximize model divergence or introduce targeted backdoors.
> 2. *Equivocation:* Transmitting conflicting model updates to different regional aggregators.
> 3. *Collusion:* Sharing full parameter states and coordinating update vectors across arbitrary aggregation tiers.
> 4. *Adaptive Straggling:* Withholding updates or timing message delivery to maximize straggler penalties and induce timeout stalls.

Cryptographic primitives (Groth16/BN254 pairing groups, MiMC hash functions, XMSS stateful hash signatures, and ML-KEM-768 lattice encapsulations) are assumed computationally unforgeable under standard hardness assumptions (q-SDH, DLP, MLWE).

```
====================================================================================================
Algorithm 1: Multi-Krum Local Aggregation Filtering
====================================================================================================
Input:  Gradient set G = {g_1, g_2, ..., g_n}, Byzantine bound f satisfying n >= 2f + 3,
        selection parameter m.
Output: Aggregated gradient vector \tilde{g}.
1: Set default selection size m <- n - f - 2;
2: for each gradient g_i in G do
3:     Find the m nearest neighbors of g_i in G \ {g_i}, denoted NN(g_i, m);
4:     Compute Euclidean distance score:
             s_i <- sum_{g_j in NN(g_i, m)} ||g_i - g_j||^2;
5: end for
6: Sort candidate indices by ascending score: s_{\pi(1)} <= s_{\pi(2)} <= ... <= s_{\pi(n)};
7: Select index set of lowest scores: S <- {\pi(1), \pi(2), ..., \pi(m)};
8: return \tilde{g} <- (1/m) * sum_{i in S} g_i;
====================================================================================================
```

### 2.3 Scope Boundaries

Three boundaries are relevant throughout, and §3 states them as an explicit
claim-status taxonomy rather than leaving them implicit:

1. **Topological vs. empirical scale.** The $10^7$ figure is strictly a topological
   design capacity parameter ($T=200, c=50,000$). Empirical testbed measurements are
   conducted on single-host Kind Kubernetes clusters up to 500 active pods, CI swarm
   matrices from 500 to 1,500 container nodes, and 1,000-node Python simulator runs.
2. **Assumption boundaries.** The formalization is **axiom-free** (`#print axioms`
   reports only Mathlib's foundation: `propext`, `Classical.choice`, `Quot.sound`).
   What remains are explicit hypotheses at each use site — `FloatOrderLaws`
   (IEEE-754 non-NaN order), `Fact (Nat.Prime dlL)`, `SchnorrDLHard` (an explicit
   discrete-log hardness `def`) and `Ed25519GroupLaws` (four explicit curve-model
   laws). The Edwards↔Montgomery↔Weierstrass bridge is now proved over an
   arbitrary field, including the torsion case and completeness under
   `IsSquare (-1)` and `¬ IsSquare d`; the concrete `affineAdd` is associative
   only conditionally. The Gaussian mechanism's Rényi divergence is **derived**, not assumed:
   `gaussianRDPBound_measure` obtains $D_\alpha = \alpha\Delta^2/(2\sigma^2)$
   unconditionally from a proved completed-square integral (§6.1). Groth16
   succinctness is an abstract constant-operation model, not a pairing-based
   proof. §3.3 restates this precisely.
3. **Traceability.** Every claim in this paper maps to an entry in our machine-readable
   formal traceability matrix (`FORMAL_TRACEABILITY_MATRIX.md`), which records the
   Lean module, the runtime evidence and the claim's status. Not every entry is
   `fully_formalized`; several are surrogates, models or empirical correspondences,
   and the matrix says so per row. The status vocabulary is defined in §3.1.

---

## 3. Claim Status and Epistemic Scope

This paper makes claims of different strengths. Rather than let "machine-checked" do
all the work in the abstract, we state once, explicitly, what *kind* of claim each
result is, and we repeat that status per claim in
`proofs/FORMAL_TRACEABILITY_MATRIX.md` (§12).

### 3.1 A status taxonomy

| Status | Meaning | Example in this paper |
| --- | --- | --- |
| `fully_formalized` | Proved in Lean 4 from stated definitions and hypotheses; `#print axioms` reports only Mathlib's foundation | the local guard arithmetic (§4), the composition counterexample (§4), the Chernoff repair (§5) |
| `model_verified` / `surrogate_verified` | Proved, but *about a model* that is not the runtime object | the constant-operation Groth16 cost model (§8.3); the integer/rational additive RDP ledger (§6.1) |
| `structural` | Invariants proved about a state machine, conditional on a hardness assumption that is not itself formalized | PQC non-hijack (§10) |
| `circuit_relation_modeled` | The proof system's accepted (statement, witness) pairs are modelled and proved; the cryptographic soundness of the proof system is not | `WeightUpdateCircuit` (§8.4) |
| `group_law_partially_formalized` | Field-level compatibility, completeness and conditional associativity are proved; an unconditional group law for the concrete implementation is not | Edwards↔Montgomery bridge and conditional `affineAdd` associativity (§12, matrix row 47) |
| `empirical` | Measured or pinned against the runtime, not proved across it | Go↔Lean correspondences (§7, §11), the Kind scale numbers (§13) |

### 3.2 Model vs. runtime

Three distinct objects are easy to conflate, and conflating them is the single most
common way a formal-methods paper overclaims:

1. **The runtime object** — Go code that actually executes.
2. **A Lean model of it** — definitions in `proofs/` intended to describe it.
3. **A proof about the model.**

Only (3) is machine-checked. (2) is validated by pinned `#eval` vectors and replayed
traces, because **Lean cannot invoke Go source**: there is no machine-checked
cross-language equality anywhere in this development. When this paper says a theorem
"corresponds to" a Go function, it means a transcription of the Lean definition was
checked against the Go output on specific inputs — not that the two were proved
equal, and not that they agree on all inputs.

### 3.3 Axioms and hypotheses

The Lean development is **axiom-free, sorry-free, and free of `native_decide`**:
`#print axioms` over the development reports only Mathlib's foundation
(`propext`, `Classical.choice`, `Quot.sound`). What remains are
explicit hypotheses at each use site: `FloatOrderLaws` (IEEE-754 non-NaN order,
§11), `Fact (Nat.Prime dlL)`, `Nat.Prime bn254Prime` for the BN254 MiMC
instantiation (§8.2), `SchnorrDLHard` (an explicit discrete-log hardness `def`),
and `Ed25519GroupLaws affineBase` (four explicit curve-model laws; `zeroMul` and
`oneMul` were removed as unconsumed). For the Edwards bridge (§12), `IsSquare (-1)`
is proved from $p \equiv 1 \pmod 4$, but `Nat.Prime ed25519P`, nonsquareness of
`ed25519D`, and the admissibility/distinctness conditions of the field
associativity theorem remain explicit hypotheses. No global `axiom` is used, and no proof
uses `sorry` or `admit`.

### 3.4 What is deliberately not claimed

- **Groth16 / q-SDH soundness is not formalized.** Mathlib has no pairing or
  computational-hardness machinery; the feasibility scout is recorded in
  `proofs/theorem_claims.json`. The circuit relation (§8.4) is proved *about*
  the proof system, not a soundness proof *of* it.
- **MiMC collision resistance is not formalized.** What is proved is the algebraic
  injectivity of the round function under explicit prime/coprimality hypotheses
  (§8.2).
- **The trusted setup is an in-process simulated ceremony** (`mpcSetupBN254`), not a
  distributed ceremony over independent machines. It is a development key.
- **The SDK benchmark's advertised 10 ms figure is a `time.sleep`.** The measured
  verification cost is 0.675 ms and proving is 38 ms (§8.4). Retraction of the
  stale figure across the documentation is pending.
- **Unconditional Ed25519 group associativity is not claimed.**
  `affineAdd_associative_of_complete` is conditional on primality of $p$,
  nonsquareness of $d$, on-curve equations, canonical coordinates, branch
  exclusions, and admissibility/distinctness conditions. Neither
  `Nat.Prime ed25519P` nor `¬ IsSquare (ed25519D : ZMod ed25519P)` is proved in
  the repository. Nonsquareness of $d$ alone is insufficient for completeness:
  the machine-checked negative control over $\mathbb{F}_{11}$ uses $d=2$.

---

## 4. Machine-Checked Disproof of Deterministic Hierarchical Composition

### 4.1 Single-Tier Byzantine Filtering Guard
At a single aggregation tier receiving $n$ candidate gradient updates, Algorithm 1 guarantees that if the Byzantine node count $f$ satisfies the honest-majority condition, the selected aggregate is bounded within a Euclidean hyper-sphere centered at the true mean of honest updates [2]. In Lean 4 (`LeanFormalization/Theorem1BFT.lean`), we formalize the local guard condition:
$$\mathcal{G}_{\text{local}}(n, f) \equiv (2f < n) \land (9f < 5n)$$

The condition $2f < n$ establishes strict honest majority, while $9f < 5n$ is the single-tier 5/9 profile guard arithmetic checked for concrete configurations — a per-tier, guard-conditional fact, not a global Byzantine tolerance.

### 4.2 The Inductive Composition Fallacy
Let a tree hierarchy have $L$ levels, where level $l$ contains $T_l$ aggregators. It has been conjectured across the distributed FL literature that if $\mathcal{G}_{\text{local}}(n_{l,i}, f_{l,i})$ holds for every aggregator $i$ at every level $l$, the overall network satisfies a global Byzantine tolerance bound $f_{\text{global}} / n_{\text{global}} < 1/2$.

The mathematical flaw in this inductive hypothesis lies in information hiding at aggregation boundaries: a parent aggregator only receives a single filtered vector from each child committee. The parent cannot distinguish whether a child committee was 100% honest or 49% Byzantine; in both cases, the child's local guard passes, and the child's output is credited with full committee weight. An adversary exploiting this asymmetry can concentrate honest nodes into sacrificial subtrees while overloading other branches.

### 4.3 Lean 4 Formalization of the Counterexample
To formally invalidate deterministic composition, we define an inductive aggregation tree data structure in Lean 4:

```lean
inductive HTree where
  | leaf (byzantine : Bool)
  | node (children : List HTree)

mutual
/-- Total leaf count in the subtree. -/
def HTree.totalLeaves : HTree -> Nat
  | .leaf _ => 1
  | .node cs => HTree.totalLeavesList cs

def HTree.totalLeavesList : List HTree -> Nat
  | [] => 0
  | c :: cs => c.totalLeaves + HTree.totalLeavesList cs
end

mutual
/-- True (ground-truth) count of Byzantine leaves in the subtree. -/
def HTree.byzantineLeaves : HTree -> Nat
  | .leaf b => if b then 1 else 0
  | .node cs => HTree.byzantineLeavesList cs

def HTree.byzantineLeavesList : List HTree -> Nat
  | [] => 0
  | c :: cs => c.byzantineLeaves + HTree.byzantineLeavesList cs
end

mutual
/-- Leaf-weight credited by a parent applying the weighted local-majority rule:
    a node is credited the sum of each child's full leaf count if that child
    is itself locally safe, else 0. -/
def HTree.safeLeafWeight : HTree -> Nat
  | .leaf b => if b then 0 else 1
  | .node cs => HTree.safeLeafWeightList cs

def HTree.safeLeafWeightList : List HTree -> Nat
  | [] => 0
  | c :: cs =>
      (if 2 * c.safeLeafWeight > c.totalLeaves then c.totalLeaves else 0)
      + HTree.safeLeafWeightList cs
end

def HTree.safe (t : HTree) : Prop :=
  2 * t.safeLeafWeight > t.totalLeaves
```

In the formalization above, `HTree.safeLeafWeight` formalizes the recursive credit assigned by a parent: if a child satisfies the local majority guard ($2 \times \text{safeLeafWeight} > \text{totalLeaves}$), the parent credits the child with its *entire* leaf count.

```
                      +---------------------------------------+
                      |                 Root                  |
                      | Total: 5, Byz: 3 (60%), SafeWeight: 3 |
                      | Guard: 2 * 3 > 5 (6 > 5) -> PASS      |
                      +---------------------------------------+
                                     /         \
                                    /           \
         +-----------------------------+     +-----------------------------+
         |         Committee A         |     |         Committee B         |
         | Total: 3, Byz: 1, Honest: 2 |     | Total: 2, Byz: 2, Honest: 0 |
         | Guard: 2 * 2 > 3 -> PASS    |     | Guard: 2 * 0 > 2 -> FAIL    |
         | (Credited Weight: 3)        |     | (Credited Weight: 0)        |
         +-----------------------------+     +-----------------------------+
                   /    |    \                           /    \
                  /     |     \                         /      \
               Hon(1) Hon(2) Byz(1)                  Byz(2)  Byz(3)
```

> **Counterexample 1 (Machine-Checked Composition Counterexample):** Consider a two-level aggregation tree containing $N = 5$ leaves structured into two sub-committees $A$ and $B$:
> * *Committee $A$:* Contains 2 honest leaves and 1 Byzantine leaf ($c_A = 3, f_A = 1$). The local guard requires $2 \times 2 > 3$ (4 > 3), which evaluates to `true`.
> * *Committee $B$:* Contains 0 honest leaves and 2 Byzantine leaves ($c_B = 2, f_B = 2$). The local guard evaluates to `false`.
> * *Root Aggregator:* Evaluates children $A$ and $B$. Since $A$ is safe, it receives full weight 3; $B$ receives weight 0. Total safe weight is 3. Root guard checks $2 \times 3 > 5$ (6 > 5), which evaluates to `true`.
> Across the global tree, total leaves $N = 5$ and total Byzantine leaves $F = 1 + 2 = 3$. The global Byzantine fraction is $3/5 = 60\% > 50\%$.

The machine-checked Lean 4 proof compiles directly using `decide`:

```lean
def hierarchical_counterexample_A : HTree :=
  .node [.leaf false, .leaf false, .leaf true]

def hierarchical_counterexample_B : HTree :=
  .node [.leaf true, .leaf true]

def hierarchical_counterexample_Root : HTree :=
  .node [hierarchical_counterexample_A, hierarchical_counterexample_B]

theorem hierarchical_counterexample_A_safe :
    hierarchical_counterexample_A.safe := by
  unfold HTree.safe; decide

theorem hierarchical_counterexample_B_not_safe :
    ¬ hierarchical_counterexample_B.safe := by
  unfold HTree.safe; decide

theorem hierarchical_counterexample_Root_safe :
    hierarchical_counterexample_Root.safe := by
  unfold HTree.safe; decide

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

### 4.4 Structural Implications
This formal result proves that deterministic hierarchical composition is structurally unsound under adversarial node placement. Adjusting per-tier thresholds (e.g., requiring $3f < n$ or $4f < n$) merely changes the numeric constants of the counterexample without curing the vulnerability: so long as a passed committee is granted full leaf weight by a parent aggregator that cannot inspect its inner constituent gradients, an adversary can pack Byzantine nodes just below the child threshold while abandoning other committees, driving the global Byzantine ratio arbitrarily close to the per-tier filter limit.

---

## 5. Probabilistic Composition Repair and Machine-Checked Chernoff Bounds

### 5.1 Probabilistic Sampling Model
To restore provable hierarchical resilience, we replace deterministic node assignment with a randomized assignment protocol. Let participants be assigned to $T$ regional committees of capacity $c$ via an explicit independently and identically distributed (i.i.d.) Bernoulli process with parameter $p = \mathbb{P}(\text{Byzantine})$. Under this model, the number of Byzantine nodes $X$ in any committee follows a binomial distribution $\text{Bin}(c, p)$.

The probability that a given committee exceeds its Byzantine filtering tolerance threshold $k$ (where $k = \lceil c/2 \rceil$ for honest majority) is governed by the binomial tail:
$$\text{binomialTail}(c, k, p) = \sum_{j=k}^c \binom{c}{j} p^j (1-p)^{c-j}$$

The system failure probability $P_{\text{fail}}$ across the entire hierarchy of $T$ committees is bounded by Boole's inequality (union bound):
$$P_{\text{fail}} = \mathbb{P}\left(\bigcup_{i=1}^T \{X_i \ge k\}\right) \le 1 - (1 - \text{binomialTail}(c, k, p))^T \le T \cdot \text{binomialTail}(c, k, p)$$

### 5.2 First-Principles Proof of Binomial Mean in Lean 4
Before bounding the tail, the expectation of a binomial distribution must be formally established. Because Mathlib's distribution library lacked a constructive proof for $\mathbb{E}[\text{Bin}(n, p)] = np$, we formalize the theorem from first principles in Lean 4 using the absorption identity $\binom{n}{i} i = n \binom{n-1}{i-1}$ and the binomial theorem `add_pow`:

```lean
theorem binomial_mean (n : ℕ) (p : ℚ) :
    ∑ i ∈ Finset.range (n + 1),
      (i : ℚ) * ((n.choose i : ℚ) * p ^ i * (1 - p) ^ (n - i)) =
    (n : ℚ) * p := by
  rcases n with _|n
  · simp
  · have hshift : ∑ i ∈ Finset.range (n + 2),
        (i : ℚ) * ((Nat.choose (n + 1) i : ℚ) * p ^ i * (1 - p) ^ (n + 1 - i)) =
      ((n + 1 : ℚ) * p) * ∑ j ∈ Finset.range (n + 1),
        (Nat.choose n j : ℚ) * p ^ j * (1 - p) ^ (n - j) := by ...
    rw [hshift]
    have hsum := add_pow p (1 - p) n
    have h1 : p + (1 - p) = 1 := by ring
    rw [h1, one_pow] at hsum
    rw [hsum.symm]
    ring
```

### 5.3 The Insufficiency of Markov's Inequality at Scale
Applying Markov's inequality $\mathbb{P}(X \ge k) \le \frac{\mathbb{E}[X]}{k} = \frac{cp}{k}$ yields a polynomial concentration bound formalized as `binomial_markov` in Lean 4:
$$P_{\text{fail}} \le T \cdot \frac{c \cdot p}{k}$$

While valid at small scales, we prove in Lean 4 that this bound is completely vacuous at production deployment scale. For $T = 200$ committees of capacity $c = 50,000$, global adversary proportion $p = 0.10$, and majority threshold $k = 25,000$:
$$T \cdot \frac{c \cdot p}{k} = 200 \cdot \frac{50,000 \times 0.10}{25,000} = 200 \cdot \frac{5,000}{25,000} = 40$$

Because a probability upper-bound of 40 exceeds 1, it provides zero assurance. In Lean 4, we machine-checked this exact limitation:
```lean
theorem probabilistic_bound_too_loose_at_deployment_scale :
    (200 : ℚ) * (50000 : ℚ) * (1 / 10) / 25000 = 40 := by
  norm_num
```

### 5.4 Machine-Checked Rational Chernoff Bounds
To overcome the polynomial decay limitation without importing non-computable transcendental real analysis into Lean 4's kernel, we formalize an exponential-moment Chernoff bound using an arbitrary rational base $z \ge 1$.

> **Definition 2 (Rational Chernoff Bound at Base $z$):** For rational base $z \ge 1$, trials $n$, threshold $k$, and success probability $p \in [0, 1]$, the rational Chernoff function is defined over $\mathbb{Q}$:
> $$\text{chernoffBoundZ}(n, k, p, z) \equiv \frac{(1 - p + p \cdot z)^n}{z^k}$$

> **Theorem 1 (Machine-Checked Rational Chernoff Tail Bound):** For any $n, k \in \mathbb{N}$, $p \in \mathbb{Q}$ with $0 \le p \le 1$, and rational base $z \in \mathbb{Q}$ with $z \ge 1$:
> $$\text{binomialTail}(n, k, p) \le \text{chernoffBoundZ}(n, k, p, z)$$

*Proof:* In Lean 4 (`Theorem1BFT.lean`, lines 499–541), we prove this by weighting the tail sum by $z^k \le z^i$ for all $i \ge k$:
$$z^k \sum_{i=k}^n \binom{n}{i} p^i (1-p)^{n-i} \le \sum_{i=k}^n z^i \binom{n}{i} p^i (1-p)^{n-i} \le \sum_{i=0}^n \binom{n}{i} (p z)^i (1-p)^{n-i} = (1 - p + p z)^n$$
Dividing both sides by $z^k > 0$ yields the result. The identity is discharged in Lean 4 using `Finset.sum_le_sum`, `add_pow`, and `linarith`. $\blacksquare$

```lean
def chernoffBoundZ (n k : ℕ) (p z : ℚ) : ℚ :=
  (1 - p + p * z) ^ n / z ^ k

theorem binomialTail_le_chernoffBoundZ (n k : ℕ) (p z : ℚ)
    (hz : 1 ≤ z) (hp0 : 0 ≤ p) (hp1 : p ≤ 1) :
    binomialTail n k p ≤ chernoffBoundZ n k p z := by ...
```

### 5.5 Deployment-Scale Certification
At the target deployment parameters of Sovereign-Mohawk ($T = 200$ committees, $c = 50,000$ leaves per committee, $p = 1/10$, threshold $k = 25,000$), we instantiate base $z = 2$:
$$\text{chernoffBoundZ}\left(50000, 25000, \frac{1}{10}, 2\right) = \frac{\left(1 - \frac{1}{10} + \frac{2}{10}\right)^{50000}}{2^{25000}} = \frac{\left(\frac{11}{10}\right)^{50000}}{2^{25000}}$$

Evaluating this rational fraction directly involves integer numerators and denominators spanning more than 5,000 decimal digits, and `norm_num` does not decide the resulting inequality in reasonable time. The proof avoids both that blow-up and any trusted reflection. Both sides of
$$\frac{(11/10)^{50000}}{2^{25000}} \le \frac{1}{10^{1000}}$$
are $1000$th powers: $\frac{(11/10)^{50000}}{2^{25000}} = \left(\frac{(11/10)^{50}}{2^{25}}\right)^{1000}$ and $\frac{1}{10^{1000}} = \left(\frac{1}{10}\right)^{1000}$. Applying `pow_le_pow_iff_left₀` reduces the goal to $\frac{(11/10)^{50}}{2^{25}} \le \frac{1}{10}$, i.e. $11^{50} \le 2^{74} \cdot 5^{49}$ — a comparison of a 53-digit and a 57-digit integer that `norm_num` decides outright. The entire development is kernel-checked, with no `native_decide`.

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
  -- It remains to show `(11/10)^50 / 2^25 ≤ 1/10`.
  have hkey : (11 : ℚ) ^ 50 ≤ 2 ^ 74 * 5 ^ 49 := by norm_num
  have h1 : (11/10 : ℚ)^50 / 2^25 = 11^50 / (2^75 * 5^50) := by
    rw [div_pow, div_div]
    have h10 : (10 : ℚ) ^ 50 = 2^50 * 5^50 := by
      rw [show (10 : ℚ) = 2 * 5 by norm_num, mul_pow]
    rw [h10]
    ring
  rw [h1]
  rw [div_le_iff₀ (by positivity : (0 : ℚ) < 2^75 * 5^50)]
  ring_nf
  norm_num

theorem chernoff_hierarchical_bound_deployment_scale :
    1 - (1 - binomialTail 50000 25000 (1/10 : ℚ)) ^ 200
      ≤ (200 : ℚ) / 10 ^ 1000 := by
  have h := chernoff_hierarchical_bound 200 50000 25000 (1/10 : ℚ) 2
    (by norm_num) (by norm_num) (by norm_num)
  have hbound := chernoffBoundZ_deployment_scale_tiny
  calc 1 - (1 - binomialTail 50000 25000 (1/10 : ℚ)) ^ 200
      ≤ (200 : ℚ) * chernoffBoundZ 50000 25000 (1/10 : ℚ) 2 := h
    _ ≤ (200 : ℚ) * (1 / 10 ^ 1000) := by nlinarith [hbound]
    _ = (200 : ℚ) / 10 ^ 1000 := by ring
```

As certified above, the probability of any tier experiencing a Byzantine failure is bounded by $\frac{200}{10^{1000}} = 2 \times 10^{-998}$. This machine-checked result bounds the failure probability of randomized committee assignment under the explicit i.i.d. Bernoulli model; it does not address adversarial placement, and no deployment-scale empirical validation of that bound is possible.

---

## 6. Multi-Tier Rényi Differential Privacy and Constructivist Logarithm Bounds

### 6.1 Rényi Differential Privacy Formulation
Privacy preservation is enforced using Rényi Differential Privacy (RDP) [4]. For order $\alpha > 1$, the Rényi divergence between output distributions $P$ and $Q$ induced by adjacent datasets $D, D'$ is defined as:
$$D_\alpha(P \parallel Q) = \frac{1}{\alpha - 1} \ln \mathbb{E}_{x \sim Q}\left[\left(\frac{P(x)}{Q(x)}\right)^\alpha\right]$$

A randomized mechanism $\mathcal{M}$ satisfies $(\alpha, \epsilon)$-RDP if $D_\alpha(\mathcal{M}(D) \parallel \mathcal{M}(D')) \le \epsilon$. For a Gaussian mechanism adding noise $\mathcal{N}(0, \sigma^2 \mathbf{I})$ calibrated to $L_2$ gradient sensitivity $\Delta_2$, the privacy cost is $\epsilon_{\text{RDP}}(\alpha) = \frac{\alpha \Delta_2^2}{2 \sigma^2}$.

**This bound is machine-derived, not asserted.** `gaussianRDP_integral` proves the completed-square identity $\int q^\alpha / p^{\alpha-1} = \exp(\alpha(\alpha-1)\Delta^2/(2\sigma^2))$ from Mathlib's `integral_gaussian` and a proved translation-invariance lemma, and `gaussianRDPBound_measure` derives $D_\alpha = \alpha\Delta^2/(2\sigma^2)$ unconditionally (only $\sigma \ne 0$, $\alpha \ne 1$) in the scalar case (matrix row 34). It supersedes an earlier existence witness that exhibited the value without deriving it.

In Lean 4 (`Theorem2RDP.lean`), we formally prove independent mechanism composition: if mechanism $\mathcal{M}_1$ satisfies $(\alpha, \epsilon_1)$-RDP and $\mathcal{M}_2$ satisfies $(\alpha, \epsilon_2)$-RDP on independent executions, their joint output satisfies $(\alpha, \epsilon_1 + \epsilon_2)$-RDP via exact tensorization of product distributions:
$$D_\alpha(P_1 \otimes P_2 \parallel Q_1 \otimes Q_2) = D_\alpha(P_1 \parallel Q_1) + D_\alpha(P_2 \parallel Q_2)$$

This tensorization was subsequently lifted from the counting measure to an
arbitrary **product measure** (`renyiDivergenceMeasure_prod`, matrix row 35), so it
holds for continuous output distributions and not only finite-support ones; §6.4
states it and its consumer.

### 6.2 Constructivist Challenge of $(\epsilon, \delta)$-DP Conversion
To map accumulated RDP guarantees to standard $(\epsilon, \delta)$-differential privacy, the runtime applies the canonical transformation:
$$\epsilon(\delta) = \epsilon_{\text{RDP}} + \frac{\ln(1/\delta)}{\alpha - 1}$$

However, the natural logarithm function $\ln(z)$ is transcendental and non-computable in constructivist kernel logic. A proof assistant kernel cannot evaluate $\ln(10^5)$ directly to verify numeric budget guards.

### 6.3 Machine-Checked Two-Sided Rational Sandwich
We resolve this limitation in `proofs/Refinement/RDPLogBound.lean` by formalizing a verified two-sided rational interval sandwich over positive rationals $\mathbb{Q}^+$.

We decompose $x = 1/\delta$ into a dyadic component $2^k$ and a residual $r \in [1, 2)$ such that $x = 2^k \cdot r$. Then:
$$\ln(x) = k \ln(2) + \ln(r)$$

Applying first-order Taylor bounds and concavity for $r \in [1, 2)$:
$$1 - \frac{1}{r} \le \ln(r) \le r - 1$$

We formalize verified rational bounds for $\ln(2)$ using the convergent rational fraction $\frac{287209}{414355} \approx 0.69314718056$:
$$\left|\ln(2) - \frac{287209}{414355}\right| \le 10^{-10}$$

```lean
def logLowerRat (k : ℕ) (r : ℚ) : ℚ :=
  (k : ℚ) * (287209 / 414355) - (k : ℚ) / 10 ^ 10 + (1 - r⁻¹)

def logUpperRat (k : ℕ) (r : ℚ) : ℚ :=
  (k : ℚ) * (287209 / 414355) + (k : ℚ) / 10 ^ 10 + (r - 1)

def epsLowerRat (k : ℕ) (r : ℚ) : ℚ := logLowerRat k r / 9
def epsUpperRat (k : ℕ) (r : ℚ) : ℚ := logUpperRat k r / 9
```

| Target $\delta$ | Witness $k$ | Residual $r$ | Lean 4 Lower Bound | Lean 4 Upper Bound |
| :--- | :--- | :--- | :--- | :--- |
| **$10^{-3}$** | $9$ | $1000 / 512$ | $0.751142$ | $0.852467$ |
| **$10^{-5}$** | $16$ | $100000 / 65536$ | $1.264210$ | $1.312948$ |
| **$10^{-8}$** | $26$ | $10^8 / 67108864$ | $2.012480$ | $2.081190$ |

*Table 2: Rational Sandwich Bounds for $\frac{\ln(1/\delta)}{\alpha-1}$ at $\alpha = 10$.*

Table 2 records the exact rational bounding intervals certified by Lean 4 for production $\delta$ targets. In our Go runtime, the RDP accountant embeds these literal `big.Rat` constants to gate model dissemination without floating-point drift.

### 6.4 Measure-Theoretic Composition and Two-Round Gaussian Accounting

`renyiDivergenceMeasure_prod` states the tensorization over an arbitrary product
measure: for nonnegative densities $p_1, q_1$ on $(\alpha, \mu)$ and $p_2, q_2$ on
$(\beta, \nu)$ with positive marginal integrands,

$$D_\alpha(p_1 \otimes p_2 \parallel q_1 \otimes q_2) = D_\alpha(p_1 \parallel q_1) + D_\alpha(p_2 \parallel q_2)$$

holds w.r.t. the product measure $\mu \cdot \nu$. The proof factors the integrand
(`Real.mul_rpow`), applies `MeasureTheory.integral_prod_mul`, and sums the
logarithms (`Real.log_mul`). The consumer is `gaussianRDPMeasure_two_rounds`: two
independent rounds of the scalar Gaussian mechanism have divergence
$2 \cdot \alpha\Delta^2/(2\sigma^2)$, obtained by composing the derived bound of
§6.1 with the tensorization.

**Scope, stated openly.** This is *independent* composition — the base measure is a
product measure. Adaptive composition, where the second mechanism's output
distribution depends on the first mechanism's realized output, is not covered
here; `Theorem2RDP.RDP_adaptive_composition` covers the finite-support case with a
worst-case bound. `renyiDivergenceMeasure_prod_positivity_needed` is the negative
control showing the marginal-integral positivity hypotheses are load-bearing: with
a zero marginal integral the claimed equality would read $\log 0 = \log 0 + \log 4$.

A self-contained summary of the four headline results — the hierarchical negative
result and Chernoff repair, the Ed25519 UF-CMA composition, the Gaussian RDP
derivation, and this composition result — is in
[`FORMAL_RESULTS_SUMMARY.md`](FORMAL_RESULTS_SUMMARY.md).
---

## 7. Communication Complexity and Wire-Format Refinement

### 7.1 Hierarchical Routing Path Depth
In flat federated learning topologies, communicating parameter updates between $n$ participants and a central parameter server requires $O(n)$ point-to-point connections, creating severe network bottlenecks. In `Theorem3Communication.lean`, we formalize hierarchical routing complexity.

> **Theorem 2 (Logarithmic Path-Depth Complexity):** For a balanced tree topology of depth $d$ with branching factor $b \ge 2$, the maximum path depth traversed by any gradient update is strictly bounded by $O(d \log_b n)$.

In Lean 4, we machine-check that the hierarchical tree reduces message hops from $O(n)$ to $O(d)$:
```lean
def hierarchical_comm_complexity (d : Nat) (n : Nat) (b : Nat) : Nat :=
  if b > 1 then d * (Nat.log b n + 1) else 0

/-- Naive FedAvg communication: O(d * n). -/
def naive_fedavg_comm (d n : Nat) : Nat := d * n
```

This is a **path-depth proxy**: it bounds the number of hops a single gradient
traversal makes, not total bytes on the wire. Total byte volume remains
model-dependent.

### 7.2 Wire-Format Refinement to Go Runtime
To prevent formal specification drift, we verify a concrete refinement relation connecting Lean 4's abstract transport specification to the Go production wire format. In `Refinement/Transport.lean`, we specify the total byte consumption of an aggregation round over $n$ participants with gradient dimension $D$:

> **Theorem 3 (Wire Serialization Exact Equality):** Under the IEEE-754 single-precision floating-point format (4 bytes per scalar element), the total wire consumption of a hierarchical aggregation round matches Go runtime serialization:
> $$\text{TotalBytes}(D, n) = 4 \cdot D \cdot (n + 1)$$
> accounting for $n$ client submissions and 1 orchestrator broadcast.

In continuous integration, `test/transport_byte_size_test.go` verifies that `unsafe.Sizeof(float32(0)) == 4` and binds the exact byte count produced by `pkg/transport` against the Lean 4 specification.

---

## 8. Zero-Knowledge Integrity via MiMC Hash Commitments and Flat Groth16

### 8.1 Untrusted Aggregator Threat
In a multi-tier hierarchy, Tier 2 (Regional) aggregators possess significant computational authority. A malicious Tier 2 aggregator could tamper with intermediate vector sums, reporting fraudulent aggregates that poison the global model while conforming to protocol schemas. To enforce verifiable computation without compromising privacy, regional aggregators must submit succinct zero-knowledge arguments of knowledge (zk-SNARKs).

### 8.2 MiMC Permutation Formalization over BN254
We base gradient vector commitments on the MiMC hash function [20], parameterized over the BN254 elliptic curve scalar field $\mathbb{F}_r$, where:
$$r = 21888242871839275222246405745257275088548364400416034343698204186575808495617$$

The round function of MiMC computes $F(x) = (x + k + c_i)^e \pmod r$, with exponent $e = 5$. A vital security property is that $F(x)$ must be an injective permutation over $\mathbb{F}_r$. **Scope caveat:** what is machine-checked is the *general algebraic lemma* — injectivity of $y \mapsto y^e$ on $\mathbb{Z}/p$ whenever $e$ is coprime to $p-1$ — not an instantiation at the BN254 scalar field, and not a MiMC collision-resistance proof.

In `Theorem5MiMCFormalization.lean`, we formalize and machine-check the algebraic injectivity of the MiMC round function (signatures verbatim from the source):

```lean
def mimcRound (p : Nat) (e : Nat) (c : ZMod p) (x : ZMod p) : ZMod p :=
  (x + c) ^ e

theorem pow_injective (p e : Nat) (hp : Nat.Prime p) (he : Nat.Coprime e (p - 1))
    (hepos : 0 < e) :
    Function.Injective (fun y : ZMod p => y ^ e) := by ...

theorem mimcRound_injective (p e : Nat) (hp : Nat.Prime p) (he : Nat.Coprime e (p - 1))
    (hepos : 0 < e) (c : ZMod p) :
    Function.Injective (mimcRound p e c) := by ...

/-- Concrete guard: over the small prime 7 with exponent 5. -/
theorem mimcRound_small_prime_guard :
    Function.Injective (mimcRound 7 5 (0 : ZMod 7)) := by ...
```

The small-prime instantiation $p = 7$ remains as a sanity check. **Update (2026-11-18):** the
injectivity lemma is now also stated at the BN254 scalar modulus
(`mimcRound_bn254_injective`). The exponent coprimality $\mathrm{Coprime}\,5\,(r-1)$
is discharged concretely by a mod-5 reduction; $\mathrm{Prime}\,r$ remains an
explicit hypothesis, because Mathlib's `Nat.Prime` decidability is trial division
and `native_decide` does not terminate in reasonable time (measured: >7 minutes
without completing). Everything else about the instantiation is machine-checked.

### 8.3 Scale-Invariant Verifier Cost Model
In `Theorem5Cryptography.lean`, we formalize an abstract Groth16 verification cost model [5]. Groth16 proofs over BN254 consist of three group elements ($A \in \mathbb{G}_1, B \in \mathbb{G}_2, C \in \mathbb{G}_1$), yielding an exact proof size of 128 bytes (uncompressed: 256 bytes). Verification requires evaluating a fixed pairing identity involving three pairing computations:
$$e(A, B) = e(\alpha, \beta) \cdot e\left(\sum_{i=0}^l v_i \gamma_i, \gamma\right) \cdot e(C, \delta)$$

We formalize a **constant-operation cost model** for Groth16 verification, scale-invariant with respect to total federated participant count $N$. **Scope caveat:** the model asserts a constant operation count by construction (`verifyOps` ignores its argument); it is a bookkeeping model, not a measurement of the production verifier and not a Groth16 soundness proof:
```lean
def verifyOps (_participants : Nat) : Nat := 3

theorem theorem5_constant_ops (n m : Nat) :
    verifyOps n = verifyOps m := by
  unfold verifyOps
  rfl
```

### 8.4 A Real Weight-Update Circuit (`WeightUpdateCircuit`)

The integrity goal of §8.1 is only meaningful if a verifier can check a
*proof* that an update was computed honestly. `internal/zkweight_circuit.go`
implements a gnark Groth16/BN254 circuit whose public statement is the six-element
`WeightStatement { ModelHashBefore, ModelHashAfter, DatasetCommitment,
GradNormBound, DPEpsilon, UpdateHash }` and whose private witness is
`{ Gradients[8], Noise[8], TrainingSteps }`. Components are signed Q32.32
fixed-point; the circuit range-checks each component and the norm bound.

The circuit constrains four relations, using gnark's MiMC over the BN254 scalar
field — the same permutation whose algebra is formalized in §8.2:

1. **Model hash chain.** `MiMC(ModelHashBefore, TrainingSteps, gradients…) =
   ModelHashAfter`, binding the gradient witness to the stated prior model state.
2. **Range and norm bound.** Per-component 64-bit range checks, then
   $\|g\|^2 \le \mathtt{GradNormBound}^2$.
3. **Update hash chain.** `MiMC(DPEpsilon, TrainingSteps, gradients…+noise…,
   DatasetCommitment) = UpdateHash`, binding the published update to the DP noise,
   the DP budget and the dataset commitment.
4. **Dataset binding.** `DatasetCommitment ≠ 0`.

`ModelHashAfter` and `UpdateHash` are *derived* by the prover's library
(`DeriveWeightStatement`), not supplied as free public inputs, so a prover cannot
choose them independently.

**Measured cost** (BN254, `results/zk/weight-proof-latest.json`): 9 569 constraints,
164-byte proof, verification **0.675 ms**, proving **38 ms** (mean over 200
iterations), one-time setup 41.4 s (39 ms compile + simulated MPC ceremony).
Verification is $O(1)$ in participant count: the aggregator's per-proof cost does
not grow with the network, which is what makes the §8.3 cost model plausible in
practice even though the model itself is a bookkeeping abstraction.

**Scope caveats (explicit).**

- What is machine-checked in Lean is the MiMC **injectivity lemma** (§8.2), not
  this circuit. The gnark constraint system is exercised in CI with positive and
  negative witnesses (`WeightUpdateProofSpec`, `zkweight_circuit_test.go`), and its
  accepted-pair relation is modelled and proved at the specification level. That is a
  statement about the circuit, not a q-SDH soundness proof for Groth16.
- The circuit proves the MiMC *relation* holds; it does not prove MiMC collision
  resistance.
- The trusted setup is the same in-process simulation noted in §8.1.

**Refinement status.** Row 22 of the traceability matrix (§12) records this as
`circuit_relation_modeled`, not `fully_formalized`.

---

## 9. Stochastic Non-IID Convergence under Robbins-Siegmund Supermartingales

### 9.1 Federated Non-IID Optimization Model
In heterogeneous edge settings, data distributions across participants are non-IID. We model the global optimization objective as $\min_{\theta \in \mathbb{R}^d} F(\theta) \equiv \frac{1}{K} \sum_{k=1}^K F_k(\theta)$, where client loss functions $F_k$ satisfy $L$-smoothness and bounded local gradient variance:
$$\mathbb{E}[\|\nabla F_k(\theta, \xi) - \nabla F_k(\theta)\|^2] \le \sigma^2, \quad \frac{1}{K} \sum_{k=1}^K \|\nabla F_k(\theta) - \nabla F(\theta)\|^2 \le \zeta^2$$

### 9.2 Descent Lemma and Supermartingale Inequality
In `DescentInequalityFull.lean`, we formalize a one-step descent inequality under client learning rate $\eta \le \frac{1}{2L}$ (the statement proved in `DescentInequalityFull.lean`, which differs from the classical textbook form in its hypotheses):
$$\mathbb{E}[F(\theta_{t+1}) \mid \mathcal{F}_t] \le F(\theta_t) - \frac{\eta}{2} \|\nabla F(\theta_t)\|^2 + \frac{\eta^2 L}{2} \left(\frac{\sigma^2}{K} + \zeta^2\right)$$

### 9.3 Robbins-Siegmund Deterministic Limit Proof
To establish asymptotic convergence, we formalize the Robbins-Siegmund almost-supermartingale theorem [21]. In `RobbinsSiegmundDeterministic.lean`, we prove from first principles that if sequence $V_k \ge 0$ converges to limit $L$ and step-sizes $a_k \ge 0$ satisfy $\sum a_k = \infty$ with $\sum a_k V_k < \infty$, the limit $L$ must be zero:

```lean
theorem robbins_siegmund_limit_zero
    (a V : ℕ -> ℝ)
    (ha : ∀ k, 0 ≤ a k) (hV : ∀ k, 0 ≤ V k)
    (hdiv : ¬ Summable a)
    (hsum : Summable (fun k => a k * V k))
    (L : ℝ) (hL : Tendsto V atTop (𝓝 L)) :
    L = 0 := by ...
```

In `Theorem6StochasticConvergence.lean`, we derive the corresponding certified rational convergence envelope:
$$\mathcal{E}(K, T, \zeta, \sigma, \delta) \equiv \frac{1}{2KT} + \zeta^2 + \frac{\sigma^2}{K} + \delta^2$$
proving that the optimization envelope contracts monotonically as round budget $T$ and participation $K$ grow.

---

## 10. Post-Quantum Cryptographic Migration and Non-Hijack Invariants

### 10.1 Hybrid Post-Quantum Transport and Attestation
To defend against "store-now, decrypt-later" adversaries possessing future cryptanalytic quantum capabilities, Sovereign-Mohawk incorporates hybrid post-quantum cryptography by default:
* **Key Exchange:** Inter-aggregator TLS channels negotiate hybrid X25519-ML-KEM-768 key encapsulation, conforming to NIST FIPS 203 [17].
* **Hardware Attestation:** Aggregator identities are attested via TPM 2.0 hardware roots of trust bound to XMSS stateful hash-based signatures.
* **Ledger Continuity:** State ledger transitions require epoch-enforced dual signatures (ECDSA + ML-DSA).

### 10.2 UF-CMA Adversarial Security Model
In `Theorem7PQCMigrationContinuity.lean` and `Theorem8DualSignatureNonHijack.lean`, we formalize an existential unforgeability under chosen-message attack (UF-CMA) game [29].

> **Definition 3 (PQC Unforgeability):** An adversary $\mathcal{A}$ with oracle access to signing oracle $\mathcal{O}$ cannot construct a valid PQC signature on an unqueried message:
> $$\forall m, \quad m \notin \mathcal{Q}_{\text{queries}} \implies \text{Verify}(\text{pk}_{\text{pqc}}, m, \mathcal{A}^{\mathcal{O}}(m)) = \texttt{false}$$

### 10.3 Machine-Checked Non-Hijack Invariants
We model the ledger migration lifecycle through three explicit phases: `preEpoch`, `cutover`, and `postEpoch`. We define the safety predicate:
$$\text{hijackSafe}(\text{auth}) \equiv (\text{phase} = \texttt{postEpoch}) \implies \text{auth.pqcSignedWitnessed}$$

```lean
theorem pqc_hardness_blocks_unwitnessed_acceptance
    (auth : MigrationAuth) (pqc : PQCSig) (oracle : SignOracle)
    (hunf : pqcUnforgeable pqc oracle)
    (hunw : ¬ (∃ msg sig, pqcSignedWitnessed pqc auth msg sig))
    (hfresh : ∀ msg, msg ∉ oracle.queries) :
    ¬ postEpochAccepts auth := by ...

theorem ledger_cutoverToPost_requires_pqc_query
    (s t : LedgerState) (trans : LedgerTransition s t)
    (hcut : trans = LedgerTransition.cutoverToPost auth) :
    auth.pqcSigned = true := by ...
```

As proved above, `pqc_hardness_blocks_unwitnessed_acceptance` verifies that a compromise of legacy ECDSA keys cannot bypass post-epoch acceptance checks *within the formal model*; the invariant is conditional on UF-CMA hardness and on acceptance being witnessed.

---

## 11. Implementation Refinement and the FloatOrderLaws Hypothesis

### 11.1 Go Runtime Correspondence
To bridge mathematical specifications with production software, Sovereign-Mohawk's core Multi-Krum algorithm is implemented in Go (`internal/multikrum.go`) and formally modeled in Lean 4 (`proofs/Refinement/MultiKrum.lean`). The Go implementation computes pairwise squared Euclidean distances over `float64` vectors, sorts Krum scores, and selects the $m$ argmin indices.

### 11.2 The Foundational Float Challenge in Lean 4
A critical discovery during formalization was that Lean 4 core defines `Float` as an opaque wrapper around an uninterpreted constant:
```lean
structure FloatSpec where
  float : Type; val : float; lt : float -> float -> Prop; le : float -> float -> Prop
opaque floatSpec : FloatSpec := { float := Unit, val := (), ... }
structure Float where val : floatSpec.float
```

Because IEEE-754 floating-point arithmetic admits Not-a-Number (`NaN`) values, floating-point comparison is not a partial order ($x \le y \land y \le x$ does not imply $x = y$ if $x$ is `NaN`). Consequently, Mathlib intentionally does *not* synthesize an instance for `LinearOrder Float`, and basic properties such as transitivity and antisymmetry are unprovable from Lean core.

### 11.3 The FloatOrderLaws Hypothesis (formerly eight global axioms)
Rather than disguising this limitation, we isolate the needed total-order laws
in one named structure, `FloatOrderLaws`, in `Refinement/MultiKrum.lean`,
conditioned strictly on non-`NaN` inputs (`NoNaNList`):

| # | Field | Formal Proposition ($\forall a, b, c \notin \text{NaN}$) |
| :--- | :--- | :--- |
| **1** | `le_refl` | $a \le a$ |
| **2** | `le_of_lt` | $a < b \implies a \le b$ |
| **3** | `not_lt_iff_le` | $\neg (a < b) \iff b \le a$ |
| **4** | `not_le_iff_lt` | $\neg (a \le b) \iff b < a$ |
| **5** | `le_antisymm` | $a \le b \land b \le a \implies a = b$ |
| **6** | `lt_of_lt_of_le` | $a < b \land b \le c \implies a < c$ |
| **7** | `le_of_le_of_le` | $a \le b \land b \le c \implies a \le c$ |
| **8** | `lt_irrefl` | $\neg (a < a)$ |

*Table 3: The IEEE-754 Float Order Laws in Lean 4.*

These are **not** global `axiom` declarations. They are fields of a structure
that is passed explicitly to each theorem that needs it, so the assumption is
visible at every use site rather than inherited silently from the global
context. `#print axioms` on `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl`
reports only Mathlib's foundation (`propext`, `Classical.choice`,
`Quot.sound`) — the eight laws appear as the theorem's explicit argument, not
as axioms in its proof tree.

Under this single explicit assumption, we machine-check that our inductive
Multi-Krum implementation selects the unique minimum score pair and matches
the single-element argmin:
```lean
theorem multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl
    (L : FloatOrderLaws) (nodes : List Node) (k : Nat) :
    ... := by ...
```

Continuous integration executes `scripts/ci/check_no_unsafe_placeholders.py`
to ensure that no unapproved axioms or unproven `sorry` placeholders exist.
The Float order laws are no longer on that allowlist, because they are no
longer axioms.

---

## 12. Master Formal Traceability Matrix

Every theoretical claim presented in this paper is tracked in our machine-readable formal traceability matrix (`FORMAL_TRACEABILITY_MATRIX.md`), which is the **authoritative** registry (47 main rows, each with its scope notes and negative controls). Table 4 presents the headline inventory connecting each claim to its Lean 4 module, core machine-checked theorems, Go implementation, runtime test evidence, and epistemic status; where a summary row and the matrix differ, the matrix wins.

| # | Claim Description | Lean Module | Key Machine-Checked Theorems | Go Implementation / Test Suite | Epistemic Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Single-Tier Multi-Krum Guard ($2f < n$) | `Theorem1BFT.lean` | `theorem1_half_bound_of_forall`, `theorem1_five_ninths_guard` | `internal/multikrum.go::MultiKrumSelect` | Fully Formalized (Single-Tier) |
| **2** | Hierarchical Composition Disproof | `Theorem1BFT.lean` | `hierarchical_composition_counterexample` | `internal/hbft/simulator.go` | **Disproved** (Counterexample Checked) |
| **3** | Probabilistic Chernoff Repair | `Theorem1BFT.lean` | `binomial_mean`, `chernoff_hierarchical_bound_deployment_scale` | `test/hbft_statistical_sanity_test.go` | Proved **under the explicit i.i.d. Bernoulli committee-sampling model**; vacuous under adversarial placement; the sanity test is an empirical regression tripwire, not verification of the deployment-scale bound |
| **4** | Independent RDP Composition | `Theorem2RDP.lean` | `RDP_sequential_composition`, `RenyiDivergence_product_add` | `internal/rdp_accountant.go::ComposeRDP` | `surrogate_verified` for the list-based rational budget. **Updated:** the Gaussian-mechanism RDP bound is no longer an axiom bridge — it is **derived** from Mathlib measure theory (row 20) |
| **5** | Constructivist Rational Log Bounds | `Refinement/RDPLogBound.lean` | `rdpLog_sandwich`, `rdpToApproxDP_bound`, `epsUpperRat` | `test/rdp_conversion_bound_test.go` | Fully Formalized (Rational Sandwich) |
| **6** | Hierarchical Path Depth $O(d \log n)$ | `Theorem3Communication.lean` | `hierarchical_comm_complexity`, `theorem3_lower_bound_match` | `internal/federation/router.go` | `fully_formalized` as a **path-depth proxy**; total bytes remain model-dependent |
| **7** | Wire Format Serialization Equivalence | `Refinement/Transport.lean` | `hierarchicalProtocol_totalBytes_eq`, `transport_impl_exact` | `test/transport_byte_size_test.go` | `fixed_vacuous_stub`; **formula-level** correspondence only — no machine-checked cross-language equality (Lean cannot invoke Go source) |
| **8** | Redundancy & Correlated Stragglers | `Theorem4StragglerResilience.lean` | `correlated_recovers_independent`, `adversarial_cannot_fail` | `internal/straggler_resilience.go` | Model Verified |
| **9** | Probabilistic Liveness Chernoff Bounds | `Theorem4ChernoffBounds.lean` | `theorem4_chernoff_bounds`, `theorem4_union_bound` | `test/liveness_quorum_test.go` | `model_verified` — proved about an explicit probability model, not the deployed runtime |
| **10** | Scale-Invariant Groth16 Verifier Cost | `Theorem5Cryptography.lean` | `theorem5_constant_ops`, `theorem5_verifier_soundness` | `internal/zksnark_verifier.go::VerifyProof` | `model_verified` — constant-operation **model**; `theorem5_verifier_soundness` is a structural statement about the toy `verify` function, **not** a Groth16 soundness proof |
| **11** | MiMC Round Injectivity (general algebraic lemma) | `Theorem5MiMCFormalization.lean` | `pow_injective`, `mimcRound_injective` | `circuits/mimc.go::MiMCHash` | Conditional on `Nat.Prime p` / `Nat.Coprime e (p-1)`; only instantiated at p=7. **BN254 is not instantiated**; this is not a MiMC collision-resistance proof |
| **12** | Robbins-Siegmund Supermartingale Limit | `RobbinsSiegmundDeterministic.lean` | `robbins_siegmund_limit_zero` | `internal/convergence.go` | `measure_theoretic_verified` — deterministic limit lemma about nonnegative almost-supermartingales; stochastic convergence is a corollary under the model's conditions |
| **13** | PQC Migration Dual-Signature Continuity | `Theorem7PQCMigrationContinuity.lean` | `theorem7_dual_signature_continuity`, `pqc_hardness_blocks` | `internal/token/migration_signatures.go` | Structural continuity; the separate hardness reduction (`pqc_hardness_blocks_unwitnessed_acceptance`) is sound **only when the acceptance bit is witnessed** |
| **14** | Post-Epoch Non-Hijack Invariant | `Theorem8DualSignatureNonHijack.lean` | `ledger_cutoverToPost_requires_pqc_query`, `theorem8_non_hijack` | `internal/token/settlement.go::SettlePayout` | Structural invariant; `theorem8_no_hijack_possible` is **definitionally vacuous** in its case analysis (see matrix row 9); the hardness reduction carries the same witnessed-acceptance caveat |
| **15** | Float Multi-Krum Selection Equivalence | `Refinement/MultiKrum.lean` | `multiKrumSelectManyImpl_one_eq_multiKrumSelectImpl` | `test/multikrum_lean_correspondence_test.go` | `surrogate_verified` under the explicit `FloatOrderLaws` hypothesis (the eight former global axioms are now one structure, passed per theorem — #316) |
| **16** | Multi-Krum aggregated SGD converges a.s. to the optimum under a Robbins-Monro diminishing step size | `MultiKrumConvergence.lean` | `mkAggregate`, `mkAggregate_deviation_sq_le`, `mkAggregate_deviation_sq_le_split`, `multikrum_descent_inequality`, `summable_diminishingStep_sq`, `not_summable_diminishingStep`, `multikrum_convergence_ae` | `internal/multikrum.go::MultiKrumAggregate` (definition-level correspondence; Lean cannot invoke Go) | `measure_theoretic_verified`; real a.s. convergence via `supermartingale_convergence_ae`; **not** a statement about the deployed binary |
| **17** | Corrected hierarchical composition, and a probabilistic bound on the runtime's `n > 2f+2` precondition under a stated i.i.d. Bernoulli network model | `ProtocolSafety.lean` | `HTree.fractionSafe`, `HTree.fractionSafe_node_of_forall`, `hierarchical_counterexample_safeButFractionUnsafe`, `guardThreshold`, `guardThreshold_correct`, `multikrum_guard_failure_prob`, `multikrum_guard_failure_deployment_scale` | `internal/multikrum.go` (the `n <= 2f+2` rejection and `neighbors = n-f-2` derivation) | `fully_formalized` (counting) and `model_verified` (probabilistic) |
| **18** | Proper reduction for the Schnorr/Ed25519 identification protocol: special soundness, HVZK, and a forger-implies-discrete-log reduction modulo an explicit forking step | `SchnorrReduction.lean` | `schnorrAccept`, `schnorr_completeness`, `schnorr_special_soundness`, `schnorr_hvzk_simulation`, `schnorr_hvzk_commitment_bijective`, `ForkingStep`, `forger_implies_dlog` | `proofs/DiscreteLogReduction.lean::recovery_yields_secret` (the same extractor for the Ed25519 nonce-reuse attack); `internal/zksnark_verifier.go` is a different, weaker construction | `fully_formalized` (group algebra); the forking step is an explicit hypothesis, not a theorem |

| **19** | Ed25519 UF-CMA, composed from four proved pieces | `Ed25519UF_CMASecurity.lean` | `ed25519_ufcma_security`, `verificationEquation_iff_ModEq`, `ed25519_two_equations_recover` | `proofs/Ed25519Test.lean` (RFC 8032 vectors), `internal/token/migration_signatures.go` | `fully_formalized` (capstone composition); the four curve group laws remain an **explicit hypothesis**, and each has a concrete violator |
| **20** | Measure-theoretic Rényi divergence; the Gaussian bound **derived** | `RenyiDivergenceMeasure.lean` | `gaussianRDP_integral`, `gaussianRDPBound_measure` | `internal/rdp_accountant.go` | `α·Δ²/(2σ²)` **derived** from a proved completed-square integral; no residual hypothesis beyond `σ ≠ 0`, `α ≠ 1`. Supersedes the earlier existence witness / axiom bridge |
| **21** | Rényi divergence over a product measure | `RenyiDivergenceCompose.lean` | `renyiDivergenceMeasure_prod`, `gaussianRDPMeasure_two_rounds` | `test/rdp_accountant_property_test.go` | `fully_formalized` (independent / product-measure composition); adaptive composition **not** covered |
| **22** | Bounded-query programmed random oracle: rewind bound | `RenyiDivergenceBoundedRO.lean` | `roForkProb_ge`, `roCount_sum`, `sum_sq_div_card_le` | — (no runtime caller; a finite abstraction) | `fully_formalized` for a **fixed / non-adaptive** query schedule; adaptive query histories **not** modelled; not yet a statement about the Ed25519 UF-CMA game |
| **23** | Diagonal multivariate Gaussian RDP | `RenyiDivergenceMultivariate.lean` | `gaussianRDPMeasure_diagonal` | `internal/rdp_accountant.go` | `fully_formalized` for **diagonal** `Σ` (independent coordinates); the general correlated case needs an affine change-of-variables lemma and is **not** implied |
| **24** | Edwards→Montgomery→Weierstrass addition-law bridge and the concrete Ed25519 affine law | `EdwardsWeierstrassBridge.lean`, `MontgomeryEdwardsAdditionCompat.lean`, `Ed25519CurveGroupLaw.lean` | `edAdd_toMont_eq_montAdd`, `montAdd_v_eq_zero_of_u_eq_zero`, `edwards_denoms_ne_zero`, `edwardsAddCompat_of_complete`, `edAddField_associative_of_complete`, `affineAdd_zmod_eq_edAddField_of_onCurve`, `affineAdd_associative_of_complete` | `proofs/Ed25519Test.lean` (RFC 8032 vectors) | `group_law_partially_formalized`: field-level compatibility, completeness, conditional associativity and the negative control are proved axiom-free; concrete associativity is conditional, **not** unconditional (§3.4, matrix row 47) |

*Table 4: Headline Formal Traceability Matrix. The authoritative registry is `FORMAL_TRACEABILITY_MATRIX.md` (47 main rows), which carries the per-claim scope notes and negative controls.*

---

## 13. Empirical Evaluation and Scaled Swarm Experiments

### 13.1 Experimental Testbed and Setup
We evaluate Sovereign-Mohawk across single-host multi-node Kubernetes (Kind) environments, CI swarm matrices, and simulated container targets. Experiments were executed on an AMD EPYC 7763 64-core workstation (128 threads, 256GB ECC DDR4-3200 RAM) running Ubuntu 22.04 LTS (Linux kernel 6.5). Container resource quotas and pod network isolation were strictly enforced via cgroups v2.

We evaluate performance across two distinct adversarial profiles:
* **Safe Profile (10% Byzantine):** Corrupted nodes execute sign-flip gradient attacks ($\tilde{g} = -\nabla F(\theta)$).
* **Edge Profile (35% Byzantine):** Corrupted nodes execute coordinated model manipulation attacks, injecting deceptive high-magnitude vectors crafted to maximize variance while bypassing naive threshold filters.

### 13.2 Byzantine Resilience and Accuracy Preservation
We evaluate model convergence on the CIFAR-10 classification benchmark across 100 federated rounds using a ResNet-18 architecture with Dirichlet non-IID data partitioning ($\alpha_{\text{Dir}} = 0.5$).

```
100 +-----------------------------------------------------------------------------------+
    |                                                                                   |
 80 |                                                    Clean Baseline (88.2%)         |
    |                                            *   *   Sovereign-Mohawk (86.4%, 35%BFT)
 60 |                                    *   *                                          |
    |                            *   *                                                  |
 40 |                    *   *                                                          |
    |            *   *                                                                  |
 20 |        *                                                                          |
    |  * .                                                                              |
  0 |  . . . . . . . . . . . . . . . . . . . . . . . . .  Unmitigated FedAvg (Divergent) |
    +----+----+----+----+----+----+----+----+----+----+---------------------------------+
    0    10   20   30   40   50   60   70   80   90  100
                              Training Round
```

Under the Edge profile (35% Byzantine), unmitigated FedAvg rapidly diverges within 15 rounds, collapsing to random chance accuracy (10.0%). In contrast, Sovereign-Mohawk's hierarchical Multi-Krum filtering isolates corrupted gradients, steadily advancing to 86.4% test accuracy after 100 rounds. This represents a negligible 1.8% accuracy differential compared to the unperturbed clean baseline (88.2%).

### 13.3 Component Ablation Study
To dissect the latency and accuracy contributions of each security primitive, we conduct an ablation analysis across 500 container pods at Round 50.

| Configuration / Feature Vector | CIFAR-10 Acc (%) | Round Duration |
| :--- | :--- | :--- |
| **Standard FedAvg (No Security / No Attack)** | 88.2% | 110 ms |
| **+ Multi-Krum Guard Only (35% Attack)** | 87.8% | 124 ms |
| **+ Multi-Krum + RDP Privacy ($\epsilon = 2.0$)** | 86.4% | 128 ms |
| **+ Full Stack (Groth16 + KEM-768 + RDP)** | 86.4% | 145 ms |

*Table 5: System Component Ablation Matrix (500 Pods, Round 50).*

Table 5 confirms that differential privacy noise injection accounts for the vast majority of the 1.8% accuracy drop ($87.8\% \to 86.4\%$). In return, zero-knowledge Groth16 verification and hybrid ML-KEM-768 post-quantum key exchange add only 17 ms of total latency overhead per aggregation round.

### 13.4 Containerized Swarm Scale Benchmarks
We measure round completion latencies across scaled container swarm configurations from 500 to 1,500 active container instances.

| Active Nodes | Tier 1 (Edge Ingestion) | Tier 2 (Regional Krum) | Tier 3 (Continental zk) | Total Round Completion |
| :--- | :--- | :--- | :--- | :--- |
| **500** | 12 ms | 45 ms | 88 ms | 145 ms |
| **1,000** | 24 ms | 82 ms | 140 ms | 246 ms |
| **1,500** | 38 ms | 125 ms | 210 ms | 373 ms |

*Table 6: Containerized Swarm Latency Breakdown Across Tiers.*

Total aggregation latency scales smoothly from 145 ms at 500 nodes to 373 ms at 1,500 nodes. Hierarchical distribution successfully prevents central bottlenecks, keeping total round completion well under the network synchrony bound $\Delta_2 = 150\text{ s}$.

### 13.5 Runtime Component Microbenchmarks
Table 7 reports single-core microbenchmark timings measured on a dedicated AMD EPYC 7763 core. The Groth16 row is the exception: it is the measured cost of the real circuit from `results/zk/weight-proof-latest.json` (9 569 constraints, 164-byte proof, 200 verify iterations), not an EPYC microbenchmark.

| Runtime Operation | Mean Latency | Median | Throughput |
| :--- | :--- | :--- | :--- |
| **Groth16 Verification (BN254, 9 569 constraints)** | $0.675\text{ ms}$ | not recorded | $1{,}482\text{ ops/s}$ |
| **Multi-Krum Aggregation ($N=100$)** | $30.63\ \mu\text{s}$ | $25.20\ \mu\text{s}$ | $32,648\text{ ops/s}$ |
| **Gradient Compression (1MB FP32)** | $995.70\ \mu\text{s}$ | $944.57\ \mu\text{s}$ | $1,004\text{ ops/s}$ |
| **Hybrid KEX (ML-KEM-768)** | $142.10\ \mu\text{s}$ | $138.00\ \mu\text{s}$ | $7,037\text{ ops/s}$ |
| **TPM 2.0 Quote Attestation** | $48.20\text{ ms}$ | $47.50\text{ ms}$ | $20.7\text{ ops/s}$ |

*Table 7: Production Runtime Component Microbenchmarks on AMD EPYC 7763.*

Multi-Krum aggregation executes in just $30.63\ \mu\text{s}$ for $N=100$ vectors ($32,648\text{ ops/s}$), demonstrating that statistical filtering incurs negligible overhead in Go. Groth16 verification processes $94.8\text{ proofs/s}$ per dedicated CPU core.

---

## 14. Related Work

### 14.1 Byzantine-Robust Federated Learning
Blanchard et al. [2] pioneered Byzantine-tolerant gradient descent with Krum and Multi-Krum for flat master-worker topologies. Subsequent works introduced Bulyan [22], coordinate-wise median, trimmed mean [7], geometric medians [6], and Zeno [32]. However, all prior theoretical guarantees were derived under flat network assumptions. As our counterexample demonstrates, these single-tier bounds do not compose deterministically in hierarchical topologies.

### 14.2 Hierarchical Federated Learning Topologies
To resolve bandwidth saturation in cellular and IoT networks, hierarchical FL (HFL) architectures cluster edge devices under intermediate gateways [8], [9]. However, existing HFL systems rely exclusively on heuristic security assumptions or flat simulations. Sovereign-Mohawk formalizes hierarchical composition in an interactive theorem prover and publishes a machine-checked disproof of its deterministic variant.

### 14.3 Formal Verification in Distributed Systems & ML
Formal verification of distributed consensus protocols (e.g., Raft, Paxos) using IronFleet, Ivy, Coq, and Lean 4 is well-established [10], [11]. However, formalizing statistical ML properties—such as empirical risk descent, differential privacy composition, and statistical Byzantine filtering—remains nascent. Recent analytical work by He and Zhang [12] investigated probabilistic bounds but did not provide machine-checked proofs or refutations.

### 14.4 Verifiable and Post-Quantum Computation
Zero-knowledge FL systems typically employ recursive proof composition (e.g., Halo2 cycles) [13], incurring severe prover overhead. Sovereign-Mohawk employs flat Groth16 proofs over MiMC permutations on BN254, bypassing recursive overhead. In the post-quantum realm, NIST FIPS 203 [17] standardized ML-KEM; we formalize structural non-hijack invariants for federated ledger cutover (conditional on UF-CMA hardness and witnessed acceptance).

| Framework | Scale Target | Formal BFT Proof | Privacy Accounting | PQC Migration |
| :--- | :--- | :--- | :--- | :--- |
| **TensorFlow Federated** [1] | $10^4$ | None | Moments Accountant | None |
| **PySyft** [14] | $10^3$ | None | $(\epsilon,\delta)$-DP | None |
| **Flower** [31] | $10^5$ | None | Heuristic DP | None |
| **Sovereign-Mohawk** | $\mathbf{10^7}$ (target) | **Single-tier guard + machine-checked disproof of deterministic composition**; probabilistic repair conditional on i.i.d. sampling | **Rational RDP** (list surrogate; Gaussian bound **derived**, and its $(ε,δ)$ conversion bracketed) | **Structural invariant**, conditional on UF-CMA + witnessed acceptance |

*Table 8: Comparative Architectural and Verification Feature Matrix.*

---

## 15. Limitations, Open Gaps, and Threats to Validity

We explicitly record technical limitations and open gaps:
1. **Gaussian RDP and its `(ε,δ)` conversion:** the Gaussian mechanism's Rényi divergence bound is **derived** from Mathlib's measure theory (`RenyiDivergenceMeasure.lean`: $D_\alpha(\mathcal{N}(\Delta,\sigma^2) \,\|\, \mathcal{N}(0,\sigma^2)) = \alpha\Delta^2/(2\sigma^2)$, unconditionally in $\sigma \neq 0$ and $\alpha \neq 1$), and the $(ε,δ)$ conversion is applied to it as an explicit two-sided **rational** bracket at the production order $\alpha = 10$ (`GaussianApproxDP.lean`). What is proved is the *bracket*, not an exact equality: $\log$ is noncomputable in Lean, so the conversion is sandwiched by rationals rather than evaluated. The general **correlated** multivariate Gaussian, **adaptive** composition, and an exact measure-theoretic conversion remain open.
2. **Groth16 Trusted Setup:** Groth16 pairing verification depends on an initial structured reference string (SRS). Migrating to transparent STARK or Halo2 schemes would eliminate trusted setup dependencies.
3. **Sampling Distribution Assumptions:** The probabilistic repair strictly presumes independent Bernoulli committee sampling. Non-uniform or geographically correlated adversarial node concentration remains an open theoretical direction.
4. **Physical WAN Scaling:** While multi-node container benchmarks up to 1,500 pods confirm microsecond aggregation efficiency, real-world planetary deployments across high-jitter wireless WANs remain future empirical work.
5. **253-Bit Primality Hypothesis:** In `DiscreteLogReduction.lean`, the primality of the Ed25519 subgroup order $L = 2^{252} + 27742317777372353535851937790883648493$ is carried as the explicit hypothesis $\texttt{Fact (Nat.Prime dlL)}$ on the four declarations that need it, as 253-bit primality certificates exceed Lean's native decidability timeout. It is not a global `axiom`; every consumer sees the assumption in the statement.
6. **Ed25519 group-law hypotheses:** `Nat.Prime ed25519P` and the nonsquareness
   of `ed25519D : ZMod ed25519P` are not proved in the repository; both remain
   explicit hypotheses. Under this Mathlib pin, `norm_num` times out on the
   77-digit primality check and neither `norm_num` nor `decide` evaluates the
   Legendre/Jacobi symbols needed for nonsquareness. The field-level bridge and
   the concrete associativity theorem are therefore conditional, not a full
   group law for the implementation.

---

## 16. Conclusion & Reproducibility Statement

Sovereign-Mohawk reframes part of the foundations of hierarchical federated learning by machine-checking a counterexample to deterministic Byzantine composition for the credited-weight guard the system uses, and by constructing a probabilistic repair whose scope (i.i.d. Bernoulli committee sampling) is stated explicitly. By pairing a scope-labelled Lean 4 formal development with an industrial Go production runtime — and publishing where the checking stops, including a disproof of our own original claim — we demonstrate that explicit models can guide the design of large-scale distributed machine learning systems.

All Lean 4 formal proof files, Go runtime source trees, Kubernetes configurations, and automated continuous integration reproducibility scripts are open-source and publicly accessible at:
> **Repository:** [https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)

### Acknowledgments
The author thanks the developers and maintainers of Lean 4, Mathlib, the `gnark` zero-knowledge cryptography suite, and the open-source Go and Kubernetes ecosystems.

---

## References

1. H. B. McMahan, E. Moore, D. Ramage, S. Hampson, and B. A. y Arcas, "Communication-efficient learning of deep networks from decentralized data," in *Proc. 20th International Conference on Artificial Intelligence and Statistics (AISTATS)*, vol. 54, pp. 1273–1282, 2017.
2. P. Blanchard, E. M. El Mhamdi, R. Guerraoui, and J. Stainer, "Machine learning with adversaries: Byzantine tolerant gradient descent," in *Advances in Neural Information Processing Systems (NeurIPS)*, vol. 30, pp. 119–129, 2017.
3. C. Dwork, N. Lynch, and L. Stockmeyer, "Consensus in the presence of partial synchrony," *Journal of the ACM*, vol. 35, no. 2, pp. 288–323, 1988.
4. I. Mironov, "Rényi differential privacy," in *Proc. 30th IEEE Computer Security Foundations Symposium (CSF)*, pp. 263–275, 2017.
5. J. Groth, "On the size of pairing-based non-interactive arguments," in *Proc. 35th Annual International Conference on the Theory and Applications of Cryptographic Techniques (EUROCRYPT)*, pp. 305–326, 2016.
6. Y. Chen, L. Su, and J. Xu, "Distributed statistical machine learning in adversarial settings: Byzantine gradient descent," *Proc. ACM Measurement and Analysis of Computing Systems (POMACS)*, vol. 1, no. 2, pp. 1–25, 2017.
7. D. Yin, Y. Chen, R. Kannan, and P. Bartlett, "Byzantine-robust distributed learning: Towards optimal statistical rates," in *Proc. 35th International Conference on Machine Learning (ICML)*, pp. 5650–5659, 2018.
8. L. Liu, J. Zhang, S. Song, and K. B. Letaief, "Client-edge-cloud hierarchical federated learning," *IEEE Journal on Selected Areas in Communications*, vol. 38, no. 10, pp. 2112–2123, 2020.
9. M. S. H. Abad, E. Ozfatura, D. Gündüz, and O. Ercetin, "Hierarchical federated learning across heterogeneous wireless networks," *IEEE Transactions on Wireless Communications*, vol. 19, no. 9, pp. 5541–5555, 2020.
10. C. Hawblitzel, J. Howell, J. Lorch, A. Narayan, B. Parno, D. Zhang, and B. Zill, "IronFleet: Proving practical distributed system implementations correct," in *Proc. 25th ACM Symposium on Operating Systems Principles (SOSP)*, pp. 1–17, 2015.
11. D. Woos, J. R. Wilcox, S. Antonov, Z. Tatlock, M. D. Ernst, and T. Anderson, "Planning for change in a formal verification of Raft," in *Proc. 12th USENIX Symposium on Operating Systems Design and Implementation (OSDI)*, pp. 257–272, 2016.
12. Y. He and J. Zhang, "Probabilistic Byzantine resilience for federated learning," *IEEE Transactions on Dependable and Secure Computing*, vol. 23, no. 1, pp. 112–126, 2026.
13. E. Ben-Sasson, A. Chiesa, E. Tromer, and M. Virza, "Scalable zero knowledge via recursive composition and distributed proofs," in *Proc. 46th Annual ACM Symposium on Theory of Computing (STOC)*, pp. 1–10, 2014.
14. T. Ryffel et al., "A generic framework for privacy preserving deep learning," in *NeurIPS Workshop on Privacy in Machine Learning (PriML)*, 2018.
15. C. Dwork and A. Roth, "The algorithmic foundations of differential privacy," *Foundations and Trends in Theoretical Computer Science*, vol. 9, no. 3–4, pp. 211–407, 2014.
16. D. J. Bernstein, "Curve25519: new Diffie-Hellman speed records," in *Proc. 9th International Conference on Public Key Cryptography (PKC)*, pp. 207–228, 2006.
17. National Institute of Standards and Technology (NIST), "FIPS 203: Module-Lattice-Based Key-Encapsulation Mechanism Standard," U.S. Department of Commerce, 2024.
18. R. Williams, "Sovereign Mohawk Proto: Formally Verified Hierarchical Federated Learning Engine," GitHub Repository, 2026. `https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto`.
19. L. de Moura and S. Ullrich, "The Lean 4 theorem prover and programming language," in *Proc. 28th International Conference on Automated Deduction (CADE)*, pp. 625–635, 2021.
20. M. R. Albrecht, L. Grassi, C. Rechberger, A. Roy, and T. Tiessen, "MiMC: Efficient cryptographic primitive for SNARKs and STARKs," in *Proc. 22nd International Conference on the Theory and Application of Cryptology and Information Security (ASIACRYPT)*, pp. 191–219, 2016.
21. H. Robbins and D. Siegmund, "A convergence theorem for nonnegative almost supermartingales and some applications," in *Optimizing Methods in Statistics*, Academic Press, pp. 233–257, 1971.
22. E. M. El Mhamdi, R. Guerraoui, and S. Rouault, "The hidden vulnerability of distributed learning in Byzantium," in *Proc. 35th International Conference on Machine Learning (ICML)*, pp. 3521–3530, 2018.
23. I. Damgård and M. Jurik, "A generalisation, a simplification and some applications of Paillier's probabilistic public-key system," in *Proc. 4th International Workshop on Practice and Theory in Public Key Cryptography (PKC)*, pp. 119–136, 2001.
24. M. Abadi et al., "Deep learning with differential privacy," in *Proc. 23rd ACM SIGSAC Conference on Computer and Communications Security (CCS)*, pp. 308–318, 2016.
25. S. P. Karimireddy, S. Kale, M. Mohri, S. J. Reddi, S. U. Stich, and A. T. Suresh, "SCAFFOLD: Stochastic controlled averaging for federated learning," in *Proc. 37th International Conference on Machine Learning (ICML)*, pp. 5132–5143, 2020.
26. T. Li, A. K. Sahu, M. Zaheer, M. Sanjabi, A. Talwalkar, and V. Smith, "Federated optimization in heterogeneous networks," in *Proc. 3rd Conference on Machine Learning and Systems (MLSys)*, pp. 429–450, 2020.
27. D. J. Bernstein, A. Hülsing, S. Kölbl, R. Niederhagen, J. Rijneveld, and P. Schwabe, "The SPHINCS+ signature framework," in *Proc. 26th ACM SIGSAC Conference on Computer and Communications Security (CCS)*, pp. 2129–2146, 2019.
28. S. Josefsson and I. Liusvaara, "Edwards-Curve Digital Signature Algorithm (EdDSA)," IETF RFC 8032, 2017.
29. S. Goldwasser, S. Micali, and R. L. Rivest, "A digital signature scheme secure against adaptive chosen-message attacks," *SIAM Journal on Computing*, vol. 17, no. 2, pp. 281–308, 1988.
30. K. Bonawitz et al., "Practical secure aggregation for privacy-preserving machine learning," in *Proc. 24th ACM SIGSAC Conference on Computer and Communications Security (CCS)*, pp. 1175–1191, 2017.
31. D. J. Beutel et al., "Flower: A friendly federated learning research framework," *arXiv preprint arXiv:2007.14390*, 2020.
32. C. Xie, S. Koyejo, and I. Gupta, "Zeno: Honest-majority Byzantine-robust distributed learning," in *Proc. 36th International Conference on Machine Learning (ICML)*, pp. 6874–6883, 2019.
33. K. Pillutla, S. M. Kakade, and Z. Harchaoui, "Robust aggregation for federated learning," *IEEE Transactions on Signal Processing*, vol. 70, pp. 1142–1154, 2022.
34. J. Bernstein, Y.-X. Wang, K. Azizzadenesheli, and A. Anandkumar, "signSGD: Compressed optimisation for non-convex problems," in *Proc. 35th International Conference on Machine Learning (ICML)*, pp. 560–569, 2018.
35. P. Kairouz et al., "Advances and open problems in federated learning," *Foundations and Trends in Machine Learning*, vol. 14, no. 1–2, pp. 1–210, 2021.
36. M. Bellare and P. Rogaway, "Random oracles are practical: A paradigm for designing efficient protocols," in *Proc. 1st ACM Conference on Computer and Communications Security (CCS)*, pp. 62–73, 1993.
37. W. Hoeffding, "Probability inequalities for sums of bounded random variables," *Journal of the American Statistical Association*, vol. 58, no. 301, pp. 13–30, 1963.
38. H. Chernoff, "A measure of asymptotic efficiency for tests of a hypothesis based on the sum of observations," *The Annals of Mathematical Statistics*, vol. 23, no. 4, pp. 493–507, 1952.
