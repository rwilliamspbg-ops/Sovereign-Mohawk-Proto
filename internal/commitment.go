// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package internal

import (
	"fmt"
	"math/big"
	"strings"
)

// ParseCommitmentHex decodes an optional hex-encoded (optionally
// 0x-prefixed) commitment string into a *big.Int, shared by every
// production call site that accepts a real Groth16 commitment
// (internal/pyapi/api.go's VerifyZKProof/BatchVerifyProofs,
// internal/hybrid/verifier.go's VerifyHybrid). An empty (or
// whitespace-only) string returns (nil, nil) so callers can treat "no
// commitment supplied" and "verify against the legacy genesis identity"
// (VerifyDataCommitmentProof vs. VerifyProof) as the same case; a
// non-empty but malformed string is a real error, not silently ignored, so
// a caller who explicitly asked for commitment-bound verification never
// falls back to weaker genesis-path verification without knowing it.
func ParseCommitmentHex(raw string) (*big.Int, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	hexStr := strings.TrimPrefix(strings.TrimPrefix(raw, "0x"), "0X")
	commitment, ok := new(big.Int).SetString(hexStr, 16)
	if !ok {
		return nil, fmt.Errorf("commitment is not a valid hex-encoded integer")
	}
	return commitment, nil
}
