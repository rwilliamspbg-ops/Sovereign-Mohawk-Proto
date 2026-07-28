package fhe

import "testing"

// --- ValidateShares ------------------------------------------------------------

func TestValidateShares(t *testing.T) {
	tests := []struct {
		name      string
		shares    []KeyShare
		threshold int
		wantErr   bool
	}{
		{"valid single share", []KeyShare{{NodeID: "a", Weight: 1}}, 1, false},
		{"valid multiple shares", []KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "b", Weight: 2}}, 2, false},
		{"non-positive threshold", []KeyShare{{NodeID: "a", Weight: 1}}, 0, true},
		{"negative threshold", []KeyShare{{NodeID: "a", Weight: 1}}, -1, true},
		{"empty shares", []KeyShare{}, 1, true},
		{"nil shares", nil, 1, true},
		{"blank node id", []KeyShare{{NodeID: "  ", Weight: 1}}, 1, true},
		{"zero weight", []KeyShare{{NodeID: "a", Weight: 0}}, 1, true},
		{"negative weight", []KeyShare{{NodeID: "a", Weight: -1}}, 1, true},
		{"duplicate node id", []KeyShare{{NodeID: "a", Weight: 1}, {NodeID: "a", Weight: 1}}, 1, true},
		{"duplicate after trim", []KeyShare{{NodeID: "a", Weight: 1}, {NodeID: " a ", Weight: 1}}, 1, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateShares(tt.shares, tt.threshold)
			if tt.wantErr && err == nil {
				t.Fatal("expected error, got nil")
			}
			if !tt.wantErr && err != nil {
				t.Fatalf("expected no error, got: %v", err)
			}
		})
	}
}

// --- HasQuorum -------------------------------------------------------------------

func TestHasQuorum(t *testing.T) {
	shares := ShareMap([]KeyShare{
		{NodeID: "a", Weight: 1},
		{NodeID: "b", Weight: 2},
		{NodeID: "c", Weight: 3},
	})
	tests := []struct {
		name         string
		participants []string
		threshold    int
		want         bool
	}{
		{"exact threshold met", []string{"a", "b"}, 3, true},
		{"threshold not met", []string{"a"}, 3, false},
		{"threshold exceeded", []string{"a", "b", "c"}, 4, true},
		{"zero threshold fails closed", []string{"a", "b", "c"}, 0, false},
		{"negative threshold fails closed", []string{"a", "b", "c"}, -5, false},
		{"unknown participant contributes nothing", []string{"unknown"}, 1, false},
		{"blank participant skipped", []string{"", "a"}, 1, true},
		{"whitespace participant trimmed and matched", []string{" a "}, 1, true},
		{"empty participants list", []string{}, 1, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := HasQuorum(tt.participants, shares, tt.threshold)
			if got != tt.want {
				t.Fatalf("expected %v, got %v", tt.want, got)
			}
		})
	}
}

func TestHasQuorum_ZeroOrNegativeWeightShareDoesNotCount(t *testing.T) {
	shares := map[string]KeyShare{
		"a": {NodeID: "a", Weight: 0},
		"b": {NodeID: "b", Weight: -3},
	}
	if HasQuorum([]string{"a", "b"}, shares, 1) {
		t.Fatal("expected non-positive weight shares to not satisfy quorum")
	}
}

// TestHasQuorum_DuplicateParticipantsDoNotInflateWeight is a regression test
// for a fixed security bug: HasQuorum used to sum a share's Weight once per
// *occurrence* in the participants slice rather than once per distinct node,
// so a single duplicated participant entry could singlehandedly satisfy a
// quorum meant to require multiple independent key holders. HasQuorum now
// de-duplicates participants internally.
func TestHasQuorum_DuplicateParticipantsDoNotInflateWeight(t *testing.T) {
	shares := map[string]KeyShare{
		"a": {NodeID: "a", Weight: 2},
	}
	// A single real key-share holder "a" (weight 2) must not be able to
	// satisfy a 3-of-N quorum alone, even if listed multiple times.
	if HasQuorum([]string{"a"}, shares, 3) {
		t.Fatal("sanity check failed: single occurrence unexpectedly met threshold 3")
	}
	if HasQuorum([]string{"a", "a"}, shares, 3) {
		t.Fatal("expected duplicate participant entries to not inflate quorum weight")
	}
	if HasQuorum([]string{"a", "a", "a", "a"}, shares, 3) {
		t.Fatal("expected repeated duplicate participant entries to still not inflate quorum weight")
	}
}

// --- ShareMap --------------------------------------------------------------------

func TestShareMap_KeysAreTrimmedNodeIDs(t *testing.T) {
	shares := ShareMap([]KeyShare{{NodeID: "  a  ", Weight: 5}})
	share, ok := shares["a"]
	if !ok {
		t.Fatal("expected map key to be the trimmed node id")
	}
	// NOTE: only the map *key* is trimmed; the stored struct's NodeID field
	// retains the original untrimmed value. This asymmetry is worth knowing
	// about for any code that reads share.NodeID back out of the map.
	if share.NodeID != "  a  " {
		t.Fatalf("expected stored share to retain original untrimmed NodeID, got %q", share.NodeID)
	}
	if share.Weight != 5 {
		t.Fatalf("unexpected weight: %d", share.Weight)
	}
}

func TestShareMap_LastDuplicateWins(t *testing.T) {
	shares := ShareMap([]KeyShare{
		{NodeID: "a", Weight: 1},
		{NodeID: "a", Weight: 99},
	})
	if shares["a"].Weight != 99 {
		t.Fatalf("expected last duplicate entry to win, got weight %d", shares["a"].Weight)
	}
}

func TestShareMap_Empty(t *testing.T) {
	shares := ShareMap(nil)
	if len(shares) != 0 {
		t.Fatalf("expected empty map for nil input, got %d entries", len(shares))
	}
}

// --- SortedParticipants ------------------------------------------------------------

func TestSortedParticipants_TrimsFiltersAndSorts(t *testing.T) {
	got := SortedParticipants([]string{"charlie", "", "  alpha  ", "bravo", "   "})
	want := []string{"alpha", "bravo", "charlie"}
	if len(got) != len(want) {
		t.Fatalf("expected %v, got %v", want, got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("expected %v, got %v", want, got)
		}
	}
}

func TestSortedParticipants_PreservesDuplicates(t *testing.T) {
	got := SortedParticipants([]string{"a", "a", "b"})
	if len(got) != 3 {
		t.Fatalf("expected duplicates to be preserved (no de-dup), got %v", got)
	}
}

func TestSortedParticipants_EmptyInput(t *testing.T) {
	got := SortedParticipants(nil)
	if len(got) != 0 {
		t.Fatalf("expected empty result for nil input, got %v", got)
	}
}
