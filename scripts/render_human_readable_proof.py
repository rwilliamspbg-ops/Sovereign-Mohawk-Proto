#!/usr/bin/env python3
"""Render cryptographic verification responses into human-readable summaries."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict


def _load_json(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _safe_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def render_summary(result: Dict[str, Any]) -> Dict[str, Any]:
    data = result.get("data")
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except json.JSONDecodeError:
            data = {}
    if not isinstance(data, dict):
        data = {}

    success = bool(result.get("success", False))
    mode = data.get("mode") or result.get("mode") or "unknown"
    scheme = data.get("selected_scheme") or data.get("scheme") or "unknown"
    backend = data.get("stark_backend") or "n/a"
    elapsed_ms = _safe_float(result.get("verification_time_ms"))

    if success:
        verdict = "Verified"
        trust = "high"
    else:
        verdict = "Rejected"
        trust = "low"

    explanation = [
        f"Verdict: {verdict}",
        f"Proof mode: {mode}",
        f"Verification scheme: {scheme}",
        f"STARK backend: {backend}",
    ]
    if elapsed_ms is not None:
        explanation.append(f"Verification time: {elapsed_ms:.3f} ms")

    message = str(result.get("message", ""))
    if message:
        explanation.append(f"Runtime message: {message}")

    return {
        "human_readable": {
            "verdict": verdict,
            "trust_level": trust,
            "plain_language_summary": "; ".join(explanation),
            "next_action": (
                "Accept this update for aggregation and settlement."
                if success
                else "Quarantine this update, inspect signatures, and re-run verification."
            ),
        },
        "raw": result,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Translate proof verification JSON into a plain-language report"
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to JSON file containing verify_proof or verify_hybrid_proof output",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Output path for rendered report (default: stdout)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload = _load_json(args.input)
        rendered = render_summary(payload)
        text = json.dumps(rendered, indent=2, sort_keys=True)
        if args.output == "-":
            print(text)
        else:
            Path(args.output).write_text(text + "\n", encoding="utf-8")
            print(f"wrote human-readable proof report to {args.output}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
