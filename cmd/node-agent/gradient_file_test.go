package main

import (
	"math"
	"os"
	"path/filepath"
	"testing"
)

func TestParseGradientFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "gradient.json")
	if err := os.WriteFile(path, []byte(`{"node_id":"n1","gradient":[1,2,3]}`), 0o600); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	vector, err := parseGradientFile(path)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(vector) != 3 || vector[0] != 1 || vector[2] != 3 {
		t.Fatalf("parsed vector = %v", vector)
	}

	badPath := filepath.Join(dir, "bad.json")
	if err := os.WriteFile(badPath, []byte(`{"gradient":"not-array"}`), 0o600); err != nil {
		t.Fatalf("write bad fixture: %v", err)
	}
	if _, err := parseGradientFile(badPath); err == nil {
		t.Fatal("expected error for malformed gradient file")
	}
}

func TestGradientNorm(t *testing.T) {
	if got := gradientNorm([]float64{3, 4}); math.Abs(got-5) > 1e-9 {
		t.Fatalf("norm = %v, want 5", got)
	}
}
