## License

This project is licensed under the **Apache License 2.0** (unless otherwise noted for third-party components).  
See the [LICENSE](LICENSE) file for the full text.

Apache 2.0 is permissive: it allows broad use, modification, and distribution (including commercial), with patent grants from contributors and a requirement to preserve copyright notices.

### Third-Party Dependencies and License Implications

We rely on several open-source libraries and tools. Their licenses are compatible with Apache 2.0 in our usage (dynamic linking, no static bundling of GPL code into binaries for distribution). Key ones:

- **ORB-SLAM3** (from UZ-SLAMLab/ORB_SLAM3): GPLv3 (copyleft).  
  Used for on-device visual SLAM in Sovereign Map. We integrate via separate module / API boundary (e.g., subprocess or wrapped calls) to avoid creating a single derivative work under GPLv3 virality. If you build/distribute binaries that statically link or closely derive from ORB-SLAM3 code, your distribution must comply with GPLv3 (source release required). For our reference implementation, we treat it as a runtime dependency—users must install ORB-SLAM3 separately under its terms.  
  → Recommendation: If commercial/proprietary use is a future goal, consider permissive SLAM alternatives (e.g., open-vSLAM, DSO) in later versions.

- **Wasmtime** (WebAssembly runtime): Apache 2.0 / MIT dual. Fully compatible.

- **Go standard library & Wasmtime Go bindings**: BSD-3-Clause or similar permissive.

- **zk-SNARK libraries** (e.g., if using arkworks, gnark, or similar Rust/Go impls): Mostly MIT/Apache 2.0.

- Other (e.g., Helm charts, React dashboard deps, gRPC): Standard permissive (MIT, Apache 2.0).

**Full list of dependencies** (generated via go mod graph / npm list where applicable):  
[Insert output here, e.g., from `go list -m all` or a requirements.txt equivalent]

We make no claims of originality over third-party components. All usage follows their respective licenses. If you fork or extend this project, please preserve notices and comply with copyleft requirements where applicable.

Questions on licensing? Feel free to open an issue or DM @RyanWill98382.
