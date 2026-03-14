package token

import (
	"fmt"
	"sort"
	"strings"
	"sync"
)

// Registry stores asset definitions by symbol.
type Registry struct {
	mu     sync.RWMutex
	assets map[string]Asset
}

// NewRegistry creates an empty asset registry.
func NewRegistry() *Registry {
	return &Registry{assets: map[string]Asset{}}
}

// NewRegistryWithDefaults creates a registry seeded with default utility assets.
func NewRegistryWithDefaults() *Registry {
	r := NewRegistry()
	_ = r.Register(defaultAsset("MHC"))
	return r
}

// Register adds or replaces an asset definition.
func (r *Registry) Register(asset Asset) error {
	normalized := normalizeAsset(asset)
	if normalized.Symbol == "" {
		return fmt.Errorf("asset symbol is required")
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.assets[normalized.Symbol] = normalized
	return nil
}

// Get returns an asset by symbol.
func (r *Registry) Get(symbol string) (Asset, bool) {
	normalized := strings.ToUpper(strings.TrimSpace(symbol))
	r.mu.RLock()
	defer r.mu.RUnlock()
	asset, ok := r.assets[normalized]
	return asset, ok
}

// List returns all registered assets sorted by symbol.
func (r *Registry) List() []Asset {
	r.mu.RLock()
	defer r.mu.RUnlock()
	items := make([]Asset, 0, len(r.assets))
	for _, asset := range r.assets {
		items = append(items, asset)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Symbol < items[j].Symbol
	})
	return items
}
