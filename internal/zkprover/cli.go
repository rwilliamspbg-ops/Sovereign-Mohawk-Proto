package zkprover

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
)

// CLIProver shells out to an external prover binary (e.g. nargo, a Halo2
// runner). The binary must accept a JSON request on stdin and emit a JSON
// proof on stdout. This keeps the Go code backend-agnostic.
type CLIProver struct {
	Binary string
	Args   []string
	Name_  string
}

func (c CLIProver) Name() string {
	if c.Name_ != "" {
		return c.Name_
	}
	return "cli"
}

func (c CLIProver) Available(ctx context.Context) bool {
	if c.Binary == "" {
		return false
	}
	_, err := exec.LookPath(c.Binary)
	return err == nil
}

func (c CLIProver) Prove(ctx context.Context, pub PublicInputs, priv PrivateInputs) (Proof, error) {
	req := map[string]any{"public": pub, "private": priv}
	in, _ := json.Marshal(req)
	cmd := exec.CommandContext(ctx, c.Binary, c.Args...)
	cmd.Stdin = bytes.NewReader(in)
	out, err := cmd.Output()
	if err != nil {
		return Proof{}, fmt.Errorf("zkprover: cli prove failed: %w", err)
	}
	var resp struct {
		Proof []byte `json:"proof"`
	}
	if err := json.Unmarshal(out, &resp); err != nil {
		return Proof{}, fmt.Errorf("zkprover: bad cli output: %w", err)
	}
	return Proof{Bytes: resp.Proof, Backend: c.Name()}, nil
}

func (c CLIProver) Verify(ctx context.Context, pub PublicInputs, proof Proof) (bool, error) {
	// Verification is typically done by the aggregator's verifier, not the
	// prover binary. Return false to force use of a real verifier.
	return false, fmt.Errorf("zkprover: cli verify not supported; use aggregator verifier")
}
