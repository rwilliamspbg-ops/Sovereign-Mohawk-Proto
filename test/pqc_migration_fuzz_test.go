package test

import (
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"testing"
	"time"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/token"
)

func TestMigrationSigningDigestFieldSensitivity(t *testing.T) {
	base, err := token.MigrationSigningDigest("MHC", "legacy-a", "mldsa-a", 100, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("base digest: %v", err)
	}
	changed, err := token.MigrationSigningDigest("MHC", "legacy-a", "mldsa-a", 101, "memo", "idem", 1)
	if err != nil {
		t.Fatalf("changed digest: %v", err)
	}
	if string(base) == string(changed) {
		t.Fatal("expected digest change when amount_units changes")
	}
}

func FuzzMigrationSigningDigest(f *testing.F) {
	f.Add("MHC", "legacy-a", "mldsa-a", int64(100), "wave-1", "idem-1", uint64(1))
	f.Add("mhc", "legacy-a", "mldsa-a", int64(100), "wave-2", "", uint64(0))

	f.Fuzz(func(t *testing.T, symbol, legacyAccount, pqcAccount string, amountUnits int64, memo, idempotency string, nonce uint64) {
		d1, err := token.MigrationSigningDigest(symbol, legacyAccount, pqcAccount, amountUnits, memo, idempotency, nonce)
		if err != nil {
			t.Skip()
		}
		d2, err := token.MigrationSigningDigest(symbol, legacyAccount, pqcAccount, amountUnits, memo, idempotency, nonce)
		if err != nil {
			t.Skip()
		}
		if len(d1) != 32 || len(d2) != 32 {
			t.Fatalf("unexpected digest length d1=%d d2=%d", len(d1), len(d2))
		}
		if string(d1) != string(d2) {
			t.Fatal("digest is not deterministic")
		}
	})
}

func FuzzMigrationDualSignatureFlow(f *testing.F) {
	f.Add("memo", "idem", uint64(10), false)
	f.Add("memo", "idem", uint64(10), true)

	f.Fuzz(func(t *testing.T, memo, idempotency string, nonce uint64, mutate bool) {
		ledger := token.NewLedger("MHC", "protocol")
		if _, err := ledger.Mint("protocol", "legacy-edge", 10, "seed"); err != nil {
			t.Fatalf("mint failed: %v", err)
		}
		ledger.ConfigurePQCMigration(true, time.Now().Add(1*time.Hour), false)

		legacyPriv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatalf("legacy keygen failed: %v", err)
		}
		pqcPub, pqcPriv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			t.Fatalf("pqc keygen failed: %v", err)
		}

		amountUnits, err := ledger.AmountToUnits(1)
		if err != nil {
			t.Fatalf("amount conversion failed: %v", err)
		}
		digest, err := token.MigrationSigningDigest("MHC", "legacy-edge", "mldsa-edge", amountUnits, memo, idempotency, nonce)
		if err != nil {
			t.Fatalf("digest build failed: %v", err)
		}
		legacySig, err := ecdsa.SignASN1(rand.Reader, legacyPriv, digest)
		if err != nil {
			t.Fatalf("legacy sign failed: %v", err)
		}
		pqcSig := ed25519.Sign(pqcPriv, digest)
		if mutate && len(pqcSig) > 0 {
			pqcSig[0] ^= 0x01
		}

		legacyPubBytes, err := x509.MarshalPKIXPublicKey(&legacyPriv.PublicKey)
		if err != nil {
			t.Fatalf("marshal legacy pub key: %v", err)
		}
		bundle := token.MigrationSignatureBundle{
			LegacyAlgorithm: "ecdsa-p256-sha256",
			LegacyPublicKey: base64.StdEncoding.EncodeToString(legacyPubBytes),
			LegacySignature: base64.StdEncoding.EncodeToString(legacySig),
			PQCAlgorithm:    "ml-dsa-65",
			PQCPublicKey:    base64.StdEncoding.EncodeToString(pqcPub),
			PQCSignature:    base64.StdEncoding.EncodeToString(pqcSig),
		}

		_, err = ledger.MigrateWithDualSignatureCryptographic("legacy-edge", "mldsa-edge", 1, memo, bundle, idempotency, nonce)
		if mutate {
			if err == nil {
				t.Fatal("expected migration failure with mutated signature")
			}
			return
		}
		if err != nil {
			t.Fatalf("expected migration success, got %v", err)
		}
	})
}
