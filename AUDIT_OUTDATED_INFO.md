# Outdated Information Audit (main branch)

## Go toolchain version mismatch

- `go.mod` declares: `go 1.27.3`
- Installed toolchain: `go version go1.27.3 windows/amd64`
- README.md:434 says "Go 1.25.9+"
- CONTRIBUTING.md:103 says "requires Go `1.25.9` from go.mod" (contradicts go.mod)
- DEPENDENCIES.md:49 lists "Go 1.25.9"
- docs/FORMAL_VERIFICATION_GUIDE.md references `go 1.25.9`
- docker/formal-verifier/Dockerfile uses `GO_VERSION=1.25.9`
- DOWNLOAD_GO.bat / INSTALL_DEPENDENCIES.bat / QUICK_START.bat reference 1.25.9 downloads

Recommendation: align either go.mod to 1.25.9 (if 1.27.3 is non-standard) or update docs/scripts to 1.27.3. Installed toolchain supports 1.27.3.

## Python SDK version

- VERSION: 2.1.0
- sdk/python mohawk __version__: 2.1.0
- check_version_sync: OK

## Other

- README benchmark TOOLROOT paths reference go1.25.9 toolchain; should match go.mod.
