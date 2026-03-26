#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def fail(message: str) -> int:
    print(f"PQC CONTRACT GATE FAILED: {message}")
    return 1


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_bridge_policies(path: Path) -> tuple[bool, str]:
    data = load_json(path)
    if data.get("version") != "v1":
        return False, "bridge-policies.json version must be v1"
    routes = data.get("routes")
    if not isinstance(routes, list) or len(routes) == 0:
        return False, "bridge-policies.json routes must be a non-empty list"

    for index, route in enumerate(routes):
        if not isinstance(route, dict):
            return False, f"route[{index}] must be an object"
        source = str(route.get("source_chain", "")).strip()
        target = str(route.get("target_chain", "")).strip()
        policy = route.get("policy")
        if not source or not target:
            return False, f"route[{index}] missing source_chain/target_chain"
        if source == target:
            return False, f"route[{index}] source_chain must differ from target_chain"
        if not isinstance(policy, dict):
            return False, f"route[{index}] missing policy object"
        policy_id = str(policy.get("id", "")).strip()
        allowed_assets = policy.get("allowed_assets")
        min_finality = policy.get("min_finality_blocks")
        if not policy_id:
            return False, f"route[{index}] policy.id is required"
        if not isinstance(allowed_assets, list) or len(allowed_assets) == 0:
            return False, f"route[{index}] policy.allowed_assets must be a non-empty list"
        if not isinstance(min_finality, (int, float)) or min_finality <= 0:
            return False, f"route[{index}] policy.min_finality_blocks must be > 0"
    return True, "ok"


def validate_capabilities(path: Path) -> tuple[bool, str]:
    data = load_json(path)
    threshold = float(data.get("byzantine_threshold", 1.0))
    if threshold > 0.555:
        return False, f"byzantine_threshold exceeds limit: {threshold}"
    runtime = str(data.get("runtime", "")).strip().lower()
    if "mohawk" not in runtime:
        return False, "capabilities runtime must reference mohawk"
    return True, "ok"


def validate_compose_pqc_defaults(path: Path) -> tuple[bool, str]:
    text = path.read_text(encoding="utf-8")
    required_lines = [
        "MOHAWK_TRANSPORT_KEX_MODE=${MOHAWK_TRANSPORT_KEX_MODE:-x25519-mlkem768-hybrid}",
        "MOHAWK_TPM_IDENTITY_SIG_MODE=${MOHAWK_TPM_IDENTITY_SIG_MODE:-xmss}",
        "MOHAWK_PQC_MIGRATION_ENABLED=${MOHAWK_PQC_MIGRATION_ENABLED:-true}",
        "MOHAWK_PQC_LOCK_LEGACY_TRANSFERS=${MOHAWK_PQC_LOCK_LEGACY_TRANSFERS:-true}",
    ]
    for line in required_lines:
        if line not in text:
            return False, f"docker-compose missing required PQC default: {line}"
    return True, "ok"


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    bridge_policies_path = root / "bridge-policies.json"
    capabilities_path = root / "capabilities.json"
    compose_path = root / "docker-compose.yml"

    for path in (bridge_policies_path, capabilities_path, compose_path):
        if not path.exists():
            return fail(f"required file missing: {path}")

    ok, msg = validate_bridge_policies(bridge_policies_path)
    if not ok:
        return fail(msg)

    ok, msg = validate_capabilities(capabilities_path)
    if not ok:
        return fail(msg)

    ok, msg = validate_compose_pqc_defaults(compose_path)
    if not ok:
        return fail(msg)

    print(
        "PQC CONTRACT GATE PASSED: bridge policies, capabilities, and compose PQC defaults validated"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
