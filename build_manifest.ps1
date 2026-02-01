<#
.SYNOPSIS
    Build manifest for Truth Gate release.
#>

$version = (Get-Content 'C:\Users\J\repos\operator_layer\VERSION' -Raw).Trim()
$timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
$files = @()

# Get all relevant files
$paths = @(
    'commands\run.md',
    'commands\prove.md',
    'lib\ops_exec.ps1',
    'lib\truth_guard.ps1',
    'lib\truth_gate_tests.ps1',
    'TRUTH_GATE.md',
    'VERSION',
    'README.md'
)

foreach ($path in $paths) {
    $fullPath = Join-Path 'C:\Users\J\repos\operator_layer' $path
    if (Test-Path $fullPath) {
        $hash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLower()
        $bytes = (Get-Item $fullPath).Length
        $files += @{
            path = $path
            sha256 = $hash
            bytes = $bytes
        }
    }
}

$manifest = @{
    generated_at = $timestamp
    source = 'truth_gate_release'
    version = $version
    files = $files
}

$manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath 'C:\Users\J\repos\operator_layer\operator_layer_manifest.json' -Encoding UTF8
Write-Host "Manifest generated with $($files.Count) files for version $version"
