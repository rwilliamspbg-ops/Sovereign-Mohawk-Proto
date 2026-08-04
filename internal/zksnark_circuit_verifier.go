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
// Theorem 5: closes the "genesisVK is not derived from any circuit's
// trusted setup" gap documented in zksnark_verifier.go — this file adds a
// second, additive Groth16/BN254 verifier whose verification key genuinely
// comes from compiling a real R1CS circuit and running a real
// groth16.Setup over it, rather than being assembled from bare curve
// generators with no circuit behind them.
//
// Circuit: DataCommitmentCircuit proves knowledge of a MiMC preimage of a
// public Commitment. Callers bind proof validity to arbitrary submitted
// data by computing Preimage = MiMC(data) off-circuit (see
// DataCommitmentDigest) and Commitment = MiMC(Preimage); the circuit then
// proves "I know a preimage of Commitment" without revealing it. Because
// MiMC is collision-resistant, two different data payloads produce
// different Commitments with overwhelming probability, so a proof that
// verifies against a given Commitment is bound to the specific data that
// produced it — the property genesisVK's fixed, content-free identity
// (in zksnark_verifier.go) could not provide.
//
// Scope, stated plainly (read before citing this as production-ready):
//  1. The (proving key, verifying key) pair below comes from a single
//     in-process groth16.Setup call, run lazily (via sync.Once) on first
//     use rather than at package init — package `internal` is imported by
//     nearly everything in this repo, and forcing every such binary to pay
//     a circuit-compile-plus-Setup cost merely for importing the package,
//     whether or not it ever calls into this file, is wasteful and was
//     measured to add a real, avoidable performance cost to unrelated
//     benchmarks. This is a REAL trusted setup over a REAL compiled
//     circuit — not a fixed identity — but it is not a multi-party
//     ceremony: the toxic waste is momentarily held by whichever
//     goroutine runs the setup and is discarded, not distributed across
//     independent participants the way a production Groth16 deployment
//     (e.g. a Powers-of-Tau + circuit-specific MPC) would require. Treat
//     dataCommitmentVK as a development/demo key, not a production-
//     security guarantee.
//  2. This circuit is not yet wired into any production call path.
//     internal/pyapi/api.go's CGo exports, internal/hybrid/verifier.go,
//     and internal/batch/aggregator.go all still call the pre-existing
//     VerifyProof/GenesisProofBytes path (zero public inputs, hardcoded
//     or nil digests) — connecting a real per-round gradient/model
//     commitment (e.g. internal/computeproof.Trace's DatasetCommitment/
//     ModelCommitmentBefore/After fields, currently unpopulated by any
//     production caller) into this circuit's Preimage remains follow-up
//     work, not attempted here.
package internal

import (
	"bytes"
	"fmt"
	"math/big"
	"sync"

	"github.com/consensys/gnark-crypto/ecc"
	gnarkmimc "github.com/consensys/gnark-crypto/hash"
	"github.com/consensys/gnark/backend/groth16"
	"github.com/consensys/gnark/constraint"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
	"github.com/consensys/gnark/std/hash/mimc"
)

// DataCommitmentCircuit proves knowledge of a MiMC preimage of a public
// Commitment, over the BN254 scalar field.
type DataCommitmentCircuit struct {
	Preimage   frontend.Variable
	Commitment frontend.Variable `gnark:",public"`
}

// Define implements frontend.Circuit: Commitment == MiMC(Preimage).
func (c *DataCommitmentCircuit) Define(api frontend.API) error {
	h, err := mimc.NewMiMC(api)
	if err != nil {
		return fmt.Errorf("construct in-circuit MiMC hasher: %w", err)
	}
	h.Write(c.Preimage)
	api.AssertIsEqual(h.Sum(), c.Commitment)
	return nil
}

var (
	dataCommitmentOnce sync.Once
	dataCommitmentCCS  constraint.ConstraintSystem
	dataCommitmentPK   groth16.ProvingKey
	dataCommitmentVK   groth16.VerifyingKey
	dataCommitmentErr  error
)

// ensureDataCommitmentSetup compiles DataCommitmentCircuit and runs its
// Groth16 trusted setup exactly once, on first use, rather than at package
// init — see the file doc comment's scope note for why eager init() was
// rejected.
func ensureDataCommitmentSetup() error {
	dataCommitmentOnce.Do(func() {
		ccs, err := frontend.Compile(ecc.BN254.ScalarField(), r1cs.NewBuilder, &DataCommitmentCircuit{})
		if err != nil {
			dataCommitmentErr = fmt.Errorf("compile DataCommitmentCircuit: %w", err)
			return
		}
		pk, vk, err := groth16.Setup(ccs)
		if err != nil {
			dataCommitmentErr = fmt.Errorf("groth16 setup for DataCommitmentCircuit: %w", err)
			return
		}
		dataCommitmentCCS = ccs
		dataCommitmentPK = pk
		dataCommitmentVK = vk
	})
	return dataCommitmentErr
}

// DataCommitmentDigest computes a MiMC(BN254) digest of data as a
// scalar-field element, suitable for use as a DataCommitmentCircuit
// Preimage. This is the off-circuit half of the binding: two different
// byte payloads produce different digests with overwhelming probability.
func DataCommitmentDigest(data []byte) *big.Int {
	h := gnarkmimc.MIMC_BN254.New()
	h.Write(data)
	return new(big.Int).SetBytes(h.Sum(nil))
}

// ProveDataCommitment produces a Groth16 proof that the prover knows a
// preimage of MiMC(preimage), for the given preimage field element
// (typically DataCommitmentDigest(data)). Returns the serialized proof and
// the public commitment the proof verifies against.
func ProveDataCommitment(preimage *big.Int) (proofBytes []byte, commitment *big.Int, err error) {
	if err := ensureDataCommitmentSetup(); err != nil {
		return nil, nil, err
	}

	h := gnarkmimc.MIMC_BN254.New()
	h.Write(preimage.Bytes())
	commitment = new(big.Int).SetBytes(h.Sum(nil))

	assignment := DataCommitmentCircuit{Preimage: preimage, Commitment: commitment}
	witness, err := frontend.NewWitness(&assignment, ecc.BN254.ScalarField())
	if err != nil {
		return nil, nil, fmt.Errorf("build witness: %w", err)
	}

	proof, err := groth16.Prove(dataCommitmentCCS, dataCommitmentPK, witness)
	if err != nil {
		return nil, nil, fmt.Errorf("groth16 prove: %w", err)
	}

	var buf bytes.Buffer
	if _, err := proof.WriteTo(&buf); err != nil {
		return nil, nil, fmt.Errorf("serialize proof: %w", err)
	}
	return buf.Bytes(), commitment, nil
}

// VerifyDataCommitmentProof verifies a Groth16 proof against the
// circuit-derived verification key (dataCommitmentVK) and a public
// commitment. Unlike VerifyProof in zksnark_verifier.go, a valid proof
// here genuinely attests to knowledge of a preimage of commitment under a
// real, compiled circuit and a real trusted setup — not a fixed,
// content-free identity.
func VerifyDataCommitmentProof(proofBytes []byte, commitment *big.Int) (bool, error) {
	if err := ensureDataCommitmentSetup(); err != nil {
		return false, err
	}

	proof := groth16.NewProof(ecc.BN254)
	if _, err := proof.ReadFrom(bytes.NewReader(proofBytes)); err != nil {
		return false, fmt.Errorf("deserialize proof: %w", err)
	}

	publicAssignment := DataCommitmentCircuit{Commitment: commitment}
	publicWitness, err := frontend.NewWitness(&publicAssignment, ecc.BN254.ScalarField(), frontend.PublicOnly())
	if err != nil {
		return false, fmt.Errorf("build public witness: %w", err)
	}

	if err := groth16.Verify(proof, dataCommitmentVK, publicWitness); err != nil {
		return false, nil
	}
	return true, nil
}
