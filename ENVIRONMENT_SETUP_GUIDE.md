# Sovereign-Mohawk-Proto: Test Environment Setup Guide

## Quick Setup (5 minutes)

### Option 1: Automated Setup Script (Recommended)

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File SETUP_ENVIRONMENT.ps1
```

This script will:
- Verify Go 1.25.9+ installation
- Verify Python 3 installation  
- Download Go module dependencies
- Create test execution scripts
- Provide next steps

### Option 2: Manual Setup

#### 1. Install Go 1.25.9+

**Windows:**
1. Download: https://go.dev/dl/go1.25.9.windows-amd64.msi
2. Run installer, select default options
3. Restart PowerShell/cmd to refresh PATH
4. Verify: `go version` (should show go1.25.9 or higher)

**Alternative (Chocolatey):**
```powershell
choco install golang --version=1.25.9
```

#### 2. Install Python 3

**Windows:**
1. Download: https://www.python.org/downloads/ (3.11+ recommended)
2. Run installer
3. **IMPORTANT:** Check "Add Python to PATH" during installation
4. Verify: `python --version` or `python3 --version`

**Alternative (Chocolatey):**
```powershell
choco install python
```

#### 3. Download Go Dependencies

```powershell
cd C:\Users\rwill\Sovereign-Mohawk-Proto
go mod download
```

---

## Running the Tests

### Quick Command (All 228 tests)

```powershell
go test ./internal -v -run "TestPhase" -timeout 600s
```

**Expected:**
- Runtime: 15-18 minutes
- Pass Rate: ≥90% (205/228 tests)
- Exit Code: 0 (success)

### Using Provided Scripts

```powershell
# PowerShell
.\RUN_TESTS.ps1

# Or Command Prompt
RUN_TESTS.bat
```

### Run Specific Phases

```powershell
# Phase 1: Data Loading, Node Distribution, Network, Byzantine (65 tests)
go test ./internal -v -run "TestPhase1" -timeout 120s

# Phase 2: Sparse, Quantization, Aggregation, DP-SGD, Async (60 tests)
go test ./internal -v -run "TestPhase2" -timeout 180s

# Phase 3: Theoretical Validation (48 tests)
go test ./internal -v -run "TestPhase3" -timeout 180s

# Phase 4: Production Readiness (55 tests)
go test ./internal -v -run "TestPhase4" -timeout 180s
```

---

## Environment Verification

### Checklist

- [ ] Go 1.25.9+ installed (`go version`)
- [ ] Python 3 installed (`python --version`)
- [ ] Project directory: `C:\Users\rwill\Sovereign-Mohawk-Proto`
- [ ] Go modules cached: `go list -m all` shows 50+ dependencies
- [ ] Test files present:
  - `internal/phase1_tests.go`
  - `internal/phase2_tests.go`
  - `internal/phase3_tests.go`
  - `internal/phase4_tests.go`

### Verification Commands

```powershell
# Check Go
go version
go env GOROOT

# Check Python
python --version

# Check Go modules cached
go list -m all | Measure-Object

# Check test files
Get-Item internal/phase*_tests.go

# Build check (no run)
go test -compile-only ./internal
```

---

## Test Suite Overview

### 228 Total Tests Organized in 4 Phases

| Phase | Tests | Duration | Pass Target | Focus Area |
|-------|-------|----------|-------------|-----------|
| Phase 1 | 65 | 2-3 min | 90.8% | Foundational (data, nodes, network, Byzantine) |
| Phase 2 | 60 | 3-5 min | 90.0% | Advanced (sparse, quantization, DP-SGD, async) |
| Phase 3 | 48 | 2-4 min | 89.6% | Theoretical (bounds, composition, staleness) |
| Phase 4 | 55 | 3-5 min | 89.1% | Production (monitoring, logging, config) |
| **Total** | **228** | **15-18 min** | **≥90%** | **Complete validation** |

---

## Documentation References

Start with these documents in order:

1. **Quick Start** → `00_TEST_EXECUTION_START_HERE.md`
   - Commands to execute all tests
   - Expected results overview
   - Quick links

2. **Detailed Report** → `DETAILED_TEST_EXECUTION_REPORT.md`
   - 228 tests with expected outcomes
   - Metrics and targets per phase
   - Quality assessment

3. **Summary** → `TEST_EXECUTION_REPORT_SUMMARY.md`
   - Executive summary
   - Key metrics
   - Pass rate targets

4. **Execution Guide** → `TEST_EXECUTION_COMPARISON_FRAMEWORK.md`
   - How to interpret results
   - Variance analysis framework
   - Comparison checklist

---

## Troubleshooting

### "go: command not found"
- Go not installed or not in PATH
- Solution: Install from https://go.dev/dl/, then restart terminal
- Verify: `go version`

### "python: command not found"
- Python not installed or not in PATH
- Solution: Install from https://python.org/, ensure "Add to PATH" is checked
- Verify: `python --version` or `python3 --version`

### Tests timeout (>22 min)
- System resources may be limited
- Solution: Run single phase at a time with lower timeout
- Example: `go test ./internal -v -run "TestPhase1" -timeout 180s`

### "Module not found" errors
- Go modules not downloaded
- Solution: Run `go mod download`
- Verify: `go list -m all`

### Tests fail with "connection refused"
- Network simulation tests may need resources
- Solution: Run with single test mode: `go test ./internal -v -run "TestName"`

### Port/resource conflicts
- Check for existing processes
- Solution: `netstat -ano` (Windows) to find port usage
- Kill conflicting processes if safe

---

## Performance Tips

### For Faster Test Runs
1. **Run single phase** instead of all tests
2. **Increase timeout** for slower systems: `-timeout 900s`
3. **Disable verbose output**: Remove `-v` flag (faster but less detail)
4. **Close other applications** to free resources
5. **Run during off-peak hours** to avoid resource contention

### For System Resources
- Tests are memory-intensive (multi-node simulation)
- Minimum: 4GB RAM, 4 cores
- Recommended: 8GB RAM, 8 cores
- SSD preferred for faster I/O

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: 1.25.9
      
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      
      - name: Download dependencies
        run: go mod download
      
      - name: Run tests
        run: go test ./internal -v -run "TestPhase" -timeout 600s
```

---

## Next Steps

After environment setup:

1. **Run initial test**: `go test ./internal -v -run "TestPhase" -timeout 600s`
2. **Review results**: Compare against `DETAILED_TEST_EXECUTION_REPORT.md`
3. **Analyze failures** (if any): Check `00_TEST_EXECUTION_START_HERE.md`
4. **Set up monitoring**: See deployment guide for production setup

---

## Support & Questions

For issues, refer to:
- **Test Details**: `DETAILED_TEST_EXECUTION_REPORT.md`
- **Metrics**: `COMPLETE_TEST_SUMMARY.md`
- **CI/CD**: `CI_WORKFLOW_COMPATIBILITY_REPORT.md`
- **Deployment**: `DEPLOYMENT_GUIDE_GENESIS_TO_PRODUCTION.md`

---

**Status:** Ready for test execution  
**Last Updated:** 2026-04-17  
**Test Count:** 228 (4 phases)  
**Expected Duration:** 15-18 minutes  
**Acceptance Criteria:** ≥90% pass rate
