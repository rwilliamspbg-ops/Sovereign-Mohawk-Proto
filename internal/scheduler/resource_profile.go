package scheduler

import "math"

type ResourceProfile struct {
	NodeID        string
	GPUClass      string
	NPUTOPS       float64
	CPUCores      int
	MemoryGB      float64
	TrustScore    float64
	FreshnessMins float64
}

type TaskSpec struct {
	TaskID           string
	ComplexityUnits  float64
	RequiredMemoryGB float64
	RequiresNPU      bool
}

func (p ResourceProfile) CapacityScore(task TaskSpec) float64 {
	if p.CPUCores <= 0 || p.MemoryGB < task.RequiredMemoryGB {
		return 0
	}
	npuFactor := 1.0
	if task.RequiresNPU {
		npuFactor = clamp(p.NPUTOPS/10.0, 0, 3)
		if npuFactor == 0 {
			return 0
		}
	}
	cpuFactor := clamp(float64(p.CPUCores)/16.0, 0.1, 1.5)
	memFactor := clamp(p.MemoryGB/(task.RequiredMemoryGB+1), 0.2, 2.0)
	trust := clamp(p.TrustScore, 0.1, 1.0)
	freshnessPenalty := math.Exp(-clamp(p.FreshnessMins, 0, 120) / 90.0)
	return cpuFactor * memFactor * npuFactor * trust * freshnessPenalty
}

func clamp(v, minV, maxV float64) float64 {
	if v < minV {
		return minV
	}
	if v > maxV {
		return maxV
	}
	return v
}
