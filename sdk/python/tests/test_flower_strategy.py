"""Tests for the Flower strategy forwarder."""

from __future__ import annotations

from mohawk.flower_strategy import FlowerStrategyForwarder


class DummyMohawkNode:
    def __init__(self):
        self.aggregate_calls = []

    def aggregate(self, updates):
        payload = list(updates)
        self.aggregate_calls.append(payload)
        return {
            "success": True,
            "count": len(payload),
            "message": "Updates aggregated successfully",
        }


class DummyDelegate:
    def __init__(self):
        self.aggregate_fit_calls = []
        self.aggregate_evaluate_calls = []

    def aggregate_fit(self, server_round, results, failures):
        self.aggregate_fit_calls.append((server_round, list(results), list(failures)))
        return {"delegate": "fit"}

    def aggregate_evaluate(self, server_round, results, failures):
        self.aggregate_evaluate_calls.append((server_round, list(results), list(failures)))
        return {"delegate": "evaluate"}


def test_strategy_forwarder_aggregates_updates():
    node = DummyMohawkNode()
    delegate = DummyDelegate()
    strategy = FlowerStrategyForwarder(node, delegate=delegate, strategy_name="fedavg")

    summary = strategy.aggregate_fit(
        3,
        [
            (
                {"cid": "client-a"},
                {"parameters": [[0.1, 0.2]], "num_examples": 8, "metrics": {"loss": 0.5}},
            ),
            (
                {"cid": "client-b"},
                {"parameters": [[0.3, 0.4]], "num_examples": 16, "metrics": {"loss": 0.25}},
            ),
        ],
        (),
    )

    assert summary.strategy_name == "fedavg"
    assert summary.server_round == 3
    assert summary.mohawk_result["success"] is True
    assert summary.metrics["clients"] == 2
    assert summary.metrics["aggregated_updates"] == 2
    assert node.aggregate_calls[0][0]["gradient"] == [0.1, 0.2]
    assert delegate.aggregate_fit_calls[0][0] == 3


def test_strategy_forwarder_averages_evaluations():
    strategy = FlowerStrategyForwarder(DummyMohawkNode(), strategy_name="fedavg")

    summary = strategy.aggregate_evaluate(
        4,
        [
            ({"cid": "client-a"}, {"loss": 0.5, "accuracy": 0.8, "num_examples": 8}),
            ({"cid": "client-b"}, {"loss": 0.25, "accuracy": 0.9, "num_examples": 16}),
        ],
        (),
    )

    assert summary.metrics["clients"] == 2
    assert summary.metrics["loss"] == 0.3333333333333333
    assert summary.metrics["accuracy"] == 0.8666666666666667
