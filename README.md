# Operator Layer Releases

Distribution repository for Claude Code operator layer.

## Current Version

```
2026-01-30-p11
```

## Install / Update

### Fresh Install

```powershell
$url = "https://github.com/jhornatlaw-creator/operator_layer/releases/download/v2026-01-30-p11/operator_layer_2026-01-30-p11.zip"
powershell -ExecutionPolicy Bypass -File install.ps1 -ReleaseUrl $url
```

### Update Existing

```powershell
$url = "https://github.com/jhornatlaw-creator/operator_layer/releases/download/v2026-01-30-p11/operator_layer_2026-01-30-p11.zip"
powershell -ExecutionPolicy Bypass -File C:\Users\J\.claude\update.ps1 -Channel Release -ReleaseUrl $url
```

## Verify Installation

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\J\.claude\lib\verify_manifest.ps1
```

Expected output: `MANIFEST: VERIFIED (46 files)`

## Verify Download (SHA256)

```powershell
# Download
$zip = "$env:TEMP\operator_layer.zip"
Invoke-WebRequest -Uri $url -OutFile $zip

# Compute hash
(Get-FileHash $zip -Algorithm SHA256).Hash

# Compare to expected
# 963BC136520872D4E46325BD016DE7F6547F3B63065D0C7B591D4C66686D3B01
```

## Release URL Pattern

```
https://github.com/jhornatlaw-creator/operator_layer/releases/download/v<VERSION>/operator_layer_<VERSION>.zip
```

## Tags

Tags are canonical checkpoints:
- `v2026-01-30-p11` - BOOT GUARD safety rails
- `operator-layer-2026-01-30-p11` - Same release (alternate naming)

## What's Included

- `/boot` - Session startup + auto-rehydration
- `/save_context` - Persist session state
- `/load_context` - Deep restore
- BOOT GUARD - Safety rails (SAFE/CAUTION/LOCKED modes)
- Manifest verification
- Scheduled maintenance
- Multi-machine sync conflict resolution

## Changelog

See [CHANGELOG_OPERATOR_LAYER.md](https://github.com/jhornatlaw-creator/operator_layer/blob/main/CHANGELOG_OPERATOR_LAYER.md) in release zip.
