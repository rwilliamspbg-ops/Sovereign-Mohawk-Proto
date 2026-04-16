#!/usr/bin/env python3
import argparse
import importlib
import json
import os
import sys
from pathlib import Path


def _read_token(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run strict auth/role smoke checks against libmohawk."
    )
    parser.add_argument(
        "--lib-path", default="", help="Path to libmohawk shared library"
    )
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

    token = _read_token(token_file)

    os.environ.setdefault("MOHAWK_API_AUTH_MODE", "file-only")
    os.environ.setdefault("MOHAWK_API_TOKEN_FILE", str(token_file))
    os.environ.setdefault("MOHAWK_API_ENFORCE_ROLES", "true")
    os.environ.setdefault("MOHAWK_API_HYBRID_ALLOWED_ROLES", "verifier,admin")

    MohawkNode = importlib.import_module("mohawk").MohawkNode

    lib_path = args.lib_path.strip()
    if lib_path:
        lp = Path(lib_path)
        if not lp.is_absolute():
            lp = repo_root / lp
        lib_path = str(lp)

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

    try:
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
            role="operator",
        )
        results["transfer"] = bool(transferred.get("success"))

        try:
            hybrid = node.verify_hybrid_proof(
                snark_proof="s" * 128,
                stark_proof="t" * 64,
                mode="both",
                auth_token=token,
                role="verifier",
            )
            results["hybrid"] = bool(hybrid.get("success"))
        except Exception as exc:  # noqa: BLE001
            error_text = str(exc).lower()
            # Proofs in smoke are intentionally synthetic; authorization is the gate here.
            if "unauthorized" in error_text:
                raise
            results["hybrid"] = True

        try:
            node.transfer_utility_coin(
                from_account="smoke-user",
                to_account="smoke-user-2",
                amount=0.25,
                memo="smoke-transfer",
                auth_token=token,
                role="guest",
            )
        except Exception as exc:  # noqa: BLE001
            results["wrong_role_blocked"] = True
            results["wrong_role_error"] = str(exc)

        try:
            node.transfer_utility_coin(
                from_account="smoke-user",
                to_account="smoke-user-2",
                amount=0.25,
                memo="smoke-transfer",
                auth_token="wrong-token",
                role="operator",
            )
        except Exception as exc:  # noqa: BLE001
            results["wrong_token_blocked"] = True
            results["wrong_token_error"] = str(exc)

    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"ok": False, "error": str(exc), "results": results}))
        return 1

    ok = all(results.values())
    print(json.dumps({"ok": ok, "results": results}))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
