# Theorem 3: Communication Optimality

### Formal Statement
The current Lean formalization proves a logarithmic path-depth communication
proxy for hierarchical routing: per-update uplink depth is
$O(d \log_b n)$ with branching factor $b > 1$.

It does not prove that total network-wide bytes are $O(d \log n)$ without an
additional compression/sparsification model.

### Comparison
* **Naive FedAvg total bytes:** $O(dn)$.
* **Hierarchical per-update depth proxy:** $O(d \log_{10} n)$.
* **Total bytes without compression:** still $O(dn)$ in the current model.

### Proof Sketch
By aggregating updates in a balanced tree, each update traverses at most
$\log_{10}(10^7)=7$ levels for branching factor $10$. This proves a logarithmic
depth bound. A separate compression theorem is required to claim sublinear total
network-wide bytes.
