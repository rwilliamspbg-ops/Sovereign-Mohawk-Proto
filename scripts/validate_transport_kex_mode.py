#!/usr/bin/env python3
"""Validate enforcement of MOHAWK transport KEX mode across environments."""

from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List

DEFAULT_KEX_MODE = "x25519-mlkem768-hybrid"
DEFAULT_KEY_BYTES = 1216


@dataclass
class CheckResult:
    name: str
    ok: bool
    details: Dict[str, Any]


def _check_compose_file(path: Path, expected_mode: str) -> CheckResult:
    if not path.exists():
        return CheckResult(path.name, False, {"error": "file not found"})

    text = path.read_text(encoding="utf-8")
    expected_snippet = f"MOHAWK_TRANSPORT_KEX_MODE=${{MOHAWK_TRANSPORT_KEX_MODE:-{expected_mode}}}"
    hits = text.count(expected_snippet)
    return CheckResult(
        path.name,
        hits > 0,
        {
            "expected_snippet": expected_snippet,
            "occurrences": hits,
        },
    )


def _check_shell_export(path: Path, expected_mode: str) -> CheckResult:
    if not path.exists():
        return CheckResult(path.name, False, {"error": "file not found"})

    text = path.read_text(encoding="utf-8")
    pattern = re.compile(r'MOHAWK_TRANSPORT_KEX_MODE="\$\{MOHAWK_TRANSPORT_KEX_MODE:-([^}]+)\}"')
    matches = pattern.findall(text)
    ok = expected_mode in matches
    return CheckResult(
        path.name,
        ok,
        {
            "detected_defaults": matches,
        },
    )


def _check_runtime_env(expected_mode: str) -> CheckResult:
    value = os.getenv("MOHAWK_TRANSPORT_KEX_MODE", "").strip()
    if not value:
        return CheckResult(
            "environment",
            False,
            {
                "error": "MOHAWK_TRANSPORT_KEX_MODE not set in current shell",
            },
        )
    return CheckResult(
        "environment",
        value == expected_mode,
        {
            "value": value,
            "expected": expected_mode,
        },
    )


def _fetch_json(url: str, timeout: float) -> Dict[str, Any]:
    req = urllib.request.Request(url=url, method="GET")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _check_p2p_endpoint(
    url: str, expected_mode: str, expected_key_bytes: int, timeout: float
) -> CheckResult:
    try:
        payload = _fetch_json(url, timeout)
    except urllib.error.HTTPError as exc:
        return CheckResult(url, False, {"error": f"http error: {exc.code}"})
    except Exception as exc:  # noqa: BLE001
        return CheckResult(url, False, {"error": str(exc)})

    mode = str(payload.get("kex_mode", "")).strip()
    key_bytes = int(payload.get("expected_public_key_bytes", 0) or 0)

    ok = mode == expected_mode and key_bytes == expected_key_bytes
    return CheckResult(
        url,
        ok,
        {
            "kex_mode": mode,
            "expected_mode": expected_mode,
            "expected_public_key_bytes": key_bytes,
            "required_public_key_bytes": expected_key_bytes,
            "peer_id_present": bool(payload.get("peer_id")),
        },
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate x25519-mlkem768-hybrid transport KEX enforcement in compose defaults, "
            "launcher scripts, current environment, and optional /p2p/info endpoints."
        )
    )
    parser.add_argument("--repo-root", default=".", help="Repository root path")
    parser.add_argument("--expected-mode", default=DEFAULT_KEX_MODE, help="Expected KEX mode")
    parser.add_argument(
        "--expected-public-key-bytes",
        type=int,
        default=DEFAULT_KEY_BYTES,
        help="Expected hybrid public key byte size",
    )
    parser.add_argument(
        "--check-runtime-env",
        action="store_true",
        help="Validate current shell MOHAWK_TRANSPORT_KEX_MODE value",
    )
    parser.add_argument(
        "--p2p-info-url",
        action="append",
        default=[],
        help="Endpoint URL to check for kex_mode and expected_public_key_bytes",
    )
    parser.add_argument("--timeout", type=float, default=4.0, help="HTTP timeout seconds")
    parser.add_argument(
        "--output-json",
        default="-",
        help="Output report path (default: stdout)",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    root = Path(args.repo_root).resolve()

    checks: List[CheckResult] = []
    checks.append(_check_compose_file(root / "docker-compose.yml", args.expected_mode))
    checks.append(_check_compose_file(root / "docker-compose.full.yml", args.expected_mode))

    checks.append(
        _check_shell_export(root / "scripts" / "mainnet_one_click.sh", args.expected_mode)
    )
    checks.append(
        _check_shell_export(root / "scripts" / "launch_full_stack_3_nodes.sh", args.expected_mode)
    )

    if args.check_runtime_env:
        checks.append(_check_runtime_env(args.expected_mode))

    for url in args.p2p_info_url:
        checks.append(
            _check_p2p_endpoint(
                url=url,
                expected_mode=args.expected_mode,
                expected_key_bytes=args.expected_public_key_bytes,
                timeout=args.timeout,
            )
        )

    ok = all(item.ok for item in checks)
    report = {
        "ok": ok,
        "expected_mode": args.expected_mode,
        "expected_public_key_bytes": args.expected_public_key_bytes,
        "checks": [asdict(item) for item in checks],
    }

    text = json.dumps(report, indent=2, sort_keys=True)
    if args.output_json == "-":
        print(text)
    else:
        Path(args.output_json).write_text(text + "\n", encoding="utf-8")
        print(f"wrote kex validation report to {args.output_json}")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
