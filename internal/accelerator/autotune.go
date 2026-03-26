package accelerator

import (
	"os"
	"runtime"
	"strconv"
	"strings"
)

// AutoTuneProfile describes accelerator selection outcomes for key operations.
type AutoTuneProfile struct {
	SelectedDevice    DeviceInfo     `json:"selected_device"`
	PreferredFormat   string         `json:"preferred_format"`
	RecommendedWorker int            `json:"recommended_workers"`
	OperationProfiles map[string]any `json:"operation_profiles"`
	DetectedDevices   []DeviceInfo   `json:"detected_devices"`
}

// SelectDevice chooses the best backend from detected devices.
// Priority defaults to NPU > CUDA > Metal > CPU and can be overridden via
// MOHAWK_ACCELERATOR_BACKEND (cpu|cuda|metal|npu|auto).
func SelectDevice(devices []DeviceInfo) DeviceInfo {
	if len(devices) == 0 {
		return cpuDevice()
	}
	preferred := strings.TrimSpace(strings.ToLower(os.Getenv("MOHAWK_ACCELERATOR_BACKEND")))
	if preferred != "" && preferred != "auto" {
		for _, device := range devices {
			if string(device.Backend) == preferred {
				return device
			}
		}
	}

	priority := map[Backend]int{
		BackendNPU:   400,
		BackendCUDA:  300,
		BackendMetal: 250,
		BackendCPU:   100,
	}
	best := devices[0]
	bestScore := scoreDevice(best, priority)
	for _, device := range devices[1:] {
		score := scoreDevice(device, priority)
		if score > bestScore {
			best = device
			bestScore = score
		}
	}
	return best
}

// RecommendGradientFormat auto-selects a compression format based on workload.
// For large vectors on accelerator backends, INT8 is preferred for throughput.
func RecommendGradientFormat(device DeviceInfo, vectorLength int) string {
	if forced := strings.TrimSpace(strings.ToLower(os.Getenv("MOHAWK_GRADIENT_FORMAT"))); forced == "fp16" || forced == "int8" {
		return forced
	}
	if vectorLength >= 2048 {
		switch device.Backend {
		case BackendNPU, BackendCUDA:
			return "int8"
		}
	}
	return "fp16"
}

// RecommendWorkers returns a backend-aware worker setting.
func RecommendWorkers(device DeviceInfo) int {
	if raw := strings.TrimSpace(os.Getenv("MOHAWK_ACCELERATOR_WORKERS")); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			return parsed
		}
	}
	base := runtime.GOMAXPROCS(0)
	switch device.Backend {
	case BackendNPU:
		if base < 2 {
			return 2
		}
		return base * 2
	case BackendCUDA, BackendMetal:
		if base < 2 {
			return 2
		}
		return base
	default:
		return base
	}
}

// BuildAutoTuneProfile creates a snapshot used by APIs/telemetry.
func BuildAutoTuneProfile(vectorLength int) AutoTuneProfile {
	devices := DetectDevices()
	selected := SelectDevice(devices)
	workers := RecommendWorkers(selected)
	format := RecommendGradientFormat(selected, vectorLength)
	return AutoTuneProfile{
		SelectedDevice:    selected,
		PreferredFormat:   format,
		RecommendedWorker: workers,
		DetectedDevices:   devices,
		OperationProfiles: map[string]any{
			"compress_gradients": map[string]any{
				"backend": selected.Backend,
				"format":  format,
				"workers": workers,
			},
			"batch_verify": map[string]any{
				"backend": selected.Backend,
				"workers": workers,
			},
			"hybrid_verify": map[string]any{
				"backend": selected.Backend,
				"workers": workers,
			},
		},
	}
}

func scoreDevice(device DeviceInfo, priority map[Backend]int) int {
	score := priority[device.Backend]
	score += device.SIMDWidth / 8
	score += device.MemoryMB / 1024
	if device.Backend != BackendCPU {
		score += 50
	}
	return score
}
