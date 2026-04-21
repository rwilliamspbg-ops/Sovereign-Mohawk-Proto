"""Smoke tests for the Flower-integrated example pack."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from examples.flower_integrated.huggingface import EXAMPLE as HUGGINGFACE_EXAMPLE
from examples.flower_integrated.llm_fine_tune import EXAMPLE as LLM_EXAMPLE
from examples.flower_integrated.quickstart_pytorch import EXAMPLE as QUICKSTART_EXAMPLE


def test_all_flower_integrated_examples():
    quickstart = QUICKSTART_EXAMPLE.run(server_round=2)
    huggingface = HUGGINGFACE_EXAMPLE.run(server_round=2)
    llm = LLM_EXAMPLE.run(server_round=2)

    assert quickstart["example"] == "quickstart-pytorch"
    assert quickstart["fit_metrics"]["mohawk_round"] == 2
    assert huggingface["example"] == "huggingface"
    assert huggingface["fit_metrics"]["mohawk_round"] == 2
    assert llm["example"] == "llm-fine-tune"
    assert llm["fit_metrics"]["mohawk_round"] == 2
