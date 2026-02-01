<#
.SYNOPSIS
    Truth Gate - blocks claims about reality without evidence.

.DESCRIPTION
    Validates that an evidence bundle exists and meets criteria before
    allowing claims about external state. Default behavior is BLOCKED
    when evidence is missing.

.PARAMETER RequireEvidenceId
    The evidence ID to validate (required).

.PARAMETER RequirePatterns
    Optional array of patterns that must appear in stdout.

.PARAMETER AllowNonZero
    Allow non-zero exit codes to pass.

.EXAMPLE
    .\truth_guard.ps1 -RequireEvidenceId "20260201_095000_DESK_abc123"

.EXAMPLE
    .\truth_guard.ps1 -RequireEvidenceId "20260201_095000_DESK_abc123" -RequirePatterns @("202 Accepted", "success")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RequireEvidenceId,

    [string[]]$RequirePatterns,
    [switch]$AllowNonZero
)

$EvidenceBase = Join-Path $env:USERPROFILE ".claude\evidence"

function Write-Blocked {
    param([string]$Reason, [string]$Remediation)

    Write-Host "=============================================="
    Write-Host "TRUTH_GUARD: BLOCKED"
    Write-Host "=============================================="
    Write-Host "REASON: $Reason"
    Write-Host ""
    Write-Host "REMEDIATION:"
    Write-Host $Remediation
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "You CANNOT claim this operation succeeded."
    Write-Host "Allowed phrasing: 'I don't know; here's the command to prove it.'"
    exit 1
}

function Write-Passed {
    param([hashtable]$Meta)

    Write-Host "=============================================="
    Write-Host "TRUTH_GUARD: OK"
    Write-Host "=============================================="
    Write-Host "EVIDENCE_ID: $($Meta.evidence_id)"
    Write-Host "COMMAND: $($Meta.command)"
    Write-Host "EXIT_CODE: $($Meta.exit_code)"
    Write-Host "DURATION_MS: $($Meta.duration_ms)"
    Write-Host "TIMESTAMP: $($Meta.start_time)"
    Write-Host "=============================================="
    exit 0
}

# Check evidence directory exists
$evidenceDir = Join-Path $EvidenceBase $RequireEvidenceId

if (-not (Test-Path $evidenceDir)) {
    Write-Blocked `
        -Reason "Evidence bundle not found: $RequireEvidenceId" `
        -Remediation @"
1. Run the command with /run to produce evidence:
   /run <your-command>

2. Use the returned EVIDENCE_ID to verify:
   /prove <evidence_id>

3. Only then can you claim the operation succeeded.
"@
}

# Check meta.json exists
$metaPath = Join-Path $evidenceDir "meta.json"
if (-not (Test-Path $metaPath)) {
    Write-Blocked `
        -Reason "Evidence metadata missing: $metaPath" `
        -Remediation "Evidence bundle is corrupted. Re-run the command with /run."
}

# Load metadata
try {
    $metaObj = Get-Content $metaPath -Raw | ConvertFrom-Json
    # Convert to hashtable manually for compatibility
    $meta = @{}
    $metaObj.PSObject.Properties | ForEach-Object { $meta[$_.Name] = $_.Value }
}
catch {
    Write-Blocked `
        -Reason "Failed to parse evidence metadata: $($_.Exception.Message)" `
        -Remediation "Evidence bundle is corrupted. Re-run the command with /run."
}

# Check exit code
if (-not $AllowNonZero -and $meta.exit_code -ne 0) {
    Write-Blocked `
        -Reason "Command failed with exit code $($meta.exit_code)" `
        -Remediation @"
The command did not succeed. Exit code: $($meta.exit_code)

Review the evidence:
  /prove $RequireEvidenceId

Fix the issue and re-run with /run.
"@
}

# Check required patterns
if ($RequirePatterns -and $RequirePatterns.Count -gt 0) {
    $stdoutPath = Join-Path $evidenceDir "raw_stdout.txt"
    $stdout = ""
    if (Test-Path $stdoutPath) {
        $stdout = Get-Content $stdoutPath -Raw -ErrorAction SilentlyContinue
    }

    $missingPatterns = @()
    foreach ($pattern in $RequirePatterns) {
        if ($stdout -notmatch [regex]::Escape($pattern)) {
            $missingPatterns += $pattern
        }
    }

    if ($missingPatterns.Count -gt 0) {
        Write-Blocked `
            -Reason "Required patterns not found in output: $($missingPatterns -join ', ')" `
            -Remediation @"
The command output does not contain expected success indicators.
Missing: $($missingPatterns -join ', ')

Review the evidence:
  /prove $RequireEvidenceId

The operation may have failed silently. Investigate and re-run.
"@
    }
}

# All checks passed
Write-Passed -Meta $meta
