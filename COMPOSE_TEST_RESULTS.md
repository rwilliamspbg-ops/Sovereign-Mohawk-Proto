# Docker Compose & Genesis Launch Test Results

Date: 2026-05-11

Summary:
- Scanned repository and located 5 docker-compose files and a `genesis-launch.sh` script.
- Attempted to start core services from `docker-compose.yml` (prometheus, alertmanager, grafana, ipfs, ops-assistant).

Outcome:
- `prometheus`, `grafana`, `alertmanager`, and `ipfs` images were pulled successfully.
- `ops-assistant` failed to build during `npm ci --only=production` due to a missing private npm package:

Error excerpt:
```
npm error 404 Not Found - GET https://registry.npmjs.org/@copilotkit%2freact-actions - Not found
npm error 404  '@copilotkit/react-actions@^1.57.1' is not in this registry.
```

Implication:
- The `ops-assistant` Dockerfile requires private package `@copilotkit/react-actions` which is not available from the public npm registry in this environment. Because of that, the `ops-assistant` container could not be built and therefore could not start.

Next steps / Recommendations:
- Provide access to the private package (via npm registry auth, private registry, or substitute local package path).
- Alternatively, modify `web/ops-assistant/package.json` to use a public or local equivalent for testing.
- After providing the dependency, re-run:

```bash
/scripts/docker-compose-wrapper.sh -f /workspaces/Sovereign-Mohawk-Proto/docker-compose.yml up -d prometheus alertmanager grafana ops-assistant ipfs
```

- Then check health of `ops-assistant`:

```bash
docker inspect -f '{{.State.Health.Status}}' ops-assistant
```

- To test `genesis-launch.sh`, ensure the same dependency is resolvable because genesis starts `ops-assistant` as part of CORE_SERVICES.

Files inspected:
- docker-compose.yml
- docker-compose.full.yml
- docker-compose.phase3-staging.yml
- docker-compose.sandbox.yml
- docker-compose.wsl2.yml
- genesis-launch.sh
- scripts/docker-compose-wrapper.sh
- web/ops-assistant/Dockerfile


Status: BLOCKED (ops-assistant build failure due to missing npm package)
