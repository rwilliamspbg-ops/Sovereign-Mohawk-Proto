package token

import "testing"

func TestNewRegistryWithDefaultsSeedsMHC(t *testing.T) {
	r := NewRegistryWithDefaults()
	asset, ok := r.Get("mhc")
	if !ok {
		t.Fatal("expected default MHC asset to be registered")
	}
	if asset.Symbol != "MHC" || asset.Decimals != 6 {
		t.Fatalf("unexpected default asset: %+v", asset)
	}
}

func TestRegistryRegisterRequiresSymbol(t *testing.T) {
	r := NewRegistry()
	if err := r.Register(Asset{Symbol: "   ", Decimals: 2}); err == nil {
		t.Fatal("expected empty symbol to be rejected")
	}
}

func TestRegistryRegisterNormalizesSymbolCase(t *testing.T) {
	r := NewRegistry()
	if err := r.Register(Asset{Symbol: "usd", Decimals: 2}); err != nil {
		t.Fatalf("register failed: %v", err)
	}
	asset, ok := r.Get("USD")
	if !ok {
		t.Fatal("expected case-insensitive lookup to find registered asset")
	}
	if asset.Symbol != "USD" {
		t.Fatalf("expected normalized symbol USD, got %q", asset.Symbol)
	}
	if _, ok := r.Get("usd"); !ok {
		t.Fatal("expected lowercase lookup to also succeed")
	}
}

func TestRegistryRegisterReplacesExistingAsset(t *testing.T) {
	r := NewRegistry()
	if err := r.Register(Asset{Symbol: "USD", Decimals: 2}); err != nil {
		t.Fatalf("register failed: %v", err)
	}
	if err := r.Register(Asset{Symbol: "USD", Decimals: 2, MaxSupplyUnits: 100}); err != nil {
		t.Fatalf("re-register failed: %v", err)
	}
	asset, ok := r.Get("USD")
	if !ok || asset.MaxSupplyUnits != 100 {
		t.Fatalf("expected re-register to replace asset definition, got %+v", asset)
	}
}

func TestRegistryGetUnknownSymbolReturnsFalse(t *testing.T) {
	r := NewRegistry()
	if _, ok := r.Get("NOPE"); ok {
		t.Fatal("expected unknown symbol to return ok=false")
	}
}

func TestRegistryListSortedBySymbol(t *testing.T) {
	r := NewRegistry()
	for _, sym := range []string{"ZZZ", "AAA", "MMM"} {
		if err := r.Register(Asset{Symbol: sym, Decimals: 2}); err != nil {
			t.Fatalf("register %s failed: %v", sym, err)
		}
	}
	items := r.List()
	if len(items) != 3 {
		t.Fatalf("expected 3 assets, got %d", len(items))
	}
	if items[0].Symbol != "AAA" || items[1].Symbol != "MMM" || items[2].Symbol != "ZZZ" {
		t.Fatalf("expected sorted symbols, got %v, %v, %v", items[0].Symbol, items[1].Symbol, items[2].Symbol)
	}
}

func TestRegistryListEmptyRegistry(t *testing.T) {
	r := NewRegistry()
	items := r.List()
	if len(items) != 0 {
		t.Fatalf("expected empty registry to list zero assets, got %d", len(items))
	}
}
