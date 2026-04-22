# Lean Formalization Test Runner
# Runs all Lean theorem verifications and captures results

$testDir = "C:\Users\rwill\Sovereign-Mohawk-Proto\proofs"
$resultsDir = "C:\Users\rwill\Sovereign-Mohawk-Proto\test-results"
$resultsFile = "$resultsDir\lean_formalization_results.txt"

# Create results directory
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

# Start test run
$startTime = Get-Date
$output = @()
$output += "=== LEAN FORMALIZATION TEST RESULTS ==="
$output += "Test Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += "Target Directory: $testDir"
$output += ""

# Check Lean installation
$output += "--- Environment Check ---"
try {
    $leanPath = (Get-Command lean -ErrorAction SilentlyContinue).Source
    if ($leanPath) {
        $output += "[FOUND] Lean at: $leanPath"
        $leanVersion = & lean --version 2>&1
        $output += "[VERSION] $leanVersion"
    }
    else {
        $output += "[NOT FOUND] Lean not in PATH"
    }
}
catch {
    $output += "[ERROR] Lean check failed: $_"
}

try {
    $lakePath = (Get-Command lake -ErrorAction SilentlyContinue).Source
    if ($lakePath) {
        $output += "[FOUND] Lake at: $lakePath"
    }
    else {
        $output += "[NOT FOUND] Lake (Lean build tool) not in PATH"
    }
}
catch {
    $output += "[ERROR] Lake check failed"
}

$output += ""
$output += "--- Project Structure ---"

# List Lean files
$leanFiles = Get-ChildItem -Path "$testDir\LeanFormalization" -Filter "*.lean" -Recurse -ErrorAction SilentlyContinue
if ($leanFiles) {
    $output += "Lean files found: $($leanFiles.Count)"
    foreach ($file in $leanFiles) {
        $relPath = $file.FullName -replace [regex]::Escape($testDir), ""
        $lineCount = (Get-Content $file.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        $output += "  > $relPath ($lineCount lines)"
    }
}
else {
    $output += "No Lean files found in LeanFormalization directory"
}

$output += ""
$output += "--- Theorem Inventory ---"

# Parse theorem definitions from Lean files
$theorems = @()
foreach ($file in $leanFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    
    # Extract theorem declarations
    $theoremMatches = [regex]::Matches($content, "theorem\s+(\w+)")
    foreach ($match in $theoremMatches) {
        $theorems += @{
            Name = $match.Groups[1].Value
            File = $file.Name
        }
    }
    
    # Extract def declarations
    $defMatches = [regex]::Matches($content, "def\s+(\w+)")
    foreach ($match in $defMatches) {
        $theorems += @{
            Name = $match.Groups[1].Value
            File = $file.Name
            Type = "definition"
        }
    }
}

if ($theorems.Count -gt 0) {
    $output += "Total definitions/theorems: $($theorems.Count)"
    foreach ($thm in $theorems) {
        $type = if ($thm['Type']) { $thm['Type'] } else { "theorem" }
        $output += "  > $($thm['Name']) [$type] (from $($thm['File']))"
    }
}
else {
    $output += "No theorems found via regex parsing"
}

$output += ""
$output += "--- File Contents Analysis ---"

# Analyze each Lean file
foreach ($file in $leanFiles) {
    $output += ""
    $output += "File: $($file.Name)"
    $output += "Path: $($file.FullName)"
    $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
    $lineCount = ($content | Measure-Object -Line).Lines
    $output += "Lines: $lineCount"
    
    # Check for proofs
    if ($content | Select-String "proof|sorry|by" -Quiet) {
        $output += "  Contains: proofs/tactics"
    }
    if ($content | Select-String "theorem" -Quiet) {
        $output += "  Contains: theorem declarations"
    }
    if ($content | Select-String "def " -Quiet) {
        $output += "  Contains: function definitions"
    }
}

$output += ""
$output += "--- Verification Log ---"

# Check for manual verification log
$verLog = "$testDir\VERIFICATION_LOG.md"
if (Test-Path $verLog) {
    $output += "[FOUND] Verification log at: $verLog"
    $verContent = Get-Content $verLog
    $output += $verContent
}
else {
    $output += "[NOT FOUND] No VERIFICATION_LOG.md"
}

# Check for proof artifacts
$output += ""
$output += "--- Proof Artifacts ---"
$manualLog = "$testDir\manual_verify.log"
if (Test-Path $manualLog) {
    $output += "[FOUND] Manual verification log"
    $content = Get-Content $manualLog
    $output += $content
}
else {
    $output += "[NOT FOUND] No manual_verify.log"
}

# Summary statistics
$output += ""
$output += "--- Test Summary ---"
$output += "Total files checked: $($leanFiles.Count)"
$output += "Total theorems/definitions found: $($theorems.Count)"
$output += "Lean environment: $(if ($leanPath) { 'AVAILABLE' } else { 'NOT AVAILABLE' })"
$output += "Lake build tool: $(if ($lakePath) { 'AVAILABLE' } else { 'NOT AVAILABLE' })"

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$output += "Test duration: $([math]::Round($duration, 2))s"
$output += "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += ""
$output += "=== END RESULTS ==="

# Write results
$output | Out-File -FilePath $resultsFile -Encoding UTF8

# Display results
Write-Host ($output -join "`n")
Write-Host ""
Write-Host "Results saved to: $resultsFile"
