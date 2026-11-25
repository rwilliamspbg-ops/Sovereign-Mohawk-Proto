// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package tpm

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	"math/big"
	"path/filepath"
	"testing"
	"time"
)

func TestXMSSIndexPersistenceRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "node.xmss-index")
	if err := saveXMSSIndex(path, 97); err != nil {
		t.Fatalf("saveXMSSIndex: %v", err)
	}
	got, err := loadXMSSIndex(path)
	if err != nil {
		t.Fatalf("loadXMSSIndex: %v", err)
	}
	if got != 97 {
		t.Fatalf("loaded index = %d, want 97", got)
	}
}

func TestXMSSStateDirUnsetMeansInMemoryCounter(t *testing.T) {
	t.Setenv("MOHAWK_TPM_XMSS_STATE_DIR", "")
	if path := xmssStateFilePath("node-1"); path != "" {
		t.Fatalf("xmssStateFilePath with unset dir = %q, want empty", path)
	}
}

// TestXMSSSignatureIndexSurvivesAttestorRecreate reproduces the restart bug:
// the signer counter used to reset to 0 while the orchestrator's replay guard
// still remembered the last index, so every post-restart attestation was
// rejected with "replay index 0 <= N".
func TestXMSSSignatureIndexSurvivesAttestorRecreate(t *testing.T) {
	t.Setenv("MOHAWK_TPM_XMSS_STATE_DIR", t.TempDir())
	const nodeID = "deskmini-node-x"

	newAttestorLikeProducer := func() *Attestor {
		statePath := xmssStateFilePath(nodeID)
		next, err := loadXMSSIndex(statePath)
		if err != nil {
			t.Fatalf("loadXMSSIndex: %v", err)
		}
		return &Attestor{
			nodeID:    nodeID,
			sigMode:   AttestationSignatureXMSS,
			hashSeed:  [32]byte{1, 2, 3},
			hashKeyID: "key-1",
			pcrDigest: make([]byte, 32),
			leafCert:  testLeafCert(t),
			statePath: statePath,
			sigIndex:  next,
		}
	}

	for want := uint64(0); want < 3; want++ {
		raw, err := newAttestorLikeProducer().GenerateQuote()
		if err != nil {
			t.Fatalf("GenerateQuote #%d: %v", want, err)
		}
		var envelope QuoteEnvelope
		if err := json.Unmarshal(raw, &envelope); err != nil {
			t.Fatalf("unmarshal quote #%d: %v", want, err)
		}
		if envelope.SignatureIndex != want {
			t.Fatalf("quote #%d SignatureIndex = %d, want %d", want, envelope.SignatureIndex, want)
		}
	}
}

func testLeafCert(t *testing.T) *x509.Certificate {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "test"},
		NotBefore:    time.Now().Add(-time.Minute),
		NotAfter:     time.Now().Add(time.Hour),
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("create cert: %v", err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatalf("parse cert: %v", err)
	}
	return cert
}
