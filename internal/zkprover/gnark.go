package zkprover

import (
	"context"
	"fmt"
	"math/big"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// GnarkProver is a real Groth16 prover backed by gnark/BN254.
//
// It proves WeightUpdateCircuit (internal/zkweight_circuit.go): the proof is
// bound to the whole public statement — model hash before/after, dataset
// commitment, gradient norm bound, DP epsilon and update hash — and to the
// private gradient/noise vectors, which are fed to the circuit as individual
// Q32.32 fixed-point witness elements. It does NOT use the legacy XOR fold
// that earlier revisions used to squash the gradient vector into one scalar;
// that fold was linear and therefore not collision-resistant.
type GnarkProver struct{}

func (GnarkProver) Name() string { return "gnark-groth16" }

func (GnarkProver) Available(_ context.Context) bool { return true }

// weightStatementFromPublic converts the SDK-facing public inputs into the
// circuit's field-element statement. Every field is required: a missing
// model/dataset/update commitment would otherwise verify against zero.
func weightStatementFromPublic(pub PublicInputs) (internal.WeightStatement, error) {
	var st internal.WeightStatement
	var err error

	if st.ModelHashBefore, err = requiredHex(pub.ModelHashBefore, "model_hash_before"); err != nil {
		return st, err
	}
	if st.ModelHashAfter, err = requiredHex(pub.ModelHashAfter, "model_hash_after"); err != nil {
		return st, err
	}
	if st.DatasetCommitment, err = requiredHex(pub.DatasetCommitment, "dataset_commitment"); err != nil {
		return st, err
	}
	if st.UpdateHash, err = requiredHex(pub.UpdateHash, "update_hash"); err != nil {
		return st, err
	}
	if st.GradNormBound, err = internal.EncodeFixedPoint(pub.GradNormBound); err != nil {
		return st, fmt.Errorf("grad_norm_bound: %w", err)
	}
	if st.DPEpsilon, err = internal.EncodeFixedPoint(pub.DPEpsilon); err != nil {
		return st, fmt.Errorf("dp_epsilon: %w", err)
	}
	return st, nil
}

func requiredHex(raw, field string) (*big.Int, error) {
	v, err := internal.ParseCommitmentHex(raw)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", field, err)
	}
	if v == nil {
		return nil, fmt.Errorf("%s is required", field)
	}
	return v, nil
}

func (GnarkProver) Prove(_ context.Context, pub PublicInputs, priv PrivateInputs) (Proof, error) {
	if len(priv.Gradients) != internal.WeightGradientCount {
		return Proof{}, fmt.Errorf("zkprover: got %d gradients, need exactly %d", len(priv.Gradients), internal.WeightGradientCount)
	}
	if len(priv.Noise) != internal.WeightGradientCount {
		return Proof{}, fmt.Errorf("zkprover: got %d noise terms, need exactly %d", len(priv.Noise), internal.WeightGradientCount)
	}

	st, err := weightStatementFromPublic(pub)
	if err != nil {
		return Proof{}, err
	}

	in := internal.WeightPublicInputs{
		ModelHashBefore:   st.ModelHashBefore,
		DatasetCommitment: st.DatasetCommitment,
		GradNormBound:     st.GradNormBound,
		DPEpsilon:         st.DPEpsilon,
	}

	var w internal.WeightWitness
	for i, g := range priv.Gradients {
		gf, err := internal.EncodeFixedPoint(g)
		if err != nil {
			return Proof{}, fmt.Errorf("zkprover: gradient %d: %w", i, err)
		}
		w.Gradients[i] = gf
	}
	for i, n := range priv.Noise {
		nf, err := internal.EncodeFixedPoint(n)
		if err != nil {
			return Proof{}, fmt.Errorf("zkprover: noise %d: %w", i, err)
		}
		w.Noise[i] = nf
	}
	w.TrainingSteps = priv.TrainingSteps

	encoded, _, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		return Proof{}, fmt.Errorf("zkprover: prove failed: %w", err)
	}

	return Proof{Bytes: encoded, Backend: "gnark-groth16"}, nil
}

// Verify checks the proof against the public statement supplied by the caller,
// not merely against the statement embedded in the proof.
func (GnarkProver) Verify(_ context.Context, pub PublicInputs, proof Proof) (bool, error) {
	if proof.Backend != "gnark-groth16" {
		return false, fmt.Errorf("zkprover: backend mismatch")
	}
	want, err := weightStatementFromPublic(pub)
	if err != nil {
		return false, err
	}
	return internal.VerifyWeightProofAgainst(proof.Bytes, want)
}
