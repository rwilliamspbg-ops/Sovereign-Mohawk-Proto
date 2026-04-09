//go:build production && (darwin || windows)

package tpm

func requireHardwareTPMProduction() bool {
	return true
}
