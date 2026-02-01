# /run - Execute with Evidence Capture

## Purpose
Execute any command that affects or queries external state, producing an evidence bundle that proves what actually happened.

**This is the ONLY valid way to make claims about reality.**

## Usage

### Local execution
```
/run echo "hello world"
/run python myscript.py
/run npm install
```

### Remote (SSH) execution
```
/run --ssh root@143.198.11.57 "systemctl status nginx"
/run --ssh user@host "cat /etc/hostname"
```

### With working directory
```
/run --cwd C:\Users\J\project "pytest tests/"
```

## What happens

1. Command is executed (locally or via SSH)
2. stdout, stderr, and exit code are captured
3. Evidence bundle is written to `~/.claude/evidence/<EVIDENCE_ID>/`
4. Summary is printed with EVIDENCE_ID

## Evidence bundle contents

```
~/.claude/evidence/<EVIDENCE_ID>/
  meta.json           # command, exit_code, timestamps, duration
  raw_stdout.txt      # unmodified stdout
  raw_stderr.txt      # unmodified stderr
  redacted_stdout.txt # secrets masked
  redacted_stderr.txt # secrets masked
```

## Output format

```
==============================================
EVIDENCE_ID: 20260201_093000_DESK_abc123
EXIT_CODE: 0
STDOUT_BYTES: 42
STDERR_BYTES: 0
EVIDENCE_PATH: C:\Users\J\.claude\evidence\20260201_093000_DESK_abc123
==============================================

--- STDOUT (redacted) ---
hello world
```

## Rules

1. **Any operation that changes or checks reality MUST use /run**
   - Deployments
   - Service starts/stops
   - File existence checks
   - Email sends
   - API calls
   - Database operations

2. **Claims require evidence**
   - "It deployed successfully" → Must cite EVIDENCE_ID
   - "The file exists" → Must cite EVIDENCE_ID
   - "Email was sent" → Must cite EVIDENCE_ID

3. **No evidence = no claim**
   - If you cannot provide an EVIDENCE_ID, say: "I don't know; here's the command to prove it."

## Implementation

```powershell
# Backend call
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\repos\operator_layer\lib\ops_exec.ps1" -Cmd "<command>"

# With SSH
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\repos\operator_layer\lib\ops_exec.ps1" -SshHost "<host>" -SshUser "<user>" -Cmd "<command>"
```
