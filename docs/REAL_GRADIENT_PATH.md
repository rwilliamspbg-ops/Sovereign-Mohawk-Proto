# Real gradients and federation forwarding in node-agents

Two optional node-agent modes connect the live p2p path to trained gradients
and to the federation hierarchy:

- `MOHAWK_GRADIENT_MODE=file` reads a trained vector from
  `MOHAWK_GRADIENT_FILE` (JSON: `{"node_id": "...", "gradient": [...]}`).
  If the file is missing or malformed, the agent falls back to `seeded`.
- `MOHAWK_FEDERATION_PARENT=host:port` makes each accepted gradient also be
  forwarded over the project's federation RPC protocol to that parent tier.

`scripts/export_trained_gradient.py` produces the file using only the Python
standard library: it trains a small linear model with SGD on deterministic data
and exports the final mini-batch gradient. Different `--seed` values give
different honest gradients, so Multi-Krum sees genuine distances.

## Example

```bash
python scripts/export_trained_gradient.py --node-id deskmini-node-1 --seed 11 \
  --dims 128 --out gradients/node-1.json

MOHAWK_GRADIENT_MODE=file MOHAWK_GRADIENT_FILE=gradients/node-1.json \
MOHAWK_FEDERATION_PARENT=127.0.0.1:9126 \
docker compose -f lan-compose-b.yml up -d --no-deps --force-recreate node-agent-1
```

The agent still submits over libp2p to the orchestrator (preserving live
Multi-Krum decision logging); the federation forward is additional, so a
regional coordinator receives the same vector as a child update.

## Scope

The trainer is a small SGD model, not a Flower client: this replaces synthetic
seeded/poisoned vectors with genuinely trained gradients while keeping the
zero-dependency property of the testbed. Byzantine mode is still available via
`MOHAWK_GRADIENT_MODE=byzantine` for adversarial comparisons. Both paths are
transport-accurate; neither claims model-accuracy results under attack.

## Flower-client export (research step)

`scripts/export_flower_gradient.py` replaces the stdlib trainer with a genuine
`flwr.client.NumPyClient` that trains a small linear model through Flower's
`fit()` interface and exports the resulting gradient in the same JSON schema:

```bash
uv venv --python 3.14 .venv-flower
uv pip install --python .venv-flower/Scripts/python.exe 'flwr[simulation]>=1.17,<2' numpy
.venv-flower/Scripts/python.exe scripts/export_flower_gradient.py   --node-id deskmini-node-1 --seed 11 --dims 128 --out gradients/node-1.json
```

`flwr` and `numpy` are optional: without them the script exits with a clear
message and its tests skip. The claim is now "Flower client trained gradient",
not merely "SGD vector"; it still uses synthetic training data and does not
claim model-accuracy resilience under attack.
