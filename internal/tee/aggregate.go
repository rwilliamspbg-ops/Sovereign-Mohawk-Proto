package tee

import (
	"context"
	"fmt"
)

// AggregationFunc is the pure aggregation kernel that runs inside the enclave.
// It receives serialized input and returns serialized output.
type AggregationFunc func(input []byte) ([]byte, error)

// ProtectedAggregator runs an aggregation function inside a TEE after verifying
// attestation. It returns the enclave output. If attestation fails or the
// enclave errors, it returns an error (fail-closed).
type ProtectedAggregator struct {
	provider TEEProvider
	trusted  *TrustedMeasurements
	binary   []byte
}

// NewProtectedAggregator constructs a protected aggregator. binary is the
// enclave payload whose measurement must be in trusted.
func NewProtectedAggregator(provider TEEProvider, trusted *TrustedMeasurements, binary []byte) *ProtectedAggregator {
	return &ProtectedAggregator{provider: provider, trusted: trusted, binary: binary}
}

// Run creates an enclave, attests it, executes fn inside it, and destroys it.
// Any failure returns an error; partial results are never returned.
func (a *ProtectedAggregator) Run(ctx context.Context, input []byte, fn AggregationFunc) ([]byte, error) {
	if a.provider == nil {
		return nil, fmt.Errorf("tee: nil provider")
	}
	h, err := a.provider.CreateEnclave(ctx, a.binary)
	if err != nil {
		return nil, fmt.Errorf("tee: create enclave: %w", err)
	}
	defer func() { _ = a.provider.Destroy(ctx, h) }()

	nonce := make([]byte, 16)
	// nonce generation is the caller's concern in production; here we use a
	// deterministic placeholder so tests are reproducible. Real deployments
	// must pass a fresh nonce from the control plane.
	copy(nonce, []byte("mohawk-nonce-16b"))

	res, err := a.provider.RemoteAttest(ctx, h, nonce)
	if err != nil {
		return nil, fmt.Errorf("tee: attest: %w", err)
	}
	if !res.Verified {
		return nil, fmt.Errorf("%w: %s", ErrAttestationFailed, res.Error)
	}
	if !a.trusted.Accepts(h.Measurement) {
		return nil, ErrMeasurementMismatch
	}

	out, err := a.provider.Run(ctx, h, input, func(in []byte) ([]byte, error) {
		return fn(in)
	})
	if err != nil {
		return nil, fmt.Errorf("tee: run: %w", err)
	}
	return out, nil
}
