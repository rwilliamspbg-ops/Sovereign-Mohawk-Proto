#!/bin/bash
# Fix UDP buffer sizes for quic-go (required for large packet handling)
# Reference: https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes

echo "Configuring UDP buffer sizes for quic-go..."

# Linux
if [[ "$OSTYPE" == "linux"* ]]; then
    # Check current settings
    echo "Current rmem_max:"
    cat /proc/sys/net/core/rmem_max
    echo "Current wmem_max:"
    cat /proc/sys/net/core/wmem_max
    
    # Set required buffers (7MB = 7340032 bytes)
    if [[ $EUID -eq 0 ]]; then
        echo "Setting UDP buffers (requires root)..."
        sysctl -w net.core.rmem_max=7340032
        sysctl -w net.core.wmem_max=7340032
        sysctl -w net.core.rmem_default=7340032
        sysctl -w net.core.wmem_default=7340032
        echo "✓ UDP buffers configured"
    else
        echo "⚠ UDP buffer config requires root (sudo). Run with:"
        echo "  sudo sysctl -w net.core.rmem_max=7340032"
        echo "  sudo sysctl -w net.core.wmem_max=7340032"
    fi

# macOS
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS: Setting UDP buffers..."
    sudo sysctl -w net.inet.udp.recvspace=7340032
    sudo sysctl -w net.inet.udp.sendspace=7340032
    echo "✓ UDP buffers configured"

# Windows (WSL)
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "Windows: UDP buffers set in WSL configuration"
    echo "Add to /etc/wsl.conf if using WSL2:"
    echo "[interop.appendWindowsPath]"
    echo "false"
    echo "Windows has default 65KB buffer; this is adequate for test scenarios"

fi

echo "Done."
