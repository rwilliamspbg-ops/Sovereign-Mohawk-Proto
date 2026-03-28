# TPM Attestation Linux Validation (2026-03-28)

## Environment

- Platform: Linux (dev container)
- Go toolchain: `go1.25.7` (pinned toolchain path)

## Command

```bash
TOOLROOT=/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.25.7.linux-amd64 \
GOROOT=$TOOLROOT PATH=$TOOLROOT/bin:$PATH GOTOOLCHAIN=local \
go test ./test -run 'TestGetVerifiedQuote|TestQuoteRoundTripWithXMSSMode|TestQuoteIncludesSignatureAlgorithm' -count=1
```

## Result

- Status: PASS
- Output: `ok      github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/test 1.067s`

## Covered Checks

- TPM quote retrieval and verify round-trip.
- XMSS mode quote round-trip verification path.
- Attestation signature algorithm metadata emission.
