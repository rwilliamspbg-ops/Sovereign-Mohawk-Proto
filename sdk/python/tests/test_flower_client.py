"""Tests for the Flower-compatible Mohawk client."""

from __future__ import annotations

import importlib
import sys
import types


class DummyMohawkNode:
    def __init__(self):
        self.compress_calls = []
        self.aggregate_calls = []

    def compress_gradients(self, gradients, *, format="auto", max_norm=1.0):
        self.compress_calls.append(
            {"gradients": list(gradients), "format": format, "max_norm": max_norm}
        )
        return {
            "success": True,
            "format": format,
            "compressed_bytes": len(self.compress_calls[-1]["gradients"]) * 2,
            "compression_ratio": 2.0,
            "data_b64": "Y29tcHJlc3NlZA==",
        }

    def aggregate(self, updates):
        payload = list(updates)
        self.aggregate_calls.append(payload)
        return {
            "success": True,
            "count": len(payload),
            "message": "Updates aggregated successfully",
        }


def train_fn(parameters, config):
    del config
    updated = []
    for tensor in parameters:
        if isinstance(tensor, list):
            updated.append([value + 1.0 for value in tensor])
        else:
            updated.append(tensor + 1.0)
    return updated, 12, {"loss": 0.25}


def evaluate_fn(parameters, config):
    del parameters, config
    return 0.25, 12, {"accuracy": 0.9}


def test_fit_submits_update_and_builds_proof_manifest():
    from mohawk.flower_client import MohawkFlowerClient

    node = DummyMohawkNode()
    client = MohawkFlowerClient(
        node,
        train_fn=train_fn,
        evaluate_fn=evaluate_fn,
        initial_parameters=[[0.0, 1.0], [2.0]],
        node_id="demo-node",
    )

    parameters = client.get_parameters({})
    updated_parameters, num_examples, metrics = client.fit(
        parameters,
        {"server_round": 7, "mohawk_format": "fp16"},
    )

    assert updated_parameters == [[1.0, 2.0], [3.0]]
    assert num_examples == 12
    assert metrics["loss"] == 0.25
    assert metrics["mohawk_compression_ratio"] == 2.0
    assert metrics["mohawk_proof"]
    assert node.compress_calls[0]["format"] == "fp16"
    assert node.aggregate_calls[0][0]["node_id"] == "demo-node"
    assert node.aggregate_calls[0][0]["gradient"] == [1.0, 2.0, 3.0]
    assert client.submit_updates is True


def test_evaluate_uses_custom_callback():
    from mohawk.flower_client import MohawkFlowerClient

    client = MohawkFlowerClient(
        DummyMohawkNode(),
        train_fn=train_fn,
        evaluate_fn=evaluate_fn,
        initial_parameters=[[0.0]],
    )

    loss, num_examples, metrics = client.evaluate([[1.0]], {})
    assert loss == 0.25
    assert num_examples == 12
    assert metrics["accuracy"] == 0.9


def test_module_uses_flower_numpyclient_when_present(monkeypatch):
    fake_flwr = types.ModuleType("flwr")
    fake_client = types.ModuleType("flwr.client")

    class FakeNumPyClient:
        pass

    fake_client.NumPyClient = FakeNumPyClient
    fake_flwr.client = fake_client
    monkeypatch.setitem(sys.modules, "flwr", fake_flwr)
    monkeypatch.setitem(sys.modules, "flwr.client", fake_client)
    monkeypatch.delitem(sys.modules, "mohawk.flower_client", raising=False)

    module = importlib.import_module("mohawk.flower_client")
    assert issubclass(module.MohawkFlowerClient, FakeNumPyClient)
