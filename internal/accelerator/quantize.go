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

package accelerator

import (
	"encoding/binary"
	"math"
)

// FP32ToFP16 converts a float32 slice to IEEE 754 half-precision bytes (2 bytes
// per element, little-endian). Halving the payload from 4 B/param → 2 B/param
// yields a ~50% wire compression ratio for gradient transmission.
func FP32ToFP16(in []float32) []byte {
	out := make([]byte, len(in)*2)
	for i, f := range in {
		binary.LittleEndian.PutUint16(out[i*2:], f32ToF16Bits(f))
	}
	return out
}

// FP16ToFP32 converts IEEE 754 half-precision bytes back to float32.
func FP16ToFP32(in []byte) []float32 {
	n := len(in) / 2
	out := make([]float32, n)
	for i := 0; i < n; i++ {
		out[i] = f16BitsToF32(binary.LittleEndian.Uint16(in[i*2:]))
	}
	return out
}

// QuantizeINT8 maps float32 values in [-maxNorm, maxNorm] to the INT8 range
// [-127, 127] using symmetric uniform quantization.
// Returns the quantized bytes and the scale factor for dequantization.
// At 1 B/param this reduces wire size by 75 % vs FP32.
func QuantizeINT8(in []float32, maxNorm float64) ([]int8, float64) {
	scale := maxNorm / 127.0
	if scale == 0 {
		scale = 1.0
	}
	out := make([]int8, len(in))
	for i, f := range in {
		q := int(math.Round(float64(f) / scale))
		switch {
		case q > 127:
			q = 127
		case q < -127:
			q = -127
		}
		out[i] = int8(q)
	}
	return out, scale
}

// DequantizeINT8 recovers float32 values from INT8 quantized bytes and the
// scale factor returned by QuantizeINT8.
func DequantizeINT8(in []int8, scale float64) []float32 {
	out := make([]float32, len(in))
	for i, q := range in {
		out[i] = float32(float64(q) * scale)
	}
	return out
}

// CompressionRatio returns the ratio of original bytes to compressed bytes.
// inputBytes is the pre-compression size; outputBytes is the post-compression size.
func CompressionRatio(inputBytes, outputBytes int) float64 {
	if outputBytes == 0 {
		return 1.0
	}
	return float64(inputBytes) / float64(outputBytes)
}

// ---- IEEE 754 half-precision helpers ----------------------------------------

// f32ToF16Bits converts a single float32 to its FP16 bit pattern.
func f32ToF16Bits(f float32) uint16 {
	bits := math.Float32bits(f)
	sign := (bits >> 16) & 0x8000
	rawExp := int((bits>>23)&0xff) - 127 + 15
	mantissa := bits & 0x7fffff

	switch {
	case rawExp <= 0:
		// Sub-normal or underflow
		if rawExp < -10 {
			return uint16(sign)
		}
		mantissa |= 0x800000
		mantissa >>= uint(1 - rawExp)
		return uint16(sign | uint32(mantissa>>13))
	case rawExp >= 31:
		// Overflow → infinity
		return uint16(sign | 0x7c00)
	default:
		return uint16(sign | uint32(rawExp<<10) | (mantissa >> 13))
	}
}

// f16BitsToF32 decodes an FP16 bit pattern to float32.
func f16BitsToF32(h uint16) float32 {
	sign := uint32(h&0x8000) << 16
	rawExp := uint32((h >> 10) & 0x1f)
	mantissa := uint32(h & 0x3ff)

	var bits uint32
	switch rawExp {
	case 0:
		if mantissa == 0 {
			bits = sign
		} else {
			// Normalise subnormal
			e := uint32(1)
			for mantissa&0x400 == 0 {
				mantissa <<= 1
				e--
			}
			mantissa &= 0x3ff
			bits = sign | ((e + 127 - 15) << 23) | (mantissa << 13)
		}
	case 31:
		// Inf or NaN
		bits = sign | 0x7f800000 | (mantissa << 13)
	default:
		bits = sign | ((rawExp + 127 - 15) << 23) | (mantissa << 13)
	}
	return math.Float32frombits(bits)
}
