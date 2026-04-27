//go:build cgo

package main

import (
	"os"
	"testing"
)

func TestParseRoleSetDefaults(t *testing.T) {
	roles := parseRoleSet("", "admin,operator")
	if _, ok := roles["admin"]; !ok {
		t.Fatal("expected admin role to be present")
	}
	if _, ok := roles["operator"]; !ok {
		t.Fatal("expected operator role to be present")
	}
}

func TestEffectiveUtilityRoleTokenBinding(t *testing.T) {
	original := apiAuthTokenRole
	apiAuthTokenRole = "admin"
	t.Cleanup(func() { apiAuthTokenRole = original })

	role, err := effectiveUtilityRole("")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if role != "admin" {
		t.Fatalf("expected token-bound role admin, got %q", role)
	}
	if _, err := effectiveUtilityRole("operator"); err == nil {
		t.Fatal("expected mismatch error for different requested role")
	}
}

func TestUtilityRateLimiterAllow(t *testing.T) {
	limiter := &utilityRateLimiter{limitPerMin: 2, counters: map[string]rateWindowCounter{}}
	if !limiter.Allow("edge-a") {
		t.Fatal("first request should pass")
	}
	if !limiter.Allow("edge-a") {
		t.Fatal("second request should pass")
	}
	if limiter.Allow("edge-a") {
		t.Fatal("third request should be rate limited")
	}
	if !limiter.Allow("edge-b") {
		t.Fatal("separate principal should have separate quota")
	}
}

func TestAuthorizeUtilityRole(t *testing.T) {
	originalPolicy := utilityRolePolicy
	utilityRolePolicy = utilityRolePolicyConfig{
		enabled: true,
		allowedByOp: map[string]map[string]struct{}{
			"mint": {
				"admin": {},
			},
		},
		requiredByOp: map[string]bool{"mint": true},
	}
	t.Cleanup(func() { utilityRolePolicy = originalPolicy })

	if err := authorizeUtilityRole("mint", "admin"); err != nil {
		t.Fatalf("expected admin role to pass: %v", err)
	}
	if err := authorizeUtilityRole("mint", "operator"); err == nil {
		t.Fatal("expected operator role to fail")
	}
}

func TestValidateAPIAccessRequiredMode(t *testing.T) {
	originalMode := apiAuthMode
	originalToken := apiAuthToken
	originalTokenRole := apiAuthTokenRole
	originalPolicy := apiRolePolicy
	originalUtilityPolicy := utilityRolePolicy
	apiAuthMode = apiAuthModeRequired
	apiAuthToken = "secret-token"
	apiAuthTokenRole = ""
	apiRolePolicy = apiRolePolicyConfig{}
	utilityRolePolicy = utilityRolePolicyConfig{
		enabled: true,
		allowedByOp: map[string]map[string]struct{}{
			"transfer": {
				"admin": {},
			},
		},
		requiredByOp: map[string]bool{"transfer": true},
	}
	t.Cleanup(func() {
		apiAuthMode = originalMode
		apiAuthToken = originalToken
		apiAuthTokenRole = originalTokenRole
		apiRolePolicy = originalPolicy
		utilityRolePolicy = originalUtilityPolicy
	})

	if err := validateAPIAccess("hybrid", "", "secret-token"); err != nil {
		t.Fatalf("expected valid token to pass: %v", err)
	}
	if err := validateAPIAccess("hybrid", "", "wrong-token"); err == nil {
		t.Fatal("expected invalid token to fail")
	}
	if err := validateUtilityAccess("transfer", "admin", "secret-token"); err != nil {
		t.Fatalf("expected valid utility access to pass: %v", err)
	}
	if err := validateUtilityAccess("transfer", "operator", "secret-token"); err == nil || err.Error() != "role \"operator\" is not allowed for transfer" {
		t.Fatalf("expected operator role to be denied explicitly, got: %v", err)
	}
	if err := validateUtilityAccess("transfer", "admin", "wrong-token"); err == nil || err.Error() != "invalid API token" {
		t.Fatalf("expected wrong token to be denied explicitly, got: %v", err)
	}
}

func TestAuthorizeAPIRole(t *testing.T) {
	originalPolicy := apiRolePolicy
	originalTokenRole := apiAuthTokenRole
	apiRolePolicy = apiRolePolicyConfig{
		enabled: true,
		allowedByOp: map[string]map[string]struct{}{
			"hybrid": {
				"operator": {},
			},
		},
		requiredByOp: map[string]bool{"hybrid": true},
	}
	apiAuthTokenRole = ""
	t.Cleanup(func() {
		apiRolePolicy = originalPolicy
		apiAuthTokenRole = originalTokenRole
	})

	if err := authorizeAPIRole("hybrid", "operator"); err != nil {
		t.Fatalf("expected operator role to pass: %v", err)
	}
	if err := authorizeAPIRole("hybrid", "viewer"); err == nil {
		t.Fatal("expected viewer role to fail")
	}
}

func TestValidateAPIAccessFileOnlyModeRequiresFile(t *testing.T) {
	originalMode := apiAuthMode
	originalToken := apiAuthToken
	originalPolicy := apiRolePolicy
	originalPath := os.Getenv("MOHAWK_API_TOKEN_FILE")
	apiAuthMode = apiAuthModeFileOnly
	apiAuthToken = ""
	apiRolePolicy = apiRolePolicyConfig{}
	_ = os.Unsetenv("MOHAWK_API_TOKEN_FILE")
	t.Cleanup(func() {
		apiAuthMode = originalMode
		apiAuthToken = originalToken
		apiRolePolicy = originalPolicy
		_ = os.Setenv("MOHAWK_API_TOKEN_FILE", originalPath)
	})

	if err := validateAPIAccess("hybrid", "", "anything"); err == nil {
		t.Fatal("expected file-only mode to require token file")
	}
}
