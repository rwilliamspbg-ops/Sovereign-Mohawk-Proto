package token

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

const currentSchemaVersion = 1

// TxType enumerates supported utility coin operations.
type TxType string

const (
	TxMint     TxType = "mint"
	TxTransfer TxType = "transfer"
)

// Tx records a utility coin ledger event.
type Tx struct {
	Type      TxType    `json:"type"`
	From      string    `json:"from,omitempty"`
	To        string    `json:"to,omitempty"`
	Amount    float64   `json:"amount"`
	Memo      string    `json:"memo,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

// Ledger is a concurrency-safe in-memory utility coin ledger.
type Ledger struct {
	schemaVersion int
	symbol        string
	minter        string
	mu            sync.RWMutex
	balances      map[string]float64
	txns          []Tx
	totalSupply   float64
	statePath     string
	auditPath     string
	auditPrev     string
	idempotency   map[string]Tx
	nonces        map[string]uint64
}

type persistentState struct {
	SchemaVersion int                `json:"schema_version"`
	Symbol        string             `json:"symbol"`
	Minter        string             `json:"minter"`
	Balances      map[string]float64 `json:"balances"`
	Txns          []Tx               `json:"txns"`
	TotalSupply   float64            `json:"total_supply"`
	AuditPrev     string             `json:"audit_prev,omitempty"`
	Nonces        map[string]uint64  `json:"nonces,omitempty"`
}

type auditRecord struct {
	Hash      string  `json:"hash"`
	PrevHash  string  `json:"prev_hash,omitempty"`
	Type      TxType  `json:"type"`
	From      string  `json:"from,omitempty"`
	To        string  `json:"to,omitempty"`
	Amount    float64 `json:"amount"`
	Memo      string  `json:"memo,omitempty"`
	Timestamp string  `json:"timestamp"`
}

// NewLedger creates a new utility coin ledger.
func NewLedger(symbol string, minter string) *Ledger {
	if strings.TrimSpace(symbol) == "" {
		symbol = "MHC"
	}
	if strings.TrimSpace(minter) == "" {
		minter = "protocol"
	}
	return &Ledger{
		schemaVersion: currentSchemaVersion,
		symbol:        strings.ToUpper(strings.TrimSpace(symbol)),
		minter:        strings.TrimSpace(minter),
		balances:      map[string]float64{},
		txns:          make([]Tx, 0, 64),
		idempotency:   map[string]Tx{},
		nonces:        map[string]uint64{},
	}
}

// NewPersistentLedger creates a ledger backed by a state file and append-only audit log.
func NewPersistentLedger(symbol string, minter string, statePath string, auditPath string) (*Ledger, error) {
	ledger := NewLedger(symbol, minter)
	ledger.statePath = strings.TrimSpace(statePath)
	ledger.auditPath = strings.TrimSpace(auditPath)
	if ledger.statePath == "" {
		return ledger, nil
	}
	if err := ledger.loadState(); err != nil {
		return nil, err
	}
	return ledger, nil
}

// Symbol returns the utility coin ticker.
func (l *Ledger) Symbol() string {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.symbol
}

// Minter returns the authorized minter identity.
func (l *Ledger) Minter() string {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.minter
}

// Mint mints utility coins to the target account.
func (l *Ledger) Mint(actor string, to string, amount float64, memo string) (Tx, error) {
	return l.MintWithControls(actor, to, amount, memo, "", 0)
}

// MintWithControls mints coins with optional idempotency and nonce replay controls.
func (l *Ledger) MintWithControls(actor string, to string, amount float64, memo string, idempotencyKey string, nonce uint64) (Tx, error) {
	actor = strings.TrimSpace(actor)
	to = strings.TrimSpace(to)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	if actor == "" {
		actor = l.Minter()
	}
	if actor != l.Minter() {
		return Tx{}, fmt.Errorf("actor %q is not authorized minter", actor)
	}
	if to == "" {
		return Tx{}, fmt.Errorf("to account is required")
	}
	if amount <= 0 {
		return Tx{}, fmt.Errorf("amount must be > 0")
	}

	l.mu.Lock()
	defer l.mu.Unlock()
	if idempotencyKey != "" {
		if existing, ok := l.idempotency[idempotencyKey]; ok {
			return existing, nil
		}
	}
	if nonce > 0 {
		last := l.nonces[actor]
		if nonce <= last {
			return Tx{}, fmt.Errorf("replay detected for actor %q: nonce %d <= %d", actor, nonce, last)
		}
		l.nonces[actor] = nonce
	}
	l.balances[to] += amount
	l.totalSupply += amount
	tx := Tx{
		Type:      TxMint,
		To:        to,
		Amount:    amount,
		Memo:      memo,
		Timestamp: time.Now().UTC(),
	}
	l.txns = append(l.txns, tx)
	if idempotencyKey != "" {
		l.idempotency[idempotencyKey] = tx
	}
	if err := l.appendAuditLocked(tx); err != nil {
		return Tx{}, err
	}
	if err := l.saveStateLocked(); err != nil {
		return Tx{}, err
	}
	return tx, nil
}

// Transfer moves utility coins between accounts.
func (l *Ledger) Transfer(from string, to string, amount float64, memo string) (Tx, error) {
	return l.TransferWithControls(from, to, amount, memo, "", 0)
}

// TransferWithControls transfers coins with optional idempotency and nonce replay controls.
func (l *Ledger) TransferWithControls(from string, to string, amount float64, memo string, idempotencyKey string, nonce uint64) (Tx, error) {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(to)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	if from == "" || to == "" {
		return Tx{}, fmt.Errorf("from and to accounts are required")
	}
	if amount <= 0 {
		return Tx{}, fmt.Errorf("amount must be > 0")
	}

	l.mu.Lock()
	defer l.mu.Unlock()
	if idempotencyKey != "" {
		if existing, ok := l.idempotency[idempotencyKey]; ok {
			return existing, nil
		}
	}
	if nonce > 0 {
		last := l.nonces[from]
		if nonce <= last {
			return Tx{}, fmt.Errorf("replay detected for account %q: nonce %d <= %d", from, nonce, last)
		}
		l.nonces[from] = nonce
	}
	if l.balances[from] < amount {
		return Tx{}, fmt.Errorf("insufficient balance in %q", from)
	}
	l.balances[from] -= amount
	l.balances[to] += amount
	tx := Tx{
		Type:      TxTransfer,
		From:      from,
		To:        to,
		Amount:    amount,
		Memo:      memo,
		Timestamp: time.Now().UTC(),
	}
	l.txns = append(l.txns, tx)
	if idempotencyKey != "" {
		l.idempotency[idempotencyKey] = tx
	}
	if err := l.appendAuditLocked(tx); err != nil {
		return Tx{}, err
	}
	if err := l.saveStateLocked(); err != nil {
		return Tx{}, err
	}
	return tx, nil
}

// Balance returns account utility coin balance.
func (l *Ledger) Balance(account string) float64 {
	account = strings.TrimSpace(account)
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.balances[account]
}

// Snapshot returns ledger metadata and balances copy.
func (l *Ledger) Snapshot() map[string]any {
	l.mu.RLock()
	defer l.mu.RUnlock()
	balances := make(map[string]float64, len(l.balances))
	for account, amount := range l.balances {
		balances[account] = amount
	}
	return map[string]any{
		"schema_version": l.schemaVersion,
		"symbol":         l.symbol,
		"minter":         l.minter,
		"total_supply":   l.totalSupply,
		"balances":       balances,
		"tx_count":       len(l.txns),
		"audit_prev":     l.auditPrev,
	}
}

// Backup copies the current state file to the provided path.
func (l *Ledger) Backup(backupPath string) error {
	l.mu.RLock()
	statePath := l.statePath
	l.mu.RUnlock()
	if strings.TrimSpace(statePath) == "" {
		return fmt.Errorf("backup unavailable: persistent state is not configured")
	}
	data, err := os.ReadFile(statePath)
	if err != nil {
		return fmt.Errorf("read state for backup: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(backupPath), 0o755); err != nil {
		return fmt.Errorf("ensure backup dir: %w", err)
	}
	if err := os.WriteFile(backupPath, data, 0o600); err != nil {
		return fmt.Errorf("write backup: %w", err)
	}
	return nil
}

// Restore replaces ledger state with a backup file and persists it.
func (l *Ledger) Restore(backupPath string) error {
	data, err := os.ReadFile(backupPath)
	if err != nil {
		return fmt.Errorf("read backup: %w", err)
	}
	var state persistentState
	if err := json.Unmarshal(data, &state); err != nil {
		return fmt.Errorf("parse backup state: %w", err)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	l.applyStateLocked(state)
	return l.saveStateLocked()
}

func (l *Ledger) loadState() error {
	if strings.TrimSpace(l.statePath) == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(l.statePath), 0o755); err != nil {
		return fmt.Errorf("ensure state dir: %w", err)
	}
	if strings.TrimSpace(l.auditPath) != "" {
		if err := os.MkdirAll(filepath.Dir(l.auditPath), 0o755); err != nil {
			return fmt.Errorf("ensure audit dir: %w", err)
		}
	}
	raw, err := os.ReadFile(l.statePath)
	if err != nil {
		if os.IsNotExist(err) {
			return l.saveStateLocked()
		}
		return fmt.Errorf("read state: %w", err)
	}
	var state persistentState
	if err := json.Unmarshal(raw, &state); err != nil {
		return fmt.Errorf("parse state: %w", err)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	l.applyStateLocked(state)
	return nil
}

func (l *Ledger) applyStateLocked(state persistentState) {
	if state.SchemaVersion <= 0 {
		state.SchemaVersion = 1
	}
	l.schemaVersion = currentSchemaVersion
	if strings.TrimSpace(state.Symbol) != "" {
		l.symbol = strings.ToUpper(strings.TrimSpace(state.Symbol))
	}
	if strings.TrimSpace(state.Minter) != "" {
		l.minter = strings.TrimSpace(state.Minter)
	}
	if state.Balances == nil {
		state.Balances = map[string]float64{}
	}
	l.balances = state.Balances
	l.txns = state.Txns
	l.totalSupply = state.TotalSupply
	l.auditPrev = strings.TrimSpace(state.AuditPrev)
	if state.Nonces == nil {
		state.Nonces = map[string]uint64{}
	}
	l.nonces = state.Nonces
	l.idempotency = map[string]Tx{}
}

func (l *Ledger) saveStateLocked() error {
	if strings.TrimSpace(l.statePath) == "" {
		return nil
	}
	state := persistentState{
		SchemaVersion: currentSchemaVersion,
		Symbol:        l.symbol,
		Minter:        l.minter,
		Balances:      l.balances,
		Txns:          l.txns,
		TotalSupply:   l.totalSupply,
		AuditPrev:     l.auditPrev,
		Nonces:        l.nonces,
	}
	raw, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal state: %w", err)
	}
	return os.WriteFile(l.statePath, raw, 0o600)
}

func (l *Ledger) appendAuditLocked(tx Tx) error {
	if strings.TrimSpace(l.auditPath) == "" {
		return nil
	}
	canonical, err := json.Marshal(tx)
	if err != nil {
		return fmt.Errorf("marshal tx for audit: %w", err)
	}
	sum := sha256.Sum256(append([]byte(l.auditPrev), canonical...))
	hash := hex.EncodeToString(sum[:])
	rec := auditRecord{
		Hash:      hash,
		PrevHash:  l.auditPrev,
		Type:      tx.Type,
		From:      tx.From,
		To:        tx.To,
		Amount:    tx.Amount,
		Memo:      tx.Memo,
		Timestamp: tx.Timestamp.UTC().Format(time.RFC3339Nano),
	}
	line, err := json.Marshal(rec)
	if err != nil {
		return fmt.Errorf("marshal audit record: %w", err)
	}
	f, err := os.OpenFile(l.auditPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return fmt.Errorf("open audit log: %w", err)
	}
	defer f.Close()
	if _, err := f.Write(append(line, '\n')); err != nil {
		return fmt.Errorf("append audit log: %w", err)
	}
	l.auditPrev = hash
	return nil
}
