//go:build linux && has_tpm
// +build linux,has_tpm

package tpm

func hasHardwareTPMBuild() bool {
	return true
}
