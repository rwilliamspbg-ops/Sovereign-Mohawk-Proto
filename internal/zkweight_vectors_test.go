package internal

import (
	"math/big"
	"testing"
)

// TestMimcFieldVectors pins the off-circuit MiMC chain used by
// DeriveWeightStatement. These literals are regression anchors: they encode both
// gnark-crypto's byte order (big-endian, one 32-byte block per Write call) and
// this file's one-element-per-Write convention. If either changes, this test
// fails rather than silently producing a different public statement.
//
// The in-circuit hash is a different object; TestWeightProof_HonestRoundTrips
// (test/zkweight_circuit_test.go) pins the two together by proving and verifying
// a real Groth16 proof and re-deriving the statement off-circuit.
func TestMimcFieldVectors(t *testing.T) {
	cases := []struct {
		name   string
		values []*big.Int
		want   string
	}{
		{"empty", nil, "0"},
		{"zero", []*big.Int{big.NewInt(0)},
			"2c7298fd87d3039ffea208538f6b297b60b373a63792b4cd0654fdc88fd0d6ee"},
		{"one", []*big.Int{big.NewInt(1)},
			"27e5458b666ef581475a9acddbc3524ca252185cae3936506e65cda9c358222b"},
		{"one_two", []*big.Int{big.NewInt(1), big.NewInt(2)},
			"7f751d627280b8f73ebe288d68acd77dc2fd6962debda017df192e355065814"},
		{"model_seed", []*big.Int{big.NewInt(0x1234567), big.NewInt(7)},
			"1937517616cc61d4e4585947117da78456ded3cc7f9de826bf19d390e74d8cae"},
	}

	for _, tc := range cases {
		got, err := mimcFields(tc.values...)
		if err != nil {
			t.Fatalf("%s: mimcFields: %v", tc.name, err)
		}
		want, ok := new(big.Int).SetString(tc.want, 16)
		if !ok {
			t.Fatalf("%s: bad test literal %q", tc.name, tc.want)
		}
		if got.Cmp(want) != 0 {
			t.Errorf("%s: MiMC chain drift\nlength : got %d, want %d\ngot  : %064x\nwant : %064x",
				tc.name, got.BitLen(), want.BitLen(), got, want)
		}
	}
}
