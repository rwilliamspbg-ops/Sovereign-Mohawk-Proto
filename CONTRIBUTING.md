# Contributing to Sovereign Mohawk Protocol (SMP)

Thank you for your interest in the **Sovereign Mohawk Protocol**! We are building
a decentralized spatial operating system where data sovereignty is a right, not
a feature. By contributing, you are helping scale a coordinator-less,
privacy-preserving network to 10 million nodes.

---

## 🏆 The Audit Status & Points System

To incentivize high-integrity contributions, we use a merit-based **Audit Points** system. Earning points grants you "Audit Status" within the community and
determines eligibility for rewards within the
[Sovereign-Mohawk-Proto](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto)
ecosystem.

### Priority Tracks & Point Values

| Track | Role | Goal | Points |
| :--- | :--- | :--- | :--- |
| **🛡️ Audit & Verify** | Cryptographer | Verify Theorems 1-6 or audit zk-SNARK logic. | **100** |
| **🏗️ Hardware Port** | Edge Engineer | Port node-agent to NPUs (e.g., Jetson, Apple Silicon). | **50** |
| **🐍 SDK Expansion** | Python Dev | Build wrappers or [Jupyter Tutorials](./notebooks). | **25** |
| **📝 Documentation** | Any | Fix typos, improve READMEs, or clarify technical specs. | **5** |

---

## 🛠️ How to Contribute

### 1. Claim a "Master Auditor" Task

Browse our [GitHub Issues](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/issues)
for the `Master Auditor` or `priority` labels. We are currently seeking:

* **Theorem 5 Verification:** Stress-test ZK-proofs against Round 45 logs.
* **NPU Optimization:** FFI bindings for **85+ TOPS** hardware.

### 2. Use Professional Templates

Your PR must include a completed template to be eligible for points:

* [Cryptographic Audit Template](./proofs/audit_verification.md)
* [Hardware Porting Template](./proofs/hardware_port.md)

### 3. Submission & Linting

1. **Fork** the repository and create a feature branch (`git checkout -b feat/your-contribution`).
2. **Implement** your changes following the [SGP-001 Privacy Standard](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto#trust--verification).
3. **Lint & Test**: Run `black`, `ruff`, and `mypy` on any Python changes to ensure they pass the [CI/CD Workflow](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/actions).
4. **Submit PR**: Tag your PR with `[AUDIT]` to trigger the verification runner.

### 4. Optional Chat Notifications for Weekly Readiness Digest

Maintainers can wire the `Weekly Readiness Digest` workflow to Slack and/or Teams.

Configure repository secrets in **Settings → Secrets and variables → Actions**:

* `SLACK_WEBHOOK_URL`
* `TEAMS_WEBHOOK_URL`

If unset, the notification step is skipped and digest artifacts are still published.

---

## 📜 Standards

* **Privacy First:** Never include raw data in logs. Use the [SGP-001](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto) scrubbers.
* **Complexity:** PRs must not increase the $O(d \log n)$ communication complexity verified in [PERFORMANCE.md](https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/PERFORMANCE.md).

---

## 🔗 Connect with the Architects

* **Bitcointalk:** [Six-Theorem Formal Verification Thread](https://bitcointalk.org/index.php?topic=5575025.0)
* **Reddit:** [r/SovereignMap Community](https://www.reddit.com/user/Famous_Aardvark_8595/)
