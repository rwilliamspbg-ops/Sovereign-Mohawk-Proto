package test

import (
	"fmt"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
)

func makeBenchmarkGradients(clients int, dim int) [][]float32 {
	gradients := make([][]float32, clients)
	for c := 0; c < clients; c++ {
		g := make([]float32, dim)
		for i := 0; i < dim; i++ {
			g[i] = float32((c+i)%97) * 0.01
		}
		gradients[c] = g
	}
	return gradients
}

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

func TestResolveAggregateWorkers_AutoSmallFallsBackToOne(t *testing.T) {
	workers := accelerator.ResolveAggregateWorkers(32, 2048, 0)
	if workers != 1 {
		t.Fatalf("expected auto workers=1 for small workload, got %d", workers)
	}
}

func TestResolveAggregateWorkers_ExplicitClamp(t *testing.T) {
	workers := accelerator.ResolveAggregateWorkers(8, 4096, 64)
	if workers != 8 {
		t.Fatalf("expected explicit workers clamped to gradients count (8), got %d", workers)
	}
}

func TestResolveAggregateWorkers_AutoLargeUsesParallel(t *testing.T) {
	workers := accelerator.ResolveAggregateWorkers(128, 4096, 0)
	if workers < 2 {
		t.Fatalf("expected auto workers >= 2 for large workload, got %d", workers)
	}
}

func TestResolveAggregateWorkers_HysteresisUnderQueuePressure(t *testing.T) {
	t.Setenv("MOHAWK_AGGREGATE_QUEUE_DEPTH", "1")
	baseline := accelerator.ResolveAggregateWorkers(777, 3333, 0)

	t.Setenv("MOHAWK_AGGREGATE_QUEUE_DEPTH", "64")
	next := accelerator.ResolveAggregateWorkers(777, 3333, 0)

	if next > baseline+1 {
		t.Fatalf("expected hysteresis to limit worker jump (baseline=%d next=%d)", baseline, next)
	}
}

func BenchmarkAggregateParallel(b *testing.B) {
	cases := []struct {
		name    string
		clients int
		dim     int
	}{
		{name: "clients32_dim2048", clients: 32, dim: 2048},
		{name: "clients128_dim4096", clients: 128, dim: 4096},
		{name: "clients256_dim8192", clients: 256, dim: 8192},
		{name: "clients512_dim8192", clients: 512, dim: 8192},
	}

	workerConfigs := []struct {
		name    string
		workers int
	}{
		{name: "workers1", workers: 1},
		{name: "workers2", workers: 2},
		{name: "workers4", workers: 4},
		{name: "workers8", workers: 8},
		{name: "workersAuto", workers: 0},
	}

	for _, tc := range cases {
		gradients := makeBenchmarkGradients(tc.clients, tc.dim)
		bytesPerOp := int64(tc.clients * tc.dim * 4)

		for _, wc := range workerConfigs {
			b.Run(fmt.Sprintf("%s/%s", tc.name, wc.name), func(b *testing.B) {
				workers := accelerator.ResolveAggregateWorkers(tc.clients, tc.dim, wc.workers)

				b.ReportAllocs()
				b.SetBytes(bytesPerOp)
				b.ResetTimer()

				for i := 0; i < b.N; i++ {
					out, err := accelerator.AggregateParallel(gradients, 1.0, workers)
					if err != nil {
						b.Fatalf("AggregateParallel error: %v", err)
					}
					if len(out) != tc.dim {
						b.Fatalf("unexpected output dim: got %d want %d", len(out), tc.dim)
					}
				}
			})
		}
	}
}

func BenchmarkAggregateAndCompressMixedLoad(b *testing.B) {
	gradients := makeBenchmarkGradients(256, 4096)
	fp32 := make([]float32, 4096)
	for i := range fp32 {
		fp32[i] = float32((i%97)-48) * 0.01
	}

	b.ReportAllocs()
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		workers := accelerator.ResolveAggregateWorkers(len(gradients), len(gradients[0]), 0)
		if _, err := accelerator.AggregateParallel(gradients, 1.0, workers); err != nil {
			b.Fatalf("AggregateParallel error: %v", err)
		}
		_ = accelerator.FP32ToFP16(fp32)
	}
}
