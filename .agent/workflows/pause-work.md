---
description: Context hygiene — dump state for clean session handoff
version: "1.0.0"
---

# /pause Workflow

<objective>
Safely pause work with complete state preservation for session handoff.
</objective>

<when_to_use>

- Ending a work session
- Context getting heavy (many failed attempts)
- Switching to a different task
- Before taking a break
- After 3+ debugging failures (Context Hygiene rule)
  </when_to_use>

<process>

## 1. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "STATE.md,JOURNAL.md"
$workflow = "/pause"

if (-not (Test-Path ".gsd")) { New-Item -ItemType Directory -Path ".gsd" -Force | Out-Null }

while (Test-Path $lockFile) {
    $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    if ($lockContent -and $lockContent.expires) {
        $expires = [datetime]::Parse($lockContent.expires)
        if ((Get-Date) -gt $expires) {
            Write-Warning "Lock expired (held by $($lockContent.workflow)). Stealing lock."
            break
        }
    }
    $retryCount++
    if ($retryCount -ge $maxRetries) {
        Write-Error "Could not acquire lock after ${maxRetries} retries"
        exit 1
    }
    Start-Sleep -Milliseconds 50
}

@{
    resource = $resource
    workflow = $workflow
    acquired = (Get-Date -Format "o")
    expires = (Get-Date).AddMinutes(5).ToString("o")
} | ConvertTo-Json | Set-Content $lockFile -Force
```

**Bash:**
```bash
lock_file=".gsd/.lock"
max_retries=10
retry_count=0
resource="STATE.md,JOURNAL.md"
workflow="/pause"

[ -d ".gsd" ] || mkdir -p ".gsd"

while [ -f "$lock_file" ]; do
    if command -v jq >/dev/null 2>&1; then
        expires=$(jq -r '.expires' "$lock_file" 2>/dev/null)
        if [ -n "$expires" ] && [ "$expires" != "null" ]; then
            now=$(date -u +%s)
            expires_epoch=$(date -u -d "$expires" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires" +%s 2>/dev/null)
            if [ -n "$expires_epoch" ] && [ "$now" -gt "$expires_epoch" ]; then
                lock_workflow=$(jq -r '.workflow' "$lock_file" 2>/dev/null)
                echo "Warning: Lock expired (held by $lock_workflow). Stealing lock." >&2
                break
            fi
        fi
    fi
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "Error: Could not acquire lock after ${max_retries} retries" >&2
        exit 1
    fi
    sleep 0.05
done

acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    expires=$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ)
else
    expires=$(date -u -v+5M +%Y-%m-%dT%H:%M:%SZ)
fi
printf '{"resource":"%s","workflow":"%s","acquired":"%s","expires":"%s"}\n' "$resource" "$workflow" "$acquired" "$expires" > "$lock_file"
```

---

## 2. Capture Current State

**PowerShell:**
```powershell
try {
```

**Bash:**
```bash
trap 'rm -f "$lock_file"' EXIT
```

Update `.gsd/STATE.md`:

```markdown
## Current Position

- **Phase**: {current phase number and name}
- **Task**: {specific task in progress, if any}
- **Status**: Paused at {timestamp}

## Last Session Summary

{What was accomplished this session}

## In-Progress Work

{Any uncommitted changes or partial work}

- Files modified: {list}
- Tests status: {passing/failing/not run}

## Blockers

{What was preventing progress, if anything}

## Context Dump

{Critical context that would be lost}:

### Decisions Made

- {Decision 1}: {rationale}
- {Decision 2}: {rationale}

### Approaches Tried

- {Approach 1}: {outcome}
- {Approach 2}: {outcome}

### Current Hypothesis

{Best guess at solution/issue}

### Files of Interest

- `{file1}`: {what's relevant}
- `{file2}`: {what's relevant}

## Next Steps

1. {Specific first action for next session}
2. {Second priority}
3. {Third priority}
```

---

## 2. Add Journal Entry

Prepend new entry to top of `.gsd/JOURNAL.md` (after the `# JOURNAL.md` header line), keeping newest-first order:

```markdown
## Session: {YYYY-MM-DD HH:MM}

### Objective

{What this session was trying to accomplish}

### Accomplished

- {Item 1}
- {Item 2}

### Verification

- [x] {What was verified}
- [ ] {What still needs verification}

### Paused Because

{Reason for pausing}

### Handoff Notes

{Critical info for resuming}
```

---

## 3. Auto-Archive Check

### 3a. Journal Archive Check

Count sessions in `JOURNAL.md`:

```bash
grep -c "^## Session:" .gsd/JOURNAL.md
```

- **If count > 5**: Run `/archive-journal` now (before committing) to move older entries to `.gsd/journal/YYYY-MM-archive.md`.
- **If count ≤ 5**: Skip — proceed to next check.

> This keeps `JOURNAL.md` lean so future sessions load only relevant context.

### 3b. Debug Session Cleanup Check

Check for old debug sessions that need archiving:

```bash
# Count debug sessions
debug_count=$(find debugging -maxdepth 1 -type d 2>/dev/null | grep -v "^debugging$" | wc -l)

# Find oldest debug session age (in days)
oldest_age=0
if [[ $debug_count -gt 0 ]]; then
    oldest_age=$(find debugging -maxdepth 1 -type d -mtime +30 2>/dev/null | grep -v "^debugging$" | wc -l)
fi
```

- **If debug_count > 10 OR oldest_age > 0**: Run `/cleanup` now to archive old sessions.
- **Otherwise**: Skip — proceed to commit.

> Old unresolved debug sessions (>30 days) are archived; resolved sessions (with SUMMARY.md) are preserved forever.

**PowerShell:**
```powershell
}
finally {
    if (Test-Path $lockFile) { Remove-Item $lockFile -Force }
}
```

**Bash:**
```bash
# Lock released by trap EXIT
```

---

## 5. Commit State

```bash
git add .gsd/STATE.md .gsd/JOURNAL.md .gsd/journal/ debugging/archived/
git commit -m "docs: pause session - {brief reason}"
```

---

## 6. Display Handoff

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► SESSION PAUSED ⏸
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

State saved to:
• .gsd/STATE.md
• .gsd/JOURNAL.md

───────────────────────────────────────────────────────

To resume later:

/resume-work

───────────────────────────────────────────────────────

💡 Fresh context = fresh perspective
   The struggles end here. Next session starts clean.

───────────────────────────────────────────────────────
```

</process>

<context_hygiene>
If pausing due to debugging failures:

1. Be explicit about what failed
2. Document exact error messages
3. List files that were touched
4. State your hypothesis clearly
5. Suggest what to try next (different approach)

A fresh context often immediately sees solutions that a polluted context missed.
</context_hygiene>
