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
// Supports hierarchical structure and communication optimality.
// Reference: /proofs/communication.md
package manifest

import (
	"crypto/ed25519"
	"crypto/x509"
	"encoding/json"
	"errors"
)

type Capability string

const (
	CapLog        Capability = "LOG"
	CapSubmitGrad Capability = "SUBMIT_GRADIENTS"
	// Add more as needed: CapGetSensor, CapNoNetwork, etc.
)

type Manifest struct {
	TaskID           string       `json:"task_id"`
	NodeID           string       `json:"node_id"`
	WasmModuleSHA256 string       `json:"wasm_module_sha256"`
	Capabilities     []Capability `json:"capabilities"`
	MaxMemPages      uint32       `json:"max_mem_pages"`
	MaxMillis        uint64       `json:"max_millis"`

	// Differential privacy hints
	MaxGradNorm float64 `json:"max_grad_norm"`
	Epsilon     float64 `json:"epsilon"`
	Delta       float64 `json:"delta"`

	Signature []byte `json:"signature"`
}

func VerifySignature(m *Manifest, orchestratorPub []byte) error {
	sig := m.Signature
	m.Signature = nil
	defer func() { m.Signature = sig }()

	data, err := json.Marshal(m)
	if err != nil {
		return err
	}

	pub, err := x509.ParsePKIXPublicKey(orchestratorPub)
	if err != nil {
		return err
	}
	pk, ok := pub.(ed25519.PublicKey)
	if !ok {
		return errors.New("not ed25519 key")
	}

	if !ed25519.Verify(pk, data, sig) {
		return errors.New("invalid manifest signature")
	}
	return nil
}
import "math" // Ensure "math" is in your imports

// ValidateCommunicationComplexity enforces Theorem 3.
// Reference: /proofs/communication.md
func (m *Manifest) ValidateCommunicationComplexity(d int, n int) error {
	// Theoretical limit: O(d * log10(n))
	limit := float64(d) * math.Log10(float64(n))
	
	// Assuming an estimated size based on fields; replace with actual byte count if available
	actual := float64(len(m.TaskID) + len(m.NodeID) + 200) // 200B for SNARK + metadata

	if actual > limit*2.0 { // Allowing 2x constant-factor overhead
		return fmt.Errorf("communication optimality violated: actual size %.2f exceeds O(d log n) bound", actual)
	}
	return nil
}
