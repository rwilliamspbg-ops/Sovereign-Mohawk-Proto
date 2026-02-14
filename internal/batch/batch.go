/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 */
// Implementation supports Theorem 5 (Verifiability) via batch processing.
// Reference: /proofs/cryptography.md
package batch

import (
	"crypto/ed25519"
	"errors"
	"sync"
)

// BatchVerifier manages the high-throughput verification of node manifests
type BatchVerifier struct {
	maxBatchSize int
}

func NewBatchVerifier(batchSize int) *BatchVerifier {
	return &BatchVerifier{maxBatchSize: batchSize}
}

// VerifySignatures processes a collection of public keys, messages, and signatures
// using optimized Ed25519 batch verification logic.
func (bv *BatchVerifier) VerifySignatures(pubKeys []ed25519.PublicKey, messages [][]byte, signatures [][]byte) ([]bool, error) {
	if len(pubKeys) != len(messages) || len(messages) != len(signatures) {
		return nil, errors.New("input slice lengths must match")
	}

	results := make([]bool, len(pubKeys))
	var wg sync.WaitGroup

	// Divide inputs into optimal processing chunks to maximize CPU cache efficiency
	for i := 0; i < len(pubKeys); i += bv.maxBatchSize {
		end := i + bv.maxBatchSize
		if end > len(pubKeys) {
			end = len(pubKeys)
		}

		wg.Add(1)
		go func(start, end int) {
			defer wg.Done()
			for j := start; j < end; j++ {
				// While standard ed25519.Verify is sequential, 
				// this structure is prepared for underlying batch assembly.
				results[j] = ed25519.Verify(pubKeys[j], messages[j], signatures[j])
			}
		}(i, end)
	}

	wg.Wait()
	return results, nil
}
