#!/usr/bin/env python3
"""Generate a baseline OpenAPI 3.1 spec for orchestrator REST endpoints.

This script intentionally uses only stdlib so it can run in CI without extra
Python packages. The output is JSON.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def build_spec(server_url: str) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "Sovereign Mohawk Orchestrator API",
            "version": "1.0.0",
            "description": "Baseline contract for orchestrator control-plane endpoints.",
            "x-generated-at": now,
        },
        "servers": [{"url": server_url}],
        "paths": {
            "/orchestrator/pubkey": {
                "get": {
                    "summary": "Get orchestrator public key",
                    "responses": {
                        "200": {
                            "description": "Hex encoded ed25519 public key",
                            "content": {
                                "text/plain": {
                                    "schema": {"type": "string"}
                                }
                            },
                        }
                    },
                }
            },
            "/jobs/next": {
                "get": {
                    "summary": "Get next federated job",
                    "parameters": [
                        {
                            "name": "node_id",
                            "in": "query",
                            "required": True,
                            "schema": {"type": "string"},
                        }
                    ],
                    "responses": {
                        "200": {
                            "description": "WASM payload and signed manifest",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "wasm": {
                                                "type": "string",
                                                "description": "Binary bytes serialized by Go JSON encoder",
                                            },
                                            "manifest": {"type": "object"},
                                        },
                                        "additionalProperties": True,
                                    }
                                }
                            },
                        },
                        "400": {"description": "Missing node_id"},
                    },
                }
            },
            "/attest": {
                "post": {
                    "summary": "Submit node attestation quote",
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "required": ["node_id", "quote"],
                                    "properties": {
                                        "node_id": {"type": "string"},
                                        "quote": {
                                            "type": "string",
                                            "description": "Base64 bytes as JSON",
                                        },
                                    },
                                }
                            }
                        },
                    },
                    "responses": {
                        "200": {"description": "Attestation accepted"},
                        "403": {"description": "Attestation failed"},
                    },
                }
            },
            "/checkpoints/put": {
                "post": {
                    "summary": "Store checkpoint payload",
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "required": ["name", "payload"],
                                    "properties": {
                                        "name": {"type": "string"},
                                        "payload": {"type": "string"},
                                    },
                                }
                            }
                        },
                    },
                    "responses": {
                        "200": {
                            "description": "Checkpoint stored",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "cid": {"type": "string"}
                                        },
                                        "required": ["cid"],
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/checkpoints/get": {
                "get": {
                    "summary": "Fetch checkpoint payload",
                    "parameters": [
                        {
                            "name": "cid",
                            "in": "query",
                            "required": True,
                            "schema": {"type": "string"},
                        }
                    ],
                    "responses": {
                        "200": {
                            "description": "Checkpoint payload",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "payload": {"type": "string"}
                                        },
                                        "required": ["payload"],
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/mesh/plan": {
                "get": {
                    "summary": "Build mesh plan",
                    "parameters": [
                        {
                            "name": "total_nodes",
                            "in": "query",
                            "required": False,
                            "schema": {"type": "integer", "minimum": 1},
                        },
                        {
                            "name": "dimensions",
                            "in": "query",
                            "required": False,
                            "schema": {"type": "integer", "minimum": 1},
                        },
                    ],
                    "responses": {
                        "200": {
                            "description": "Mesh plan",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "additionalProperties": True,
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/p2p/info": {
                "get": {
                    "summary": "Get orchestrator libp2p details",
                    "responses": {
                        "200": {
                            "description": "Peer host details",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "peer_id": {"type": "string"},
                                            "addrs": {
                                                "type": "array",
                                                "items": {"type": "string"},
                                            },
                                            "kex_mode": {"type": "string"},
                                            "expected_public_key_bytes": {
                                                "type": "integer"
                                            },
                                        },
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/ledger/migration/status": {
                "get": {
                    "summary": "Get migration policy status",
                    "responses": {
                        "200": {
                            "description": "Current migration status",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "additionalProperties": True,
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/ledger/migration/config": {
                "post": {
                    "summary": "Update migration policy",
                    "security": [{"bearerAuth": []}],
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "required": [
                                        "enabled",
                                        "require_crypto_epoch",
                                        "lock_legacy_transfers",
                                    ],
                                    "properties": {
                                        "enabled": {"type": "boolean"},
                                        "migration_eta": {
                                            "type": "string",
                                            "format": "date-time",
                                        },
                                        "migration_epoch": {
                                            "type": "string",
                                            "format": "date-time",
                                        },
                                        "require_crypto_epoch": {"type": "boolean"},
                                        "lock_legacy_transfers": {"type": "boolean"},
                                    },
                                }
                            }
                        },
                    },
                    "responses": {
                        "200": {"description": "Updated migration status"},
                        "401": {"description": "Unauthorized"},
                    },
                }
            },
            "/ledger/migration/digest": {
                "post": {
                    "summary": "Build signing digest for migration",
                    "security": [{"bearerAuth": []}],
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "required": ["legacy_account", "pqc_account", "amount"],
                                    "properties": {
                                        "legacy_account": {"type": "string"},
                                        "pqc_account": {"type": "string"},
                                        "amount": {"type": "number"},
                                        "memo": {"type": "string"},
                                        "idempotency_key": {"type": "string"},
                                        "nonce": {
                                            "type": "integer",
                                            "minimum": 0,
                                        },
                                    },
                                }
                            }
                        },
                    },
                    "responses": {
                        "200": {
                            "description": "Digest response",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "required": [
                                            "symbol",
                                            "amount_units",
                                            "digest_hex",
                                        ],
                                        "properties": {
                                            "symbol": {"type": "string"},
                                            "amount_units": {
                                                "type": "integer",
                                                "minimum": 0,
                                            },
                                            "digest_hex": {"type": "string"},
                                        },
                                    }
                                }
                            },
                        },
                        "401": {"description": "Unauthorized"},
                    },
                }
            },
            "/ledger/migration/migrate": {
                "post": {
                    "summary": "Execute migration transfer",
                    "security": [{"bearerAuth": []}],
                    "requestBody": {
                        "required": True,
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "required": ["legacy_account", "pqc_account", "amount"],
                                    "properties": {
                                        "legacy_account": {"type": "string"},
                                        "pqc_account": {"type": "string"},
                                        "amount": {"type": "number"},
                                        "memo": {"type": "string"},
                                        "legacy_signed": {"type": "boolean"},
                                        "pqc_signed": {"type": "boolean"},
                                        "legacy_algo": {"type": "string"},
                                        "legacy_pub_key": {"type": "string"},
                                        "legacy_sig": {"type": "string"},
                                        "pqc_algo": {"type": "string"},
                                        "pqc_pub_key": {"type": "string"},
                                        "pqc_sig": {"type": "string"},
                                        "idempotency_key": {"type": "string"},
                                        "nonce": {
                                            "type": "integer",
                                            "minimum": 0,
                                        },
                                    },
                                }
                            }
                        },
                    },
                    "responses": {
                        "200": {
                            "description": "Migration transaction",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {"tx": {"type": "object"}},
                                        "required": ["tx"],
                                    }
                                }
                            },
                        },
                        "401": {"description": "Unauthorized"},
                    },
                }
            },
            "/metrics": {
                "get": {
                    "summary": "Prometheus metrics",
                    "responses": {
                        "200": {
                            "description": "Prometheus exposition format",
                            "content": {
                                "text/plain": {"schema": {"type": "string"}}
                            },
                        }
                    },
                }
            },
        },
        "components": {
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "Opaque token",
                }
            }
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate OpenAPI spec JSON")
    parser.add_argument(
        "--output",
        default="results/api/openapi.json",
        help="Output path for generated OpenAPI JSON",
    )
    parser.add_argument(
        "--server-url",
        default="https://localhost:8080",
        help="Server URL placed in the OpenAPI servers block",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    spec = build_spec(args.server_url)
    output_path.write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    print(f"wrote OpenAPI spec to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
