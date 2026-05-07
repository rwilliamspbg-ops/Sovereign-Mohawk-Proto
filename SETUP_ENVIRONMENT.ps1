# Sovereign-Mohawk-Proto Test Environment Setup Script
# Configures Go 1.25.9, Python 3, and dependencies for running 228-test suite

param(
    [switch]$SkipGo = $false,
    [switch]$SkipPython = $false,
    [switch]$SkipModules = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host ""
Write-Host "Sovereign-Mohawk-Proto Test Environment Setup" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "Running without administrator privileges. Some installations may fail." -ForegroundColor Yellow
}

# Step 1: Check for Go
Write-Host ""
Write-Host "Step 1: Verifying Go 1.25.9+ Installation" -ForegroundColor Yellow
Write-Host ""

try {
    $goVersion = & go version 2>&1
    if ($goVersion -match "go1\.25") {
        Write-Host "Go 1.25.9+ already installed: $goVersion" -ForegroundColor Green
        $goInstalled = $true
    } else {
        Write-Host "Go installed but wrong version: $goVersion" -ForegroundColor Yellow
        $goInstalled = $false
    }
} catch {
    Write-Host "Go not found in PATH" -ForegroundColor Yellow
    $goInstalled = $false
}

if (-not $goInstalled -and -not $SkipGo) {
    Write-Host ""
    Write-Host "INSTALL GO:" -ForegroundColor Magenta
    Write-Host "1. Download: https://go.dev/dl/go1.25.9.windows-amd64.msi" -ForegroundColor Magenta
    Write-Host "2. Run installer (use default options)" -ForegroundColor Magenta
    Write-Host "3. Restart PowerShell" -ForegroundColor Magenta
    Write-Host "4. Verify: go version" -ForegroundColor Magenta
    Write-Host ""
}

# Step 2: Check Python
Write-Host ""
Write-Host "Step 2: Verifying Python 3 Installation" -ForegroundColor Yellow
Write-Host ""

try {
    $pythonVersion = & python --version 2>&1
    Write-Host "Python installed: $pythonVersion" -ForegroundColor Green
    $pythonInstalled = $true
} catch {
    try {
        $pythonVersion = & python3 --version 2>&1
        Write-Host "Python 3 installed: $pythonVersion" -ForegroundColor Green
        $pythonInstalled = $true
    } catch {
        Write-Host "Python not found in PATH" -ForegroundColor Yellow
        $pythonInstalled = $false
    }
}

if (-not $pythonInstalled -and -not $SkipPython) {
    Write-Host ""
    Write-Host "INSTALL PYTHON (optional):" -ForegroundColor Magenta
    Write-Host "1. Download: https://www.python.org/downloads/" -ForegroundColor Magenta
    Write-Host "2. Run installer" -ForegroundColor Magenta
    Write-Host "3. CHECK: Add Python to PATH" -ForegroundColor Magenta
    Write-Host "4. Verify: python --version" -ForegroundColor Magenta
    Write-Host ""
}

# Step 3: Download Go modules
Write-Host ""
Write-Host "Step 3: Downloading Go Module Dependencies" -ForegroundColor Yellow
Write-Host ""

if ($goInstalled -and -not $SkipModules) {
    try {
        Write-Host "Running: go mod download" -ForegroundColor Blue
        & go mod download
        Write-Host "Go modules downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download modules: $_" -ForegroundColor Red
        Write-Host "Try running manually: go mod download" -ForegroundColor Blue
    }
}

# Step 4: Verify test files exist
Write-Host ""
Write-Host "Step 4: Verifying Test Files" -ForegroundColor Yellow
Write-Host ""

$testFiles = @(
    "internal\phase1_tests.go",
    "internal\phase2_tests.go",
    "internal\phase3_tests.go",
    "internal\phase4_tests.go"
)

$missingTests = @()
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Write-Host "Found: $file" -ForegroundColor Green
    } else {
        Write-Host "Missing: $file" -ForegroundColor Yellow
        $missingTests += $file
    }
}

# Step 5: Summary
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Setup Complete" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""

if ($goInstalled -and $pythonInstalled) {
    Write-Host "All dependencies verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "READY TO RUN TESTS:" -ForegroundColor Cyan
    Write-Host "  Option 1: .\QUICK_START.bat" -ForegroundColor Cyan
    Write-Host "  Option 2: go test ./internal -v -run TestPhase -timeout 600s" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "INSTALLATION REQUIRED:" -ForegroundColor Yellow
    if (-not $goInstalled) {
        Write-Host "  - Go 1.25.9+: https://go.dev/dl/" -ForegroundColor Yellow
    }
    if (-not $pythonInstalled) {
        Write-Host "  - Python 3.11+: https://www.python.org/downloads/" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "After installation, re-run this script or execute:" -ForegroundColor Cyan
    Write-Host "  go test ./internal -v -run TestPhase -timeout 600s" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "DOCUMENTATION:" -ForegroundColor Cyan
Write-Host "  - START_HERE_SETUP.md" -ForegroundColor Cyan
Write-Host "  - ENVIRONMENT_SETUP_GUIDE.md" -ForegroundColor Cyan
Write-Host "  - QUICK_REFERENCE_CARD.txt" -ForegroundColor Cyan
Write-Host ""
