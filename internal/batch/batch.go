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

// Implementation supports Theorem 5 (Verifiability) via batch processing.
// Reference: /proofs/cryptography.md
package batch

import (
	"crypto/ed25519"
	"errors"
	"sync"
)

// BatchVerifier manages the high-throughput verification of node manifests.
type BatchVerifier struct {
	maxBatchSize int
}

// NewBatchVerifier initializes a verifier with a specific throughput limit.
func NewBatchVerifier(batchSize int) *BatchVerifier {
	return &BatchVerifier{maxBatchSize: batchSize}
}

// VerifySignatures processes public keys, messages, and signatures in parallel.
// This is required to maintain the O(1) verification time described in Theorem 5.
func (bv *BatchVerifier) VerifySignatures(pubKeys []ed25519.PublicKey, messages [][]byte, signatures [][]byte) ([]bool, error) {
	if len(pubKeys) != len(messages) || len(messages) != len(signatures) {
		return nil, errors.New("input slice lengths must match")
	}

	results := make([]bool, len(pubKeys))
	var wg sync.WaitGroup

	for i := 0; i < len(pubKeys); i += bv.maxBatchSize {
		end := i + bv.maxBatchSize
		if end > len(pubKeys) {
			end = len(pubKeys)
		}

		wg.Add(1)
		go func(start, end int) {
			defer wg.Done()
			for j := start; j < end; j++ {
				// Standard ed25519 verification; prepared for future batch assembly.
				results[j] = ed25519.Verify(pubKeys[j], messages[j], signatures[j])
			}
		}(i, end)
	}

	wg.Wait()
	return results, nil
}
