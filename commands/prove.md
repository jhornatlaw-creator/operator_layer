# /prove - Display Evidence Bundle

## Purpose
Display the contents of an evidence bundle to verify what actually happened during a /run command.

## Usage

```
/prove <EVIDENCE_ID>
/prove 20260201_093000_DESK_abc123
```

### List recent evidence
```
/prove --list
/prove --list 10
```

## Output

### Summary view (default)
```
==============================================
EVIDENCE_ID: 20260201_093000_DESK_abc123
COMMAND: echo "hello world"
EXIT_CODE: 0
DURATION_MS: 127
TIMESTAMP: 2026-02-01T09:30:00.000Z
EXECUTION_MODE: local
WORKING_DIR: C:\Users\J\project
==============================================

--- STDOUT (last 50 lines, redacted) ---
hello world

--- STDERR (last 20 lines, redacted) ---
(empty)
```

### Full output
```
/prove <EVIDENCE_ID> --full
```

### Raw output (shows unredacted - use with caution)
```
/prove <EVIDENCE_ID> --raw
```

## Evidence validation

Use `/prove` to verify claims before accepting them:

1. Check EVIDENCE_ID matches what was claimed
2. Check EXIT_CODE is 0 (or expected value)
3. Check STDOUT contains expected success indicators
4. Check TIMESTAMP is recent and relevant

## Implementation

```powershell
# Display evidence
$evidenceDir = Join-Path $env:USERPROFILE ".claude\evidence\<EVIDENCE_ID>"
$meta = Get-Content (Join-Path $evidenceDir "meta.json") | ConvertFrom-Json
$stdout = Get-Content (Join-Path $evidenceDir "redacted_stdout.txt") -Tail 50
$stderr = Get-Content (Join-Path $evidenceDir "redacted_stderr.txt") -Tail 20

# List recent
Get-ChildItem (Join-Path $env:USERPROFILE ".claude\evidence") -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name, LastWriteTime
```

## Truth Guard Integration

After viewing evidence with `/prove`, validate it:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\repos\operator_layer\lib\truth_guard.ps1" -RequireEvidenceId "<EVIDENCE_ID>"
```

This confirms:
- Evidence exists
- Exit code is 0 (unless --allow-nonzero)
- Required patterns are present (if specified)
