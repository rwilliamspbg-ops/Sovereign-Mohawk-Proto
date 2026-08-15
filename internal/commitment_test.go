package internal

import "testing"

func TestParseCommitmentHex(t *testing.T) {
	if got, err := ParseCommitmentHex(""); err != nil || got != nil {
		t.Fatalf("expected (nil, nil) for empty string, got (%v, %v)", got, err)
	}
	if got, err := ParseCommitmentHex("   "); err != nil || got != nil {
		t.Fatalf("expected whitespace-only string to be treated as absent, got (%v, %v)", got, err)
	}
	if got, err := ParseCommitmentHex("0xFF"); err != nil || got == nil || got.Text(16) != "ff" {
		t.Fatalf("expected 0xff to parse to 255, got (%v, %v)", got, err)
	}
	if got, err := ParseCommitmentHex("ff"); err != nil || got == nil || got.Text(16) != "ff" {
		t.Fatalf("expected bare hex (no 0x prefix) to parse, got (%v, %v)", got, err)
	}
	if _, err := ParseCommitmentHex("not-hex!!"); err == nil {
		t.Fatalf("expected an error for malformed hex, got nil")
	}
}
