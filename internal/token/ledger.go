package token

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const currentSchemaVersion = 2

// TxType enumerates supported utility coin operations.
type TxType string

const (
	TxMint     TxType = "mint"
	TxTransfer TxType = "transfer"
	TxBurn     TxType = "burn"
	TxMigrate  TxType = "migrate"
)

// Tx records a utility coin ledger event.
type Tx struct {
	Type        TxType    `json:"type"`
	From        string    `json:"from,omitempty"`
	To          string    `json:"to,omitempty"`
	Amount      float64   `json:"amount"`
	AmountUnits int64     `json:"amount_units,omitempty"`
	Memo        string    `json:"memo,omitempty"`
	Timestamp   time.Time `json:"timestamp"`
}

// Asset defines the precision and supply constraints for a utility asset.
type Asset struct {
	Symbol         string `json:"symbol"`
	Decimals       uint8  `json:"decimals"`
	MaxSupplyUnits int64  `json:"max_supply_units,omitempty"`
}

// Ledger is a concurrency-safe in-memory utility coin ledger.
type Ledger struct {
	schemaVersion       int
	asset               Asset
	minter              string
	pqcMigration        bool
	migrationETA        time.Time
	migrationEpoch      time.Time
	requireCryptoEpoch  bool
	lockLegacyTransfers bool
	mu                  sync.RWMutex
	balances            map[string]int64
	txns                []Tx
	totalSupply         int64
	statePath           string
	auditPath           string
	auditPrev           string
	idempotency         map[string]Tx
	nonces              map[string]uint64
	migrations          map[string]string
}

type persistentState struct {
	SchemaVersion       int                `json:"schema_version"`
	Symbol              string             `json:"symbol,omitempty"`
	Asset               Asset              `json:"asset,omitempty"`
	Minter              string             `json:"minter"`
	Balances            map[string]float64 `json:"balances,omitempty"`
	BalancesUnits       map[string]int64   `json:"balances_units,omitempty"`
	Txns                []Tx               `json:"txns"`
	TotalSupply         float64            `json:"total_supply,omitempty"`
	TotalSupplyUnits    int64              `json:"total_supply_units,omitempty"`
	AuditPrev           string             `json:"audit_prev,omitempty"`
	Nonces              map[string]uint64  `json:"nonces,omitempty"`
	PQCMigration        bool               `json:"pqc_migration"`
	MigrationETA        time.Time          `json:"migration_eta,omitempty"`
	MigrationEpoch      time.Time          `json:"migration_epoch,omitempty"`
	RequireCryptoEpoch  bool               `json:"require_crypto_epoch,omitempty"`
	LockLegacyTransfers bool               `json:"lock_legacy_transfers,omitempty"`
	AddressMap          map[string]string  `json:"address_map,omitempty"`
}

type auditRecord struct {
	Hash        string  `json:"hash"`
	PrevHash    string  `json:"prev_hash,omitempty"`
	Type        TxType  `json:"type"`
	From        string  `json:"from,omitempty"`
	To          string  `json:"to,omitempty"`
	Amount      float64 `json:"amount"`
	AmountUnits int64   `json:"amount_units,omitempty"`
	Memo        string  `json:"memo,omitempty"`
	Timestamp   string  `json:"timestamp"`
}

// NewLedger creates a new utility coin ledger.
func NewLedger(symbol string, minter string) *Ledger {
	if strings.TrimSpace(minter) == "" {
		minter = "protocol"
	}
	return &Ledger{
		schemaVersion: currentSchemaVersion,
		asset:         defaultAsset(symbol),
		minter:        strings.TrimSpace(minter),
		pqcMigration:  false,
		balances:      map[string]int64{},
		txns:          make([]Tx, 0, 64),
		idempotency:   map[string]Tx{},
		nonces:        map[string]uint64{},
		migrations:    map[string]string{},
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
	return l.asset.Symbol
}

// Asset returns the configured utility asset metadata.
func (l *Ledger) Asset() Asset {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.asset
}

// Minter returns the authorized minter identity.
func (l *Ledger) Minter() string {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.minter
}

// EnablePQCMigration toggles the dual-signature migration period and optional ETA.
func (l *Ledger) EnablePQCMigration(enabled bool, eta time.Time) {
	l.ConfigurePQCMigration(enabled, eta, false)
}

// ConfigurePQCMigration toggles migration period controls and optional legacy transfer lock.
func (l *Ledger) ConfigurePQCMigration(enabled bool, eta time.Time, lockLegacyTransfers bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.pqcMigration = enabled
	l.lockLegacyTransfers = lockLegacyTransfers
	if eta.IsZero() {
		l.migrationETA = time.Time{}
	} else {
		l.migrationETA = eta.UTC()
	}
}

// ConfigurePQCMigrationEpoch sets migration epoch controls used for cutover enforcement.
func (l *Ledger) ConfigurePQCMigrationEpoch(epoch time.Time, requireCryptoAfterEpoch bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if epoch.IsZero() {
		l.migrationEpoch = time.Time{}
	} else {
		l.migrationEpoch = epoch.UTC()
	}
	l.requireCryptoEpoch = requireCryptoAfterEpoch
}

// PQCMigrationStatus returns migration controls and migration count.
func (l *Ledger) PQCMigrationStatus() map[string]any {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return map[string]any{
		"enabled":               l.pqcMigration,
		"migration_eta":         l.migrationETA,
		"migration_epoch":       l.migrationEpoch,
		"epoch_active":          !l.migrationEpoch.IsZero() && !time.Now().UTC().Before(l.migrationEpoch),
		"require_crypto_epoch":  l.requireCryptoEpoch,
		"lock_legacy_transfers": l.lockLegacyTransfers,
		"mapped":                len(l.migrations),
	}
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
	amountUnits, err := l.amountToUnits(amount)
	if err != nil {
		return Tx{}, err
	}
	if actor == "" {
		actor = l.Minter()
	}
	if actor != l.Minter() {
		return Tx{}, fmt.Errorf("actor %q is not authorized minter", actor)
	}
	if to == "" {
		return Tx{}, fmt.Errorf("to account is required")
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
	if l.asset.MaxSupplyUnits > 0 && l.totalSupply > l.asset.MaxSupplyUnits-amountUnits {
		return Tx{}, fmt.Errorf("mint exceeds max supply for %s", l.asset.Symbol)
	}
	l.balances[to] += amountUnits
	l.totalSupply += amountUnits
	tx := Tx{
		Type:        TxMint,
		To:          to,
		Amount:      l.unitsToAmount(amountUnits),
		AmountUnits: amountUnits,
		Memo:        memo,
		Timestamp:   time.Now().UTC(),
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

// MigrateWithDualSignature moves funds from a legacy account to an ML-DSA account.
func (l *Ledger) MigrateWithDualSignature(legacyAccount string, pqcAccount string, amount float64, memo string, legacySigned bool, pqcSigned bool) (Tx, error) {
	return l.MigrateWithDualSignatureControls(legacyAccount, pqcAccount, amount, memo, legacySigned, pqcSigned, "", 0)
}

// MigrateWithDualSignatureCryptographic moves funds with cryptographic dual-signature verification.
func (l *Ledger) MigrateWithDualSignatureCryptographic(legacyAccount string, pqcAccount string, amount float64, memo string, signatures MigrationSignatureBundle, idempotencyKey string, nonce uint64) (Tx, error) {
	legacyAccount = strings.TrimSpace(legacyAccount)
	pqcAccount = strings.TrimSpace(pqcAccount)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	if legacyAccount == "" || pqcAccount == "" {
		return Tx{}, fmt.Errorf("legacy and pqc accounts are required")
	}
	amountUnits, err := l.amountToUnits(amount)
	if err != nil {
		return Tx{}, err
	}
	digest, err := MigrationSigningDigest(l.Symbol(), legacyAccount, pqcAccount, amountUnits, memo, idempotencyKey, nonce)
	if err != nil {
		return Tx{}, err
	}
	if err := verifyMigrationSignatureBundle(digest, signatures); err != nil {
		return Tx{}, err
	}
	return l.migrateWithDualSignatureUnits(legacyAccount, pqcAccount, amountUnits, memo, idempotencyKey, nonce, true)
}

// MigrateWithDualSignatureControls moves funds from a legacy account to a PQC account with replay/idempotency controls.
func (l *Ledger) MigrateWithDualSignatureControls(legacyAccount string, pqcAccount string, amount float64, memo string, legacySigned bool, pqcSigned bool, idempotencyKey string, nonce uint64) (Tx, error) {
	legacyAccount = strings.TrimSpace(legacyAccount)
	pqcAccount = strings.TrimSpace(pqcAccount)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	if legacyAccount == "" || pqcAccount == "" {
		return Tx{}, fmt.Errorf("legacy and pqc accounts are required")
	}
	if !legacySigned || !pqcSigned {
		return Tx{}, fmt.Errorf("dual-signature authorization required for migration")
	}
	amountUnits, err := l.amountToUnits(amount)
	if err != nil {
		return Tx{}, err
	}
	return l.migrateWithDualSignatureUnits(legacyAccount, pqcAccount, amountUnits, memo, idempotencyKey, nonce, false)
}

func (l *Ledger) migrateWithDualSignatureUnits(legacyAccount string, pqcAccount string, amountUnits int64, memo string, idempotencyKey string, nonce uint64, cryptographic bool) (Tx, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if idempotencyKey != "" {
		if existing, ok := l.idempotency[idempotencyKey]; ok {
			return existing, nil
		}
	}
	if nonce > 0 {
		last := l.nonces[legacyAccount]
		if nonce <= last {
			return Tx{}, fmt.Errorf("replay detected for legacy account %q: nonce %d <= %d", legacyAccount, nonce, last)
		}
		l.nonces[legacyAccount] = nonce
	}
	if !l.pqcMigration {
		return Tx{}, fmt.Errorf("pqc migration period is not enabled")
	}
	if l.requireCryptoEpoch && !cryptographic {
		if !l.migrationEpoch.IsZero() && !time.Now().UTC().Before(l.migrationEpoch) {
			return Tx{}, fmt.Errorf("post-epoch migration requires cryptographic dual signatures")
		}
	}
	if legacyAccount == pqcAccount {
		return Tx{}, fmt.Errorf("legacy and pqc accounts must differ")
	}
	if mapped, exists := l.migrations[legacyAccount]; exists && mapped != pqcAccount {
		return Tx{}, fmt.Errorf("legacy account %q already mapped to %q", legacyAccount, mapped)
	}
	if l.balances[legacyAccount] < amountUnits {
		return Tx{}, fmt.Errorf("insufficient balance in %q", legacyAccount)
	}
	l.balances[legacyAccount] -= amountUnits
	l.balances[pqcAccount] += amountUnits
	l.migrations[legacyAccount] = pqcAccount
	tx := Tx{
		Type:        TxMigrate,
		From:        legacyAccount,
		To:          pqcAccount,
		Amount:      l.unitsToAmount(amountUnits),
		AmountUnits: amountUnits,
		Memo:        memo,
		Timestamp:   time.Now().UTC(),
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

// Burn removes utility coins from an account.
func (l *Ledger) Burn(from string, amount float64, memo string) (Tx, error) {
	return l.BurnWithControls(from, amount, memo, "", 0)
}

// TransferWithControls transfers coins with optional idempotency and nonce replay controls.
func (l *Ledger) TransferWithControls(from string, to string, amount float64, memo string, idempotencyKey string, nonce uint64) (Tx, error) {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(to)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	amountUnits, err := l.amountToUnits(amount)
	if err != nil {
		return Tx{}, err
	}
	if from == "" || to == "" {
		return Tx{}, fmt.Errorf("from and to accounts are required")
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
	if l.lockLegacyTransfers {
		if mapped, ok := l.migrations[from]; ok && mapped != "" {
			return Tx{}, fmt.Errorf("legacy account %q is migration-locked; transfer from %q", from, mapped)
		}
	}
	if l.balances[from] < amountUnits {
		return Tx{}, fmt.Errorf("insufficient balance in %q", from)
	}
	l.balances[from] -= amountUnits
	l.balances[to] += amountUnits
	tx := Tx{
		Type:        TxTransfer,
		From:        from,
		To:          to,
		Amount:      l.unitsToAmount(amountUnits),
		AmountUnits: amountUnits,
		Memo:        memo,
		Timestamp:   time.Now().UTC(),
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

// BurnWithControls burns coins with optional idempotency and nonce replay controls.
func (l *Ledger) BurnWithControls(from string, amount float64, memo string, idempotencyKey string, nonce uint64) (Tx, error) {
	from = strings.TrimSpace(from)
	idempotencyKey = strings.TrimSpace(idempotencyKey)
	amountUnits, err := l.amountToUnits(amount)
	if err != nil {
		return Tx{}, err
	}
	if from == "" {
		return Tx{}, fmt.Errorf("from account is required")
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
	if l.lockLegacyTransfers {
		if mapped, ok := l.migrations[from]; ok && mapped != "" {
			return Tx{}, fmt.Errorf("legacy account %q is migration-locked; burn from %q", from, mapped)
		}
	}
	if l.balances[from] < amountUnits {
		return Tx{}, fmt.Errorf("insufficient balance in %q", from)
	}
	l.balances[from] -= amountUnits
	l.totalSupply -= amountUnits
	tx := Tx{
		Type:        TxBurn,
		From:        from,
		Amount:      l.unitsToAmount(amountUnits),
		AmountUnits: amountUnits,
		Memo:        memo,
		Timestamp:   time.Now().UTC(),
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
	return l.unitsToAmount(l.balances[account])
}

// BalanceUnits returns the raw base-unit balance for an account.
func (l *Ledger) BalanceUnits(account string) int64 {
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
	balancesUnits := make(map[string]int64, len(l.balances))
	for account, amountUnits := range l.balances {
		balances[account] = l.unitsToAmount(amountUnits)
		balancesUnits[account] = amountUnits
	}
	return map[string]any{
		"schema_version":     l.schemaVersion,
		"symbol":             l.asset.Symbol,
		"asset":              l.asset,
		"decimals":           l.asset.Decimals,
		"unit_scale":         unitScale(l.asset.Decimals),
		"minter":             l.minter,
		"total_supply":       l.unitsToAmount(l.totalSupply),
		"total_supply_units": l.totalSupply,
		"balances":           balances,
		"balances_units":     balancesUnits,
		"tx_count":           len(l.txns),
		"audit_prev":         l.auditPrev,
	}
}

// SetAssetPolicy updates the ledger asset policy.
func (l *Ledger) SetAssetPolicy(asset Asset) error {
	normalized := normalizeAsset(asset)
	if normalized.Symbol == "" {
		return fmt.Errorf("asset symbol is required")
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.totalSupply > 0 && !strings.EqualFold(normalized.Symbol, l.asset.Symbol) {
		return fmt.Errorf("cannot change asset symbol with non-zero supply")
	}
	if normalized.MaxSupplyUnits > 0 && normalized.MaxSupplyUnits < l.totalSupply {
		return fmt.Errorf("max supply below current total supply")
	}
	l.asset = normalized
	return l.saveStateLocked()
}

// AmountToUnits converts a decimal amount into integer base units.
func (l *Ledger) AmountToUnits(amount float64) (int64, error) {
	l.mu.RLock()
	asset := l.asset
	l.mu.RUnlock()
	return amountToUnitsForAsset(amount, asset)
}

// UnitsToAmount converts integer base units into a decimal amount.
func (l *Ledger) UnitsToAmount(amountUnits int64) float64 {
	l.mu.RLock()
	asset := l.asset
	l.mu.RUnlock()
	return unitsToAmountForAsset(amountUnits, asset)
}

// Backup copies the current state file to the provided path.
func (l *Ledger) Backup(backupPath string) error {
	l.mu.RLock()
	if strings.TrimSpace(l.statePath) == "" {
		l.mu.RUnlock()
		return fmt.Errorf("backup unavailable: persistent state is not configured")
	}
	state := persistentState{
		SchemaVersion:       currentSchemaVersion,
		Symbol:              l.asset.Symbol,
		Asset:               l.asset,
		Minter:              l.minter,
		Balances:            l.amountBalancesLocked(),
		BalancesUnits:       l.copyBalancesUnitsLocked(),
		Txns:                l.txns,
		TotalSupply:         l.unitsToAmount(l.totalSupply),
		TotalSupplyUnits:    l.totalSupply,
		AuditPrev:           l.auditPrev,
		Nonces:              l.nonces,
		PQCMigration:        l.pqcMigration,
		MigrationETA:        l.migrationETA,
		MigrationEpoch:      l.migrationEpoch,
		RequireCryptoEpoch:  l.requireCryptoEpoch,
		LockLegacyTransfers: l.lockLegacyTransfers,
		AddressMap:          l.migrations,
	}
	l.mu.RUnlock()
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal backup state: %w", err)
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
	needsMigration := state.SchemaVersion != currentSchemaVersion || state.BalancesUnits == nil || (state.TotalSupplyUnits == 0 && state.TotalSupply > 0) || strings.TrimSpace(state.Asset.Symbol) == ""
	l.mu.Lock()
	defer l.mu.Unlock()
	l.applyStateLocked(state)
	if needsMigration {
		return l.saveStateLocked()
	}
	return nil
}

func (l *Ledger) applyStateLocked(state persistentState) {
	if state.SchemaVersion <= 0 {
		state.SchemaVersion = 1
	}
	l.schemaVersion = currentSchemaVersion
	l.asset = normalizeAsset(state.Asset)
	if l.asset.Symbol == "" {
		l.asset = defaultAsset(state.Symbol)
	}
	if strings.TrimSpace(state.Minter) != "" {
		l.minter = strings.TrimSpace(state.Minter)
	}
	if state.BalancesUnits == nil {
		state.BalancesUnits = make(map[string]int64, len(state.Balances))
		for account, amount := range state.Balances {
			amountUnits, err := amountToUnitsForAsset(amount, l.asset)
			if err != nil {
				continue
			}
			state.BalancesUnits[account] = amountUnits
		}
	}
	for index := range state.Txns {
		if state.Txns[index].AmountUnits == 0 && state.Txns[index].Amount > 0 {
			amountUnits, err := amountToUnitsForAsset(state.Txns[index].Amount, l.asset)
			if err == nil {
				state.Txns[index].AmountUnits = amountUnits
			}
		}
		state.Txns[index].Amount = unitsToAmountForAsset(state.Txns[index].AmountUnits, l.asset)
	}
	l.balances = state.BalancesUnits
	l.txns = state.Txns
	if state.TotalSupplyUnits == 0 && state.TotalSupply > 0 {
		amountUnits, err := amountToUnitsForAsset(state.TotalSupply, l.asset)
		if err == nil {
			state.TotalSupplyUnits = amountUnits
		}
	}
	l.totalSupply = state.TotalSupplyUnits
	l.auditPrev = strings.TrimSpace(state.AuditPrev)
	l.pqcMigration = state.PQCMigration
	l.migrationETA = state.MigrationETA.UTC()
	l.migrationEpoch = state.MigrationEpoch.UTC()
	l.requireCryptoEpoch = state.RequireCryptoEpoch
	l.lockLegacyTransfers = state.LockLegacyTransfers
	if state.Nonces == nil {
		state.Nonces = map[string]uint64{}
	}
	l.nonces = state.Nonces
	if state.AddressMap == nil {
		state.AddressMap = map[string]string{}
	}
	l.migrations = state.AddressMap
	l.idempotency = map[string]Tx{}
}

func (l *Ledger) saveStateLocked() error {
	if strings.TrimSpace(l.statePath) == "" {
		return nil
	}
	state := persistentState{
		SchemaVersion:       currentSchemaVersion,
		Symbol:              l.asset.Symbol,
		Asset:               l.asset,
		Minter:              l.minter,
		Balances:            l.amountBalancesLocked(),
		BalancesUnits:       l.copyBalancesUnitsLocked(),
		Txns:                l.txns,
		TotalSupply:         l.unitsToAmount(l.totalSupply),
		TotalSupplyUnits:    l.totalSupply,
		AuditPrev:           l.auditPrev,
		Nonces:              l.nonces,
		PQCMigration:        l.pqcMigration,
		MigrationETA:        l.migrationETA,
		MigrationEpoch:      l.migrationEpoch,
		RequireCryptoEpoch:  l.requireCryptoEpoch,
		LockLegacyTransfers: l.lockLegacyTransfers,
		AddressMap:          l.migrations,
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
		Hash:        hash,
		PrevHash:    l.auditPrev,
		Type:        tx.Type,
		From:        tx.From,
		To:          tx.To,
		Amount:      tx.Amount,
		AmountUnits: tx.AmountUnits,
		Memo:        tx.Memo,
		Timestamp:   tx.Timestamp.UTC().Format(time.RFC3339Nano),
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

func (l *Ledger) amountToUnits(amount float64) (int64, error) {
	return amountToUnitsForAsset(amount, l.asset)
}

func (l *Ledger) unitsToAmount(amountUnits int64) float64 {
	return unitsToAmountForAsset(amountUnits, l.asset)
}

func (l *Ledger) amountBalancesLocked() map[string]float64 {
	balances := make(map[string]float64, len(l.balances))
	for account, amountUnits := range l.balances {
		balances[account] = l.unitsToAmount(amountUnits)
	}
	return balances
}

func (l *Ledger) copyBalancesUnitsLocked() map[string]int64 {
	balances := make(map[string]int64, len(l.balances))
	for account, amountUnits := range l.balances {
		balances[account] = amountUnits
	}
	return balances
}

func defaultAsset(symbol string) Asset {
	asset := normalizeAsset(Asset{Symbol: symbol, Decimals: 6})
	if asset.Symbol == "" {
		asset.Symbol = "MHC"
	}
	return asset
}

func normalizeAsset(asset Asset) Asset {
	asset.Symbol = strings.ToUpper(strings.TrimSpace(asset.Symbol))
	if asset.Decimals == 0 {
		asset.Decimals = 6
	}
	return asset
}

func amountToUnitsForAsset(amount float64, asset Asset) (int64, error) {
	asset = normalizeAsset(asset)
	if math.IsNaN(amount) || math.IsInf(amount, 0) {
		return 0, fmt.Errorf("amount must be finite")
	}
	if amount <= 0 {
		return 0, fmt.Errorf("amount must be > 0")
	}
	formatted := strconv.FormatFloat(amount, 'f', int(asset.Decimals), 64)
	parts := strings.SplitN(formatted, ".", 2)
	whole := parts[0]
	fraction := ""
	if len(parts) == 2 {
		fraction = parts[1]
	}
	if int(asset.Decimals) > 0 {
		fraction = fraction + strings.Repeat("0", int(asset.Decimals)-len(fraction))
	}
	combined := whole + fraction
	amountUnits, err := strconv.ParseInt(combined, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("amount exceeds supported range")
	}
	if amountUnits <= 0 {
		return 0, fmt.Errorf("amount must be > 0")
	}
	return amountUnits, nil
}

func unitsToAmountForAsset(amountUnits int64, asset Asset) float64 {
	asset = normalizeAsset(asset)
	return float64(amountUnits) / float64(unitScale(asset.Decimals))
}

func unitScale(decimals uint8) int64 {
	scale := int64(1)
	for range decimals {
		scale *= 10
	}
	return scale
}
