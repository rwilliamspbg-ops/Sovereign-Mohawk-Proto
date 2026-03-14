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
// Theorem 5: Constant-time (10ms) zk-SNARK verification for 10M nodes.
//
// Implementation: Groth16 pairing-based zk-SNARK verifier on BN254 (alt_bn128).
// Wire format (128 bytes, compressed):
//
//	[0:32]  — A: G1 point (compressed, 32 bytes)
//	[32:96] — B: G2 point (compressed, 64 bytes)
//	[96:128]— C: G1 point (compressed, 32 bytes)
//
// Verification equation:  e(-A, B) · e(α, β) · e(IC₀, γ) · e(C, δ) = 1
// Genesis VK uses canonical BN254 generator points (α=G1, β=G2, γ=G2, δ=G2, IC₀=G1).
// A valid genesis proof satisfying this VK with no public inputs: A=G1, B=G2, C=−G1.
package internal

import (
	"errors"
	"fmt"
	"time"

	"github.com/consensys/gnark-crypto/ecc/bn254"
)

// ProofBytes is the wire size of a compressed BN254 Groth16 proof.
const ProofBytes = bn254.SizeOfG1AffineCompressed + bn254.SizeOfG2AffineCompressed + bn254.SizeOfG1AffineCompressed

// genesisVK holds the protocol genesis verification key.
// All points are set to canonical BN254 generators in init().
var genesisVK struct {
	Alpha bn254.G1Affine
	Beta  bn254.G2Affine
	Gamma bn254.G2Affine
	Delta bn254.G2Affine
	IC0   bn254.G1Affine // constant IC term for zero-public-input statements
}

func init() {
	_, _, g1, g2 := bn254.Generators()
	genesisVK.Alpha = g1
	genesisVK.Beta = g2
	genesisVK.Gamma = g2
	genesisVK.Delta = g2
	genesisVK.IC0 = g1
}

// GenesisProofBytes returns a deterministic BN254 Groth16 proof valid under the
// genesis verification key with no public inputs.
// Proof: A=G1gen, B=G2gen, C=−G1gen satisfies e(−A,B)·e(α,β)·e(IC₀,γ)·e(C,δ)=1.
func GenesisProofBytes() []byte {
	_, _, g1, g2 := bn254.Generators()
	var negG1 bn254.G1Affine
	negG1.Neg(&g1)

	aB := g1.Bytes()
	bB := g2.Bytes()
	cB := negG1.Bytes()

	proof := make([]byte, ProofBytes)
	copy(proof[0:32], aB[:])
	copy(proof[32:96], bB[:])
	copy(proof[96:128], cB[:])
	return proof
}

// VerifyProof performs BN254 Groth16 pairing verification against the genesis VK.
// Proof layout (128 bytes, compressed): A [0:32] | B [32:96] | C [96:128].
// The inputs parameter is reserved for public statement scalars; currently unused
// in zero-public-input mode (IC length = 1).
//
// Active Guard — Theorem 5: verification must complete within 15 ms.
// The four Miller-loop pairing check on BN254 is O(1) in the number of nodes
// because proof size is constant regardless of the aggregation scale.
func VerifyProof(proof []byte, inputs []byte) (bool, error) {
	start := time.Now()

	if len(proof) < ProofBytes {
		return false, fmt.Errorf(
			"invalid proof size: got %d bytes, need %d (BN254 compressed: G1[32]+G2[64]+G1[32])",
			len(proof), ProofBytes)
	}

	var pA bn254.G1Affine
	var pB bn254.G2Affine
	var pC bn254.G1Affine

	if _, err := pA.SetBytes(proof[0:32]); err != nil {
		return false, fmt.Errorf("invalid proof A (G1): %w", err)
	}
	if _, err := pB.SetBytes(proof[32:96]); err != nil {
		return false, fmt.Errorf("invalid proof B (G2): %w", err)
	}
	if _, err := pC.SetBytes(proof[96:128]); err != nil {
		return false, fmt.Errorf("invalid proof C (G1): %w", err)
	}

	// Reject proofs with any degenerate infinity point.
	if pA.IsInfinity() || pB.IsInfinity() || pC.IsInfinity() {
		return false, errors.New("degenerate proof: one or more points are at infinity")
	}

	// Groth16 multi-pairing check:  e(−A, B) · e(α, β) · e(IC₀, γ) · e(C, δ) = 1
	var negA bn254.G1Affine
	negA.Neg(&pA)

	ok, err := bn254.PairingCheck(
		[]bn254.G1Affine{negA, genesisVK.Alpha, genesisVK.IC0, pC},
		[]bn254.G2Affine{pB, genesisVK.Beta, genesisVK.Gamma, genesisVK.Delta},
	)
	if err != nil {
		return false, fmt.Errorf("pairing computation failed: %w", err)
	}

	// Active Guard: Theorem 5 — O(1) latency enforcement.
	if elapsed := time.Since(start); elapsed > 15*time.Millisecond {
		return false, fmt.Errorf("verification latency %v exceeded theoretical O(1) bound", elapsed)
	}

	return ok, nil
}
