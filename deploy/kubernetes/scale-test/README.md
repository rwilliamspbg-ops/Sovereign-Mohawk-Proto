# Kubernetes Scale Test (kind)

Reproduces the real, multi-hundred-node `kind` deployment test documented in
[results/go-live/evidence/k8s_scale_deployment_test_2026-08-10.md](../../../results/go-live/evidence/k8s_scale_deployment_test_2026-08-10.md).
Real orchestrator, real `node-agent`, real mTLS per-replica identity, real
`ipfs/kubo` — not a simulation.

This is a manual/local testing tool, not wired into CI.

## Prerequisites

- Docker (with enough allocated memory for your target replica count — see
  the evidence doc's "per-pod memory footprint" figure to estimate; ~10MB
  per `node-agent` replica plus a few hundred MB of fixed control-plane/
  orchestrator/IPFS overhead is a reasonable planning number, though your
  actual ceiling may be lower for other reasons, e.g. disk I/O — see the
  evidence doc's root-cause section)
- [`kind`](https://kind.sigs.k8s.io/)
- `kubectl`
- `openssl`

## Steps

1. **Edit `kind-config.yaml`**: replace the `extraMounts[0].hostPath` placeholder
   with an absolute path where you'll generate the certificate pool (step 3).

2. **Create the cluster:**

   ```bash
   kind create cluster --name sovereign-mohawk-scale-test --config kind-config.yaml
   ```

3. **Generate the certificate pool** (real CA + orchestrator leaf + one
   client cert per planned `node-agent` replica, 0-indexed to match
   `StatefulSet` pod ordinals):

   ```bash
   MOHAWK_TPM_CLIENT_CERT_POOL_SIZE=500 OUT_DIR=/path/matching/kind-config/extraMounts \
     ./generate-cert-pool.sh
   ```

4. **Build and load the images** (the Helm chart's default registry image
   references may not exist for your commit — see the evidence doc's
   "Real bug found" section; building locally sidesteps this):

   ```bash
   cd ../../..   # repo root
   docker build -f cmd/node-agent/Dockerfile -t local/node-agent:scale-test .
   docker build -f cmd/orchestrator/Dockerfile -t local/orchestrator:scale-test .
   kind load docker-image local/node-agent:scale-test --name sovereign-mohawk-scale-test
   kind load docker-image local/orchestrator:scale-test --name sovereign-mohawk-scale-test
   docker exec sovereign-mohawk-scale-test-control-plane crictl pull ipfs/kubo:v0.28.0
   ```

5. **Create the namespace and shared secret:**

   ```bash
   kubectl create namespace scale-test
   kubectl create secret generic mohawk-shared-secrets -n scale-test \
     --from-file=mohawk_api_token=<cert-dir>/mohawk_api_token \
     --from-file=mohawk_tpm_ca_cert.pem=<cert-dir>/mohawk_tpm_ca_cert.pem \
     --from-file=mohawk_tpm_orchestrator_cert.pem=<cert-dir>/mohawk_tpm_orchestrator_cert.pem \
     --from-file=mohawk_tpm_orchestrator_key.pem=<cert-dir>/mohawk_tpm_orchestrator_key.pem
   ```

6. **Deploy:**

   ```bash
   kubectl apply -f 01-orchestrator.yaml -f 02-ipfs.yaml
   kubectl -n scale-test wait --for=condition=Ready pod -l app=orchestrator --timeout=90s
   kubectl -n scale-test wait --for=condition=Ready pod -l app=ipfs --timeout=90s
   kubectl apply -f 03-node-agent.yaml
   ```

7. **Scale:**

   ```bash
   kubectl -n scale-test scale statefulset node-agent --replicas=500
   ```

   Watch progress with:

   ```bash
   kubectl -n scale-test get statefulset node-agent -w
   ```

   Real per-container resource usage (no metrics-server required):

   ```bash
   docker exec sovereign-mohawk-scale-test-control-plane crictl stats
   ```

## Notes

- `03-node-agent.yaml` is a `StatefulSet`, not a `Deployment`, specifically
  so each replica gets a stable ordinal hostname (`node-agent-0`,
  `node-agent-1`, ...) — the container's own startup script uses that
  ordinal to select its unique certificate from the pool, mirroring the
  `HOSTNAME`-index logic in `docker-compose.full.yml`'s `node-agent`
  service.
- The certificate pool is mounted via a `hostPath` volume, not a
  Kubernetes `Secret` — a single Secret has a 1MiB size limit, which a
  pool of a few hundred RSA-3072 cert/key pairs exceeds. `hostPath` only
  works because this is a single-node `kind` cluster; a real multi-node
  cluster would need a different distribution mechanism (e.g. one Secret
  per replica, or a shared read-only volume/CSI mount).
- If you push replica counts high enough to destabilize the control
  plane, see the evidence doc's root-cause section before assuming it's
  an application bug — on Docker Desktop specifically, it was disk I/O
  latency (etcd's WAL), not memory or CPU.
