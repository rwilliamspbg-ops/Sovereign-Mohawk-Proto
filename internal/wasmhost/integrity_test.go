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

package wasmhost

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"testing"
)

func TestVerifyHotReloadIntegrity(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen failed: %v", err)
	}
	wasm := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	sum := sha256.Sum256(wasm)

	sig := ed25519.Sign(priv, sum[:])
	if err := VerifyHotReloadIntegrity(
		wasm,
		hex.EncodeToString(sum[:]),
		base64.StdEncoding.EncodeToString(sig),
		base64.StdEncoding.EncodeToString(pub),
	); err != nil {
		t.Fatalf("expected integrity check pass, got %v", err)
	}
}

func TestVerifyHotReloadIntegrityRejectsMismatch(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keygen failed: %v", err)
	}
	wasm := []byte{0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00}
	sum := sha256.Sum256(wasm)

	sig := ed25519.Sign(priv, sum[:])
	badHash := make([]byte, len(sum))
	copy(badHash, sum[:])
	badHash[0] ^= 0x01

	err = VerifyHotReloadIntegrity(
		wasm,
		hex.EncodeToString(badHash),
		base64.StdEncoding.EncodeToString(sig),
		base64.StdEncoding.EncodeToString(pub),
	)
	if err == nil {
		t.Fatal("expected hash mismatch failure")
	}
}
