#!/usr/bin/env python3
"""Generate ``docs/api/GRPC_FEDERATION.md`` from ``api/federation/federation.proto``.

The proto is the single source of truth.  This script parses it with the Python
standard library only (no protobuf/grpc dependencies) and renders the reference
document.  A small, explicit override map carries prose that is not derivable
from the proto file (notably the Go import path, which changed in the proto
after the document was first written, and a few field descriptions).

Usage:
    python3 scripts/generate_grpc_api_doc.py            # write the document
    python3 scripts/generate_grpc_api_doc.py --check    # fail on drift
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PROTO_PATH = REPO_ROOT / "api" / "federation" / "federation.proto"
DOC_PATH = REPO_ROOT / "docs" / "api" / "GRPC_FEDERATION.md"

# --------------------------------------------------------------------------
# Prose that is not derivable from the proto (override map).
#
# Keep this deliberately small: anything the proto actually says is parsed
# from the proto, so the override map cannot silently mask drift.  Only the
# pieces below live outside the .proto file.
# --------------------------------------------------------------------------

HEADER_STATUS = (
    "**Status**: Generated from `api/federation/federation.proto`; " "do not edit by hand."
)

# The proto's option go_package points at the codegen output module.  The
# repository packages the generated Go types under gen/federation (import path
# below), so the document records the import path rather than the option
# verbatim; the proto option is still validated against it.
GO_PACKAGE_DOC = "github.com/sovereign-mohawk/proto-gen/federation;federationpb"
GO_PACKAGE_PROTO_EXPECTED = (
    "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/gen/federation;federationpb"
)

SERVICE_SUMMARY = "Handles gradient forwarding and aggregation across tiers (L1 to L4)."

# Comment prose attached to individual messages (the proto only carries a
# leading comment on some of them).
MESSAGE_SUMMARY = {
    "GradientRequest": "Single gradient forwarded to parent tier.",
    "GradientStreamMessage": "Sent by child nodes to parent (stream client to server).",
    "AggregationStreamResponse": "Sent by parent to children (stream server to client).",
    "SingleGradient": "One gradient inside a GradientStreamMessage.",
    "AggregationResult": "Aggregated gradient result for one round.",
    "BatchRequest": "Batch of gradients forwarded together.",
    "ForwardResponse": "Acknowledgement returned by ForwardGradient/ForwardBatch.",
    "HealthCheckRequest": "Periodic health probe payload.",
    "HealthCheckResponse": "Tier link health snapshot.",
}

# Comments the proto does not carry (or carries only partially).  Everything
# else is taken verbatim from the proto's own comments.
FIELD_DESCRIPTION_OVERRIDE = {
    ("GradientRequest", "gradient_id"): "Gradient identity",
    ("GradientRequest", "source_node_id"): "Originating node",
    ("GradientRequest", "source_tier_node_id"): "Tier node id",
    ("GradientRequest", "aggregation_round"): "Round number",
    ("GradientRequest", "dimension_count"): "Tensor dimensionality",
    ("GradientRequest", "gradient_data"): "Gradient values",
    ("GradientRequest", "norm"): "Gradient norm",
    ("GradientRequest", "timestamp"): "Creation time",
    ("GradientRequest", "path_hops"): "Breadcrumb trail",
    ("GradientRequest", "proof"): "Byzantine resilience proof",
    ("BatchRequest", "gradients"): "Gradients to forward",
    ("BatchRequest", "batch_id"): "Batch identifier",
    ("BatchRequest", "batch_size"): "Number of gradients",
    ("ForwardResponse", "success"): "Whether accepted",
    ("ForwardResponse", "message"): "Status message",
    ("ForwardResponse", "accepted_count"): "Gradients accepted",
    ("ForwardResponse", "server_process_time_ms"): "Server processing time",
    ("GradientStreamMessage", "source_node_id"): "Originating node",
    ("GradientStreamMessage", "source_tier_node_id"): "Tier node id",
    ("GradientStreamMessage", "gradients"): "One or more gradients",
    ("GradientStreamMessage", "aggregation_round"): "Round number",
    ("GradientStreamMessage", "timestamp"): "Creation time",
    ("SingleGradient", "gradient_id"): "Gradient identity",
    ("SingleGradient", "dimension_count"): "Tensor dimensionality",
    ("SingleGradient", "gradient_data"): "Gradient values",
    ("SingleGradient", "norm"): "Gradient norm",
    ("SingleGradient", "proof"): "Byzantine resilience proof",
    ("AggregationStreamResponse", "gradient_id"): "Acknowledged gradient",
    ("AggregationStreamResponse", "received"): "Whether received",
    ("AggregationStreamResponse", "aggregation_status"): '"received" / "processing" / "aggregated"',
    ("AggregationStreamResponse", "server_process_time_ms"): "Server processing time",
    ("AggregationStreamResponse", "timestamp"): "Response time",
    ("AggregationStreamResponse", "round_result"): "Batch result when round complete",
    ("AggregationResult", "round_id"): "Round identifier",
    ("AggregationResult", "tier_node_id"): "Aggregating tier node",
    ("AggregationResult", "aggregated_count"): "Gradients aggregated",
    ("AggregationResult", "skipped_count"): "Byzantine-filtered count",
    ("AggregationResult", "gradient_result"): "Aggregated gradient",
    ("AggregationResult", "gradient_norm"): "Aggregated norm",
    ("AggregationResult", "aggregation_time_ms"): "Aggregation duration",
    ("AggregationResult", "aggregation_method"): '"mean" / "median" / "multikrum" / etc.',
    ("HealthCheckRequest", "tier_node_id"): "Tier node id",
    ("HealthCheckResponse", "healthy"): "Whether the tier link is healthy",
    ("HealthCheckResponse", "latency_ms"): "Round-trip latency in milliseconds",
    ("HealthCheckResponse", "packet_loss"): "Observed packet loss fraction",
    ("HealthCheckResponse", "gradients_forwarded"): "Gradients forwarded so far",
    ("HealthCheckResponse", "gradients_received"): "Gradients received so far",
    ("HealthCheckResponse", "last_check"): "Time of the last health check",
}

FOOTER = """## Regeneration

This document is generated from `api/federation/federation.proto` by
`make docs-api` (`scripts/generate_grpc_api_doc.py`); do not edit it by hand.
`make docs-api-check` regenerates it into a temporary file and fails if the
committed copy differs, so proto and document cannot drift apart.
"""


# --------------------------------------------------------------------------
# Minimal proto3 parser (stdlib only).
# --------------------------------------------------------------------------


def _strip_comments(text: str) -> tuple[str, dict[int, list[str]]]:
    """Return text without comments plus leading-comment blocks keyed by line."""
    comment_blocks: dict[int, list[str]] = {}
    out_lines: list[str] = []
    pending: list[str] = []
    for raw in text.splitlines():
        code, comment = _split_line(raw)
        code = code.rstrip()
        if comment is not None:
            comment = comment.strip()
            if comment.startswith("//"):
                pending.append(comment[2:].strip())
        if code.strip():
            out_lines.append(code)
            if pending:
                comment_blocks[len(out_lines)] = pending
                pending = []
        elif not comment:
            # A blank line with no comment ends the pending comment block.
            pending = []
    return "\n".join(out_lines), comment_blocks


def _split_line(raw: str) -> tuple[str, str | None]:
    """Split one source line into code and ``//`` comment (string-aware)."""
    in_string = False
    escaped = False
    for index, char in enumerate(raw):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
            continue
        if char == "/" and raw[index : index + 2] == "//":
            return raw[:index], raw[index + 2 :]
    return raw, None


def _balanced(text: str, start: int) -> int:
    """Return the index of the ``}`` closing the ``{`` at ``start``."""
    depth = 0
    in_string = False
    escaped = False
    index = start
    while index < len(text):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise ValueError("unbalanced braces in proto")


def _skip_ws(text: str, index: int) -> int:
    while index < len(text) and text[index].isspace():
        index += 1
    return index


def _scan_to_semicolon(text: str, index: int) -> int:
    """Advance to the next top-level `;`, ignoring semicolons inside strings.

    Needed because `option go_package = "...;..."` carries a semicolon inside
    its quoted value.
    """
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == ";":
            return index
        index += 1
    return index


def _read_string(text: str, index: int) -> tuple[str, int]:
    index = _skip_ws(text, index)
    if index >= len(text) or text[index] != '"':
        raise ValueError(f"expected string at offset {index}")
    index += 1
    chars: list[str] = []
    while index < len(text):
        char = text[index]
        if char == "\\" and index + 1 < len(text):
            chars.append(text[index + 1])
            index += 2
            continue
        if char == '"':
            return "".join(chars), index + 1
        chars.append(char)
        index += 1
    raise ValueError("unterminated string literal")


def _match(text: str, index: int, keyword: str) -> bool:
    end = index + len(keyword)
    if text[index:end] != keyword:
        return False
    before = text[index - 1] if index > 0 else " "
    after = text[end] if end < len(text) else " "
    return not (before.isalnum() or before in "_$") and not (after.isalnum() or after in "_$")


def _expect(text: str, index: int, char: str) -> int:
    index = _skip_ws(text, index)
    if index >= len(text) or text[index] != char:
        raise ValueError(f"expected {char!r} at offset {index} in proto")
    return index + 1


def _skip_balanced(text: str, index: int) -> int:
    """Skip a ``{ ... }`` block (already positioned at ``{``)."""
    return _balanced(text, index) + 1


class ProtoModel:
    """Parsed view of the parts of a .proto file this document renders."""

    def __init__(self) -> None:
        self.syntax = ""
        self.package = ""
        self.go_package = ""
        self.imports: list[str] = []
        self.services: list[dict] = []
        self.messages: list[dict] = []


def parse_proto(text: str) -> ProtoModel:
    stripped, comment_blocks = _strip_comments(text)
    lines = stripped.splitlines()
    # Map each stripped line to the line number it had in the stripped text.
    stripped_to_original = list(range(len(lines)))
    model = ProtoModel()
    index = 0
    while index < len(stripped):
        char = stripped[index]
        if char.isspace():
            index += 1
            continue
        if char == ";":
            index += 1
            continue
        word, index = _read_word(stripped, index)
        if word == "syntax":
            index = _expect(stripped, index, "=")
            value, index = _read_string(stripped, index)
            model.syntax = value
            index = _expect(stripped, index, ";")
        elif word == "package":
            start = index
            index = _scan_to_semicolon(stripped, index)
            model.package = stripped[start:index].strip()
        elif word == "import":
            index = _skip_ws(stripped, index)
            if _match(stripped, index, "public") or _match(stripped, index, "weak"):
                _, index = _read_word(stripped, index)
            value, index = _read_string(stripped, index)
            model.imports.append(value)
            index = _expect(stripped, index, ";")
        elif word == "option":
            start = index
            index = _scan_to_semicolon(stripped, index)
            option_text = stripped[start:index]
            match = re.search(r"go_package\s*=\s*\"([^\"]*)\"", option_text)
            if match:
                model.go_package = match.group(1)
        elif word == "service":
            name, index = _read_name(stripped, index)
            index = _expect(stripped, index, "{") - 1  # step back onto the '{'
            body_end = _balanced(stripped, index)
            body = stripped[index + 1 : body_end]
            model.services.append(
                {
                    "name": name,
                    "rpcs": _parse_rpcs(body),
                    "comment": _block_comment(comment_blocks, lines, name),
                }
            )
            index = body_end + 1
        elif word == "message":
            name, index = _read_name(stripped, index)
            index = _expect(stripped, index, "{") - 1  # step back onto the '{'
            body_end = _balanced(stripped, index)
            body = stripped[index + 1 : body_end]
            model.messages.append(
                {
                    "name": name,
                    "fields": _parse_fields(body),
                    "comment": _block_comment(comment_blocks, lines, name),
                }
            )
            index = body_end + 1
        else:
            # option blocks, enum, reserved, etc. -- skip to the next statement.
            if index < len(stripped) and stripped[index] == "{":
                index = _skip_balanced(stripped, index)
            else:
                while index < len(stripped) and stripped[index] != ";":
                    index += 1
                index += 1
    return model


def _read_word(text: str, index: int) -> tuple[str, int]:
    index = _skip_ws(text, index)
    start = index
    while index < len(text) and (text[index].isalnum() or text[index] in "_$."):
        index += 1
    if start == index:
        raise ValueError(f"expected identifier at offset {index}")
    return text[start:index], index


def _read_name(text: str, index: int) -> tuple[str, int]:
    index = _skip_ws(text, index)
    start = index
    while index < len(text) and (text[index].isalnum() or text[index] in "_."):
        index += 1
    if start == index:
        raise ValueError(f"expected name at offset {index}")
    return text[start:index], index


def _parse_rpcs(body: str) -> list[dict]:
    rpcs: list[dict] = []
    index = 0
    while index < len(body):
        index = _skip_ws(body, index)
        if index >= len(body):
            break
        if body.startswith("//", index):
            index = body.find("\n", index)
            index = len(body) if index == -1 else index + 1
            continue
        word, index = _read_word(body, index)
        if word != "rpc":
            # options/semicolons inside the service body.
            index = _skip_ws(body, index)
            if index < len(body) and body[index] == "{":
                index = _skip_balanced(body, index)
            elif index < len(body) and body[index] == ";":
                index += 1
            else:
                while index < len(body) and body[index] not in ";{":
                    index += 1
            continue
        name, index = _read_name(body, index)
        index = _expect(body, index, "(")
        client_streaming = False
        probe = _skip_ws(body, index)
        if _match(body, probe, "stream"):
            client_streaming = True
            _, index = _read_word(body, index)
        request, index = _read_name(body, index)
        index = _expect(body, index, ")")
        returns, index = _read_word(body, index)
        if returns != "returns":
            raise ValueError(f"expected 'returns' in rpc {name}")
        index = _expect(body, index, "(")
        server_streaming = False
        probe = _skip_ws(body, index)
        if _match(body, probe, "stream"):
            server_streaming = True
            _, index = _read_word(body, index)
        response, index = _read_name(body, index)
        index = _expect(body, index, ")")
        index = _skip_ws(body, index)
        if index < len(body) and body[index] == "{":
            index = _skip_balanced(body, index)
            index = _skip_ws(body, index)
            if index < len(body) and body[index] == ";":
                index += 1
        else:
            index = _expect(body, index, ";")
        rpcs.append(
            {
                "name": name,
                "request": request,
                "response": response,
                "client_streaming": client_streaming,
                "server_streaming": server_streaming,
            }
        )
    return rpcs


def _parse_fields(body: str) -> list[dict]:
    fields: list[dict] = []
    index = 0
    while index < len(body):
        index = _skip_ws(body, index)
        if index >= len(body):
            break
        if body.startswith("//", index):
            index = body.find("\n", index)
            index = len(body) if index == -1 else index + 1
            continue
        word, index = _read_word(body, index)
        if word in ("option", "reserved", "enum", "message", "oneof"):
            index = _skip_ws(body, index)
            if index < len(body) and body[index] == "{":
                index = _skip_balanced(body, index)
            else:
                while index < len(body) and body[index] != ";":
                    index += 1
                index += 1
            continue
        # `word` is the first token: a label (`repeated`/`required`/`optional`)
        # or, more often, the field type itself.
        repeated = word == "repeated"
        if repeated or word in ("required", "optional"):
            # `word` was the label; the next token is the type.
            field_type, index = _read_name(body, index)
        else:
            field_type = word
        name, index = _read_name(body, index)
        index = _expect(body, index, "=")
        number_text, index = _read_name(body, index)
        options: list[str] = []
        index = _skip_ws(body, index)
        if index < len(body) and body[index] == "[":
            depth = 0
            start = index
            while index < len(body):
                if body[index] == "[":
                    depth += 1
                elif body[index] == "]":
                    depth -= 1
                    if depth == 0:
                        index += 1
                        break
                index += 1
            options = [part.strip() for part in body[start + 1 : index - 1].split(",")]
        index = _skip_ws(body, index)
        if index < len(body) and body[index] == ";":
            index += 1
        fields.append(
            {
                "name": name,
                "number": int(number_text),
                "type": field_type,
                "repeated": repeated,
                "packed": "packed = true" in options or "packed=true" in options,
            }
        )
    return fields


def _block_comment(comment_blocks: dict[int, list[str]], lines: list[str], name: str) -> list[str]:
    """Leading comment block for a declaration named ``name``.

    The comment map is keyed by stripped-line number, so a declaration's
    comment block is the one stored on the line it occupies.
    """
    for number, line in enumerate(lines, start=1):
        if re.search(rf"\b{re.escape(name)}\b", line) and (
            re.search(rf"\b(service|message|rpc)\s+{re.escape(name)}\b", line)
        ):
            return comment_blocks.get(number, [])
    return []


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------


def _clean_comment(block: list[str]) -> str:
    text = " ".join(part.strip() for part in block if part.strip())
    return text.strip()


def _service_description(service: dict) -> str:
    comment = _clean_comment(service["comment"])
    if comment:
        # Proto comment: "FederationService handles gradient forwarding and
        # aggregation across tiers." -> drop the leading service name.
        comment = re.sub(rf"^{re.escape(service['name'])}\s+", "", comment)
        return comment[:1].upper() + comment[1:] if comment else SERVICE_SUMMARY
    return SERVICE_SUMMARY


def _message_description(message: dict) -> str:
    comment = _clean_comment(message["comment"])
    override = MESSAGE_SUMMARY.get(message["name"])
    if override:
        return override
    if comment:
        comment = re.sub(rf"^{re.escape(message['name'])}\s+(is|represents|for)\b", "", comment)
        return comment[:1].upper() + comment[1:] if comment else ""
    return ""


def _field_type(field: dict) -> str:
    label = "repeated " if field["repeated"] else ""
    base = field["type"]
    if field["packed"]:
        base = f"{base} (packed)"
    return f"{label}{base}"


def _field_description(message_name: str, field: dict) -> str:
    override = FIELD_DESCRIPTION_OVERRIDE.get((message_name, field["name"]))
    return override if override is not None else ""


def _rpc_type(rpc: dict) -> str:
    if rpc["client_streaming"] and rpc["server_streaming"]:
        return "bidirectional"
    if rpc["client_streaming"]:
        return "client streaming"
    if rpc["server_streaming"]:
        return "server streaming"
    return "unary"


def _rpc_request_label(rpc: dict) -> str:
    return f"stream `{rpc['request']}`" if rpc["client_streaming"] else f"`{rpc['request']}`"


def _rpc_response_label(rpc: dict) -> str:
    return f"stream `{rpc['response']}`" if rpc["server_streaming"] else f"`{rpc['response']}`"


def _md_cell(text: str) -> str:
    return text.replace("|", "\\|")


def render_document(model: ProtoModel) -> str:
    if model.syntax != "proto3":
        raise ValueError(f"unsupported proto syntax {model.syntax!r}; expected 'proto3'")
    if model.go_package != GO_PACKAGE_PROTO_EXPECTED:
        raise ValueError(
            "proto go_package option "
            f"{model.go_package!r} does not match the expected {GO_PACKAGE_PROTO_EXPECTED!r}; "
            "update GO_PACKAGE_PROTO_EXPECTED/GO_PACKAGE_DOC in the generator"
        )
    if not model.services:
        raise ValueError("no service declaration found in proto")

    lines: list[str] = []
    lines.append("# gRPC Federation Service Reference")
    lines.append("")
    lines.append(HEADER_STATUS)
    lines.append(f"**Package**: `{model.package}`")
    lines.append(f"**Go package**: `{GO_PACKAGE_DOC}`")
    lines.append("")

    for service in model.services:
        lines.append(f"## Service: {service['name']}")
        lines.append("")
        lines.append(_service_description(service))
        lines.append("")
        lines.append("| RPC | Request | Response | Type |")
        lines.append("|---|---|---|---|")
        for rpc in service["rpcs"]:
            lines.append(
                f"| `{rpc['name']}` | {_rpc_request_label(rpc)} | "
                f"{_rpc_response_label(rpc)} | {_rpc_type(rpc)} |"
            )
        lines.append("")

    lines.append("## Messages")
    lines.append("")

    for message in model.messages:
        lines.append(f"### {message['name']}")
        lines.append("")
        description = _message_description(message)
        if description:
            lines.append(description)
            lines.append("")
        lines.append("| Field | Number | Type | Description |")
        lines.append("|---|---|---|---|")
        for field in message["fields"]:
            lines.append(
                f"| {field['name']} | {field['number']} | "
                f"{_md_cell(_field_type(field))} | {_md_cell(_field_description(message['name'], field))} |"
            )
        lines.append("")

    lines.append(FOOTER.rstrip("\n"))
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proto", type=Path, default=PROTO_PATH, help="proto file to parse")
    parser.add_argument("--output", type=Path, default=DOC_PATH, help="markdown file to write")
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the committed document differs from the generated output",
    )
    args = parser.parse_args(argv)

    model = parse_proto(args.proto.read_text(encoding="utf-8"))
    generated = render_document(model)

    if args.check:
        committed = args.output.read_text(encoding="utf-8")
        if committed == generated:
            print(f"docs-api-check: PASS ({args.output} matches {args.proto})")
            return 0
        diff = difflib.unified_diff(
            committed.splitlines(keepends=True),
            generated.splitlines(keepends=True),
            fromfile=str(args.output),
            tofile=f"{args.output} (generated)",
        )
        sys.stdout.write("".join(diff))
        print(f"docs-api-check: FAIL ({args.output} is out of date; run: make docs-api)")
        return 1

    args.output.write_text(generated, encoding="utf-8", newline="\n")
    print(f"docs-api: wrote {args.output} from {args.proto}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
