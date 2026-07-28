package token

import (
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"strings"
	"testing"
)

// buildValidBundle produces a MigrationSignatureBundle with real ECDSA
// P-256 (legacy) and Ed25519 (pqc) signatures over the given digest.
func buildValidBundle(t *testing.T, digest []byte) MigrationSignatureBundle {
	t.Helper()
	legacyPriv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("legacy keygen: %v", err)
	}
	pqcPub, pqcPriv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("pqc keygen: %v", err)
	}
	legacySig, err := ecdsa.SignASN1(rand.Reader, legacyPriv, digest)
	if err != nil {
		t.Fatalf("legacy sign: %v", err)
	}
	pqcSig := ed25519.Sign(pqcPriv, digest)
	legacyPubBytes, err := x509.MarshalPKIXPublicKey(&legacyPriv.PublicKey)
	if err != nil {
		t.Fatalf("marshal legacy pub key: %v", err)
	}
	return MigrationSignatureBundle{
		LegacyAlgorithm: "ecdsa-p256-sha256",
		LegacyPublicKey: base64.StdEncoding.EncodeToString(legacyPubBytes),
		LegacySignature: base64.StdEncoding.EncodeToString(legacySig),
		PQCAlgorithm:    "ml-dsa-65",
		PQCPublicKey:    base64.StdEncoding.EncodeToString(pqcPub),
		PQCSignature:    base64.StdEncoding.EncodeToString(pqcSig),
	}
}

// --- MigrationSigningDigest --------------------------------------------------

func TestMigrationSigningDigestDeterministicAndFixedLength(t *testing.T) {
	d1, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	d2, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	if len(d1) != 32 {
		t.Fatalf("expected 32-byte sha256 digest, got %d", len(d1))
	}
	if string(d1) != string(d2) {
		t.Fatal("expected identical inputs to produce identical digests")
	}
}

func TestMigrationSigningDigestSymbolCaseInsensitive(t *testing.T) {
	lower, err := MigrationSigningDigest("mhc", "legacy", "pqc", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	upper, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	if string(lower) != string(upper) {
		t.Fatal("expected symbol casing to be normalized before digesting")
	}
}

func TestMigrationSigningDigestSensitiveToEachField(t *testing.T) {
	base, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("base digest: %v", err)
	}
	variants := map[string][]byte{}
	mustDigest := func(name, symbol, legacy, pqc string, amount int64, memo, idem string, nonce uint64) {
		d, err := MigrationSigningDigest(symbol, legacy, pqc, amount, memo, idem, nonce)
		if err != nil {
			t.Fatalf("%s digest: %v", name, err)
		}
		variants[name] = d
	}
	mustDigest("legacy-account", "MHC", "legacy-2", "pqc", 100, "memo", "idem", 1)
	mustDigest("pqc-account", "MHC", "legacy", "pqc-2", 100, "memo", "idem", 1)
	mustDigest("amount", "MHC", "legacy", "pqc", 101, "memo", "idem", 1)
	mustDigest("memo", "MHC", "legacy", "pqc", 100, "memo-2", "idem", 1)
	mustDigest("idempotency", "MHC", "legacy", "pqc", 100, "memo", "idem-2", 1)
	mustDigest("nonce", "MHC", "legacy", "pqc", 100, "memo", "idem", 2)

	for name, d := range variants {
		if string(d) == string(base) {
			t.Errorf("expected changing %q to change the digest", name)
		}
	}
}

// --- verifyMigrationSignatureBundle (unexported) -----------------------------

func TestVerifyMigrationSignatureBundle_EmptyBundleIsRejected(t *testing.T) {
	// Regression test for a fixed security bug: an empty bundle used to be
	// treated as "not enabled" and passed with no error at all, which let
	// MigrateWithDualSignatureCryptographic authorize an unverified
	// migration (see TestMigrateWithDualSignatureCryptographic_EmptyBundleIsRejected
	// in ledger_test.go). It must now be rejected outright.
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	if err := verifyMigrationSignatureBundle(digest, MigrationSignatureBundle{}); err == nil {
		t.Fatal("expected an empty bundle to be rejected, got nil error")
	}
}

func TestVerifyMigrationSignatureBundle_IncompleteBundleErrors(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	bundle.LegacySignature = "" // enabled (PQC sig present) but now incomplete
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected an incomplete-but-enabled bundle to fail")
	}
}

func TestVerifyMigrationSignatureBundle_ValidBundleSucceeds(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	if err := verifyMigrationSignatureBundle(digest, bundle); err != nil {
		t.Fatalf("expected valid bundle to verify, got: %v", err)
	}
}

func TestVerifyMigrationSignatureBundle_TamperedLegacySignatureFails(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	raw, err := base64.StdEncoding.DecodeString(bundle.LegacySignature)
	if err != nil {
		t.Fatalf("decode signature: %v", err)
	}
	raw[0] ^= 0xFF
	bundle.LegacySignature = base64.StdEncoding.EncodeToString(raw)
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected tampered legacy signature to fail verification")
	}
}

func TestVerifyMigrationSignatureBundle_TamperedPQCSignatureFails(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	raw, err := base64.StdEncoding.DecodeString(bundle.PQCSignature)
	if err != nil {
		t.Fatalf("decode signature: %v", err)
	}
	raw[0] ^= 0xFF
	bundle.PQCSignature = base64.StdEncoding.EncodeToString(raw)
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected tampered pqc signature to fail verification")
	}
}

func TestVerifyMigrationSignatureBundle_WrongDigestFails(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	otherDigest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 101, "memo", "", 0)
	if err != nil {
		t.Fatalf("other digest: %v", err)
	}
	if err := verifyMigrationSignatureBundle(otherDigest, bundle); err == nil {
		t.Fatal("expected signature bound to a different digest to fail")
	}
}

func TestVerifyMigrationSignatureBundle_UnsupportedLegacyAlgorithm(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	bundle.LegacyAlgorithm = "rsa-pss"
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected unsupported legacy algorithm to fail")
	}
}

func TestVerifyMigrationSignatureBundle_UnsupportedPQCAlgorithm(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	bundle.PQCAlgorithm = "falcon-512"
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected unsupported pqc algorithm to fail")
	}
}

func TestVerifyMigrationSignatureBundle_WrongLengthPQCSignatureFails(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	bundle.PQCSignature = base64.StdEncoding.EncodeToString([]byte("too-short"))
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected wrong-length pqc signature to fail")
	}
}

// --- decodeMaterial ------------------------------------------------------------

func TestDecodeMaterial(t *testing.T) {
	raw := []byte{0x01, 0x02, 0x03, 0xFF}
	pemBlock := string(pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: raw}))

	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"std base64", base64.StdEncoding.EncodeToString(raw), false},
		{"raw unpadded base64", base64.RawStdEncoding.EncodeToString(raw), false},
		{"hex no prefix", hex.EncodeToString(raw), false},
		{"hex with 0x prefix", "0x" + hex.EncodeToString(raw), false},
		{"pem block", pemBlock, false},
		{"empty string", "", true},
		{"whitespace only", "   ", true},
		{"garbage", "not-valid-material!!", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			decoded, err := decodeMaterial(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error decoding %q", tt.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error decoding %q: %v", tt.input, err)
			}
			if len(decoded) == 0 {
				t.Fatalf("expected non-empty decoded material for %q", tt.input)
			}
		})
	}
}

// --- parseECDSAP256PublicKey ----------------------------------------------------

func TestParseECDSAP256PublicKey_PKIXEncoded(t *testing.T) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	der, err := x509.MarshalPKIXPublicKey(&priv.PublicKey)
	if err != nil {
		t.Fatalf("marshal pub key: %v", err)
	}
	pub, err := parseECDSAP256PublicKey(der)
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	if !pub.Equal(&priv.PublicKey) {
		t.Fatal("parsed public key does not match original")
	}
}

func TestParseECDSAP256PublicKey_RawUncompressedPoint(t *testing.T) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	raw := elliptic.Marshal(elliptic.P256(), priv.PublicKey.X, priv.PublicKey.Y) //nolint:staticcheck // exercising legacy uncompressed-point path
	pub, err := parseECDSAP256PublicKey(raw)
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	if !pub.Equal(&priv.PublicKey) {
		t.Fatal("parsed public key does not match original")
	}
}

func TestParseECDSAP256PublicKey_InvalidLength(t *testing.T) {
	if _, err := parseECDSAP256PublicKey([]byte{0x04, 0x01, 0x02}); err == nil {
		t.Fatal("expected invalid-length key to fail")
	}
}

func TestParseECDSAP256PublicKey_InvalidPrefix(t *testing.T) {
	buf := make([]byte, 65)
	buf[0] = 0x02 // compressed-point prefix, not supported by this raw path
	if _, err := parseECDSAP256PublicKey(buf); err == nil {
		t.Fatal("expected non-0x04-prefixed key to fail")
	}
}

func TestParseECDSAP256PublicKey_PointNotOnCurve(t *testing.T) {
	buf := make([]byte, 65)
	buf[0] = 0x04
	for i := 1; i < 65; i++ {
		buf[i] = 0x01
	}
	if _, err := parseECDSAP256PublicKey(buf); err == nil {
		t.Fatal("expected point not on curve to fail")
	}
}

// --- parseEd25519PublicKey ----------------------------------------------------

func TestParseEd25519PublicKey_RawSize(t *testing.T) {
	pub, _, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	parsed, err := parseEd25519PublicKey(pub)
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	if string(parsed) != string(pub) {
		t.Fatal("parsed key does not match original")
	}
}

func TestParseEd25519PublicKey_PKIXEncoded(t *testing.T) {
	pub, _, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	der, err := x509.MarshalPKIXPublicKey(pub)
	if err != nil {
		t.Fatalf("marshal pub key: %v", err)
	}
	parsed, err := parseEd25519PublicKey(der)
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	if string(parsed) != string(pub) {
		t.Fatal("parsed key does not match original")
	}
}

func TestParseEd25519PublicKey_InvalidSize(t *testing.T) {
	if _, err := parseEd25519PublicKey([]byte{0x01, 0x02, 0x03}); err == nil {
		t.Fatal("expected invalid-size key to fail")
	}
}

// --- verifyECDSASignature -----------------------------------------------------

func TestVerifyECDSASignature_ASN1AndRawForms(t *testing.T) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	digest := []byte("0123456789abcdef0123456789abcdef")[:32]

	asn1Sig, err := ecdsa.SignASN1(rand.Reader, priv, digest)
	if err != nil {
		t.Fatalf("sign asn1: %v", err)
	}
	if !verifyECDSASignature(&priv.PublicKey, digest, asn1Sig) {
		t.Fatal("expected ASN.1 signature to verify")
	}

	r, s, err := ecdsa.Sign(rand.Reader, priv, digest)
	if err != nil {
		t.Fatalf("sign raw: %v", err)
	}
	raw := append(r.FillBytes(make([]byte, 32)), s.FillBytes(make([]byte, 32))...)
	if !verifyECDSASignature(&priv.PublicKey, digest, raw) {
		t.Fatal("expected raw r||s signature to verify")
	}
}

func TestVerifyECDSASignature_InvalidRejected(t *testing.T) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("keygen: %v", err)
	}
	digest := []byte("0123456789abcdef0123456789abcdef")[:32]
	if verifyECDSASignature(&priv.PublicKey, digest, []byte("too-short")) {
		t.Fatal("expected malformed signature to be rejected")
	}
	if verifyECDSASignature(&priv.PublicKey, digest, make([]byte, 64)) {
		t.Fatal("expected all-zero raw signature to be rejected")
	}
}

// --- algorithm name normalization sanity ---------------------------------------

func TestVerifyMigrationSignatureBundle_AcceptsKnownAlgorithmAliases(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	for _, algo := range []string{"ml-dsa", "mldsa", "ml-dsa-44", "ml-dsa-87", "ed25519", "MLDSA-ED25519-COMPAT"} {
		bundle := buildValidBundle(t, digest)
		bundle.PQCAlgorithm = algo
		if err := verifyMigrationSignatureBundle(digest, bundle); err != nil {
			t.Errorf("expected algorithm alias %q to be accepted, got: %v", algo, err)
		}
	}
}

func TestVerifyMigrationSignatureBundle_RejectsUnknownJunkPublicKey(t *testing.T) {
	digest, err := MigrationSigningDigest("MHC", "legacy", "pqc", 100, "memo", "", 0)
	if err != nil {
		t.Fatalf("digest: %v", err)
	}
	bundle := buildValidBundle(t, digest)
	bundle.LegacyPublicKey = strings.Repeat("z", 10) // undecodable
	if err := verifyMigrationSignatureBundle(digest, bundle); err == nil {
		t.Fatal("expected undecodable legacy public key to fail")
	}
}
