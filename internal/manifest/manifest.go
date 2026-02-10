// internal/manifest/manifest.go
package manifest

import (
	"crypto/ed25519"
	"crypto/x509"
	"encoding/json"
	"errors"
)

type Capability string

const (
	CapLog          Capability = "LOG"
	CapGetSensor    Capability = "GET_SENSOR"
	CapSubmitGrad   Capability = "SUBMIT_GRADIENTS"
	CapNoNetwork    Capability = "NO_NETWORK"
)

type Manifest struct {
	TaskID           string       `json:"task_id"`
	NodeID           string       `json:"node_id"`
	WasmModuleSHA256 string       `json:"wasm_module_sha256"`
	Capabilities     []Capability `json:"capabilities"`
	MaxMemPages      uint32       `json:"max_mem_pages"`
	MaxMillis        uint64       `json:"max_millis"`

	// DP / FL config hints
	MaxGradNorm float64 `json:"max_grad_norm"`
	Epsilon     float64 `json:"epsilon"`
	Delta       float64 `json:"delta"`

	Signature []byte `json:"signature"`
}

func VerifySignature(m *Manifest, orchestratorPub []byte) error {
	sig := m.Signature
	m.Signature = nil
	defer func() { m.Signature = sig }()

	data, err := json.Marshal(m)
	if err != nil {
		return err
	}
	pub, err := x509.ParsePKIXPublicKey(orchestratorPub)
	if err != nil {
		return err
	}
	pk, ok := pub.(ed25519.PublicKey)
	if !ok {
		return errors.New("not ed25519 key")
	}
	if !ed25519.Verify(pk, data, sig) {
		return errors.New("invalid manifest signature")
	}
	return nil
}
