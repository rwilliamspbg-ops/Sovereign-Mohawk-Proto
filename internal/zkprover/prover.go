// Package zkprover defines the client-side ZK proof generation interface for
// per-update weight proofs (Pillar 1, P1.2). It is backend-agnostic: a
// concrete prover (Noir, Halo2, ...) is invoked via a Prover interface, so
// the node-agent does not depend on a specific compiler.
package zkprover

import (
	"context"
	"fmt"
)

// PublicInputs are the public statement of the weight proof.
type PublicInputs struct {
	ModelHashBefore   string
	ModelHashAfter    string
	DatasetCommitment string
	GradNormBound     float64
	DPEpsilon         float64
	Delta             float64
	UpdateHash        string
}

// PrivateInputs are the witness (never leave the client).
type PrivateInputs struct {
	Gradients     []float64
	Noise         []float64
	TrainingSteps uint32
}

// Proof is the generated SNARK.
type Proof struct {
	Bytes   []byte
	Backend string
}

// Prover generates proofs. Implementations may shell out to a compiler binary.
type Prover interface {
	// Name returns the backend identifier (e.g. "noir", "halo2", "mock").
	Name() string
	// Available reports whether the backend is usable on this host.
	Available(ctx context.Context) bool
	// Prove generates a proof for the given statement + witness.
	Prove(ctx context.Context, pub PublicInputs, priv PrivateInputs) (Proof, error)
	// Verify checks a proof (used by aggregators; may delegate to on-chain/off-chain verifier).
	Verify(ctx context.Context, pub PublicInputs, proof Proof) (bool, error)
}

// ErrUnavailable is returned when no backend is present.
var ErrUnavailable = fmt.Errorf("zkprover: no backend available")

// SelectProver picks the first available prover from the list, or returns
// ErrUnavailable if none.
func SelectProver(ctx context.Context, provers []Prover) (Prover, error) {
	for _, p := range provers {
		if p != nil && p.Available(ctx) {
			return p, nil
		}
	}
	return nil, ErrUnavailable
}
