// Package mpc implements a minimal additive secret-sharing multi-party
// computation (MPC) aggregator. It is the P4.3 precursor: a (n,n) additive
// scheme where each party splits its gradient vector into n shares (one per
// party), each party sums the shares it receives, and the resulting per-party
// partial sum is broadcast. The global aggregate is the sum of all partial
// sums — no single party ever sees another party's plaintext update.
//
// Scope: additive (n,n) sharing over float64. Production should move to
// fixed-point or field arithmetic and a (t,n) threshold scheme.
package mpc

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"math"
)

// PartyID identifies a participant.
type PartyID string

// Share is one additive share of a vector held by one party.
type Share struct {
	From PartyID
	To   PartyID
	Data []float64
}

// SplitVector splits value into n additive shares that sum to value (exact
// in IEEE-754 for the values we handle). The first n-1 shares are random;
// the last is the residual.
func SplitVector(value []float64, n int, rng func() float64) ([][]float64, error) {
	if n < 2 {
		return nil, fmt.Errorf("mpc: need at least 2 parties, got %d", n)
	}
	if len(value) == 0 {
		return nil, fmt.Errorf("mpc: empty vector")
	}
	shares := make([][]float64, n)
	for i := range shares {
		shares[i] = make([]float64, len(value))
	}
	for j := range value {
		// n-1 random shares
		sum := 0.0
		for i := 0; i < n-1; i++ {
			r := rng()
			shares[i][j] = r
			sum += r
		}
		shares[n-1][j] = value[j] - sum
	}
	return shares, nil
}

// DefaultRNG returns a crypto-backed float64 in (-1,1).
func DefaultRNG() float64 {
	var b [8]byte
	_, _ = rand.Read(b[:])
	u := binary.LittleEndian.Uint64(b[:])
	// map to (-1,1)
	return (float64(u)/float64(math.MaxUint64))*2 - 1
}

// Aggregate sums a list of vectors element-wise.
func Aggregate(vecs [][]float64) ([]float64, error) {
	if len(vecs) == 0 {
		return nil, fmt.Errorf("mpc: no vectors to aggregate")
	}
	dim := len(vecs[0])
	for _, v := range vecs {
		if len(v) != dim {
			return nil, fmt.Errorf("mpc: dimension mismatch: %d vs %d", len(v), dim)
		}
	}
	out := make([]float64, dim)
	for _, v := range vecs {
		for i := range v {
			out[i] += v[i]
		}
	}
	return out, nil
}

// Coordinator runs an (n,n) additive MPC aggregation round.
type Coordinator struct {
	Parties []PartyID
}

// NewCoordinator builds a coordinator for the given parties.
func NewCoordinator(parties []PartyID) *Coordinator {
	return &Coordinator{Parties: parties}
}

// Round executes one MPC aggregation round. Each party provides its private
// vector; the function returns the global aggregate. Internally it simulates
// the message passing; in production the shares would be exchanged over the
// network.
func (c *Coordinator) Round(inputs map[PartyID][]float64) ([]float64, error) {
	n := len(c.Parties)
	if n < 2 {
		return nil, fmt.Errorf("mpc: need at least 2 parties")
	}
	for _, p := range c.Parties {
		if _, ok := inputs[p]; !ok {
			return nil, fmt.Errorf("mpc: missing input for %s", p)
		}
	}

	// Each party splits its vector into n shares.
	allShares := make([][][]float64, n) // [party][shareIndex][dim]
	for i, p := range c.Parties {
		sh, err := SplitVector(inputs[p], n, DefaultRNG)
		if err != nil {
			return nil, err
		}
		allShares[i] = sh
	}

	// Each party j receives share j from every party and sums them.
	partialSums := make([][]float64, n)
	for j := range c.Parties {
		received := make([][]float64, n)
		for i := range c.Parties {
			received[i] = allShares[i][j]
		}
		ps, err := Aggregate(received)
		if err != nil {
			return nil, err
		}
		partialSums[j] = ps
	}

	// Global aggregate = sum of partial sums.
	return Aggregate(partialSums)
}
