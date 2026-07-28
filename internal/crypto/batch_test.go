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

package crypto

import (
	"strings"
	"testing"
)

func TestVerifyBatchIntegrity_ValidID(t *testing.T) {
	ok, err := VerifyBatchIntegrity("batch-abc-123")
	if err != nil {
		t.Fatalf("expected no error for valid batch ID, got: %v", err)
	}
	if !ok {
		t.Fatal("expected true for valid batch ID")
	}
}

func TestVerifyBatchIntegrity_EmptyID(t *testing.T) {
	ok, err := VerifyBatchIntegrity("")
	if err == nil {
		t.Fatal("expected error for empty batch ID, got nil")
	}
	if ok {
		t.Fatal("expected false for empty batch ID")
	}
}

// The error returned on the empty-ID path is relied on elsewhere (and by
// operators reading logs) to identify this specific failure mode. Pin its
// content so a future refactor doesn't silently change the message people
// grep for.
func TestVerifyBatchIntegrity_EmptyID_ErrorContent(t *testing.T) {
	_, err := VerifyBatchIntegrity("")
	if err == nil {
		t.Fatal("expected non-nil error")
	}
	msg := err.Error()
	if !strings.Contains(msg, "empty batch identifier") {
		t.Errorf("expected error to mention 'empty batch identifier', got: %q", msg)
	}
	if !strings.Contains(msg, "Theorem 5") {
		t.Errorf("expected error to reference Theorem 5, got: %q", msg)
	}
}

// Table-driven pass over a variety of "non-empty" identifiers to make sure
// the function only special-cases the truly-empty string and does not, for
// example, also reject whitespace-only or unusually-shaped identifiers.
func TestVerifyBatchIntegrity_TableDriven(t *testing.T) {
	tests := []struct {
		name    string
		batchID string
		wantOK  bool
		wantErr bool
	}{
		{name: "simple id", batchID: "batch-1", wantOK: true, wantErr: false},
		{name: "empty string", batchID: "", wantOK: false, wantErr: true},
		{name: "single space", batchID: " ", wantOK: true, wantErr: false},
		{name: "whitespace only", batchID: "   \t\n", wantOK: true, wantErr: false},
		{name: "single character", batchID: "x", wantOK: true, wantErr: false},
		{name: "numeric id", batchID: "0", wantOK: true, wantErr: false},
		{name: "uuid-like", batchID: "550e8400-e29b-41d4-a716-446655440000", wantOK: true, wantErr: false},
		{name: "unicode id", batchID: "batch-批次-\U0001F600", wantOK: true, wantErr: false},
		{name: "id with null byte", batchID: "batch-\x00-1", wantOK: true, wantErr: false},
		{name: "id containing quotes", batchID: `batch-"quoted"-1`, wantOK: true, wantErr: false},
		{
			name:    "very long id (64KB)",
			batchID: strings.Repeat("a", 64*1024),
			wantOK:  true,
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ok, err := VerifyBatchIntegrity(tt.batchID)
			if (err != nil) != tt.wantErr {
				t.Fatalf("VerifyBatchIntegrity(%q) error = %v, wantErr %v", tt.batchID, err, tt.wantErr)
			}
			if ok != tt.wantOK {
				t.Fatalf("VerifyBatchIntegrity(%q) ok = %v, want %v", tt.batchID, ok, tt.wantOK)
			}
		})
	}
}

// VerifyBatchIntegrity should be side-effect free and deterministic: calling
// it repeatedly with the same input must always yield the same result.
func TestVerifyBatchIntegrity_Deterministic(t *testing.T) {
	for i := 0; i < 5; i++ {
		ok, err := VerifyBatchIntegrity("batch-repeat")
		if err != nil {
			t.Fatalf("iteration %d: unexpected error: %v", i, err)
		}
		if !ok {
			t.Fatalf("iteration %d: expected true", i)
		}
	}

	for i := 0; i < 5; i++ {
		ok, err := VerifyBatchIntegrity("")
		if err == nil {
			t.Fatalf("iteration %d: expected error", i)
		}
		if ok {
			t.Fatalf("iteration %d: expected false", i)
		}
	}
}
