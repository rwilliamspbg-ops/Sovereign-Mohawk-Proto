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
//  1. The (proving key, verifying key) pair below comes from a multi-party
//     trusted setup (MPC) simulated in-process: N independent contributors
//     chain their contributions via gnark's mpcsetup flow (Phase 1 SRS +
//     Phase 2 circuit-specific), and the final key is sealed with a public
//     beacon challenge. No single contributor holds the toxic waste. This is
//     still an in-process simulation (not a distributed ceremony over a
//     network), so treat dataCommitmentVK as a development/demo key, not a
//     production-security guarantee. A real deployment would run each
//     contribution on a separate, independently-operated machine.
//  2. Wired into production as of 2026-08-15: internal/pyapi/api.go's
//     VerifyZKProof/BatchVerifyProofs CGo exports and
//     internal/hybrid/verifier.go's SNARKVerifier/VerifyHybrid now accept
//     an optional hex-encoded commitment (internal.ParseCommitmentHex) and
//     route to VerifyDataCommitmentProof when one is supplied, falling
//     back to the legacy VerifyProof/GenesisProofBytes path when absent —
//     purely additive, no existing caller's behavior changed.
//     internal/batch/aggregator.go's Aggregator now also supports the circuit
//     path: when Aggregator.GradientCommitment is non-nil, ProcessRound
//     verifies via VerifyDataCommitmentProof instead of the legacy
//     SHA-256-of-empty baseline check (see test/batch_zk_attestation_test.go).
//     Connecting a real per-round gradient/model commitment (e.g.
//     internal/computeproof.Trace's DatasetCommitment/
//     ModelCommitmentBefore/After fields, still unpopulated by any
//     production caller as of this writing) into this circuit's Preimage
//     remains separate follow-up work, not attempted here — today's
//     callers must supply the commitment themselves.
package internal

import (
	"bytes"
	"fmt"
	"math/big"
	"sync"

	"github.com/consensys/gnark-crypto/ecc"
	gnarkmimc "github.com/consensys/gnark-crypto/hash"
	"github.com/consensys/gnark/backend/groth16"
	mpcsetup "github.com/consensys/gnark/backend/groth16/bn254/mpcsetup"
	"github.com/consensys/gnark/constraint"
	cs "github.com/consensys/gnark/constraint/bn254"
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

// ensureDataCommitmentSetup compiles DataCommitmentCircuit and runs a
// multi-party trusted setup (MPC) over it, simulating N independent
// contributors in-process. The final (proving key, verifying key) pair
// is produced via gnark's mpcsetup flow, so no single party holds the
// toxic waste — the beacon contribution at Seal is reproducible by any
// verifier. Runs lazily via sync.Once on first use.
func ensureDataCommitmentSetup() error {
	dataCommitmentOnce.Do(func() {
		ccs, err := frontend.Compile(ecc.BN254.ScalarField(), r1cs.NewBuilder, &DataCommitmentCircuit{})
		if err != nil {
			dataCommitmentErr = fmt.Errorf("compile DataCommitmentCircuit: %w", err)
			return
		}

		const nContributors = 3
		domainSize := ecc.NextPowerOfTwo(uint64(ccs.GetNbConstraints()))
		beacon := []byte("sovereign-mohawk mpc beacon")

		// Phase 1: circuit-independent SRS, chained contributions.
		p1 := mpcsetup.Phase1{}
		p1.Initialize(domainSize)
		var phase1Contribs []*mpcsetup.Phase1
		cur := p1
		for i := 0; i < nContributors; i++ {
			cur.Contribute()
			cp := new(mpcsetup.Phase1)
			*cp = cur
			phase1Contribs = append(phase1Contribs, cp)
			// chain: serialize and deserialize into a fresh Phase1 for next contributor
			var buf bytes.Buffer
			if _, err := cur.WriteTo(&buf); err != nil {
				dataCommitmentErr = fmt.Errorf("phase1 marshal: %w", err)
				return
			}
			next := mpcsetup.Phase1{}
			if _, err := next.ReadFrom(&buf); err != nil {
				dataCommitmentErr = fmt.Errorf("phase1 unmarshal: %w", err)
				return
			}
			cur = next
		}
		srsCommons, err := mpcsetup.VerifyPhase1(domainSize, beacon, phase1Contribs...)
		if err != nil {
			dataCommitmentErr = fmt.Errorf("mpc phase1 verify: %w", err)
			return
		}

		// Phase 2: circuit-specific setup, chained contributions.
		p2 := mpcsetup.Phase2{}
		p2.Initialize(ccs.(*cs.R1CS), &srsCommons)
		var phase2Contribs []*mpcsetup.Phase2
		cur2 := p2
		for i := 0; i < nContributors; i++ {
			cur2.Contribute()
			cp := new(mpcsetup.Phase2)
			*cp = cur2
			phase2Contribs = append(phase2Contribs, cp)
			var buf bytes.Buffer
			if _, err := cur2.WriteTo(&buf); err != nil {
				dataCommitmentErr = fmt.Errorf("phase2 marshal: %w", err)
				return
			}
			next := mpcsetup.Phase2{}
			if _, err := next.ReadFrom(&buf); err != nil {
				dataCommitmentErr = fmt.Errorf("phase2 unmarshal: %w", err)
				return
			}
			cur2 = next
		}
		pk, vk, err := mpcsetup.VerifyPhase2(ccs.(*cs.R1CS), &srsCommons, beacon, phase2Contribs...)
		if err != nil {
			dataCommitmentErr = fmt.Errorf("mpc phase2 verify: %w", err)
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
