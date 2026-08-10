package main

import (
	"fmt"
	"strings"
)

func pickDialableAddr(addrs []string) (string, error) {
	if len(addrs) == 0 {
		return "", fmt.Errorf("no addresses available")
	}
	for _, addr := range addrs {
		if strings.Contains(addr, "127.0.0.1") || strings.Contains(addr, "/ip6/") || strings.Contains(addr, "::1") {
			continue
		}
		return addr, nil
	}
	return addrs[0], nil
}
