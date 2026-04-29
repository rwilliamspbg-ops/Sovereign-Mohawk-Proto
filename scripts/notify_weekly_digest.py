#!/usr/bin/env python3
"""Post weekly digest notifications to Slack/Teams/Discord webhooks."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from urllib import request


def post_json(webhook: str, payload: dict, label: str) -> None:
    req = request.Request(
        webhook,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with request.urlopen(req, timeout=10) as resp:
        print(f"{label}: {resp.status}")


def chunk_for_discord(message: str, limit: int = 1900) -> list[str]:
    lines = message.splitlines(keepends=True)
    chunks: list[str] = []
    current = ""

    for line in lines:
        if len(line) > limit:
            if current:
                chunks.append(current)
                current = ""
            start = 0
            while start < len(line):
                chunks.append(line[start : start + limit])
                start += limit
            continue

        if len(current) + len(line) <= limit:
            current += line
        else:
            chunks.append(current)
            current = line

    if current:
        chunks.append(current)

    return chunks or [message[:limit]]


def build_text(digest_path: Path) -> str:
    digest = digest_path.read_text(encoding="utf-8")
    run_url = (
        f"{os.environ['GITHUB_SERVER_URL']}/"
        f"{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    )
    return f"Weekly Mainnet Readiness Digest\nRun: {run_url}\n\n{digest}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Post weekly digest webhook notifications"
    )
    parser.add_argument(
        "--digest-path",
        default="reports/weekly-readiness-digest.md",
        help="Path to generated digest markdown",
    )
    args = parser.parse_args()

    text = build_text(Path(args.digest_path))

    slack_teams_text = text
    if len(slack_teams_text) > 3500:
        slack_teams_text = (
            slack_teams_text[:3500]
            + "\n\n[truncated] See workflow artifacts for full digest."
        )

    for env_name in ("SLACK_WEBHOOK_URL", "TEAMS_WEBHOOK_URL"):
        webhook = os.environ.get(env_name, "").strip()
        if webhook:
            post_json(webhook, {"text": slack_teams_text}, env_name)

    discord_webhook = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if discord_webhook:
        chunks = chunk_for_discord(text)
        total = len(chunks)
        for i, chunk in enumerate(chunks, start=1):
            payload = {"content": chunk}
            if total > 1:
                payload["content"] = f"[{i}/{total}]\n{chunk}"
            post_json(discord_webhook, payload, f"DISCORD_WEBHOOK_URL ({i}/{total})")


if __name__ == "__main__":
    main()
