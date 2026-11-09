package test

import "os"

// Allow the legacy empty-proof attestation fallback in tests that predate the
// real ZK commitment wiring. Production code keeps this disabled by default.
func init() {
	os.Setenv("MOHAWK_ALLOW_LEGACY_ATTESTATION", "1")
}