package metrics

import "testing"

func TestObserveMultiKrumDecision(t *testing.T) {
	// Prime result children so baseline reads exist.
	ObserveMultiKrumDecision(1, 0, 0, true)
	baselineBatches := liveMetricValue(t, "mohawk_orchestrator_multikrum_batches_total", map[string]string{"result": "success"})
	baselineFiltered := liveMetricValue(t, "mohawk_orchestrator_multikrum_filtered_total", nil)

	ObserveMultiKrumDecision(6, 5, 1, true)

	if got := liveMetricValue(t, "mohawk_orchestrator_multikrum_batches_total", map[string]string{"result": "success"}) - baselineBatches; got != 1 {
		t.Fatalf("batch counter delta = %v, want 1", got)
	}
	if got := liveMetricValue(t, "mohawk_orchestrator_multikrum_filtered_total", nil) - baselineFiltered; got != 1 {
		t.Fatalf("filtered counter delta = %v, want 1", got)
	}
	if got := liveMetricValue(t, "mohawk_orchestrator_multikrum_selected", nil); got != 5 {
		t.Fatalf("selected gauge = %v, want 5", got)
	}
}

func TestObserveMultiKrumDecisionError(t *testing.T) {
	ObserveMultiKrumDecision(1, 0, 0, false)
	before := liveMetricValue(t, "mohawk_orchestrator_multikrum_batches_total", map[string]string{"result": "error"})
	ObserveMultiKrumDecision(2, 0, 0, false)
	if got := liveMetricValue(t, "mohawk_orchestrator_multikrum_batches_total", map[string]string{"result": "error"}) - before; got != 1 {
		t.Fatalf("error counter delta = %v, want 1", got)
	}
}

func TestObserveMultiKrumNodeDecision(t *testing.T) {
	labels := map[string]string{"node": "byzantine-probe", "result": "filtered"}
	ObserveMultiKrumNodeDecision(labels["node"], false)
	before := liveMetricValue(t, "mohawk_orchestrator_multikrum_node_decisions_total", labels)
	ObserveMultiKrumNodeDecision(labels["node"], false)
	if got := liveMetricValue(t, "mohawk_orchestrator_multikrum_node_decisions_total", labels) - before; got != 1 {
		t.Fatalf("node decision counter delta = %v, want 1", got)
	}
}
