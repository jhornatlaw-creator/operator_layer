<#
.SYNOPSIS
    Smoke tests for Truth Gate functionality.

.DESCRIPTION
    Validates that:
    1. ops_exec.ps1 produces evidence bundles
    2. truth_guard.ps1 blocks missing evidence
    3. truth_guard.ps1 passes valid evidence
    4. Secret redaction works
#>

param(
    [switch]$Verbose
)

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:OperatorLayerPath = Split-Path -Parent $PSScriptRoot

function Write-TestResult {
    param([string]$Name, [bool]$Passed, [string]$Details = "")

    if ($Passed) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "       $Details" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

function Test-OpsExecLocal {
    Write-Host "`n=== Test: ops_exec.ps1 local execution ===" -ForegroundColor Cyan

    $opsExec = Join-Path $script:OperatorLayerPath "lib\ops_exec.ps1"

    # Run a simple command
    $output = & powershell -ExecutionPolicy Bypass -File $opsExec -Cmd "echo 'truth_gate_test_marker'"

    # Check for EVIDENCE_ID in output
    $outputText = $output -join "`n"
    $hasEvidenceId = $outputText -match "EVIDENCE_ID:\s*(\S+)"
    Write-TestResult "Produces EVIDENCE_ID" $hasEvidenceId

    if ($hasEvidenceId) {
        $evidenceId = $Matches[1]

        # Check evidence directory exists
        $evidenceDir = Join-Path $env:USERPROFILE ".claude\evidence\$evidenceId"
        $dirExists = Test-Path $evidenceDir
        Write-TestResult "Evidence directory created" $dirExists

        # Check meta.json exists
        $metaExists = Test-Path (Join-Path $evidenceDir "meta.json")
        Write-TestResult "meta.json exists" $metaExists

        # Check raw_stdout.txt exists and contains marker
        $stdoutPath = Join-Path $evidenceDir "raw_stdout.txt"
        $stdoutExists = Test-Path $stdoutPath
        Write-TestResult "raw_stdout.txt exists" $stdoutExists

        if ($stdoutExists) {
            $stdout = Get-Content $stdoutPath -Raw
            $hasMarker = $stdout -match "truth_gate_test_marker"
            Write-TestResult "stdout contains expected output" $hasMarker
        }

        # Check EXIT_CODE is 0
        $hasExitCode = $outputText -match "EXIT_CODE:\s*0"
        Write-TestResult "EXIT_CODE is 0" $hasExitCode

        # Return evidence ID for later tests
        return $evidenceId
    }

    return $null
}

function Test-TruthGuardBlocks {
    Write-Host "`n=== Test: truth_guard.ps1 blocks missing evidence ===" -ForegroundColor Cyan

    $truthGuard = Join-Path $script:OperatorLayerPath "lib\truth_guard.ps1"

    # Use a nonexistent evidence ID
    $fakeId = "nonexistent_evidence_id_12345"

    $output = & powershell -ExecutionPolicy Bypass -File $truthGuard -RequireEvidenceId $fakeId 2>&1
    $exitCode = $LASTEXITCODE

    # Should be blocked (exit code 1)
    $isBlocked = $exitCode -eq 1
    Write-TestResult "Exits with code 1 for missing evidence" $isBlocked

    # Should contain BLOCKED
    $hasBlocked = ($output -join "`n") -match "TRUTH_GUARD:\s*BLOCKED"
    Write-TestResult "Output contains TRUTH_GUARD: BLOCKED" $hasBlocked

    # Should contain remediation
    $hasRemediation = ($output -join "`n") -match "REMEDIATION"
    Write-TestResult "Output contains remediation instructions" $hasRemediation
}

function Test-TruthGuardPasses {
    param([string]$EvidenceId)

    Write-Host "`n=== Test: truth_guard.ps1 passes valid evidence ===" -ForegroundColor Cyan

    if (-not $EvidenceId) {
        Write-TestResult "Skipped (no evidence ID from previous test)" $false "Run ops_exec test first"
        return
    }

    $truthGuard = Join-Path $script:OperatorLayerPath "lib\truth_guard.ps1"

    $output = & powershell -ExecutionPolicy Bypass -File $truthGuard -RequireEvidenceId $EvidenceId 2>&1
    $exitCode = $LASTEXITCODE

    # Should pass (exit code 0)
    $isPassed = $exitCode -eq 0
    Write-TestResult "Exits with code 0 for valid evidence" $isPassed

    # Should contain OK
    $hasOk = ($output -join "`n") -match "TRUTH_GUARD:\s*OK"
    Write-TestResult "Output contains TRUTH_GUARD: OK" $hasOk
}

function Test-SecretRedaction {
    Write-Host "`n=== Test: Secret redaction ===" -ForegroundColor Cyan

    $opsExec = Join-Path $script:OperatorLayerPath "lib\ops_exec.ps1"

    # Run a command that outputs something that looks like a secret
    $testSecret = "api_key=SG.fake_sendgrid_key_12345.abcdefghijklmnop"
    $output = & powershell -ExecutionPolicy Bypass -File $opsExec -Cmd "echo '$testSecret'"

    # Check that output is redacted
    $outputJoined = $output -join "`n"
    $hasRedacted = $outputJoined -match "\[REDACTED\]"
    Write-TestResult "Secrets are redacted in output" $hasRedacted

    # Check that raw file still has secret but redacted file doesn't
    if ($outputJoined -match "EVIDENCE_ID:\s*(\S+)") {
        $evidenceId = $Matches[1]
        $evidenceDir = Join-Path $env:USERPROFILE ".claude\evidence\$evidenceId"

        $redactedPath = Join-Path $evidenceDir "redacted_stdout.txt"
        if (Test-Path $redactedPath) {
            $redacted = Get-Content $redactedPath -Raw
            $noSecretInRedacted = $redacted -notmatch "SG\.fake_sendgrid"
            Write-TestResult "Redacted file does not contain secret pattern" $noSecretInRedacted
        }
    }
}

# Run all tests
Write-Host "=============================================="
Write-Host "TRUTH GATE SMOKE TESTS"
Write-Host "=============================================="

$evidenceId = Test-OpsExecLocal
Test-TruthGuardBlocks
Test-TruthGuardPasses -EvidenceId $evidenceId
Test-SecretRedaction

# Summary
Write-Host "`n=============================================="
Write-Host "SUMMARY"
Write-Host "=============================================="
Write-Host "Passed: $script:TestsPassed"
Write-Host "Failed: $script:TestsFailed"

if ($script:TestsFailed -eq 0) {
    Write-Host "`nTRUTH GATE: ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nTRUTH GATE: TESTS FAILED" -ForegroundColor Red
    exit 1
}
