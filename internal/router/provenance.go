package router

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ProvenanceEvent captures how one vertical's insight influenced another.
type ProvenanceEvent struct {
	OfferID         string    `json:"offer_id"`
	SourceVertical  string    `json:"source_vertical"`
	TargetVertical  string    `json:"target_vertical"`
	SubscriberModel string    `json:"subscriber_model"`
	ImpactMetric    string    `json:"impact_metric"`
	ImpactDelta     float64   `json:"impact_delta"`
	RecordedAt      time.Time `json:"recorded_at"`
}

// ProvenanceRecord is the append-only hash-chained representation of events.
type ProvenanceRecord struct {
	Index      int             `json:"index"`
	Event      ProvenanceEvent `json:"event"`
	PrevHash   string          `json:"prev_hash,omitempty"`
	RecordHash string          `json:"record_hash"`
}

// ProvenanceLedger keeps immutable record ordering for audit and replay.
type ProvenanceLedger struct {
	mu          sync.RWMutex
	records     []ProvenanceRecord
	persistPath string
}

// NewProvenanceLedger creates an empty provenance ledger.
func NewProvenanceLedger() *ProvenanceLedger {
	return &ProvenanceLedger{records: make([]ProvenanceRecord, 0, 64)}
}

// NewFileBackedProvenanceLedger creates a provenance ledger persisted to disk.
func NewFileBackedProvenanceLedger(path string) (*ProvenanceLedger, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, fmt.Errorf("persist path is required")
	}
	ledger := &ProvenanceLedger{
		records:     make([]ProvenanceRecord, 0, 64),
		persistPath: path,
	}
	if err := ledger.loadLocked(); err != nil {
		return nil, err
	}
	return ledger, nil
}

// Append adds a new record and links it to the previous record hash.
func (l *ProvenanceLedger) Append(event ProvenanceEvent) (ProvenanceRecord, error) {
	event.OfferID = strings.TrimSpace(event.OfferID)
	event.SourceVertical = normalizeVertical(event.SourceVertical)
	event.TargetVertical = normalizeVertical(event.TargetVertical)
	event.SubscriberModel = strings.TrimSpace(event.SubscriberModel)
	event.ImpactMetric = strings.TrimSpace(event.ImpactMetric)
	if event.RecordedAt.IsZero() {
		event.RecordedAt = time.Now().UTC()
	}
	if event.OfferID == "" || event.SourceVertical == "" || event.TargetVertical == "" || event.ImpactMetric == "" {
		return ProvenanceRecord{}, fmt.Errorf("offer_id, source_vertical, target_vertical, and impact_metric are required")
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	prev := ""
	if n := len(l.records); n > 0 {
		prev = l.records[n-1].RecordHash
	}
	record := ProvenanceRecord{
		Index:    len(l.records),
		Event:    event,
		PrevHash: prev,
	}
	encoded, _ := json.Marshal(record)
	h := sha256.Sum256(encoded)
	record.RecordHash = hex.EncodeToString(h[:])
	l.records = append(l.records, record)
	if err := l.persistLocked(); err != nil {
		l.records = l.records[:len(l.records)-1]
		return ProvenanceRecord{}, err
	}
	return record, nil
}

// Records returns a copy of all records.
func (l *ProvenanceLedger) Records() []ProvenanceRecord {
	l.mu.RLock()
	defer l.mu.RUnlock()
	out := make([]ProvenanceRecord, len(l.records))
	copy(out, l.records)
	return out
}

func (l *ProvenanceLedger) loadLocked() error {
	if l.persistPath == "" {
		return nil
	}
	raw, err := os.ReadFile(l.persistPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read provenance ledger %q: %w", l.persistPath, err)
	}
	if len(raw) == 0 {
		return nil
	}
	var records []ProvenanceRecord
	if err := json.Unmarshal(raw, &records); err != nil {
		return fmt.Errorf("decode provenance ledger %q: %w", l.persistPath, err)
	}
	l.records = records
	return nil
}

func (l *ProvenanceLedger) persistLocked() error {
	if l.persistPath == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(l.persistPath), 0o755); err != nil {
		return fmt.Errorf("create provenance directory: %w", err)
	}
	raw, err := json.MarshalIndent(l.records, "", "  ")
	if err != nil {
		return fmt.Errorf("encode provenance records: %w", err)
	}
	tmp := l.persistPath + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o600); err != nil {
		return fmt.Errorf("write provenance temp file: %w", err)
	}
	if err := os.Rename(tmp, l.persistPath); err != nil {
		return fmt.Errorf("commit provenance file: %w", err)
	}
	return nil
}
