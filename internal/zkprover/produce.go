package zkprover

import (
	"context"
	"fmt"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// ProduceWeightProof is the node-side production producer for per-update weight
// proofs (ZK finalization plan, milestone M2, Gap 1).
//
// It runs the supplied Prover on the round's public statement and private
// witness, then returns exactly the pair (encoded proof, WeightStatement) that
// batch.Aggregator consumes in ProcessRound (Aggregator.WeightProof /
// Aggregator.WeightStatement).
//
// Before this existed the only producers were cmd/simulate (which called
// internal.ProveWeightUpdate directly and then assigned the two fields by hand)
// and cmd/zkweightbench (a benchmark harness). No runtime path produced a
// framed, self-consistent proof, so the aggregator's WeightProof field could
// only be populated by a simulation command. This function is the missing
// producer; it is backend-agnostic (any Prover) and does not change what is
// proved -- WeightUpdateCircuit is unchanged.
//
// The returned WeightStatement is the one EMBEDDED in the produced proof
// (internal.DecodeWeightProof), not a caller-supplied one: WeightUpdateCircuit
// DERIVES ModelHashAfter and UpdateHash from the witness, so the embedded
// statement is the authoritative record of what was actually proved. Note that
// GnarkProver likewise ignores PublicInputs.ModelHashAfter / UpdateHash; callers
// that need the derived values should use the returned statement.
//
// Self-check: the framed proof must verify against the statement it carries
// before it is returned. This is what keeps a placeholder prover (MockProver)
// out of a production proof path -- its hash-based "proof" does not verify as a
// WeightUpdateCircuit proof, so ProduceWeightProof rejects it rather than
// handing the aggregator something ProcessRound would only reject later.
func ProduceWeightProof(ctx context.Context, p Prover, pub PublicInputs, priv PrivateInputs) ([]byte, internal.WeightStatement, error) {
	if p == nil {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: nil prover")
	}
	if !p.Available(ctx) {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: prover %q is not available", p.Name())
	}

	proof, err := p.Prove(ctx, pub, priv)
	if err != nil {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: prove: %w", err)
	}
	if len(proof.Bytes) == 0 {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: prover %q returned an empty proof", p.Name())
	}

	// Recover the statement the circuit actually committed to.
	_, st, err := internal.DecodeWeightProof(proof.Bytes)
	if err != nil {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: produced proof does not carry a weight statement: %w", err)
	}

	// Self-check: refuse to emit a proof that does not verify.
	if ok, err := internal.VerifyWeightProofAgainst(proof.Bytes, st); err != nil {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: produced proof failed verification: %w", err)
	} else if !ok {
		return nil, internal.WeightStatement{}, fmt.Errorf("zkprover: produced proof failed verification")
	}

	return proof.Bytes, st, nil
}
