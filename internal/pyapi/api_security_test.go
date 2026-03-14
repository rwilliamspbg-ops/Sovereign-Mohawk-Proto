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
	originalPolicy := apiRolePolicy
	apiAuthMode = apiAuthModeRequired
	apiAuthToken = "secret-token"
	apiRolePolicy = apiRolePolicyConfig{}
	t.Cleanup(func() {
		apiAuthMode = originalMode
		apiAuthToken = originalToken
		apiRolePolicy = originalPolicy
	})

	if err := validateAPIAccess("bridge", "", "secret-token"); err != nil {
		t.Fatalf("expected valid token to pass: %v", err)
	}
	if err := validateAPIAccess("bridge", "", "wrong-token"); err == nil {
		t.Fatal("expected invalid token to fail")
	}
}

func TestAuthorizeAPIRole(t *testing.T) {
	originalPolicy := apiRolePolicy
	originalTokenRole := apiAuthTokenRole
	apiRolePolicy = apiRolePolicyConfig{
		enabled: true,
		allowedByOp: map[string]map[string]struct{}{
			"bridge": {
				"operator": {},
			},
		},
		requiredByOp: map[string]bool{"bridge": true},
	}
	apiAuthTokenRole = ""
	t.Cleanup(func() {
		apiRolePolicy = originalPolicy
		apiAuthTokenRole = originalTokenRole
	})

	if err := authorizeAPIRole("bridge", "operator"); err != nil {
		t.Fatalf("expected operator role to pass: %v", err)
	}
	if err := authorizeAPIRole("bridge", "viewer"); err == nil {
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

func TestParseBridgeSettlementAssets(t *testing.T) {
	assets := parseBridgeSettlementAssets(" mhc, USDX, mhc ,, usdx ")
	if len(assets) != 2 {
		t.Fatalf("expected 2 unique assets, got %d (%v)", len(assets), assets)
	}
	if assets[0] != "MHC" || assets[1] != "USDX" {
		t.Fatalf("unexpected parsed assets: %v", assets)
	}
}

func TestLoadBridgeSettlementConfigFromEnv(t *testing.T) {
	t.Setenv("MOHAWK_BRIDGE_SETTLEMENT_ASSETS", "MHC,USDX")
	t.Setenv("MOHAWK_UTILITY_MINTER_USDX", "mint-usdx")

	registry, ledgers, minters, err := loadBridgeSettlementConfig()
	if err != nil {
		t.Fatalf("loadBridgeSettlementConfig failed: %v", err)
	}
	if registry == nil {
		t.Fatal("expected settlement registry to be configured")
	}
	if _, ok := registry.Get("MHC"); !ok {
		t.Fatal("expected MHC in settlement registry")
	}
	if _, ok := registry.Get("USDX"); !ok {
		t.Fatal("expected USDX in settlement registry")
	}
	if len(ledgers) != 2 {
		t.Fatalf("expected 2 settlement ledgers, got %d", len(ledgers))
	}
	if ledgers["MHC"] == nil || ledgers["USDX"] == nil {
		t.Fatal("expected settlement ledgers for MHC and USDX")
	}
	if minters["USDX"] != "mint-usdx" {
		t.Fatalf("unexpected USDX settlement minter: %q", minters["USDX"])
	}
}
