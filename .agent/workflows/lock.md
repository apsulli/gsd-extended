---
description: Light-touch file locking for shared GSD resources
documentation: Cross-platform advisory locking with concurrent read support
version: "1.0.0"
---

# /lock Workflow

<role>
You are a GSD lock manager. You provide advisory file locking for shared GSD resources.

**Core responsibilities:**
- Acquire locks before modifying shared files (STATE.md, JOURNAL.md, ROADMAP.md)
- Release locks after operations complete
- Handle lock expiration and stealing for crashed processes
- Support concurrent reads (exclusive write) semantics
</role>

<objective>
Provide simple, cross-platform file locking for GSD workflows.

**Design principles:**
- Advisory locking (cooperative - workflows must use /lock)
- ~50ms delay acceptable for lock acquisition
- Max 10 retries (500ms total wait time)
- Lock expires after 5 minutes to prevent deadlocks
- Expired locks are stolen with warning
</objective>

<context>
**Lock file location:** `.gsd/.lock`

**Lock file format (JSON):**
```json
{
  "resource": "STATE.md",
  "workflow": "/execute",
  "acquired": "2026-03-11T14:30:00Z",
  "expires": "2026-03-11T14:35:00Z"
}
```

**Supported resources:**
- `STATE.md` — Current project state
- `JOURNAL.md` — Session journal entries
- `ROADMAP.md` — Phase definitions and status
- `debugging/` — Debug session directories
</context>

<process>

## 1. Acquire Lock

Try to create `.gsd/.lock` file. If exists and not expired: wait and retry.

**PowerShell:**

```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "STATE.md"  # Change to target resource
$workflow = "/execute"  # Change to calling workflow

# Check if .gsd directory exists
if (-not (Test-Path ".gsd")) {
    New-Item -ItemType Directory -Path ".gsd" -Force
}

# Try to acquire lock with retries
while (Test-Path $lockFile) {
    $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    $now = Get-Date
    
    # Check if lock is expired
    if ($lockContent -and $lockContent.expires) {
        $expires = [datetime]::Parse($lockContent.expires)
        if ($now -gt $expires) {
            Write-Warning "Lock expired (held by $($lockContent.workflow)). Stealing lock."
            break
        }
    }
    
    $retryCount++
    if ($retryCount -ge $maxRetries) {
        Write-Error "Could not acquire lock after ${maxRetries} retries (held by $($lockContent.workflow) for resource $($lockContent.resource))"
        exit 1
    }
    
    Start-Sleep -Milliseconds 50
}

# Create lock file
$lockData = @{
    resource = $resource
    workflow = $workflow
    acquired = (Get-Date -Format "o")
    expires = (Get-Date).AddMinutes(5).ToString("o")
}
$lockData | ConvertTo-Json | Set-Content $lockFile -Force
Write-Host "Lock acquired for $resource"
```

**Bash:**

```bash
lock_file=".gsd/.lock"
max_retries=10
retry_count=0
resource="STATE.md"  # Change to target resource
workflow="/execute"  # Change to calling workflow

# Check if .gsd directory exists
if [ ! -d ".gsd" ]; then
    mkdir -p ".gsd"
fi

# Try to acquire lock with retries
while [ -f "$lock_file" ]; do
    # Check if lock is expired
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

# Create lock file (macOS compatible)
acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    # GNU date (Linux)
    expires=$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ)
else
    # BSD date (macOS)
    expires=$(date -u -v+5M +%Y-%m-%dT%H:%M:%SZ)
fi

printf '{"resource":"%s","workflow":"%s","acquired":"%s","expires":"%s"}\n' \
    "$resource" "$workflow" "$acquired" "$expires" > "$lock_file"

echo "Lock acquired for $resource"
```

---

## 2. Release Lock

Delete the lock file. **Always use trap/finally to ensure release.**

**PowerShell (finally block):**

```powershell
try {
    # ... your code that modifies shared files ...
}
finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force
        Write-Host "Lock released"
    }
}
```

**Bash (trap):**

```bash
# Set trap at the start of your script
trap 'rm -f "$lock_file"; echo "Lock released"' EXIT

# ... your code that modifies shared files ...

# Trap will automatically clean up on exit
```

---

## 3. Check Lock Status

Read and display current lock information.

**PowerShell:**

```powershell
if (Test-Path $lockFile) {
    $lock = Get-Content $lockFile | ConvertFrom-Json
    Write-Host "Current lock:"
    Write-Host "  Resource: $($lock.resource)"
    Write-Host "  Workflow: $($lock.workflow)"
    Write-Host "  Acquired: $($lock.acquired)"
    Write-Host "  Expires:  $($lock.expires)"
    
    $expires = [datetime]::Parse($lock.expires)
    if ((Get-Date) -gt $expires) {
        Write-Warning "Lock has EXPIRED"
    }
} else {
    Write-Host "No active lock"
}
```

**Bash:**

```bash
if [ -f "$lock_file" ]; then
    if command -v jq >/dev/null 2>&1; then
        echo "Current lock:"
        echo "  Resource: $(jq -r '.resource' "$lock_file")"
        echo "  Workflow: $(jq -r '.workflow' "$lock_file")"
        echo "  Acquired: $(jq -r '.acquired' "$lock_file")"
        echo "  Expires:  $(jq -r '.expires' "$lock_file")"
    else
        cat "$lock_file"
    fi
else
    echo "No active lock"
fi
```

---

## 4. Force Release (Emergency)

Remove a stale lock manually.

**PowerShell:**

```powershell
if (Test-Path ".gsd/.lock") {
    Remove-Item ".gsd/.lock" -Force
    Write-Host "Lock force-released"
}
```

**Bash:**

```bash
if [ -f ".gsd/.lock" ]; then
    rm -f ".gsd/.lock"
    echo "Lock force-released"
fi
```

</process>

<usage_examples>

### Example: Lock Before Writing STATE.md

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$resource = "STATE.md"
$workflow = "/execute"

# Acquire lock
# ... (acquire code from section 1) ...

try {
    # Modify STATE.md
    Set-Content ".gsd/STATE.md" $newContent
}
finally {
    if (Test-Path $lockFile) { Remove-Item $lockFile }
}
```

**Bash:**
```bash
lock_file=".gsd/.lock"
resource="STATE.md"
workflow="/execute"

# Acquire lock
# ... (acquire code from section 1) ...

trap 'rm -f "$lock_file"' EXIT

# Modify STATE.md
echo "$new_content" > ".gsd/STATE.md"
```

### Example: Multi-Resource Lock

For operations that modify multiple files, use the primary resource:

```powershell
$resource = "STATE.md,JOURNAL.md"  # List all resources
```

</usage_examples>

<lock_behavior>

## Lock Semantics

| Scenario | Behavior |
|----------|----------|
| Lock free | Acquire immediately |
| Lock held, not expired | Wait 50ms, retry (max 10) |
| Lock held, expired | Steal with warning |
| Max retries exceeded | Error and exit |
| Process exits normally | Lock auto-released via trap/finally |
| Process crashes | Lock expires after 5 min, then stealable |

## Best Practices

1. **Always use trap/finally** — Ensure lock release even on errors
2. **Keep locks short** — Acquire, modify, release quickly
3. **One lock per operation** — Don't hold across long operations
4. **Check expiration** — Expired locks indicate crashed processes
5. **Specify correct resource** — Helps debugging lock contention

</lock_behavior>

<related>

## Related Workflows

| Command | Uses Lock For |
|---------|---------------|
| `/execute` | STATE.md updates |
| `/verify` | STATE.md updates |
| `/pause` | STATE.md, JOURNAL.md |
| `/debug-flow` | debugging/ directory |
| `/add-phase` | ROADMAP.md |
| `/insert-phase` | ROADMAP.md, STATE.md |
| `/remove-phase` | ROADMAP.md, STATE.md |

</related>
