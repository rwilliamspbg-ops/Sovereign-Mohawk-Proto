package tpm

import (
	"testing"
	"time"
)

func TestGetVerifiedQuoteLeaseCache(t *testing.T) {
	t.Setenv("MOHAWK_TPM_IDENTITY_SIG_MODE", "rsa-pss-sha256")
	t.Setenv("MOHAWK_TPM_QUOTE_LEASE_TTL", "2m")

	q1, exp1, cached1, err := GetVerifiedQuoteLease("lease-node")
	if err != nil {
		t.Fatalf("first lease quote failed: %v", err)
	}
	if len(q1) == 0 {
		t.Fatalf("expected non-empty quote")
	}
	if cached1 {
		t.Fatalf("first quote should not be cache hit")
	}
	if exp1.IsZero() {
		t.Fatalf("expected non-zero lease expiry")
	}

	q2, exp2, cached2, err := GetVerifiedQuoteLease("lease-node")
	if err != nil {
		t.Fatalf("second lease quote failed: %v", err)
	}
	if !cached2 {
		t.Fatalf("second quote should come from cache")
	}
	if len(q2) == 0 {
		t.Fatalf("expected non-empty cached quote")
	}
	if exp2.Before(time.Now()) {
		t.Fatalf("cached lease should not be expired")
	}
}
