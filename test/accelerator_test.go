package test

import (
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
)

func TestDetectDevicesIncludesCPU(t *testing.T) {
	devices := accelerator.DetectDevices()
	if len(devices) == 0 {
		t.Fatal("expected at least one device")
	}
	if devices[0].Backend != accelerator.BackendCPU {
		t.Fatalf("expected first backend to be cpu, got %s", devices[0].Backend)
	}
}

func TestFP16RoundTrip(t *testing.T) {
	input := []float32{0.1, -0.2, 1.5, 3.14}
	encoded := accelerator.FP32ToFP16(input)
	decoded := accelerator.FP16ToFP32(encoded)
	if len(decoded) != len(input) {
		t.Fatalf("decoded len mismatch: got %d want %d", len(decoded), len(input))
	}
}

func TestINT8QuantizationRoundTrip(t *testing.T) {
	input := []float32{0.1, -0.2, 0.3, -0.4}
	quantized, scale := accelerator.QuantizeINT8(input, 1.0)
	if scale <= 0 {
		t.Fatalf("invalid scale: %f", scale)
	}
	recovered := accelerator.DequantizeINT8(quantized, scale)
	if len(recovered) != len(input) {
		t.Fatalf("recovered len mismatch: got %d want %d", len(recovered), len(input))
	}
}

func TestAggregateParallel(t *testing.T) {
	gradients := [][]float32{
		{0.1, 0.2, 0.3},
		{0.2, 0.3, 0.4},
		{0.3, 0.4, 0.5},
	}
	out, err := accelerator.AggregateParallel(gradients, 1.0, 2)
	if err != nil {
		t.Fatalf("AggregateParallel returned error: %v", err)
	}
	if len(out) != 3 {
		t.Fatalf("expected output dimension 3, got %d", len(out))
	}
}
