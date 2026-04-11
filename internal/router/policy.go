package router

import (
	"fmt"
	"strings"
	"sync"
)

// PolicyEngine controls which vertical pairs are routable.
type PolicyEngine struct {
	mu      sync.RWMutex
	routes  map[string]map[string]struct{}
	blocked map[string]map[string]struct{}
}

// NewPolicyEngine returns an empty policy set (default deny).
func NewPolicyEngine() *PolicyEngine {
	return &PolicyEngine{
		routes:  map[string]map[string]struct{}{},
		blocked: map[string]map[string]struct{}{},
	}
}

// Allow authorizes a source->target route.
func (p *PolicyEngine) Allow(sourceVertical string, targetVertical string) {
	sourceVertical = normalizeVertical(sourceVertical)
	targetVertical = normalizeVertical(targetVertical)
	if sourceVertical == "" || targetVertical == "" {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	if _, ok := p.routes[sourceVertical]; !ok {
		p.routes[sourceVertical] = map[string]struct{}{}
	}
	p.routes[sourceVertical][targetVertical] = struct{}{}
}

// Block explicitly denies a route, overriding allow rules.
func (p *PolicyEngine) Block(sourceVertical string, targetVertical string) {
	sourceVertical = normalizeVertical(sourceVertical)
	targetVertical = normalizeVertical(targetVertical)
	if sourceVertical == "" || targetVertical == "" {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	if _, ok := p.blocked[sourceVertical]; !ok {
		p.blocked[sourceVertical] = map[string]struct{}{}
	}
	p.blocked[sourceVertical][targetVertical] = struct{}{}
}

// AllowRoute validates an attempted route against current policy rules.
func (p *PolicyEngine) AllowRoute(sourceVertical string, targetVertical string) error {
	sourceVertical = normalizeVertical(sourceVertical)
	targetVertical = normalizeVertical(targetVertical)
	if sourceVertical == "" || targetVertical == "" {
		return fmt.Errorf("source and target verticals are required")
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	if targets, ok := p.blocked[sourceVertical]; ok {
		if _, blocked := targets[targetVertical]; blocked {
			return fmt.Errorf("route %s->%s is blocked", sourceVertical, targetVertical)
		}
	}
	if targets, ok := p.routes[sourceVertical]; ok {
		if _, allowed := targets[targetVertical]; allowed {
			return nil
		}
	}
	return fmt.Errorf("route %s->%s is not allowed", sourceVertical, targetVertical)
}

// LoadRoutes registers allow-list routes in source->targets form.
func (p *PolicyEngine) LoadRoutes(routes map[string][]string) {
	for source, targets := range routes {
		s := strings.TrimSpace(source)
		for _, target := range targets {
			p.Allow(s, target)
		}
	}
}
