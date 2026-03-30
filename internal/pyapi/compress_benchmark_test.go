package main

import (
	"encoding/json"
	"fmt"
	"math"
	"testing"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
)

type benchCompressRequest struct {
	Gradients []float64 `json:"gradients"`
	Format    string    `json:"format"`
	MaxNorm   float64   `json:"max_norm"`
}

func benchGradientFloat64(dim int) []float64 {
	out := make([]float64, dim)
	for i := 0; i < dim; i++ {
		out[i] = math.Sin(float64(i)*0.013) * 0.4
	}
	return out
}

func benchGradientFloat32(dim int) []float32 {
	out := make([]float32, dim)
	for i := 0; i < dim; i++ {
		out[i] = float32(math.Sin(float64(i)*0.013) * 0.4)
	}
	return out
}

func benchJSONPayload(dim int) []byte {
	payload := benchCompressRequest{
		Gradients: benchGradientFloat64(dim),
		Format:    "fp16",
		MaxNorm:   1.0,
	}
	encoded, _ := json.Marshal(payload)
	return encoded
}

func benchCompressCore(fp32 []float32, format string, maxNorm float64) []byte {
	if format == "" || format == "auto" {
		tune := accelerator.BuildAutoTuneProfile(len(fp32))
		format = tune.PreferredFormat
	}
	if format == "int8" {
		effectiveMaxNorm := maxNorm
		if effectiveMaxNorm <= 0 {
			effectiveMaxNorm = float64(accelerator.L2Norm(fp32))
		}
		quantized, _ := accelerator.QuantizeINT8(fp32, effectiveMaxNorm)
		compressed := make([]byte, len(quantized))
		for i, q := range quantized {
			compressed[i] = byte(q)
		}
		return compressed
	}
	return accelerator.FP32ToFP16(fp32)
}

func runJSONCompressionPath(payload []byte) []byte {
	var req benchCompressRequest
	_ = json.Unmarshal(payload, &req)
	fp32 := make([]float32, len(req.Gradients))
	for i, v := range req.Gradients {
		fp32[i] = float32(v)
	}
	return benchCompressCore(fp32, req.Format, req.MaxNorm)
}

func runZeroCopyCompressionPath(fp32 []float32) []byte {
	return benchCompressCore(fp32, "fp16", 1.0)
}

func BenchmarkCompressGradientsJSON(b *testing.B) {
	for _, dim := range []int{512, 2048, 8192, 16384} {
		b.Run(fmt.Sprintf("dim%d", dim), func(b *testing.B) {
			payload := benchJSONPayload(dim)
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_ = runJSONCompressionPath(payload)
			}
		})
	}
}

func BenchmarkCompressGradientsZeroCopy(b *testing.B) {
	for _, dim := range []int{512, 2048, 8192, 16384} {
		b.Run(fmt.Sprintf("dim%d", dim), func(b *testing.B) {
			fp32 := benchGradientFloat32(dim)
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_ = runZeroCopyCompressionPath(fp32)
			}
		})
	}
}
