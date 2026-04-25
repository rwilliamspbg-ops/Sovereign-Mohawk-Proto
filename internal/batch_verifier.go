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

// Reference: /proofs/cryptography.md
// Theorem 5: High-throughput signature verification for 10M-node scale.
package internal

import (
	"crypto/ed25519"
	"errors"
	"fmt"
	"sync"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/accelerator"
)

// BatchVerifier manages parallel verification of node signatures.
// Essential for maintaining the O(1) effective verification time per node.
type BatchVerifier struct {
	maxBatchSize int
}

// ComputeProofVerifier validates a per-update proof-of-compute payload.
// Implementations should be deterministic so replay tests remain reproducible.
type ComputeProofVerifier func(tracePayload []byte, proofPayload []byte) (bool, error)

// NewBatchVerifier initializes a verifier with the specified parallelism limit.
func NewBatchVerifier(batchSize int) *BatchVerifier {
	if batchSize <= 0 {
		batchSize = accelerator.BuildAutoTuneProfile(0).RecommendedWorker
		if batchSize <= 0 {
			batchSize = 1
		}
	}
	return &BatchVerifier{maxBatchSize: batchSize}
}

// VerifySignatures processes a set of messages and signatures against public keys.
// This parallel implementation supports the scaling requirements of Theorem 5.
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
				results[j] = ed25519.Verify(pubKeys[j], messages[j], signatures[j])
			}
		}(i, end)
	}

	wg.Wait()
	return results, nil
}

// VerifySignaturesWithComputeProof extends signature checks with proof-of-compute
// validation for each update envelope.
func (bv *BatchVerifier) VerifySignaturesWithComputeProof(
	pubKeys []ed25519.PublicKey,
	messages [][]byte,
	signatures [][]byte,
	tracePayloads [][]byte,
	proofPayloads [][]byte,
	verifyCompute ComputeProofVerifier,
) ([]bool, error) {
	if len(tracePayloads) != len(pubKeys) || len(proofPayloads) != len(pubKeys) {
		return nil, errors.New("compute proof payload lengths must match signature inputs")
	}
	if verifyCompute == nil {
		return nil, errors.New("compute proof verifier is required")
	}

	sigResults, err := bv.VerifySignatures(pubKeys, messages, signatures)
	if err != nil {
		return nil, err
	}

	results := make([]bool, len(sigResults))
	for i := range sigResults {
		if !sigResults[i] {
			results[i] = false
			continue
		}
		ok, verr := verifyCompute(tracePayloads[i], proofPayloads[i])
		if verr != nil {
			return nil, fmt.Errorf("compute proof verification failed at index %d: %w", i, verr)
		}
		results[i] = ok
	}

	return results, nil
}
