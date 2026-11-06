package tee

import (
	"context"
	"crypto/rand"
	"fmt"
)

// SimulatedProvider is the CI-safe backend. It runs the enclave logic in
// process but exercises the full measurement/attestation gate so that code
// paths are identical to a real backend.
type SimulatedProvider struct {
	trusted *TrustedMeasurements
}

// NewSimulatedProvider builds a simulated provider. trusted may be nil (then
// every measurement is rejected — fail-closed).
func NewSimulatedProvider(trusted *TrustedMeasurements) *SimulatedProvider {
	return &SimulatedProvider{trusted: trusted}
}

func (s *SimulatedProvider) Platform() Platform { return PlatformSimulated }

func (s *SimulatedProvider) Available(_ context.Context) bool { return true }

func (s *SimulatedProvider) CreateEnclave(_ context.Context, binary []byte) (EnclaveHandle, error) {
	m := ComputeMeasurement(PlatformSimulated, binary)
	// Measurement is recorded; attestation gate (RemoteAttest) enforces trust.
	return EnclaveHandle{
		ID:          newHandleID(),
		Platform:    PlatformSimulated,
		Measurement: m,
	}, nil
}

func (s *SimulatedProvider) RemoteAttest(_ context.Context, h EnclaveHandle, nonce []byte) (AttestationResult, error) {
	if len(nonce) == 0 {
		return AttestationResult{Verified: false, Error: "empty nonce"}, nil
	}
	if !s.trusted.Accepts(h.Measurement) {
		return AttestationResult{
			Verified:    false,
			Measurement: h.Measurement,
			Error:       ErrMeasurementMismatch.Error(),
		}, nil
	}
	report := append([]byte("sim-report:"), nonce...)
	return AttestationResult{
		Verified:    true,
		Measurement: h.Measurement,
		Report:      report,
	}, nil
}

func (s *SimulatedProvider) Run(ctx context.Context, h EnclaveHandle, input []byte, fn func([]byte) ([]byte, error)) ([]byte, error) {
	// Re-attest is the caller's responsibility; Run trusts the handle. A real
	// backend would re-verify inside the enclave.
	if fn == nil {
		return nil, fmt.Errorf("tee: nil enclave function")
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}
	return fn(input)
}

func (s *SimulatedProvider) Destroy(_ context.Context, _ EnclaveHandle) error { return nil }

// Hardware stubs: real backends are not implemented yet. They report
// unavailable so callers fall back to simulation or fail closed.

type sgxProvider struct{ trusted *TrustedMeasurements }

func NewSGXProvider(trusted *TrustedMeasurements) TEEProvider { return &sgxProvider{trusted: trusted} }
func (p *sgxProvider) Platform() Platform                    { return PlatformSGX }
func (p *sgxProvider) Available(_ context.Context) bool      { return false } // TODO: probe /dev/sgx_enclave
func (p *sgxProvider) CreateEnclave(context.Context, []byte) (EnclaveHandle, error) {
	return EnclaveHandle{}, ErrNotAvailable
}
func (p *sgxProvider) RemoteAttest(context.Context, EnclaveHandle, []byte) (AttestationResult, error) {
	return AttestationResult{Verified: false, Error: ErrNotAvailable.Error()}, nil
}
func (p *sgxProvider) Run(context.Context, EnclaveHandle, []byte, func([]byte) ([]byte, error)) ([]byte, error) {
	return nil, ErrNotAvailable
}
func (p *sgxProvider) Destroy(context.Context, EnclaveHandle) error { return ErrNotAvailable }

type sevProvider struct{ trusted *TrustedMeasurements }

func NewSEVProvider(trusted *TrustedMeasurements) TEEProvider { return &sevProvider{trusted: trusted} }
func (p *sevProvider) Platform() Platform                    { return PlatformSEVSNP }
func (p *sevProvider) Available(_ context.Context) bool      { return false } // TODO: probe /dev/sev
func (p *sevProvider) CreateEnclave(context.Context, []byte) (EnclaveHandle, error) {
	return EnclaveHandle{}, ErrNotAvailable
}
func (p *sevProvider) RemoteAttest(context.Context, EnclaveHandle, []byte) (AttestationResult, error) {
	return AttestationResult{Verified: false, Error: ErrNotAvailable.Error()}, nil
}
func (p *sevProvider) Run(context.Context, EnclaveHandle, []byte, func([]byte) ([]byte, error)) ([]byte, error) {
	return nil, ErrNotAvailable
}
func (p *sevProvider) Destroy(context.Context, EnclaveHandle) error { return ErrNotAvailable }

type trustZoneProvider struct{ trusted *TrustedMeasurements }

func NewTrustZoneProvider(trusted *TrustedMeasurements) TEEProvider {
	return &trustZoneProvider{trusted: trusted}
}
func (p *trustZoneProvider) Platform() Platform                    { return PlatformTrustZone }
func (p *trustZoneProvider) Available(_ context.Context) bool      { return false } // TODO: OP-TEE probe
func (p *trustZoneProvider) CreateEnclave(context.Context, []byte) (EnclaveHandle, error) {
	return EnclaveHandle{}, ErrNotAvailable
}
func (p *trustZoneProvider) RemoteAttest(context.Context, EnclaveHandle, []byte) (AttestationResult, error) {
	return AttestationResult{Verified: false, Error: ErrNotAvailable.Error()}, nil
}
func (p *trustZoneProvider) Run(context.Context, EnclaveHandle, []byte, func([]byte) ([]byte, error)) ([]byte, error) {
	return nil, ErrNotAvailable
}
func (p *trustZoneProvider) Destroy(context.Context, EnclaveHandle) error { return ErrNotAvailable }

func newHandleID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return fmt.Sprintf("enclave-%x", b)
}
