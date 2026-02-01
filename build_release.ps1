<#
.SYNOPSIS
    Build release zip for Truth Gate.
#>

$version = (Get-Content 'C:\Users\J\repos\operator_layer\VERSION' -Raw).Trim()
$zipPath = "C:\Users\J\repos\operator_layer\releases\operator_layer_$version.zip"

# Create releases dir if needed
New-Item -ItemType Directory -Force -Path 'C:\Users\J\repos\operator_layer\releases' | Out-Null

# Remove old zip if exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Create zip
Compress-Archive -Path @(
    'C:\Users\J\repos\operator_layer\commands',
    'C:\Users\J\repos\operator_layer\lib',
    'C:\Users\J\repos\operator_layer\TRUTH_GATE.md',
    'C:\Users\J\repos\operator_layer\VERSION',
    'C:\Users\J\repos\operator_layer\README.md',
    'C:\Users\J\repos\operator_layer\operator_layer_manifest.json'
) -DestinationPath $zipPath -Force

# Generate SHA256
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
$hash | Out-File -FilePath "$zipPath.sha256" -Encoding UTF8 -NoNewline

Write-Host "Release created: $zipPath"
Write-Host "SHA256: $hash"
