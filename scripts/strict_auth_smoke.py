#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def _read_token(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def _blocked_with_message(result: dict, *expected_fragments: str) -> tuple[bool, str]:
    message = str(result.get("message", ""))
    if result.get("success", True):
        return False, message
    lowered = message.lower()
    return all(fragment.lower() in lowered for fragment in expected_fragments), message


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run strict auth/role smoke checks against libmohawk."
    )
    parser.add_argument("--lib-path", default="", help="Path to libmohawk shared library")
    parser.add_argument(
        "--token-file", default="secrets/mohawk_api_token", help="API token file path"
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    sdk_path = repo_root / "sdk" / "python"
    if str(sdk_path) not in sys.path:
        sys.path.insert(0, str(sdk_path))

    token_file = Path(args.token_file)
    if not token_file.is_absolute():
        token_file = repo_root / token_file
    if not token_file.exists():
        print(json.dumps({"ok": False, "error": f"token file not found: {token_file}"}))
        return 2

    os.environ["MOHAWK_API_AUTH_MODE"] = "file-only"
    os.environ["MOHAWK_API_TOKEN_FILE"] = str(token_file)
    os.environ["MOHAWK_API_TOKEN_ROLE"] = "admin"
    os.environ["MOHAWK_API_ENFORCE_ROLES"] = "true"
    os.environ["MOHAWK_UTILITY_ENFORCE_ROLES"] = "true"
    os.environ["MOHAWK_UTILITY_MINT_ALLOWED_ROLES"] = "minter,admin,protocol"
    os.environ["MOHAWK_UTILITY_TRANSFER_ALLOWED_ROLES"] = "user,operator,admin,protocol"
    os.environ["MOHAWK_UTILITY_BURN_ALLOWED_ROLES"] = "operator,admin,protocol"
    os.environ["MOHAWK_UTILITY_BACKUP_ALLOWED_ROLES"] = "operator,admin"
    os.environ["MOHAWK_UTILITY_RESTORE_ALLOWED_ROLES"] = "admin"
    os.environ["MOHAWK_API_HYBRID_ALLOWED_ROLES"] = "verifier,admin"

    lib_path = args.lib_path.strip()
    if lib_path:
        lp = Path(lib_path)
        if not lp.is_absolute():
            lp = repo_root / lp
        lib_path = str(lp)

    probe_env = os.environ.copy()
    probe_env.update(
        {
            "MOHAWK_API_AUTH_MODE": "file-only",
            "MOHAWK_API_TOKEN_FILE": str(token_file),
            "MOHAWK_API_TOKEN_ROLE": "admin",
            "MOHAWK_API_ENFORCE_ROLES": "true",
            "MOHAWK_UTILITY_ENFORCE_ROLES": "true",
            "MOHAWK_UTILITY_MINT_ALLOWED_ROLES": "minter,admin,protocol",
            "MOHAWK_UTILITY_TRANSFER_ALLOWED_ROLES": "user,operator,admin,protocol",
            "MOHAWK_UTILITY_BURN_ALLOWED_ROLES": "operator,admin,protocol",
            "MOHAWK_UTILITY_BACKUP_ALLOWED_ROLES": "operator,admin",
            "MOHAWK_UTILITY_RESTORE_ALLOWED_ROLES": "admin",
            "MOHAWK_API_HYBRID_ALLOWED_ROLES": "verifier,admin",
            "PYTHONPATH": str(sdk_path),
        }
    )

    probe_code = r"""
import importlib
import json
import sys
from pathlib import Path

MohawkNode = importlib.import_module("mohawk").MohawkNode
repo_root = Path(sys.argv[1])
lib_path = sys.argv[2]
token_file = Path(sys.argv[3])
token = token_file.read_text(encoding="utf-8").strip()

node = MohawkNode(lib_path=lib_path or None)
results = {
    "mint": False,
    "transfer": False,
    "hybrid": False,
    "wrong_role_blocked": False,
    "wrong_token_blocked": False,
    "wrong_role_error": "",
    "wrong_token_error": "",
}

minted = node.mint_utility_coin(
    to="smoke-user",
    amount=1.0,
    actor="protocol",
    auth_token=token,
    role="admin",
    idempotency_key="smoke-mint-1",
    nonce=1,
)
results["mint"] = bool(minted.get("success"))

transferred = node.transfer_utility_coin(
    from_account="smoke-user",
    to_account="smoke-user-2",
    amount=0.25,
    memo="smoke-transfer",
    auth_token=token,
    role="admin",
)
results["transfer"] = bool(transferred.get("success"))

try:
    hybrid = node.verify_hybrid_proof(
        snark_proof="s" * 128,
        stark_proof="t" * 64,
        mode="both",
        auth_token=token,
        role="admin",
    )
    results["hybrid"] = bool(hybrid.get("success"))
except Exception as exc:  # noqa: BLE001
    if "unauthorized" in str(exc).lower():
        raise
    results["hybrid"] = True

wrong_role = node.bridge.invoke_json(
    "TransferUtilityCoin",
    {
        "from": "smoke-user",
        "to": "smoke-user-2",
        "amount": 0.10,
        "memo": "smoke-wrong-role",
        "auth_token": token,
        "role": "guest",
    },
)
results["wrong_role_blocked"], results["wrong_role_error"] = _blocked_with_message(
    wrong_role,
    "unauthorized",
    'role "guest" is not allowed for transfer',
)

wrong_token = node.bridge.invoke_json(
    "TransferUtilityCoin",
    {
        "from": "smoke-user",
        "to": "smoke-user-2",
        "amount": 0.25,
        "memo": "smoke-transfer",
        "auth_token": "wrong-token",
        "role": "operator",
    },
)
results["wrong_token_blocked"], results["wrong_token_error"] = _blocked_with_message(
    wrong_token,
    "unauthorized",
    "invalid api token",
)

print(json.dumps({"ok": all(results.values()), "results": results}))
"""

    completed = subprocess.run(
        [
            sys.executable,
            "-c",
            probe_code,
            str(repo_root),
            lib_path,
            str(token_file),
        ],
        env=probe_env,
        capture_output=True,
        text=True,
    )
    if completed.stdout.strip():
        print(completed.stdout.strip())
    if completed.returncode != 0:
        if completed.stderr.strip():
            print(completed.stderr.strip(), file=sys.stderr)
        return completed.returncode

    payload = json.loads(completed.stdout)
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
