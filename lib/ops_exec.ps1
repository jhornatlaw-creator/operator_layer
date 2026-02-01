<#
.SYNOPSIS
    Execute commands locally or via SSH with evidence capture.

.DESCRIPTION
    Single entrypoint for running commands that affect or query external state.
    Produces an evidence bundle with raw stdout/stderr, exit code, and metadata.
    Evidence is required for any claim about reality.

.PARAMETER Cmd
    The command to execute (required).

.PARAMETER Cwd
    Working directory for local commands.

.PARAMETER SshHost
    Remote host for SSH execution.

.PARAMETER SshUser
    SSH username (default: root).

.PARAMETER SshKeyPath
    Path to SSH private key.

.PARAMETER TimeoutSec
    Command timeout in seconds (default: 300).

.PARAMETER NoRedact
    Disable secret redaction in output.

.EXAMPLE
    .\ops_exec.ps1 -Cmd "echo hello"

.EXAMPLE
    .\ops_exec.ps1 -SshHost "143.198.11.57" -SshUser "root" -Cmd "date"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Cmd,

    [string]$Cwd,
    [string]$SshHost,
    [string]$SshUser = "root",
    [string]$SshKeyPath,
    [int]$TimeoutSec = 300,
    [switch]$NoRedact
)

# Evidence base directory
$EvidenceBase = Join-Path $env:USERPROFILE ".claude\evidence"

# Secret patterns to redact (simplified for PowerShell compatibility)
$SecretPatterns = @(
    'SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',
    'api_key\s*[=:]\s*\S{16,}',
    'apikey\s*[=:]\s*\S{16,}',
    'password\s*[=:]\s*\S{8,}',
    'secret\s*[=:]\s*\S{16,}',
    'token\s*[=:]\s*\S{16,}',
    'Bearer\s+[A-Za-z0-9_-]{20,}',
    'sk-[A-Za-z0-9]{32,}',
    'pk-[A-Za-z0-9]{32,}',
    'AWS_SECRET[A-Za-z_]*\s*[=:]\s*\S{20,}',
    '-----BEGIN[^-]+PRIVATE KEY-----'
)

function Get-EvidenceId {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $machineId = $env:COMPUTERNAME.Substring(0, [Math]::Min(4, $env:COMPUTERNAME.Length))
    $random = -join ((48..57) + (97..102) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    return "${timestamp}_${machineId}_${random}"
}

function Redact-Secrets {
    param([string]$Text)

    if ($NoRedact) { return $Text }
    if (-not $Text) { return $Text }

    $redacted = $Text
    foreach ($pattern in $SecretPatterns) {
        try {
            $redacted = $redacted -replace $pattern, '[REDACTED]'
        }
        catch {
            # Skip pattern if regex fails
        }
    }
    return $redacted
}

function Write-Evidence {
    param(
        [string]$EvidenceId,
        [string]$Command,
        [string]$Stdout,
        [string]$Stderr,
        [int]$ExitCode,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$ExecutionMode,
        [string]$WorkingDir
    )

    $evidenceDir = Join-Path $EvidenceBase $EvidenceId
    New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

    # Handle null values
    if (-not $Stdout) { $Stdout = "" }
    if (-not $Stderr) { $Stderr = "" }

    # Write raw output
    $Stdout | Out-File -FilePath (Join-Path $evidenceDir "raw_stdout.txt") -Encoding UTF8
    $Stderr | Out-File -FilePath (Join-Path $evidenceDir "raw_stderr.txt") -Encoding UTF8

    # Write redacted output
    (Redact-Secrets $Stdout) | Out-File -FilePath (Join-Path $evidenceDir "redacted_stdout.txt") -Encoding UTF8
    (Redact-Secrets $Stderr) | Out-File -FilePath (Join-Path $evidenceDir "redacted_stderr.txt") -Encoding UTF8

    # Calculate bytes safely
    $stdoutBytes = 0
    $stderrBytes = 0
    if ($Stdout) { $stdoutBytes = [System.Text.Encoding]::UTF8.GetByteCount($Stdout) }
    if ($Stderr) { $stderrBytes = [System.Text.Encoding]::UTF8.GetByteCount($Stderr) }

    # Write metadata
    $meta = @{
        evidence_id = $EvidenceId
        command = $Command
        execution_mode = $ExecutionMode
        working_dir = $WorkingDir
        exit_code = $ExitCode
        start_time = $StartTime.ToString("o")
        end_time = $EndTime.ToString("o")
        duration_ms = [int]($EndTime - $StartTime).TotalMilliseconds
        hostname = $env:COMPUTERNAME
        username = $env:USERNAME
        stdout_bytes = $stdoutBytes
        stderr_bytes = $stderrBytes
    }

    if ($SshHost) {
        $meta.ssh_host = $SshHost
        $meta.ssh_user = $SshUser
    }

    $meta | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $evidenceDir "meta.json") -Encoding UTF8

    return $evidenceDir
}

# Main execution
$evidenceId = Get-EvidenceId
$startTime = Get-Date
$stdout = ""
$stderr = ""
$exitCode = 0
$executionMode = "local"
$workingDir = if ($Cwd) { $Cwd } else { (Get-Location).Path }

try {
    if ($SshHost) {
        # SSH execution
        $executionMode = "ssh"
        $workingDir = "remote:$SshHost"

        $sshArgs = @()
        if ($SshKeyPath) {
            $sshArgs += "-i"
            $sshArgs += $SshKeyPath
        }
        $sshArgs += "-o"
        $sshArgs += "BatchMode=yes"
        $sshArgs += "-o"
        $sshArgs += "ConnectTimeout=10"
        $sshArgs += "${SshUser}@${SshHost}"
        $sshArgs += $Cmd

        $tempStdout = Join-Path $env:TEMP "ops_stdout_$evidenceId.txt"
        $tempStderr = Join-Path $env:TEMP "ops_stderr_$evidenceId.txt"

        $process = Start-Process -FilePath "ssh" -ArgumentList $sshArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempStdout -RedirectStandardError $tempStderr

        $stdout = Get-Content $tempStdout -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $tempStderr -Raw -ErrorAction SilentlyContinue
        $exitCode = $process.ExitCode

        Remove-Item $tempStdout -Force -ErrorAction SilentlyContinue
        Remove-Item $tempStderr -Force -ErrorAction SilentlyContinue
    }
    else {
        # Local execution
        if ($Cwd) {
            Push-Location $Cwd
        }

        try {
            $tempStdout = Join-Path $env:TEMP "ops_stdout_$evidenceId.txt"
            $tempStderr = Join-Path $env:TEMP "ops_stderr_$evidenceId.txt"

            $process = Start-Process -FilePath "powershell" -ArgumentList "-Command", $Cmd -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempStdout -RedirectStandardError $tempStderr

            $stdout = Get-Content $tempStdout -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content $tempStderr -Raw -ErrorAction SilentlyContinue
            $exitCode = $process.ExitCode

            Remove-Item $tempStdout -Force -ErrorAction SilentlyContinue
            Remove-Item $tempStderr -Force -ErrorAction SilentlyContinue
        }
        finally {
            if ($Cwd) {
                Pop-Location
            }
        }
    }
}
catch {
    $stderr = $_.Exception.Message
    $exitCode = 1
}

$endTime = Get-Date

# Write evidence
$evidencePath = Write-Evidence -EvidenceId $evidenceId -Command $Cmd -Stdout $stdout -Stderr $stderr -ExitCode $exitCode -StartTime $startTime -EndTime $endTime -ExecutionMode $executionMode -WorkingDir $workingDir

# Write last_id.txt sidecar for session continuity
$lastIdPath = Join-Path $EvidenceBase "last_id.txt"
$evidenceId | Out-File -FilePath $lastIdPath -Encoding UTF8 -NoNewline

# Calculate bytes safely for display
$stdoutBytes = 0
$stderrBytes = 0
if ($stdout) { $stdoutBytes = [System.Text.Encoding]::UTF8.GetByteCount($stdout) }
if ($stderr) { $stderrBytes = [System.Text.Encoding]::UTF8.GetByteCount($stderr) }

# Output summary
Write-Host "=============================================="
Write-Host "EVIDENCE_ID: $evidenceId"
Write-Host "EXIT_CODE: $exitCode"
Write-Host "STDOUT_BYTES: $stdoutBytes"
Write-Host "STDERR_BYTES: $stderrBytes"
Write-Host "EVIDENCE_PATH: $evidencePath"
Write-Host "=============================================="

# Output redacted stdout/stderr
if ($stdout) {
    Write-Host ""
    Write-Host "--- STDOUT (redacted) ---"
    Write-Host (Redact-Secrets $stdout)
}

if ($stderr) {
    Write-Host ""
    Write-Host "--- STDERR (redacted) ---"
    Write-Host (Redact-Secrets $stderr)
}

# Exit with same code as command
exit $exitCode
