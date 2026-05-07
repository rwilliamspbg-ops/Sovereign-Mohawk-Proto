@echo off
REM ═══════════════════════════════════════════════════════════════════
REM Sovereign-Mohawk Environment Quick Setup
REM Downloads and installs Go 1.25.9 and Python 3
REM Run as Administrator
REM ═══════════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║  Environment Setup - Sovereign-Mohawk                    ║
echo ║  Go 1.25.9 + Python 3 Installation Helper               ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Check if running as administrator
for /f "tokens=*" %%A in ('whoami /priv /fo list ^| find /i "SeLoadDriverPrivilege"') do (
    if not "%%A"=="" (
        set ISADMIN=1
    )
)

if "%ISADMIN%"=="" (
    echo WARNING: Not running as Administrator
    echo Some installations may fail without admin privileges
    echo.
    echo To run as Administrator:
    echo   1. Right-click this batch file
    echo   2. Select "Run as administrator"
    echo.
    pause
)

echo.
echo Step 1: Checking current installations...
echo ────────────────────────────────────────

go version >nul 2>&1
if !errorlevel! equ 0 (
    echo ✓ Go is installed
    for /f "tokens=*" %%i in ('go version') do echo   %%i
) else (
    echo ✗ Go not found
)

python --version >nul 2>&1
if !errorlevel! equ 0 (
    echo ✓ Python is installed
    for /f "tokens=*" %%i in ('python --version') do echo   %%i
) else (
    python3 --version >nul 2>&1
    if !errorlevel! equ 0 (
        echo ✓ Python 3 is installed
        for /f "tokens=*" %%i in ('python3 --version') do echo   %%i
    ) else (
        echo ✗ Python not found
    )
)

echo.
echo ════════════════════════════════════════════════════════════
echo.

REM Menu
:menu
echo Select what to install:
echo.
echo 1. Go 1.25.9 (required)
echo 2. Python 3.12 (optional, for analysis)
echo 3. Both
echo 4. Skip installation
echo 0. Exit
echo.

set /p choice="Enter choice (0-4): "

if "%choice%"=="1" goto install_go
if "%choice%"=="2" goto install_python
if "%choice%"=="3" goto install_both
if "%choice%"=="4" goto download_info
if "%choice%"=="0" exit /b 0

echo Invalid choice
goto menu

:install_both
call :install_go
call :install_python
goto finish

:install_go
echo.
echo Downloading Go 1.25.9...
echo (this may take 1-2 minutes)
echo.

REM Use PowerShell for download
powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "$ProgressPreference = 'SilentlyContinue'; " ^
  "Write-Host 'Downloading Go 1.25.9...'; " ^
  "Invoke-WebRequest -Uri 'https://go.dev/dl/go1.25.9.windows-amd64.msi' -OutFile 'go_installer.msi'; " ^
  "Write-Host 'Download complete. Running installer...'; " ^
  "Start-Process 'go_installer.msi' -Wait -ArgumentList '/quiet'; " ^
  "Write-Host 'Go installation complete'"

echo.
echo Testing Go installation...
go version

if !errorlevel! equ 0 (
    echo ✓ Go 1.25.9 installed successfully
) else (
    echo ✗ Go installation may have failed
    echo   Try manual install: https://go.dev/dl/go1.25.9.windows-amd64.msi
)

echo.
goto menu

:install_python
echo.
echo Downloading Python 3.12...
echo (this may take 1-2 minutes)
echo.

powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "$ProgressPreference = 'SilentlyContinue'; " ^
  "Write-Host 'Downloading Python 3.12...'; " ^
  "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.1/python-3.12.1-amd64.exe' -OutFile 'python_installer.exe'; " ^
  "Write-Host 'Download complete. Running installer...'; " ^
  "Start-Process 'python_installer.exe' -Wait -ArgumentList 'InstallAllUsers=1 PrependPath=1 /quiet'; " ^
  "Write-Host 'Python installation complete'"

echo.
echo Testing Python installation...
python --version

if !errorlevel! equ 0 (
    echo ✓ Python installed successfully
) else (
    echo ✗ Python installation may have failed
    echo   Try manual install: https://www.python.org/downloads/
)

echo.
goto menu

:download_info
echo.
echo Manual Download Instructions:
echo ════════════════════════════════════════════════════════════
echo.
echo Go 1.25.9 (REQUIRED):
echo   1. Visit: https://go.dev/dl/
echo   2. Download: go1.25.9.windows-amd64.msi
echo   3. Run installer, use default options
echo   4. Restart terminal
echo.
echo Python 3 (OPTIONAL, for analysis):
echo   1. Visit: https://www.python.org/downloads/
echo   2. Download: Python 3.12 or higher
echo   3. IMPORTANT: Check "Add Python to PATH"
echo   4. Complete installation
echo.
echo After installation, run:
echo   go mod download
echo   go test ./internal -v -run "TestPhase" -timeout 600s
echo.

set /p cont="Press Enter to continue or type 'skip' to exit: "
if /i "%cont%"=="skip" (
    exit /b 0
) else (
    goto menu
)

:finish
echo.
echo ════════════════════════════════════════════════════════════
echo Setup Complete!
echo ════════════════════════════════════════════════════════════
echo.
echo Next steps:
echo   1. Close this window
echo   2. Open PowerShell or Command Prompt
echo   3. Navigate to: C:\Users\rwill\Sovereign-Mohawk-Proto
echo   4. Run: go mod download
echo   5. Run: go test ./internal -v -run "TestPhase" -timeout 600s
echo.
echo Or use the convenient scripts:
echo   - QUICK_START.bat (interactive menu)
echo   - RUN_TESTS.bat (direct test execution)
echo   - SETUP_ENVIRONMENT.ps1 (PowerShell setup)
echo.
pause
exit /b 0
