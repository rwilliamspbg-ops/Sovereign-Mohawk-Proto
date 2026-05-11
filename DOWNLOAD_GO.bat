@echo off
REM Download Go 1.25.9 using curl (built-in on Windows 10+)

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║  Go 1.25.9 Download Helper                               ║
echo ║  Using built-in curl                                     ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

set "DOWNLOAD_URL=https://go.dev/dl/go1.25.9.windows-amd64.zip"
set "OUTPUT_FILE=go1.25.9.zip"

echo Downloading Go 1.25.9...
echo From: %DOWNLOAD_URL%
echo To: %OUTPUT_FILE%
echo.
echo This may take 2-3 minutes...
echo.

curl -L -o "%OUTPUT_FILE%" "%DOWNLOAD_URL%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo Download successful!
    echo.
    echo Next steps:
    echo 1. Right-click "%OUTPUT_FILE%" in File Explorer
    echo 2. Select "Extract All..."
    echo 3. Extract to: C:\
    echo    (This creates C:\go)
    echo 4. Add to PATH:
    echo    - Open Settings ^> Environment Variables
    echo    - Click "Edit the system environment variables"
    echo    - Click "Environment Variables..."
    echo    - Under System variables, find "Path", click Edit
    echo    - Click "New"
    echo    - Add: C:\go\bin
    echo    - Click OK on all dialogs
    echo 5. Restart PowerShell/Command Prompt
    echo 6. Verify: go version
    echo.
    pause
) else (
    echo.
    echo Download failed!
    echo.
    echo Manual download:
    echo 1. Visit: https://go.dev/dl/
    echo 2. Download: go1.25.9.windows-amd64.zip
    echo 3. Extract to C:\ (creates C:\go)
    echo 4. Add C:\go\bin to PATH
    echo 5. Restart terminal
    echo 6. Verify: go version
    echo.
    pause
    exit /b 1
)
