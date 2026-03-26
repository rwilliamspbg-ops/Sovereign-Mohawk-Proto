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

func TestAutoTuneSelectDevicePriority(t *testing.T) {
	devices := []accelerator.DeviceInfo{
		{Backend: accelerator.BackendCPU, Name: "cpu", SIMDWidth: 256},
		{Backend: accelerator.BackendCUDA, Name: "cuda0", SIMDWidth: 128, MemoryMB: 8192},
		{Backend: accelerator.BackendNPU, Name: "npu0", SIMDWidth: 128},
	}
	selected := accelerator.SelectDevice(devices)
	if selected.Backend != accelerator.BackendNPU {
		t.Fatalf("expected NPU to be selected by priority, got %s", selected.Backend)
	}
}

func TestAutoTuneSelectDeviceEnvOverride(t *testing.T) {
	t.Setenv("MOHAWK_ACCELERATOR_BACKEND", "cuda")
	devices := []accelerator.DeviceInfo{
		{Backend: accelerator.BackendCPU, Name: "cpu", SIMDWidth: 256},
		{Backend: accelerator.BackendCUDA, Name: "cuda0", SIMDWidth: 128, MemoryMB: 8192},
	}
	selected := accelerator.SelectDevice(devices)
	if selected.Backend != accelerator.BackendCUDA {
		t.Fatalf("expected CUDA override selection, got %s", selected.Backend)
	}
}

func TestAutoTuneRecommendGradientFormat(t *testing.T) {
	device := accelerator.DeviceInfo{Backend: accelerator.BackendCUDA, Name: "cuda0"}
	formatLarge := accelerator.RecommendGradientFormat(device, 4096)
	if formatLarge != "int8" {
		t.Fatalf("expected int8 for large CUDA workload, got %s", formatLarge)
	}
	formatSmall := accelerator.RecommendGradientFormat(device, 256)
	if formatSmall != "fp16" {
		t.Fatalf("expected fp16 for small workload, got %s", formatSmall)
	}
}

func TestAutoTuneRecommendWorkersByBackend(t *testing.T) {
	npu := accelerator.DeviceInfo{Backend: accelerator.BackendNPU, Name: "npu0"}
	cpu := accelerator.DeviceInfo{Backend: accelerator.BackendCPU, Name: "cpu0"}
	npuWorkers := accelerator.RecommendWorkers(npu)
	cpuWorkers := accelerator.RecommendWorkers(cpu)
	if npuWorkers < 2 {
		t.Fatalf("expected at least 2 workers for NPU, got %d", npuWorkers)
	}
	if cpuWorkers < 1 {
		t.Fatalf("expected at least 1 worker for CPU, got %d", cpuWorkers)
	}
}

func TestAutoTuneRecommendWorkersEnvOverride(t *testing.T) {
	t.Setenv("MOHAWK_ACCELERATOR_WORKERS", "7")
	device := accelerator.DeviceInfo{Backend: accelerator.BackendNPU, Name: "npu0"}
	workers := accelerator.RecommendWorkers(device)
	if workers != 7 {
		t.Fatalf("expected env override worker count 7, got %d", workers)
	}
}
