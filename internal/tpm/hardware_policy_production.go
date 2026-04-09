//go:build production
// +build production

package tpm

func requireHardwareTPMProduction() bool {
	return true
}
