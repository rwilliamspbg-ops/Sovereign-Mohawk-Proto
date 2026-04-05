package wasmhost

import (
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/subtle"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"strings"
)

// VerifyHotReloadIntegrity enforces integrity and provenance checks for inline
// WASM hot-reload payloads prior to module load.
func VerifyHotReloadIntegrity(wasmBin []byte, requiredHashHex string, signature string, publicKey string) error {
	if len(wasmBin) == 0 {
		return fmt.Errorf("empty wasm module")
	}

	requiredHashHex = strings.TrimSpace(requiredHashHex)
	signature = strings.TrimSpace(signature)
	publicKey = strings.TrimSpace(publicKey)
	if requiredHashHex == "" {
		return fmt.Errorf("module_sha256 is required for hot-reload")
	}
	if signature == "" {
		return fmt.Errorf("module_signature is required for hot-reload")
	}
	if publicKey == "" {
		return fmt.Errorf("module_public_key is required for hot-reload")
	}

	sum := sha256.Sum256(wasmBin)
	actual := hex.EncodeToString(sum[:])
	want := strings.TrimPrefix(strings.ToLower(requiredHashHex), "0x")
	if len(want) != sha256.Size*2 {
		return fmt.Errorf("module_sha256 length must be %d hex chars", sha256.Size*2)
	}
	if subtle.ConstantTimeCompare([]byte(actual), []byte(want)) != 1 {
		return fmt.Errorf("module_sha256 mismatch")
	}

	sigRaw, err := decodeBinaryMaterial(signature)
	if err != nil {
		return fmt.Errorf("decode module_signature: %w", err)
	}
	if len(sigRaw) != ed25519.SignatureSize {
		return fmt.Errorf("module_signature length %d != %d", len(sigRaw), ed25519.SignatureSize)
	}

	pub, err := parseEd25519PublicKey(publicKey)
	if err != nil {
		return fmt.Errorf("parse module_public_key: %w", err)
	}
	if !ed25519.Verify(pub, sum[:], sigRaw) {
		return fmt.Errorf("module signature verification failed")
	}

	return nil
}

func decodeBinaryMaterial(raw string) ([]byte, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return nil, fmt.Errorf("empty value")
	}
	if strings.Contains(trimmed, "-----BEGIN") {
		block, _ := pem.Decode([]byte(trimmed))
		if block == nil {
			return nil, fmt.Errorf("invalid pem block")
		}
		return block.Bytes, nil
	}
	if decoded, err := base64.StdEncoding.DecodeString(trimmed); err == nil {
		return decoded, nil
	}
	if decoded, err := base64.RawStdEncoding.DecodeString(trimmed); err == nil {
		return decoded, nil
	}
	decoded, err := hex.DecodeString(strings.TrimPrefix(strings.ToLower(trimmed), "0x"))
	if err == nil {
		return decoded, nil
	}
	return nil, fmt.Errorf("value is neither PEM, base64, nor hex")
}

func parseEd25519PublicKey(raw string) (ed25519.PublicKey, error) {
	pubRaw, err := decodeBinaryMaterial(raw)
	if err != nil {
		return nil, err
	}
	if len(pubRaw) == ed25519.PublicKeySize {
		return ed25519.PublicKey(pubRaw), nil
	}
	pubAny, err := x509.ParsePKIXPublicKey(pubRaw)
	if err != nil {
		return nil, fmt.Errorf("invalid ed25519 public key")
	}
	pub, ok := pubAny.(ed25519.PublicKey)
	if !ok {
		return nil, fmt.Errorf("invalid ed25519 public key")
	}
	return pub, nil
}
