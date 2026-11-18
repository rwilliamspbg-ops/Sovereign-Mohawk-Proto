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
//
// WeightUpdateCircuit — the per-update ZK statement for Pillar 1.
//
// Unlike DataCommitmentCircuit (zksnark_circuit_verifier.go), which proves
// knowledge of a MiMC preimage of ONE field element, this circuit binds a
// whole training update:
//
//	ModelHashAfter  == MiMC(ModelHashBefore, TrainingSteps, Gradients…)
//	∑ Gradients[i]² ≤ GradNormBound²          (each component range-checked)
//	UpdateHash      == MiMC(DPEpsilon, TrainingSteps, Gradients[i]+Noise[i]…,
//	                        DatasetCommitment)
//	DatasetCommitment ≠ 0
//
// The public statement is the six-element WeightStatement; the witness is the
// gradient/noise vectors. A valid proof therefore attests that the submitted
// update really is the one derived from the stated model state, dataset
// commitment, DP budget and norm bound — the property the legacy genesisVK
// identity (zksnark_verifier.go) cannot provide.
//
// Encoding contract (read before constructing a witness):
//   - Gradient and noise components are signed fixed-point integers, Q32.32
//     (see EncodeFixedPoint). The circuit range-checks |component| < 2^63, so
//     |value| < 2^31 in real units.
//   - GradNormBound is a non-negative Q32.32 fixed-point integer, range-checked
//     to 63 bits.
//   - ModelHashBefore / DatasetCommitment / DPEpsilon are field elements; they
//     are reduced mod p before hashing, matching the in-circuit variables.
//   - ModelHashAfter and UpdateHash are DERIVED, not supplied: DeriveWeightStatement
//     computes them with the same MiMC parameters the circuit uses, so a prover
//     cannot choose them freely.
//
// Trusted setup: the (pk, vk) pair comes from the same in-process multi-party
// ceremony simulation used by DataCommitmentCircuit (see mpcSetupBN254). It is a
// development key, not a production-security guarantee.
package internal

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"math/big"
	"sync"

	"github.com/consensys/gnark-crypto/ecc"
	"github.com/consensys/gnark-crypto/ecc/bn254/fr"
	gnarkmimc "github.com/consensys/gnark-crypto/hash"
	"github.com/consensys/gnark/backend/groth16"
	mpcsetup "github.com/consensys/gnark/backend/groth16/bn254/mpcsetup"
	"github.com/consensys/gnark/constraint"
	cs "github.com/consensys/gnark/constraint/bn254"
	"github.com/consensys/gnark/frontend"
	"github.com/consensys/gnark/frontend/cs/r1cs"
	"github.com/consensys/gnark/std/hash/mimc"
)

const (
	// WeightGradientCount is the fixed arity of the gradient/noise vectors.
	WeightGradientCount = 8

	// WeightComponentBits is the range-check width for one signed component.
	// A signed Q32.32 component is offset by 2^63 and checked to 64 bits, so
	// |component| < 2^63.
	WeightComponentBits = 64

	// WeightFixedPointShift is the Q32.32 scaling exponent.
	WeightFixedPointShift = 32

	// WeightNormBoundBits is the range-check width for GradNormBound.
	WeightNormBoundBits = 63
)

// weightSignOffset is the offset applied to a signed component before the
// 64-bit range check: component + 2^63 must fit in 64 bits, i.e.
// -2^63 <= component < 2^63.
var weightSignOffset = new(big.Int).Lsh(big.NewInt(1), 63)

// WeightPublicInputs are the caller-supplied public values of an update.
type WeightPublicInputs struct {
	ModelHashBefore   *big.Int
	DatasetCommitment *big.Int
	GradNormBound     *big.Int
	DPEpsilon         *big.Int
}

// WeightStatement is the full public input vector of WeightUpdateCircuit.
type WeightStatement struct {
	ModelHashBefore   *big.Int
	ModelHashAfter    *big.Int
	DatasetCommitment *big.Int
	GradNormBound     *big.Int
	DPEpsilon         *big.Int
	UpdateHash        *big.Int
}

// WeightWitness is the private training witness.
type WeightWitness struct {
	Gradients     [WeightGradientCount]*big.Int
	Noise         [WeightGradientCount]*big.Int
	TrainingSteps uint32
}

// WeightUpdateCircuit is the gnark circuit for one weight update.
type WeightUpdateCircuit struct {
	// public
	ModelHashBefore   frontend.Variable `gnark:",public"`
	ModelHashAfter    frontend.Variable `gnark:",public"`
	DatasetCommitment frontend.Variable `gnark:",public"`
	GradNormBound     frontend.Variable `gnark:",public"`
	DPEpsilon         frontend.Variable `gnark:",public"`
	UpdateHash        frontend.Variable `gnark:",public"`

	// private
	Gradients     [WeightGradientCount]frontend.Variable
	Noise         [WeightGradientCount]frontend.Variable
	TrainingSteps frontend.Variable
}

// Define implements frontend.Circuit.
func (c *WeightUpdateCircuit) Define(api frontend.API) error {
	// (1) model hash chain over the raw gradients
	mh, err := mimc.NewMiMC(api)
	if err != nil {
		return fmt.Errorf("construct model hasher: %w", err)
	}
	mh.Write(c.ModelHashBefore, c.TrainingSteps)
	for i := range c.Gradients {
		mh.Write(c.Gradients[i])
	}
	api.AssertIsEqual(mh.Sum(), c.ModelHashAfter)

	// (2) per-component range check, then the L2 norm bound.
	var normSq frontend.Variable = 0
	for i := range c.Gradients {
		api.ToBinary(api.Add(c.Gradients[i], weightSignOffset), WeightComponentBits)
		normSq = api.Add(normSq, api.Mul(c.Gradients[i], c.Gradients[i]))
	}
	api.ToBinary(c.GradNormBound, WeightNormBoundBits)
	api.AssertIsLessOrEqual(normSq, api.Mul(c.GradNormBound, c.GradNormBound))

	// (3) noise range check, then the update hash chain over noised gradients.
	uh, err := mimc.NewMiMC(api)
	if err != nil {
		return fmt.Errorf("construct update hasher: %w", err)
	}
	uh.Write(c.DPEpsilon, c.TrainingSteps)
	for i := range c.Gradients {
		api.ToBinary(api.Add(c.Noise[i], weightSignOffset), WeightComponentBits)
		uh.Write(api.Add(c.Gradients[i], c.Noise[i]))
	}
	uh.Write(c.DatasetCommitment)
	api.AssertIsEqual(uh.Sum(), c.UpdateHash)

	// (4) dataset binding: the commitment must be non-zero.
	api.AssertIsDifferent(c.DatasetCommitment, 0)

	return nil
}

// EncodeFixedPoint converts a real-valued gradient/noise component into a
// signed Q32.32 fixed-point integer suitable for the circuit. NaN and infinities
// are rejected; magnitudes beyond 2^31 are rejected because the circuit's
// 64-bit range check would fail.
func EncodeFixedPoint(v float64) (*big.Int, error) {
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return nil, fmt.Errorf("fixed-point: non-finite value %v", v)
	}
	scaled := math.Round(v * float64(int64(1)<<WeightFixedPointShift))
	if scaled > math.MaxInt64 || scaled < math.MinInt64 {
		return nil, fmt.Errorf("fixed-point: %v overflows int64 after scaling", v)
	}
	return big.NewInt(int64(scaled)), nil
}

// fieldElement canonicalizes v into [0, p). A nil component means zero, so a
// zero-value WeightWitness is usable rather than a nil-pointer crash.
func fieldElement(v *big.Int) *big.Int {
	if v == nil {
		return new(big.Int)
	}
	return new(big.Int).Mod(v, fr.Modulus())
}

// fieldOrZero returns v, or 0 when v is nil.
func fieldOrZero(v *big.Int) *big.Int {
	if v == nil {
		return new(big.Int)
	}
	return v
}

// mimcFields hashes field elements with the MiMC parameters the circuit uses.
// Each element is written as its own 32-byte big-endian block, matching the
// in-circuit Write(var) one variable at a time.
func mimcFields(values ...*big.Int) (*big.Int, error) {
	h := gnarkmimc.MIMC_BN254.New()
	for _, v := range values {
		e := fieldElement(v)
		var b [fr.Bytes]byte
		e.FillBytes(b[:])
		if _, err := h.Write(b[:]); err != nil {
			return nil, fmt.Errorf("mimc write: %w", err)
		}
	}
	return new(big.Int).SetBytes(h.Sum(nil)), nil
}

// DeriveWeightStatement computes the two derived public inputs (ModelHashAfter,
// UpdateHash) from the caller-supplied inputs and the witness.
func DeriveWeightStatement(in WeightPublicInputs, w WeightWitness) (WeightStatement, error) {
	st := WeightStatement{
		ModelHashBefore:   fieldElement(in.ModelHashBefore),
		DatasetCommitment: fieldElement(in.DatasetCommitment),
		GradNormBound:     fieldElement(in.GradNormBound),
		DPEpsilon:         fieldElement(in.DPEpsilon),
	}

	steps := big.NewInt(int64(w.TrainingSteps))
	modelVals := make([]*big.Int, 0, 2+len(w.Gradients))
	modelVals = append(modelVals, st.ModelHashBefore, steps)
	modelVals = append(modelVals, w.Gradients[:]...)
	modelAfter, err := mimcFields(modelVals...)
	if err != nil {
		return WeightStatement{}, fmt.Errorf("derive model hash: %w", err)
	}
	st.ModelHashAfter = modelAfter

	updateVals := make([]*big.Int, 0, 2+len(w.Gradients)+1)
	updateVals = append(updateVals, st.DPEpsilon, steps)
	for i := range w.Gradients {
		sum := fieldElement(new(big.Int).Add(fieldOrZero(w.Gradients[i]), fieldOrZero(w.Noise[i])))
		updateVals = append(updateVals, sum)
	}
	updateVals = append(updateVals, st.DatasetCommitment)
	updateHash, err := mimcFields(updateVals...)
	if err != nil {
		return WeightStatement{}, fmt.Errorf("derive update hash: %w", err)
	}
	st.UpdateHash = updateHash

	return st, nil
}

// ---------------------------------------------------------------------------
// Trusted setup
// ---------------------------------------------------------------------------

var (
	weightOnce sync.Once
	weightCCS  constraint.ConstraintSystem
	weightPK   groth16.ProvingKey
	weightVK   groth16.VerifyingKey
	weightErr  error
)

// mpcSetupBN254 compiles nothing; it runs a simulated in-process multi-party
// Groth16 setup over an already-compiled constraint system. Phase 1 is
// circuit-independent, Phase 2 is circuit-specific; contributions are chained
// and the result is sealed against a public beacon. It is a simulation, not a
// distributed ceremony — see the package doc.
func mpcSetupBN254(ccs constraint.ConstraintSystem, nContributors int, beacon []byte) (groth16.ProvingKey, groth16.VerifyingKey, error) {
	domainSize := ecc.NextPowerOfTwo(uint64(ccs.GetNbConstraints()))
	if domainSize < 2 {
		domainSize = 2
	}

	p1 := mpcsetup.Phase1{}
	p1.Initialize(domainSize)
	cur := p1
	phase1Contribs := make([]*mpcsetup.Phase1, 0, nContributors)
	for i := 0; i < nContributors; i++ {
		cur.Contribute()
		cp := new(mpcsetup.Phase1)
		*cp = cur
		phase1Contribs = append(phase1Contribs, cp)
		var buf bytes.Buffer
		if _, err := cur.WriteTo(&buf); err != nil {
			return nil, nil, fmt.Errorf("phase1 marshal: %w", err)
		}
		next := mpcsetup.Phase1{}
		if _, err := next.ReadFrom(&buf); err != nil {
			return nil, nil, fmt.Errorf("phase1 unmarshal: %w", err)
		}
		cur = next
	}
	srsCommons, err := mpcsetup.VerifyPhase1(domainSize, beacon, phase1Contribs...)
	if err != nil {
		return nil, nil, fmt.Errorf("mpc phase1 verify: %w", err)
	}

	r1cs, ok := ccs.(*cs.R1CS)
	if !ok {
		return nil, nil, fmt.Errorf("expected *cs.R1CS, got %T", ccs)
	}

	p2 := mpcsetup.Phase2{}
	p2.Initialize(r1cs, &srsCommons)
	cur2 := p2
	phase2Contribs := make([]*mpcsetup.Phase2, 0, nContributors)
	for i := 0; i < nContributors; i++ {
		cur2.Contribute()
		cp := new(mpcsetup.Phase2)
		*cp = cur2
		phase2Contribs = append(phase2Contribs, cp)
		var buf bytes.Buffer
		if _, err := cur2.WriteTo(&buf); err != nil {
			return nil, nil, fmt.Errorf("phase2 marshal: %w", err)
		}
		next := mpcsetup.Phase2{}
		if _, err := next.ReadFrom(&buf); err != nil {
			return nil, nil, fmt.Errorf("phase2 unmarshal: %w", err)
		}
		cur2 = next
	}
	pk, vk, err := mpcsetup.VerifyPhase2(r1cs, &srsCommons, beacon, phase2Contribs...)
	if err != nil {
		return nil, nil, fmt.Errorf("mpc phase2 verify: %w", err)
	}
	return pk, vk, nil
}

func ensureWeightSetup() error {
	weightOnce.Do(func() {
		ccs, err := frontend.Compile(ecc.BN254.ScalarField(), r1cs.NewBuilder, &WeightUpdateCircuit{})
		if err != nil {
			weightErr = fmt.Errorf("compile WeightUpdateCircuit: %w", err)
			return
		}
		pk, vk, err := mpcSetupBN254(ccs, 3, []byte("sovereign-mohawk weight-update mpc beacon"))
		if err != nil {
			weightErr = err
			return
		}
		weightCCS, weightPK, weightVK = ccs, pk, vk
	})
	return weightErr
}

// WeightCircuitConstraintCount reports the compiled constraint count. It is
// exported so benchmarks and CI can record it as an artifact.
func WeightCircuitConstraintCount() (int, error) {
	if err := ensureWeightSetup(); err != nil {
		return 0, err
	}
	return weightCCS.GetNbConstraints(), nil
}

// ---------------------------------------------------------------------------
// Prove / verify
// ---------------------------------------------------------------------------

// ProveWeightUpdate derives the statement, proves it, and returns the encoded
// proof together with the full public statement.
func ProveWeightUpdate(in WeightPublicInputs, w WeightWitness) ([]byte, WeightStatement, error) {
	st, err := DeriveWeightStatement(in, w)
	if err != nil {
		return nil, WeightStatement{}, err
	}
	if err := ensureWeightSetup(); err != nil {
		return nil, WeightStatement{}, err
	}

	var grads, noise [WeightGradientCount]frontend.Variable
	for i := range w.Gradients {
		grads[i] = fieldElement(w.Gradients[i])
		noise[i] = fieldElement(w.Noise[i])
	}
	assignment := WeightUpdateCircuit{
		ModelHashBefore:   st.ModelHashBefore,
		ModelHashAfter:    st.ModelHashAfter,
		DatasetCommitment: st.DatasetCommitment,
		GradNormBound:     st.GradNormBound,
		DPEpsilon:         st.DPEpsilon,
		UpdateHash:        st.UpdateHash,
		Gradients:         grads,
		Noise:             noise,
		TrainingSteps:     w.TrainingSteps,
	}
	witness, err := frontend.NewWitness(&assignment, ecc.BN254.ScalarField())
	if err != nil {
		return nil, WeightStatement{}, fmt.Errorf("build witness: %w", err)
	}
	proof, err := groth16.Prove(weightCCS, weightPK, witness)
	if err != nil {
		return nil, WeightStatement{}, fmt.Errorf("groth16 prove: %w", err)
	}
	var buf bytes.Buffer
	if _, err := proof.WriteTo(&buf); err != nil {
		return nil, WeightStatement{}, fmt.Errorf("serialize proof: %w", err)
	}
	encoded, err := EncodeWeightProof(buf.Bytes(), st)
	if err != nil {
		return nil, WeightStatement{}, err
	}
	return encoded, st, nil
}

var (
	weightProofMagic   = [4]byte{'S', 'M', 'W', 'P'}
	weightProofVersion = byte(1)
	// weightProofHeader = magic(4) | version(1) | arity(2) | 6 public inputs × 32B
	weightProofHeader = 4 + 1 + 2 + 6*fr.Bytes
)

// EncodeWeightProof frames a serialized gnark proof with its public statement.
// Layout: "SMWP" | version(1) | arity(2, big-endian) | 6 × 32-byte big-endian
// public inputs | proof bytes.
func EncodeWeightProof(proof []byte, st WeightStatement) ([]byte, error) {
	buf := make([]byte, 0, weightProofHeader+len(proof))
	buf = append(buf, weightProofMagic[:]...)
	buf = append(buf, weightProofVersion)
	var arity [2]byte
	binary.BigEndian.PutUint16(arity[:], WeightGradientCount)
	buf = append(buf, arity[:]...)

	for i, v := range []*big.Int{
		st.ModelHashBefore, st.ModelHashAfter, st.DatasetCommitment,
		st.GradNormBound, st.DPEpsilon, st.UpdateHash,
	} {
		if v == nil {
			return nil, fmt.Errorf("public input %d is nil", i)
		}
		var b [fr.Bytes]byte
		fieldElement(v).FillBytes(b[:])
		buf = append(buf, b[:]...)
	}
	buf = append(buf, proof...)
	return buf, nil
}

// DecodeWeightProof splits an encoded proof into the raw proof and the public
// statement.
func DecodeWeightProof(raw []byte) ([]byte, WeightStatement, error) {
	var st WeightStatement
	if len(raw) < weightProofHeader {
		return nil, st, fmt.Errorf("encoded weight proof too short: %d bytes", len(raw))
	}
	if !bytes.Equal(raw[:4], weightProofMagic[:]) {
		return nil, st, errors.New("encoded weight proof has wrong magic")
	}
	if raw[4] != weightProofVersion {
		return nil, st, fmt.Errorf("unsupported weight proof version %d", raw[4])
	}
	if arity := binary.BigEndian.Uint16(raw[5:7]); int(arity) != WeightGradientCount {
		return nil, st, fmt.Errorf("weight proof arity %d, expected %d", arity, WeightGradientCount)
	}
	off := 7
	vals := make([]*big.Int, 6)
	for i := range vals {
		vals[i] = new(big.Int).SetBytes(raw[off : off+fr.Bytes])
		off += fr.Bytes
	}
	st = WeightStatement{
		ModelHashBefore:   vals[0],
		ModelHashAfter:    vals[1],
		DatasetCommitment: vals[2],
		GradNormBound:     vals[3],
		DPEpsilon:         vals[4],
		UpdateHash:        vals[5],
	}
	return raw[off:], st, nil
}

// VerifyWeightProof verifies an encoded weight proof against its own embedded
// public statement.
func VerifyWeightProof(raw []byte) (bool, error) {
	proofBytes, st, err := DecodeWeightProof(raw)
	if err != nil {
		return false, err
	}
	return verifyWeightProofBytes(proofBytes, st)
}

// VerifyWeightProofAgainst verifies an encoded weight proof AND requires the
// embedded public statement to equal want in all six fields. This is the check
// an aggregator should use: it ties the proof to the statement the caller
// actually claimed, rather than to whatever statement the proof happens to
// carry.
func VerifyWeightProofAgainst(raw []byte, want WeightStatement) (bool, error) {
	proofBytes, st, err := DecodeWeightProof(raw)
	if err != nil {
		return false, err
	}
	if !st.equal(want) {
		// Well-formed proof, but not a proof of the claimed statement. This is a
		// rejection, not a verification error (compare VerifyDataCommitmentProof,
		// which also returns (false, nil) when groth16.Verify fails).
		return false, nil
	}
	return verifyWeightProofBytes(proofBytes, st)
}

func (st WeightStatement) equal(other WeightStatement) bool {
	fields := []*big.Int{st.ModelHashBefore, st.ModelHashAfter, st.DatasetCommitment, st.GradNormBound, st.DPEpsilon, st.UpdateHash}
	others := []*big.Int{other.ModelHashBefore, other.ModelHashAfter, other.DatasetCommitment, other.GradNormBound, other.DPEpsilon, other.UpdateHash}
	for i := range fields {
		if fieldElement(fields[i]).Cmp(fieldElement(others[i])) != 0 {
			return false
		}
	}
	return true
}

func verifyWeightProofBytes(proofBytes []byte, st WeightStatement) (bool, error) {
	if err := ensureWeightSetup(); err != nil {
		return false, err
	}

	proof := groth16.NewProof(ecc.BN254)
	if _, err := proof.ReadFrom(bytes.NewReader(proofBytes)); err != nil {
		return false, fmt.Errorf("deserialize proof: %w", err)
	}

	publicAssignment := WeightUpdateCircuit{
		ModelHashBefore:   st.ModelHashBefore,
		ModelHashAfter:    st.ModelHashAfter,
		DatasetCommitment: st.DatasetCommitment,
		GradNormBound:     st.GradNormBound,
		DPEpsilon:         st.DPEpsilon,
		UpdateHash:        st.UpdateHash,
	}
	publicWitness, err := frontend.NewWitness(&publicAssignment, ecc.BN254.ScalarField(), frontend.PublicOnly())
	if err != nil {
		return false, fmt.Errorf("build public witness: %w", err)
	}
	if err := groth16.Verify(proof, weightVK, publicWitness); err != nil {
		return false, nil
	}
	return true, nil
}
