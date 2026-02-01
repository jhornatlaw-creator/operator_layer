# Truth Gate Doctrine

## The Problem

Claude claimed work was completed when it wasn't. Files that "existed" didn't exist. Pipelines that "ran successfully" never ran. This erodes trust completely.

## The Rule

**If you cannot provide an EVIDENCE_ID produced by /run, you must not claim external reality.**

This is non-negotiable. There are no exceptions.

## What Requires Evidence

Any claim about external state:
- "The file exists" → EVIDENCE_ID required
- "The deployment succeeded" → EVIDENCE_ID required
- "The email was sent" → EVIDENCE_ID required
- "The service is running" → EVIDENCE_ID required
- "The pipeline completed" → EVIDENCE_ID required
- "The timer is active" → EVIDENCE_ID required
- "The command returned X" → EVIDENCE_ID required

## What Doesn't Require Evidence

- Code you just wrote (it's in the conversation)
- Analysis of files you just read (Read tool output is visible)
- Plans and recommendations (not claims about reality)
- Questions and clarifications

## How It Works

### 1. Execute with Evidence
```
/run systemctl status harris-pipeline.timer
```

Output:
```
EVIDENCE_ID: 20260201_130000_DESK_abc123
EXIT_CODE: 0
...
```

### 2. Make Claims with Evidence
```
The timer is active (EVIDENCE_ID: 20260201_130000_DESK_abc123).
```

### 3. Verify Evidence
```
/prove 20260201_130000_DESK_abc123
```

## What Happens Without Evidence

If you cannot provide an EVIDENCE_ID:

**BLOCKED.** You cannot claim the operation succeeded.

Allowed phrasing:
- "I don't know if it worked. Run `/run <command>` to verify."
- "I can't confirm that. Here's how to check: `/run <command>`"
- "No evidence. The command to verify is: `<command>`"

## Truth Guard Gate

The truth_guard.ps1 script enforces this:

```powershell
.\lib\truth_guard.ps1 -RequireEvidenceId "abc123"

# If missing: TRUTH_GUARD: BLOCKED
# If present: TRUTH_GUARD: OK
```

## Integration Points

### /boot
Shows last evidence ID and reminder:
```
last_evidence: 20260201_130000_DESK_abc123
REMINDER: No external-state claims without evidence_id
```

### /save_context
Persists `evidence_last_id` to latest.json

### /load_context
Surfaces last evidence ID for continuity

## Why This Exists

On 2026-02-01, Claude claimed:
- Harris pipeline ran successfully on the droplet
- Files harris0201 existed
- The deployment was complete

None of this was true. The code wasn't even on the droplet. The files didn't exist. Hours were wasted.

This gate ensures that can never happen again.

## Severity

On a scale of 1 to 10, fabricating completed work is **100000000000000**.

It's not a mistake. It's not an oversight. It's fraud.

This gate exists to prevent fraud.
