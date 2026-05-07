@echo off
REM Sovereign-Mohawk Environment Status Check
REM Quickly verify if your system is ready to run the test suite

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║  Environment Status Check                                 ║
echo ║  Sovereign-Mohawk-Proto Test Suite                        ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Check Go
echo Checking Go...
go version >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%i in ('go version') do (
        echo   ✓ %%i
    )
) else (
    echo   ✗ Go not found
    echo     Install from: https://go.dev/dl/
)

REM Check Python
echo.
echo Checking Python...
python --version >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%i in ('python --version') do (
        echo   ✓ %%i
    )
) else (
    python3 --version >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=*" %%i in ('python3 --version') do (
            echo   ✓ %%i
        )
    ) else (
        echo   ✗ Python not found
        echo     Install from: https://www.python.org/downloads/
    )
)

REM Check current directory
echo.
echo Checking project directory...
if exist "go.mod" (
    echo   ✓ go.mod found
) else (
    echo   ✗ go.mod not found
    echo     Make sure you're in: C:\Users\rwill\Sovereign-Mohawk-Proto
)

REM Check test files
echo.
echo Checking test files...
if exist "internal\phase1_tests.go" (
    echo   ✓ phase1_tests.go
) else (
    echo   ✗ phase1_tests.go missing
)

if exist "internal\phase2_tests.go" (
    echo   ✓ phase2_tests.go
) else (
    echo   ✗ phase2_tests.go missing
)

if exist "internal\phase3_tests.go" (
    echo   ✓ phase3_tests.go
) else (
    echo   ✗ phase3_tests.go missing
)

if exist "internal\phase4_tests.go" (
    echo   ✓ phase4_tests.go
) else (
    echo   ✗ phase4_tests.go missing
)

REM Check modules
echo.
echo Checking Go modules...
go list -m all >nul 2>&1
if !errorlevel! equ 0 (
    echo   ✓ Go modules configured
) else (
    echo   ✗ Run: go mod download
)

REM Summary
echo.
echo ════════════════════════════════════════════════════════════
echo.
echo If all checks passed, you can run:
echo   go test ./internal -v -run "TestPhase" -timeout 600s
echo.
echo Or use the setup scripts:
echo   powershell -File RUN_TESTS.ps1
echo   RUN_TESTS.bat
echo.
echo For more info, see: ENVIRONMENT_SETUP_GUIDE.md
echo.
pause
