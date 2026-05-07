@echo off
REM ═══════════════════════════════════════════════════════════════════
REM Sovereign-Mohawk-Proto: Quick Start Test Runner
REM 228 Tests | 4 Phases | 15-18 min runtime | ≥90% pass target
REM ═══════════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║  Sovereign-Mohawk Test Suite Quick Start                 ║
echo ║  228 Tests | 4 Phases | 15-18 min                        ║
echo ║  Expected Pass Rate: ≥90%% (205/228)                     ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Check if Go is installed
go version >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Go not found in PATH
    echo.
    echo Install Go 1.25.9+ from: https://go.dev/dl/
    echo After installation, restart this terminal
    echo.
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "go.mod" (
    echo ERROR: go.mod not found
    echo.
    echo Make sure you run this from:
    echo   C:\Users\rwill\Sovereign-Mohawk-Proto
    echo.
    pause
    exit /b 1
)

REM Menu
:menu
echo.
echo ════════════════════════════════════════════════════════════
echo Select Test Suite to Run:
echo ════════════════════════════════════════════════════════════
echo.
echo 1. All Tests (228 tests, 15-18 min) - RECOMMENDED
echo 2. Phase 1 Only (65 tests, 2-3 min) - Data, Nodes, Network
echo 3. Phase 2 Only (60 tests, 3-5 min) - Sparse, Quantization, DP
echo 4. Phase 3 Only (48 tests, 2-4 min) - Theoretical
echo 5. Phase 4 Only (55 tests, 3-5 min) - Production
echo 6. Check Environment
echo 0. Exit
echo.

set /p choice="Enter choice (0-6): "

if "%choice%"=="1" goto runall
if "%choice%"=="2" goto phase1
if "%choice%"=="3" goto phase2
if "%choice%"=="4" goto phase3
if "%choice%"=="5" goto phase4
if "%choice%"=="6" goto check
if "%choice%"=="0" goto end

echo Invalid choice. Please try again.
goto menu

:runall
cls
echo ════════════════════════════════════════════════════════════
echo Running: All 228 Tests (4 Phases)
echo Timeout: 600 seconds (10 minutes)
echo Expected: 15-18 minutes total
echo Pass Rate Target: ≥90%% (205/228)
echo ════════════════════════════════════════════════════════════
echo.
go test ./internal -v -run "TestPhase" -timeout 600s
goto results

:phase1
cls
echo ════════════════════════════════════════════════════════════
echo Running: Phase 1 Only (65 tests)
echo Focus: Data Loading, Node Distribution, Network, Byzantine
echo Timeout: 120 seconds
echo Expected: 2-3 minutes
echo Pass Rate Target: 90.8%% (59/65)
echo ════════════════════════════════════════════════════════════
echo.
go test ./internal -v -run "TestPhase1" -timeout 120s
goto results

:phase2
cls
echo ════════════════════════════════════════════════════════════
echo Running: Phase 2 Only (60 tests)
echo Focus: Sparse, Quantization, Aggregation, DP-SGD, Async
echo Timeout: 180 seconds
echo Expected: 3-5 minutes
echo Pass Rate Target: 90.0%% (54/60)
echo ════════════════════════════════════════════════════════════
echo.
go test ./internal -v -run "TestPhase2" -timeout 180s
goto results

:phase3
cls
echo ════════════════════════════════════════════════════════════
echo Running: Phase 3 Only (48 tests)
echo Focus: Theoretical Validation, Bounds, Composition
echo Timeout: 180 seconds
echo Expected: 2-4 minutes
echo Pass Rate Target: 89.6%% (43/48)
echo ════════════════════════════════════════════════════════════
echo.
go test ./internal -v -run "TestPhase3" -timeout 180s
goto results

:phase4
cls
echo ════════════════════════════════════════════════════════════
echo Running: Phase 4 Only (55 tests)
echo Focus: Production, Monitoring, Logging, Config, Checkpointing
echo Timeout: 180 seconds
echo Expected: 3-5 minutes
echo Pass Rate Target: 89.1%% (49/55)
echo ════════════════════════════════════════════════════════════
echo.
go test ./internal -v -run "TestPhase4" -timeout 180s
goto results

:check
cls
call CHECK_ENVIRONMENT.bat
goto menu

:results
echo.
echo ════════════════════════════════════════════════════════════
if %ERRORLEVEL% equ 0 (
    echo RESULT: PASSED ✓
) else (
    echo RESULT: SOME TESTS FAILED (Exit Code: %ERRORLEVEL%)
)
echo ════════════════════════════════════════════════════════════
echo.
echo Next Steps:
echo   1. Review test output above
echo   2. For detailed analysis, see DETAILED_TEST_EXECUTION_REPORT.md
echo   3. To run other tests, press any key to continue
echo.
pause
goto menu

:end
echo.
echo Goodbye!
echo For more info, see: ENVIRONMENT_SETUP_GUIDE.md
echo.
exit /b 0
