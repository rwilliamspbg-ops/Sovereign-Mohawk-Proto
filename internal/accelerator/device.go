// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package accelerator provides hardware-aware compute acceleration for
// gradient aggregation and zk-SNARK proof batching. It detects available
// CPU, GPU (CUDA), and NPU (Apple Metal / ANE) backends and exposes
// quantization helpers for bandwidth-efficient gradient compression.
package accelerator

import (
	"os"
	"runtime"
	"strconv"
	"strings"
)

// Backend identifies a hardware acceleration backend.
type Backend string

const (
	BackendCPU   Backend = "cpu"
	BackendCUDA  Backend = "cuda"
	BackendMetal Backend = "metal"
	BackendNPU   Backend = "npu"
)

// DeviceInfo describes a compute device available on the current host.
type DeviceInfo struct {
	Backend   Backend `json:"backend"`
	Name      string  `json:"name"`
	Index     int     `json:"index"`
	SIMDWidth int     `json:"simd_width"` // vector width in bits: 128 / 256 / 512
	MemoryMB  int     `json:"memory_mb"`  // 0 = unknown
}

// DetectDevices enumerates compute devices available on this host.
// The CPU entry is always first. CUDA devices are added when /dev/nvidiaX
// character devices are present. Apple Metal is added on darwin.
func DetectDevices() []DeviceInfo {
	devices := []DeviceInfo{cpuDevice()}
	devices = append(devices, cudaDevices()...)
	if hasMetal() {
		devices = append(devices, DeviceInfo{
			Backend:   BackendMetal,
			Name:      "Apple Metal (GPU/ANE)",
			SIMDWidth: 128,
		})
	}
	return devices
}

// cpuDevice returns a DeviceInfo for the host CPU with SIMD width inferred
// from /proc/cpuinfo on Linux or GOARCH heuristics on other platforms.
func cpuDevice() DeviceInfo {
	width := simdWidth()
	return DeviceInfo{
		Backend:   BackendCPU,
		Name:      "CPU (" + runtime.GOARCH + ")",
		SIMDWidth: width,
	}
}

// simdWidth returns the widest SIMD vector width available on this CPU.
func simdWidth() int {
	switch runtime.GOARCH {
	case "amd64":
		flags := readCPUFlags()
		if strings.Contains(flags, "avx512") {
			return 512
		}
		if strings.Contains(flags, "avx2") {
			return 256
		}
		if strings.Contains(flags, "sse2") {
			return 128
		}
		return 64
	case "arm64":
		return 128 // NEON
	case "arm":
		return 64
	default:
		return 64
	}
}

// readCPUFlags returns the lowercase flags string from /proc/cpuinfo.
func readCPUFlags() string {
	data, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "flags") {
			return strings.ToLower(line)
		}
	}
	return ""
}

// cudaDevices scans for /dev/nvidia0 … /dev/nvidia7 character devices.
// Each present device is reported as a BackendCUDA entry.
func cudaDevices() []DeviceInfo {
	var devices []DeviceInfo
	for i := 0; i < 8; i++ {
		if _, err := os.Stat("/dev/nvidia" + strconv.Itoa(i)); err != nil {
			break
		}
		devices = append(devices, DeviceInfo{
			Backend: BackendCUDA,
			Name:    "NVIDIA GPU " + strconv.Itoa(i),
			Index:   i,
		})
	}
	return devices
}

// hasMetal returns true on darwin where the Metal framework is available.
func hasMetal() bool {
	return runtime.GOOS == "darwin"
}
