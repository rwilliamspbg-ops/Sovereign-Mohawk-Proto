package router

import (
	"fmt"
	"strings"

	"github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/internal/wasmhost"
)

// TranslationRequest represents a gradient payload remapped between domain schemas.
type TranslationRequest struct {
	SourceVertical string    `json:"source_vertical"`
	TargetVertical string    `json:"target_vertical"`
	SourceSchema   []string  `json:"source_schema"`
	TargetSchema   []string  `json:"target_schema"`
	Gradient       []float64 `json:"gradient"`
}

// Translator applies model-agnostic schema remapping.
type Translator interface {
	Translate(req TranslationRequest) ([]float64, error)
}

// SchemaTranslator uses schema labels to map source gradient dimensions to target space.
type SchemaTranslator struct{}

// Translate projects source gradient dimensions into the target schema.
func (SchemaTranslator) Translate(req TranslationRequest) ([]float64, error) {
	if len(req.SourceSchema) == 0 || len(req.TargetSchema) == 0 {
		return nil, fmt.Errorf("source_schema and target_schema are required")
	}
	if len(req.Gradient) != len(req.SourceSchema) {
		return nil, fmt.Errorf("gradient length must match source_schema length")
	}

	sourceIndex := make(map[string]int, len(req.SourceSchema))
	for i, feature := range req.SourceSchema {
		sourceIndex[strings.TrimSpace(strings.ToLower(feature))] = i
	}

	translated := make([]float64, len(req.TargetSchema))
	for i, targetFeature := range req.TargetSchema {
		if srcIdx, ok := sourceIndex[strings.TrimSpace(strings.ToLower(targetFeature))]; ok {
			translated[i] = req.Gradient[srcIdx]
		}
	}
	return translated, nil
}

// VerifyTranslationModule validates WASM translator modules before activation.
func VerifyTranslationModule(wasmBin []byte) error {
	return wasmhost.ValidateModuleLimits(wasmBin)
}
