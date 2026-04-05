#!/usr/bin/env python3
"""Demonstrate WASM path load + inline hot-reload via bytes/base64."""

import base64
import hashlib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from mohawk import InitializationError, MohawkNode


def _print_result(title: str, result: dict, ci_mode: bool) -> None:
    if ci_mode:
        status = "ok" if result.get("success") else "fail"
        hash_value = result.get("module_hash", "-")
        print(f"{title}: {status} module_hash={hash_value}")
        return

    print(title)
    print(f"  success: {result.get('success')}")
    print(f"  message: {result.get('message')}")
    if result.get("module_hash"):
        print(f"  module_hash: {result['module_hash']}")
    if result.get("module_path"):
        print(f"  module_path: {result['module_path']}")
    if result.get("data"):
        try:
            decoded = json.loads(result["data"])
            print(f"  data: {json.dumps(decoded)}")
        except Exception:
            print(f"  data: {result['data']}")
    print()


def main() -> None:
    ci_mode = "--ci" in sys.argv or os.getenv("CI") == "1"

    print("🧱 MOHAWK WASM Hot-Reload Demo\n")

    wasm_path = Path("wasm-modules/fl_task/target/wasm32-wasi/release/fl_task.wasm")

    try:
        node = MohawkNode()

        # 1) Standard filesystem load
        by_path = node.load_wasm(str(wasm_path))
        _print_result("1) Load by path", by_path, ci_mode)

        # 2) Inline bytes hot-reload (signed)
        if wasm_path.exists():
            wasm_bytes = wasm_path.read_bytes()
        else:
            wasm_bytes = b"\x00asm\x01\x00\x00\x00"
        module_signature = os.getenv("MOHAWK_WASM_MODULE_SIGNATURE", "")
        module_public_key = os.getenv("MOHAWK_WASM_MODULE_PUBLIC_KEY", "")
        by_bytes = {}
        by_b64 = {}
        if module_signature and module_public_key:
            module_sha256 = hashlib.sha256(wasm_bytes).hexdigest()
            by_bytes = node.load_wasm(
                wasm_bytes=wasm_bytes,
                module_sha256=module_sha256,
                module_signature=module_signature,
                module_public_key=module_public_key,
            )
            _print_result("2) Hot-reload by bytes", by_bytes, ci_mode)

            # 3) Inline base64 hot-reload
            wasm_b64 = base64.b64encode(wasm_bytes).decode("ascii")
            by_b64 = node.load_wasm(
                wasm_b64=wasm_b64,
                module_sha256=module_sha256,
                module_signature=module_signature,
                module_public_key=module_public_key,
            )
            _print_result("3) Hot-reload by base64", by_b64, ci_mode)

            if (
                by_path.get("module_hash")
                and by_bytes.get("module_hash")
                and by_b64.get("module_hash")
            ):
                if not (by_path["module_hash"] == by_bytes["module_hash"] == by_b64["module_hash"]):
                    raise RuntimeError("module_hash mismatch across path/bytes/base64 loads")
        else:
            print(
                "2) Skipping inline hot-reload: set MOHAWK_WASM_MODULE_SIGNATURE and MOHAWK_WASM_MODULE_PUBLIC_KEY"
            )

        status = node.status("demo-node")
        data = status.get("status_data") or status.get("data")
        if ci_mode:
            print(f"4) Status snapshot: {status.get('message')} status_data_present={bool(data)}")
        else:
            print("4) Status snapshot")
            print(f"  message: {status.get('message')}")
            print(f"  status_data: {data}")

    except InitializationError as exc:
        print(f"Initialization failed: {exc}")
        print("Build shared library first: make build-python-lib")
        raise SystemExit(1)
    except Exception as exc:
        print(f"Unexpected error: {exc}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
