// Command zkweightbench measures the WeightUpdateCircuit prover/verifier and
// writes a machine-checkable artifact under results/zk/, failing if a documented
// budget is exceeded.
//
// It exists because the SDK's published "10.55 ms" zk verification figure was
// produced by a time.sleep in sdk/python/tests/test_benchmarks.py, not by a
// measurement. This program is the measurement.
//
// Usage:
//
//	go run ./cmd/zkweightbench -out results/zk
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"time"

	internal "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

type measurement struct {
	Iterations int     `json:"iterations"`
	TotalMs    float64 `json:"total_ms"`
	MeanMs     float64 `json:"mean_ms"`
}

type budgets struct {
	VerifyMeanMs float64 `json:"verify_mean_ms"`
	ProveMeanMs  float64 `json:"prove_mean_ms"`
	SetupMs      float64 `json:"setup_ms"`
}

type artifact struct {
	GeneratedAt  string      `json:"generated_at"`
	GitSHA       string      `json:"git_sha,omitempty"`
	Arity        int         `json:"arity"`
	Constraints  int         `json:"constraints"`
	Prove        measurement `json:"prove"`
	Verify       measurement `json:"verify"`
	Setup        measurement `json:"setup"`
	ProofBytes   int         `json:"proof_bytes"`
	EncodedBytes int         `json:"encoded_bytes"`
	Budgets      budgets     `json:"budgets"`
	Violations   []string    `json:"violations"`
}

const (
	proveIterations  = 20
	verifyIterations = 200
)

func fixed(t float64) *big.Int {
	v, err := internal.EncodeFixedPoint(t)
	if err != nil {
		panic(err)
	}
	return v
}

func fixture() (internal.WeightPublicInputs, internal.WeightWitness) {
	gradients := []float64{0.5, -0.25, 1.0, -1.5, 2.0, -0.75, 0.125, -0.5}
	noise := []float64{0.01, -0.02, 0.03, -0.04, 0.05, -0.06, 0.07, -0.08}

	in := internal.WeightPublicInputs{
		ModelHashBefore:   big.NewInt(0x1234567),
		DatasetCommitment: big.NewInt(0xdeadbeef),
		GradNormBound:     fixed(3.0),
		DPEpsilon:         fixed(3),
	}
	var w internal.WeightWitness
	for i, g := range gradients {
		w.Gradients[i] = fixed(g)
	}
	for i, n := range noise {
		w.Noise[i] = fixed(n)
	}
	w.TrainingSteps = 7
	return in, w
}

func measure(iterations int, fn func() error) (measurement, error) {
	start := time.Now()
	for i := 0; i < iterations; i++ {
		if err := fn(); err != nil {
			return measurement{}, err
		}
	}
	total := time.Since(start)
	return measurement{
		Iterations: iterations,
		TotalMs:    float64(total.Microseconds()) / 1000.0,
		MeanMs:     float64(total.Microseconds()) / 1000.0 / float64(iterations),
	}, nil
}

func main() {
	outDir := flag.String("out", "results/zk", "directory for the JSON artifact")
	flag.Parse()

	in, w := fixture()

	// One-time compile + simulated MPC trusted setup.
	setup, err := measure(1, func() error {
		_, err := internal.WeightCircuitConstraintCount()
		return err
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "setup failed: %v\n", err)
		os.Exit(1)
	}
	constraints := 0
	if n, err := internal.WeightCircuitConstraintCount(); err == nil {
		constraints = n
	}

	prove, err := measure(proveIterations, func() error {
		_, _, err := internal.ProveWeightUpdate(in, w)
		return err
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "prove failed: %v\n", err)
		os.Exit(1)
	}

	encoded, _, err := internal.ProveWeightUpdate(in, w)
	if err != nil {
		fmt.Fprintf(os.Stderr, "prove failed: %v\n", err)
		os.Exit(1)
	}
	raw, _, err := internal.DecodeWeightProof(encoded)
	if err != nil {
		fmt.Fprintf(os.Stderr, "decode failed: %v\n", err)
		os.Exit(1)
	}

	verify, err := measure(verifyIterations, func() error {
		ok, err := internal.VerifyWeightProof(encoded)
		if err != nil {
			return err
		}
		if !ok {
			return fmt.Errorf("proof did not verify")
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "verify failed: %v\n", err)
		os.Exit(1)
	}

	b := budgets{VerifyMeanMs: 15, ProveMeanMs: 30000, SetupMs: 120000}
	a := artifact{
		GeneratedAt:  time.Now().UTC().Format(time.RFC3339),
		GitSHA:       os.Getenv("GITHUB_SHA"),
		Arity:        internal.WeightGradientCount,
		Constraints:  constraints,
		Prove:        prove,
		Verify:       verify,
		Setup:        setup,
		ProofBytes:   len(raw),
		EncodedBytes: len(encoded),
		Budgets:      b,
		Violations:   []string{},
	}

	if verify.MeanMs > b.VerifyMeanMs {
		a.Violations = append(a.Violations, fmt.Sprintf("verify mean %.3f ms exceeds budget %.3f ms", verify.MeanMs, b.VerifyMeanMs))
	}
	if prove.MeanMs > b.ProveMeanMs {
		a.Violations = append(a.Violations, fmt.Sprintf("prove mean %.3f ms exceeds budget %.3f ms", prove.MeanMs, b.ProveMeanMs))
	}
	if setup.MeanMs > b.SetupMs {
		a.Violations = append(a.Violations, fmt.Sprintf("setup %.3f ms exceeds budget %.3f ms", setup.MeanMs, b.SetupMs))
	}

	if err := os.MkdirAll(*outDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir: %v\n", err)
		os.Exit(1)
	}
	stamp := time.Now().UTC().Format("2006-01-02T15-04-05Z")
	for _, name := range []string{
		filepath.Join(*outDir, "weight-proof-latest.json"),
		filepath.Join(*outDir, fmt.Sprintf("weight-proof-%s.json", stamp)),
	} {
		data, err := json.MarshalIndent(a, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "marshal: %v\n", err)
			os.Exit(1)
		}
		if err := os.WriteFile(name, data, 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "write %s: %v\n", name, err)
			os.Exit(1)
		}
	}

	fmt.Printf("arity=%d constraints=%d proof=%dB encoded=%dB\n", a.Arity, a.Constraints, a.ProofBytes, a.EncodedBytes)
	fmt.Printf("setup=%.1fms prove=%.2fms/op verify=%.3fms/op\n", a.Setup.MeanMs, a.Prove.MeanMs, a.Verify.MeanMs)

	if len(a.Violations) > 0 {
		for _, v := range a.Violations {
			fmt.Fprintf(os.Stderr, "BUDGET VIOLATION: %s\n", v)
		}
		os.Exit(1)
	}
}
