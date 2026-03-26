package token

import (
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"
	"strings"
)

type MigrationSignatureBundle struct {
	LegacyAlgorithm string
	LegacyPublicKey string
	LegacySignature string
	PQCAlgorithm    string
	PQCPublicKey    string
	PQCSignature    string
}

func (b MigrationSignatureBundle) Enabled() bool {
	return strings.TrimSpace(b.LegacySignature) != "" || strings.TrimSpace(b.PQCSignature) != ""
}

func (b MigrationSignatureBundle) Complete() bool {
	return strings.TrimSpace(b.LegacyAlgorithm) != "" &&
		strings.TrimSpace(b.LegacyPublicKey) != "" &&
		strings.TrimSpace(b.LegacySignature) != "" &&
		strings.TrimSpace(b.PQCAlgorithm) != "" &&
		strings.TrimSpace(b.PQCPublicKey) != "" &&
		strings.TrimSpace(b.PQCSignature) != ""
}

// MigrationSigningDigest returns the canonical digest signed by both legacy and PQC keys.
func MigrationSigningDigest(symbol string, legacyAccount string, pqcAccount string, amountUnits int64, memo string, idempotencyKey string, nonce uint64) ([]byte, error) {
	payload := struct {
		SchemaVersion int    `json:"schema_version"`
		Symbol        string `json:"symbol"`
		LegacyAccount string `json:"legacy_account"`
		PQCAccount    string `json:"pqc_account"`
		AmountUnits   int64  `json:"amount_units"`
		Memo          string `json:"memo,omitempty"`
		Idempotency   string `json:"idempotency_key,omitempty"`
		Nonce         uint64 `json:"nonce,omitempty"`
	}{
		SchemaVersion: 1,
		Symbol:        strings.ToUpper(strings.TrimSpace(symbol)),
		LegacyAccount: strings.TrimSpace(legacyAccount),
		PQCAccount:    strings.TrimSpace(pqcAccount),
		AmountUnits:   amountUnits,
		Memo:          memo,
		Idempotency:   strings.TrimSpace(idempotencyKey),
		Nonce:         nonce,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal migration payload: %w", err)
	}
	digest := sha256.Sum256(encoded)
	return digest[:], nil
}

func verifyMigrationSignatureBundle(digest []byte, bundle MigrationSignatureBundle) error {
	if !bundle.Enabled() {
		return nil
	}
	if !bundle.Complete() {
		return fmt.Errorf("cryptographic migration signatures are incomplete")
	}
	if err := verifyLegacyECDSA(digest, bundle.LegacyAlgorithm, bundle.LegacyPublicKey, bundle.LegacySignature); err != nil {
		return err
	}
	if err := verifyPQCSignatureCompat(digest, bundle.PQCAlgorithm, bundle.PQCPublicKey, bundle.PQCSignature); err != nil {
		return err
	}
	return nil
}

func verifyLegacyECDSA(digest []byte, algorithm string, publicKey string, signature string) error {
	algo := strings.ToLower(strings.TrimSpace(algorithm))
	if algo == "" {
		algo = "ecdsa-p256-sha256"
	}
	if algo != "ecdsa-p256-sha256" && algo != "ecdsa" {
		return fmt.Errorf("unsupported legacy signature algorithm %q", algorithm)
	}
	pubRaw, err := decodeMaterial(publicKey)
	if err != nil {
		return fmt.Errorf("decode legacy public key: %w", err)
	}
	pub, err := parseECDSAP256PublicKey(pubRaw)
	if err != nil {
		return fmt.Errorf("parse legacy public key: %w", err)
	}
	sigRaw, err := decodeMaterial(signature)
	if err != nil {
		return fmt.Errorf("decode legacy signature: %w", err)
	}
	if verifyECDSASignature(pub, digest, sigRaw) {
		return nil
	}
	return fmt.Errorf("legacy signature verification failed")
}

func verifyPQCSignatureCompat(digest []byte, algorithm string, publicKey string, signature string) error {
	algo := strings.ToLower(strings.TrimSpace(algorithm))
	if algo == "" {
		algo = "ml-dsa-65"
	}
	supported := algo == "ml-dsa" || algo == "mldsa" || algo == "ml-dsa-44" || algo == "ml-dsa-65" || algo == "ml-dsa-87" || algo == "mldsa-ed25519-compat" || algo == "ed25519"
	if !supported {
		return fmt.Errorf("unsupported pqc signature algorithm %q", algorithm)
	}
	pubRaw, err := decodeMaterial(publicKey)
	if err != nil {
		return fmt.Errorf("decode pqc public key: %w", err)
	}
	pub, err := parseEd25519PublicKey(pubRaw)
	if err != nil {
		return fmt.Errorf("parse pqc public key: %w", err)
	}
	sigRaw, err := decodeMaterial(signature)
	if err != nil {
		return fmt.Errorf("decode pqc signature: %w", err)
	}
	if len(sigRaw) != ed25519.SignatureSize {
		return fmt.Errorf("pqc signature length %d != %d", len(sigRaw), ed25519.SignatureSize)
	}
	if !ed25519.Verify(pub, digest, sigRaw) {
		return fmt.Errorf("pqc signature verification failed")
	}
	return nil
}

func decodeMaterial(raw string) ([]byte, error) {
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
	if decoded, err := hex.DecodeString(strings.TrimPrefix(trimmed, "0x")); err == nil {
		return decoded, nil
	}
	return nil, fmt.Errorf("value is neither PEM, base64, nor hex")
}

func parseECDSAP256PublicKey(raw []byte) (*ecdsa.PublicKey, error) {
	if pubAny, err := x509.ParsePKIXPublicKey(raw); err == nil {
		if pub, ok := pubAny.(*ecdsa.PublicKey); ok {
			if pub.Curve != elliptic.P256() {
				return nil, fmt.Errorf("expected P-256 ECDSA public key")
			}
			return pub, nil
		}
	}
	if len(raw) != 65 || raw[0] != 0x04 {
		return nil, fmt.Errorf("invalid uncompressed P-256 public key")
	}
	if _, err := ecdh.P256().NewPublicKey(raw); err != nil {
		return nil, fmt.Errorf("invalid uncompressed P-256 public key")
	}
	x := new(big.Int).SetBytes(raw[1:33])
	y := new(big.Int).SetBytes(raw[33:65])
	return &ecdsa.PublicKey{Curve: elliptic.P256(), X: x, Y: y}, nil
}

func parseEd25519PublicKey(raw []byte) (ed25519.PublicKey, error) {
	if len(raw) == ed25519.PublicKeySize {
		return ed25519.PublicKey(raw), nil
	}
	if pubAny, err := x509.ParsePKIXPublicKey(raw); err == nil {
		if pub, ok := pubAny.(ed25519.PublicKey); ok {
			return pub, nil
		}
	}
	return nil, fmt.Errorf("invalid ed25519 public key")
}

func verifyECDSASignature(pub *ecdsa.PublicKey, digest []byte, sig []byte) bool {
	if ecdsa.VerifyASN1(pub, digest, sig) {
		return true
	}
	if len(sig) != 64 {
		return false
	}
	r := new(big.Int).SetBytes(sig[:32])
	s := new(big.Int).SetBytes(sig[32:])
	return ecdsa.Verify(pub, digest, r, s)
}
