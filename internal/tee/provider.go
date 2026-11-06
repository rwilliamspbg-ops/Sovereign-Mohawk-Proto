// Package tee provides a hardware-agnostic abstraction over Trusted Execution
// Environments (TEEs) such as Intel SGX, AMD SEV-SNP and ARM TrustZone.
//
// Design goals:
//   - A single TEEProvider interface so the aggregation kernel can run unchanged
//     inside any supported enclave.
//   - Simulation mode for CI (no hardware) that mirrors the real API surface.
//   - Fail-closed attestation: an enclave that cannot prove its measurement is
//     treated as untrusted.
//
// Scope (P4.1): abstraction + simulation. Real hardware backends are follow-ups.
package tee

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
)

// Platform identifies a TEE backend.
type Platform string

const (
	PlatformSGX       Platform = "sgx"
	PlatformSEVSNP    Platform = "sev-snp"
	PlatformTrustZone Platform = "trustzone"
	PlatformSimulated Platform = "simulated"
)

// AllPlatforms is the canonical list used by discovery and tests.
var AllPlatforms = []Platform{PlatformSGX, PlatformSEVSNP, PlatformTrustZone, PlatformSimulated}

// IsValid reports whether p is a known platform.
func (p Platform) IsValid() bool {
	for _, v := range AllPlatforms {
		if v == p {
			return true
		}
	}
	return false
}

// Measurement is the cryptographic identity of an enclave (MRENCLAVE / launch
// digest / PCR set). It must be compared against a trusted allow-list.
type Measurement struct {
	Platform Platform
	Digest   string // hex-encoded
	Raw      []byte
}

// String renders a measurement for logs.
func (m Measurement) String() string {
	return fmt.Sprintf("%s:%s", m.Platform, m.Digest)
}

// AttestationResult is returned by RemoteAttest. Verified must be true before
// any data is sent into the enclave.
type AttestationResult struct {
	Verified    bool
	Measurement Measurement
	Report      []byte // raw attestation report (platform-specific)
	Error       string
}

// EnclaveHandle is an opaque handle to a running enclave instance.
type EnclaveHandle struct {
	ID          string
	Platform    Platform
	Measurement Measurement
}

// TEEProvider is the contract every backend must implement. All methods must
// be safe for concurrent use. Implementations must fail closed: on any error
// the caller must treat the enclave as untrusted.
type TEEProvider interface {
	// Platform returns the backend identifier.
	Platform() Platform

	// Available reports whether the hardware/runtime for this backend is present
	// on the host. In simulation mode this always returns true.
	Available(ctx context.Context) bool

	// CreateEnclave provisions a new enclave with the given binary (or, in
	// simulation mode, records the measurement). Returns a handle.
	CreateEnclave(ctx context.Context, binary []byte) (EnclaveHandle, error)

	// RemoteAttest produces and verifies an attestation report binding the
	// enclave measurement to a nonce. Verified must be true before use.
	RemoteAttest(ctx context.Context, h EnclaveHandle, nonce []byte) (AttestationResult, error)

	// Run executes fn inside the enclave, passing input and returning output.
	// In simulation mode fn runs in-process but the call still exercises the
	// measurement/attestation gate.
	Run(ctx context.Context, h EnclaveHandle, input []byte, fn func([]byte) ([]byte, error)) ([]byte, error)

	// Destroy releases enclave resources.
	Destroy(ctx context.Context, h EnclaveHandle) error
}

// ErrNotAvailable is returned when a backend's hardware is absent.
var ErrNotAvailable = errors.New("tee: backend not available on this host")

// ErrAttestationFailed is returned when attestation verification fails.
var ErrAttestationFailed = errors.New("tee: attestation verification failed")

// ErrMeasurementMismatch is returned when the enclave measurement differs from
// the trusted allow-list.
var ErrMeasurementMismatch = errors.New("tee: enclave measurement not in allow-list")

// TrustedMeasurements is an allow-list of enclave measurements accepted by
// the control plane. Empty means "accept none" (fail-closed).
type TrustedMeasurements struct {
	byPlatform map[Platform]map[string]struct{}
}

// NewTrustedMeasurements builds an allow-list from a map of platform -> digests.
func NewTrustedMeasurements(allowed map[Platform][]string) *TrustedMeasurements {
	tm := &TrustedMeasurements{byPlatform: make(map[Platform]map[string]struct{})}
	for p, digests := range allowed {
		set := make(map[string]struct{}, len(digests))
		for _, d := range digests {
			set[d] = struct{}{}
		}
		tm.byPlatform[p] = set
	}
	return tm
}

// Accepts reports whether m is in the allow-list.
func (tm *TrustedMeasurements) Accepts(m Measurement) bool {
	if tm == nil {
		return false
	}
	set, ok := tm.byPlatform[m.Platform]
	if !ok {
		return false
	}
	_, ok = set[m.Digest]
	return ok
}

// ComputeMeasurement derives a measurement digest from a binary blob. Used by
// simulation mode and by the build pipeline to populate allow-lists.
func ComputeMeasurement(p Platform, binary []byte) Measurement {
	sum := sha256.Sum256(binary)
	return Measurement{
		Platform: p,
		Digest:   hex.EncodeToString(sum[:]),
		Raw:      sum[:],
	}
}
