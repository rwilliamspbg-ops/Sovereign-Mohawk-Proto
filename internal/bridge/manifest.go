package bridge

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	// DefaultPolicyManifestFile is the repository-level default bridge policy manifest path.
	DefaultPolicyManifestFile = "bridge-policies.json"
	// PolicyManifestPathEnv is an optional environment override for bridge policy manifest path.
	PolicyManifestPathEnv = "MOHAWK_BRIDGE_POLICY_MANIFEST"
)

// RoutePolicyRoute binds a route key to a policy in a manifest.
type RoutePolicyRoute struct {
	SourceChain string      `json:"source_chain"`
	TargetChain string      `json:"target_chain"`
	Policy      RoutePolicy `json:"policy"`
}

// RoutePolicyManifest is a portable JSON manifest for route policies.
type RoutePolicyManifest struct {
	Version string             `json:"version,omitempty"`
	Routes  []RoutePolicyRoute `json:"routes"`
}

// ParseRoutePolicyManifest parses JSON manifest bytes.
func ParseRoutePolicyManifest(raw []byte) (RoutePolicyManifest, error) {
	var manifest RoutePolicyManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return RoutePolicyManifest{}, fmt.Errorf("invalid route policy manifest JSON: %w", err)
	}
	if len(manifest.Routes) == 0 {
		return RoutePolicyManifest{}, fmt.Errorf("route policy manifest has no routes")
	}
	for i, route := range manifest.Routes {
		if normalizeChain(route.SourceChain) == "" || normalizeChain(route.TargetChain) == "" {
			return RoutePolicyManifest{}, fmt.Errorf("route %d missing source_chain or target_chain", i)
		}
		if route.Policy.ID == "" {
			manifest.Routes[i].Policy.ID = routeKey(route.SourceChain, route.TargetChain)
		}
	}
	return manifest, nil
}

// LoadRoutePolicyManifestFile loads and parses a manifest from a JSON file.
func LoadRoutePolicyManifestFile(path string) (RoutePolicyManifest, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return RoutePolicyManifest{}, fmt.Errorf("read policy manifest: %w", err)
	}
	return ParseRoutePolicyManifest(raw)
}

// RegisterRoutePolicyManifest installs all routes from a parsed manifest.
func (e *Engine) RegisterRoutePolicyManifest(manifest RoutePolicyManifest) {
	for _, route := range manifest.Routes {
		e.RegisterRoutePolicy(route.SourceChain, route.TargetChain, route.Policy)
	}
}

// ResolveDefaultRoutePolicyManifestPath resolves the best-effort default manifest path.
func ResolveDefaultRoutePolicyManifestPath() string {
	if fromEnv := os.Getenv(PolicyManifestPathEnv); fromEnv != "" {
		return fromEnv
	}
	return DefaultPolicyManifestFile
}

// LoadDefaultRoutePolicyManifest attempts to load the default manifest path.
// It returns (manifest, loaded, error) where loaded=false means no file was found.
func LoadDefaultRoutePolicyManifest() (RoutePolicyManifest, bool, error) {
	path := ResolveDefaultRoutePolicyManifestPath()
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return RoutePolicyManifest{}, false, nil
		}
		return RoutePolicyManifest{}, false, fmt.Errorf("stat default policy manifest: %w", err)
	}
	manifest, err := LoadRoutePolicyManifestFile(path)
	if err != nil {
		return RoutePolicyManifest{}, false, err
	}
	return manifest, true, nil
}
