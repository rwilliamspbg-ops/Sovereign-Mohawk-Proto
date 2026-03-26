param(
    [switch]$Down,
    [switch]$NoBuild
)

$ErrorActionPreference = "Stop"

function Write-Die {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function New-HexToken {
    param([int]$Bytes = 24)
    $buf = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buf)
    return -join ($buf | ForEach-Object { $_.ToString("x2") })
}

function Wait-HttpOk {
    param(
        [string]$Url,
        [int]$Retries = 30,
        [int]$DelaySeconds = 2
    )

    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                return $true
            }
        } catch {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $false
}

if (-not (Test-Command "docker")) {
    Write-Die "docker is required but not installed"
}

try {
    docker info | Out-Null
} catch {
    Write-Die "docker daemon is not reachable"
}

if ($Down) {
    docker compose down
    Write-Host "stack stopped"
    exit 0
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$secretsDir = Join-Path $repoRoot "runtime-secrets"
if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir | Out-Null
}

$tokenPath = Join-Path $secretsDir "mohawk_api_token"
$certPath = Join-Path $secretsDir "mohawk_tpm_ca_cert.pem"
$keyPath = Join-Path $secretsDir "mohawk_tpm_ca_key.pem"

if ((Test-Path $tokenPath) -and (Get-Item $tokenPath).PSIsContainer) {
    Write-Die "runtime-secrets/mohawk_api_token is a directory. Remove it and rerun. Example: Remove-Item -Recurse -Force .\runtime-secrets\mohawk_api_token"
}

if ((Test-Path $certPath) -and (Get-Item $certPath).PSIsContainer) {
    Write-Die "runtime-secrets/mohawk_tpm_ca_cert.pem is a directory. Remove it and rerun."
}

if ((Test-Path $keyPath) -and (Get-Item $keyPath).PSIsContainer) {
    Write-Die "runtime-secrets/mohawk_tpm_ca_key.pem is a directory. Remove it and rerun."
}

$tokenMissing = (-not (Test-Path $tokenPath)) -or ((Get-Item $tokenPath).Length -eq 0)

if ($tokenMissing) {
    if (Test-Path $tokenPath) {
        try {
            $item = Get-Item $tokenPath
            if ($item.IsReadOnly) {
                $item.IsReadOnly = $false
            }
        } catch {
            Write-Die "cannot unlock runtime-secrets/mohawk_api_token. Remove it manually and rerun."
        }
    }

    try {
        Set-Content -Path $tokenPath -Value (New-HexToken 24) -NoNewline -Encoding ascii
        Write-Host "created runtime-secrets/mohawk_api_token"
    } catch {
        Write-Die "cannot write runtime-secrets/mohawk_api_token. Check file ACLs and retry."
    }
}

if ((-not (Test-Path $certPath)) -or (-not (Test-Path $keyPath)) -or ((Get-Item $certPath).Length -eq 0) -or ((Get-Item $keyPath).Length -eq 0)) {
    if (-not (Test-Command "openssl")) {
        Write-Die "openssl is required to create runtime TPM CA secrets. Install openssl or run scripts/launch_full_stack_3_nodes.sh from Git Bash."
    }

    & openssl req -x509 -newkey rsa:3072 `
        -keyout $keyPath `
        -out $certPath `
        -sha256 -days 365 -nodes `
        -subj "/CN=Sovereign-Mohawk TPM Root/O=Sovereign-Mohawk" | Out-Null

    Write-Host "created runtime TPM CA secrets"
}

if (-not $env:MOHAWK_TRANSPORT_KEX_MODE) {
    $env:MOHAWK_TRANSPORT_KEX_MODE = "x25519-mlkem768-hybrid"
}
if (-not $env:MOHAWK_TPM_IDENTITY_SIG_MODE) {
    $env:MOHAWK_TPM_IDENTITY_SIG_MODE = "xmss"
}

$buildFlag = @()
if ($NoBuild) {
    $buildFlag = @("--no-build")
}

& docker compose up -d @buildFlag orchestrator shard-us-east tpm-metrics pyapi-metrics-exporter prometheus grafana ipfs
& docker compose up -d @buildFlag node-agent-1 node-agent-2 node-agent-3

if (-not (Wait-HttpOk "http://localhost:9090/-/healthy" 30 2)) {
    Write-Die "prometheus did not become healthy"
}

if (-not (Wait-HttpOk "http://localhost:3000/api/health" 30 2)) {
    Write-Die "grafana did not become healthy"
}

$agentCount = (docker ps --format "{{.Names}}" | Select-String -Pattern '^node-agent-[1-3]$' -AllMatches).Matches.Count
if ($agentCount -ne 3) {
    docker ps --format "table {{.Names}}`t{{.Status}}"
    Write-Die "expected 3 running node-agent containers, found $agentCount"
}

$orchRunning = docker ps --format "{{.Names}}" | Select-String -Pattern '^orchestrator$' -Quiet
if (-not $orchRunning) {
    Write-Die "orchestrator container is not running"
}

Write-Host "full stack is running with orchestrator + 3 node agents"
Write-Host "grafana: http://localhost:3000"
Write-Host "prometheus: http://localhost:9090"
