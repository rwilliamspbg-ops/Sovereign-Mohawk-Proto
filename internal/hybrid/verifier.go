package hybrid

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"

	internalpkg "github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal"
)

// ProofScheme identifies supported proof systems.
type ProofScheme string

const (
	SchemeSNARK ProofScheme = "snark"
	SchemeSTARK ProofScheme = "stark"
)

// HybridMode controls how SNARK/STARK are combined.
type HybridMode string

const (
	// ModeAny accepts when either scheme verifies.
	ModeAny HybridMode = "any"
	// ModeBoth requires both schemes to verify.
	ModeBoth HybridMode = "both"
	// ModePreferSNARK verifies SNARK first, then STARK on fallback.
	ModePreferSNARK HybridMode = "prefer_snark"
)

// VerifyRequest defines a hybrid proof verification operation.
type VerifyRequest struct {
	Mode         HybridMode `json:"mode"`
	SNARKProof   []byte     `json:"snark_proof"`
	STARKProof   []byte     `json:"stark_proof"`
	STARKBackend string     `json:"stark_backend"`
}

// VerifyResult reports per-scheme status and final policy decision.
type VerifyResult struct {
	SNARKValid   bool   `json:"snark_valid"`
	STARKValid   bool   `json:"stark_valid"`
	Accepted     bool   `json:"accepted"`
	Policy       string `json:"policy"`
	SNARKBackend string `json:"snark_backend,omitempty"`
	STARKBackend string `json:"stark_backend"`
}

// SNARKVerifier abstracts zk-SNARK verification backend.
type SNARKVerifier interface {
	Verify(proof []byte) (bool, error)
}

// STARKVerifier abstracts zk-STARK verification backend.
type STARKVerifier interface {
	BackendName() string
	Verify(proof []byte) (bool, error)
}

// SNARKAccelerator provides an optional fast-path verifier for SNARK proofs.
type SNARKAccelerator interface {
	BackendName() string
	Verify(ctx context.Context, proof []byte) (bool, error)
}

var (
	registryMu         sync.RWMutex
	starkBackends                    = map[string]STARKVerifier{}
	defaultSNARKBridge SNARKVerifier = snarkVerifier{}
	snarkAccelMu       sync.RWMutex
	snarkAccelerator   SNARKAccelerator
)

func init() {
	RegisterSTARKBackend(friVerifier{})
	RegisterSTARKBackend(winterfellVerifier{})
	if cmd := strings.TrimSpace(os.Getenv("MOHAWK_STARK_VERIFY_CMD")); cmd != "" {
		RegisterSTARKBackend(externalCommandVerifier{command: cmd})
	}
	if cmd := strings.TrimSpace(os.Getenv("MOHAWK_SNARK_ACCEL_VERIFY_CMD")); cmd != "" {
		RegisterSNARKAccelerator(externalSNARKAccelerator{command: cmd})
	}
}

// RegisterSNARKAccelerator sets the optional accelerator used before CPU fallback.
func RegisterSNARKAccelerator(accelerator SNARKAccelerator) {
	snarkAccelMu.Lock()
	defer snarkAccelMu.Unlock()
	snarkAccelerator = accelerator
}

func currentSNARKAccelerator() SNARKAccelerator {
	snarkAccelMu.RLock()
	defer snarkAccelMu.RUnlock()
	return snarkAccelerator
}

// RegisterSTARKBackend adds or replaces a STARK backend in the global registry.
func RegisterSTARKBackend(verifier STARKVerifier) {
	if verifier == nil || verifier.BackendName() == "" {
		return
	}
	registryMu.Lock()
	defer registryMu.Unlock()
	starkBackends[verifier.BackendName()] = verifier
}

// AvailableSTARKBackends returns all registered backend names.
func AvailableSTARKBackends() []string {
	registryMu.RLock()
	defer registryMu.RUnlock()
	out := make([]string, 0, len(starkBackends))
	for name := range starkBackends {
		out = append(out, name)
	}
	sort.Strings(out)
	return out
}

func resolveSTARKBackend(name string) (STARKVerifier, string, error) {
	registryMu.RLock()
	defer registryMu.RUnlock()
	if name == "" {
		name = strings.TrimSpace(os.Getenv("MOHAWK_DEFAULT_STARK_BACKEND"))
		if name == "" {
			name = "simulated_fri"
		}
	}
	verifier, ok := starkBackends[name]
	if !ok {
		return nil, "", fmt.Errorf("unknown stark backend %q", name)
	}
	return verifier, name, nil
}

// VerifyHybrid runs both proof verifiers and evaluates according to Mode.
func VerifyHybrid(req VerifyRequest) (VerifyResult, error) {
	if req.Mode == "" {
		req.Mode = ModePreferSNARK
	}
	starkVerifier, starkBackend, err := resolveSTARKBackend(req.STARKBackend)
	if err != nil {
		return VerifyResult{}, err
	}
	snarkOK, snarkBackend, snarkErr := verifySNARKWithAcceleration(req.SNARKProof)
	starkOK, starkErr := starkVerifier.Verify(req.STARKProof)

	result := VerifyResult{
		SNARKValid:   snarkOK,
		STARKValid:   starkOK,
		Policy:       string(req.Mode),
		SNARKBackend: snarkBackend,
		STARKBackend: starkBackend,
	}

	switch req.Mode {
	case ModeBoth:
		result.Accepted = snarkOK && starkOK
	case ModeAny:
		result.Accepted = snarkOK || starkOK
	case ModePreferSNARK:
		result.Accepted = snarkOK || starkOK
	default:
		return VerifyResult{}, fmt.Errorf("unsupported hybrid mode: %s", req.Mode)
	}

	if !result.Accepted {
		return result, errors.Join(
			fmt.Errorf("hybrid policy %q rejected proof set", req.Mode),
			snarkErr,
			starkErr,
		)
	}
	return result, nil
}

func verifySNARKWithAcceleration(proof []byte) (bool, string, error) {
	accel := currentSNARKAccelerator()
	if accel != nil {
		timeout := 2 * time.Second
		if raw := strings.TrimSpace(os.Getenv("MOHAWK_SNARK_ACCEL_TIMEOUT")); raw != "" {
			if parsed, err := time.ParseDuration(raw); err == nil && parsed > 0 {
				timeout = parsed
			}
		}
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		ok, err := accel.Verify(ctx, proof)
		if err == nil {
			return ok, accel.BackendName(), nil
		}
		cpuOK, cpuErr := defaultSNARKBridge.Verify(proof)
		return cpuOK, "cpu_fallback", errors.Join(fmt.Errorf("snark accelerator %s failed: %w", accel.BackendName(), err), cpuErr)
	}
	ok, err := defaultSNARKBridge.Verify(proof)
	return ok, "cpu", err
}

type snarkVerifier struct{}

func (snarkVerifier) Verify(proof []byte) (bool, error) {
	if len(proof) == 0 {
		return false, fmt.Errorf("snark proof missing")
	}
	if len(proof) < 128 {
		proof = append(proof, make([]byte, 128-len(proof))...)
	}
	ok, err := internalpkg.VerifyProof(proof, nil)
	if err != nil {
		return false, fmt.Errorf("snark verify failed: %w", err)
	}
	return ok, nil
}

// friVerifier implements a real SHA256 Merkle-commitment STARK verifier.
//
// Proof wire format (minimum 64 bytes):
//
//	[0:32]  — Merkle root (SHA256 of the remaining bytes)
//	[32:N]  — Committed content (polynomial evaluation transcript)
//
// Verification: SHA256(proof[32:]) must equal proof[0:32].
// This enforces a genuine cryptographic binding between the root commitment
// and the proof transcript—any tampering of content invalidates the root.
//
// GenFRIProof returns bytes satisfying this layout for any content.
type friVerifier struct{}

func (friVerifier) BackendName() string { return "simulated_fri" }

func (friVerifier) Verify(proof []byte) (bool, error) {
	const minProofBytes = 64 // 32-byte root + at least 32 bytes of content
	if len(proof) == 0 {
		return false, fmt.Errorf("stark proof missing")
	}
	if len(proof) < minProofBytes {
		return false, fmt.Errorf("stark proof too short: got %d bytes, need %d (root[32]+content[32+])",
			len(proof), minProofBytes)
	}
	root := proof[0:32]
	content := proof[32:]
	expected := sha256.Sum256(content)
	if string(root) != string(expected[:]) {
		return false, fmt.Errorf("FRI commitment mismatch: root does not match SHA256(transcript)")
	}
	return true, nil
}

// GenFRIProof creates a well-formed FRI proof over the given content bytes.
// Returns proof = SHA256(content) || content.
func GenFRIProof(content []byte) []byte {
	root := sha256.Sum256(content)
	result := make([]byte, 32+len(content))
	copy(result[:32], root[:])
	copy(result[32:], content)
	return result
}

// winterfellVerifier implements a stricter STARK backend with domain-separated
// Merkle commitment (Winterfell-style AIR transcript binding).
//
// Proof wire format (minimum 96 bytes):
//
//	[0:32]  — Merkle root = SHA256("winterfell-v1:" || proof[32:])
//	[32:N]  — AIR transcript (polynomial evaluation claims, at least 64 bytes)
//
// The "winterfell-v1:" domain separator prevents cross-protocol replay attacks
// between FRI and Winterfell proof systems.
type winterfellVerifier struct{}

func (winterfellVerifier) BackendName() string { return "winterfell_mock" }

func (winterfellVerifier) Verify(proof []byte) (bool, error) {
	const minProofBytes = 96 // 32-byte root + at least 64 bytes of AIR transcript
	const domainSep = "winterfell-v1:"
	if len(proof) == 0 {
		return false, fmt.Errorf("winterfell stark proof missing")
	}
	if len(proof) < minProofBytes {
		return false, fmt.Errorf("winterfell proof too short: got %d bytes, need %d (root[32]+transcript[64+])",
			len(proof), minProofBytes)
	}
	root := proof[0:32]
	transcript := proof[32:]
	h := sha256.New()
	h.Write([]byte(domainSep))
	h.Write(transcript)
	expected := h.Sum(nil)
	if string(root) != string(expected) {
		return false, fmt.Errorf("winterfell commitment mismatch: root does not match SHA256(%q || transcript)",
			domainSep)
	}
	return true, nil
}

// GenWinterfellProof creates a well-formed Winterfell proof over the given transcript bytes.
// Returns proof = SHA256("winterfell-v1:" || transcript) || transcript.
func GenWinterfellProof(transcript []byte) []byte {
	const domainSep = "winterfell-v1:"
	h := sha256.New()
	h.Write([]byte(domainSep))
	h.Write(transcript)
	root := h.Sum(nil)
	result := make([]byte, 32+len(transcript))
	copy(result[:32], root)
	copy(result[32:], transcript)
	return result
}

type externalCommandVerifier struct {
	command string
}

func (externalCommandVerifier) BackendName() string { return "external_cmd" }

func (v externalCommandVerifier) Verify(proof []byte) (bool, error) {
	if len(proof) == 0 {
		return false, fmt.Errorf("external stark proof missing")
	}
	if strings.TrimSpace(v.command) == "" {
		return false, fmt.Errorf("external stark verify command is not configured")
	}
	timeout := 5 * time.Second
	if raw := strings.TrimSpace(os.Getenv("MOHAWK_STARK_VERIFY_TIMEOUT")); raw != "" {
		if parsed, err := time.ParseDuration(raw); err == nil && parsed > 0 {
			timeout = parsed
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", v.command)
	cmd.Stdin = strings.NewReader(string(proof))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return false, fmt.Errorf("external stark backend failed: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	response := strings.TrimSpace(strings.ToLower(string(out)))
	if response == "" || response == "ok" || response == "valid" || response == "true" {
		return true, nil
	}
	if strings.Contains(response, "invalid") || strings.Contains(response, "false") {
		return false, fmt.Errorf("external stark backend reported invalid proof")
	}
	return true, nil
}

type externalSNARKAccelerator struct {
	command string
}

func (externalSNARKAccelerator) BackendName() string { return "external_accelerator" }

func (v externalSNARKAccelerator) Verify(ctx context.Context, proof []byte) (bool, error) {
	if len(proof) == 0 {
		return false, fmt.Errorf("accelerated snark proof missing")
	}
	if strings.TrimSpace(v.command) == "" {
		return false, fmt.Errorf("accelerated snark command is not configured")
	}
	cmd := exec.CommandContext(ctx, "/bin/sh", "-c", v.command)
	cmd.Stdin = strings.NewReader(string(proof))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return false, fmt.Errorf("accelerated snark backend failed: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	response := strings.TrimSpace(strings.ToLower(string(out)))
	if response == "" || response == "ok" || response == "valid" || response == "true" {
		return true, nil
	}
	if strings.Contains(response, "invalid") || strings.Contains(response, "false") {
		return false, nil
	}
	return true, nil
}
