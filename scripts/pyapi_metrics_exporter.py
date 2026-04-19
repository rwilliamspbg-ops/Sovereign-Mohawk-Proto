#!/usr/bin/env python3
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SDK_PATH = ROOT / "sdk" / "python"

if str(SDK_PATH) not in os.sys.path:
    os.sys.path.insert(0, str(SDK_PATH))

from mohawk import MohawkNode  # noqa: E402


def _load_token() -> str:
    token_path = Path(
        os.getenv("MOHAWK_API_TOKEN_FILE", str(ROOT / "runtime-secrets" / "mohawk_api_token"))
    )
    if not token_path.is_absolute():
        token_path = ROOT / token_path
    return token_path.read_text(encoding="utf-8").strip()


def _int_env(name: str, default: int) -> int:
    raw = os.getenv(name, "")
    if raw is None:
        return default
    raw = raw.strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


class ExporterState:
    def __init__(self) -> None:
        self.node = MohawkNode(lib_path=os.getenv("MOHAWK_LIB_PATH", str(ROOT / "libmohawk.so")))
        self.token = _load_token()
        self.lock = threading.Lock()
        self.last_error = ""

        os.environ.setdefault("MOHAWK_API_AUTH_MODE", "file-only")
        os.environ.setdefault("MOHAWK_API_ENFORCE_ROLES", "true")
        os.environ.setdefault("MOHAWK_API_HYBRID_ALLOWED_ROLES", "verifier,admin")

    def metrics_text(self) -> str:
        snapshot = self.node.metrics_snapshot()
        data = snapshot.get("data", "")
        if not isinstance(data, str):
            data = json.dumps(data)
        return data

    def emit_hybrid_and_utility(self) -> None:
        self.node.mint_utility_coin(
            to="metrics-exporter",
            amount=1.0,
            actor="protocol",
            auth_token=self.token,
            role="admin",
            idempotency_key="pyapi-metrics-exporter-mint",
            nonce=1,
        )
        self.node.transfer_utility_coin(
            sender="metrics-exporter",
            recipient="metrics-exporter-peer",
            amount=0.1,
            memo="pyapi-metrics-exporter-transfer",
            auth_token=self.token,
            role="admin",
            idempotency_key="pyapi-metrics-exporter-transfer",
            nonce=2,
        )
        try:
            self.node.verify_hybrid_proof(
                snark_proof="s" * 128,
                stark_proof="t" * 64,
                mode="both",
                auth_token=self.token,
                role="verifier",
            )
        except Exception:
            pass


def start_traffic_loop(state: ExporterState) -> None:
    enabled = os.getenv("MOHAWK_PYAPI_TRAFFIC_ENABLED", "true").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
    if not enabled:
        return
    interval = max(2, _int_env("MOHAWK_PYAPI_TRAFFIC_INTERVAL_SECONDS", 10))

    def worker() -> None:
        while True:
            try:
                state.emit_hybrid_and_utility()
                state.last_error = ""
            except Exception as exc:  # noqa: BLE001
                state.last_error = str(exc)
            time.sleep(interval)

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()


class MetricsHandler(BaseHTTPRequestHandler):
    state: ExporterState = None  # type: ignore

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            payload = {
                "ok": True,
                "last_error": self.state.last_error,
            }
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return

        try:
            body = self.state.metrics_text().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as exc:  # noqa: BLE001
            body = f"# exporter_error {exc}\n".encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)


def main() -> int:
    state = ExporterState()
    MetricsHandler.state = state
    start_traffic_loop(state)

    addr = os.getenv("MOHAWK_PYAPI_EXPORTER_ADDR", "0.0.0.0")
    port = _int_env("MOHAWK_PYAPI_EXPORTER_PORT", 9104)
    server = HTTPServer((addr, port), MetricsHandler)
    print(f"pyapi metrics exporter listening on {addr}:{port}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
