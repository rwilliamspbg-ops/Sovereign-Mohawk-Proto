package metrics

import (
	"testing"

	"github.com/prometheus/client_golang/prometheus"
)

func liveMetricValue(t *testing.T, name string, wantLabels map[string]string) float64 {
	t.Helper()
	families, err := prometheus.DefaultGatherer.Gather()
	if err != nil {
		t.Fatalf("gather metrics: %v", err)
	}
	for _, family := range families {
		if family.GetName() != name {
			continue
		}
		for _, metric := range family.GetMetric() {
			labels := make(map[string]string, len(metric.GetLabel()))
			for _, pair := range metric.GetLabel() {
				labels[pair.GetName()] = pair.GetValue()
			}
			matches := true
			for key, value := range wantLabels {
				if labels[key] != value {
					matches = false
					break
				}
			}
			if !matches {
				continue
			}
			if metric.Counter != nil {
				return metric.GetCounter().GetValue()
			}
			if metric.Gauge != nil {
				return metric.GetGauge().GetValue()
			}
		}
	}
	t.Fatalf("metric %s with labels %v not found", name, wantLabels)
	return 0
}

func TestObserveGradientReceivedIncrementsCounter(t *testing.T) {
	labels := map[string]string{"node": "live-metrics-test-node", "task": "live-metrics-test-task"}
	// Prime the child series so the baseline can be read from the registry.
	ObserveGradientReceived(labels["node"], labels["task"], 1)
	before := liveMetricValue(t, "mohawk_orchestrator_gradients_received_total", labels)

	ObserveGradientReceived(labels["node"], labels["task"], 42)

	if got := liveMetricValue(t, "mohawk_orchestrator_gradients_received_total", labels) - before; got != 1 {
		t.Fatalf("counter delta = %v, want 1", got)
	}
}

func TestObserveGradientReceivedSetsLastRound(t *testing.T) {
	ObserveGradientReceived("live-metrics-round-node", "live-metrics-round-task", 4242)
	if got := liveMetricValue(t, "mohawk_orchestrator_last_round", nil); got < 4242 {
		t.Fatalf("last round = %v, want at least 4242", got)
	}
}

func TestObserveGradientReceivedDoesNotLowerLastRound(t *testing.T) {
	ObserveGradientReceived("live-metrics-max-node", "live-metrics-max-task", 999999)
	ObserveGradientReceived("live-metrics-max-node", "live-metrics-max-task", 1)
	if got := liveMetricValue(t, "mohawk_orchestrator_last_round", nil); got != 999999 {
		t.Fatalf("last round regressed to %v, want 999999", got)
	}
}
