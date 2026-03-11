---
description: Add a new phase to the end of the roadmap
version: "1.0.0"
---

# /add-phase Workflow

<objective>
Add a new phase to the end of the current roadmap.
</objective>

<process>

## 1. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "ROADMAP.md,STATE.md"
$workflow = "/add-phase"

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
resource="ROADMAP.md,STATE.md"
workflow="/add-phase"

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

## 2. Generate Operation ID

**PowerShell:**
```powershell
try {
    $operationId = "$(Get-Date -Format 'yyyyMMddHHmmss')-$([Guid]::NewGuid().ToString().Substring(0,8))"
```

**Bash:**
```bash
trap 'rm -f "$lock_file"' EXIT
OPERATION_ID="$(date +%s)-$(openssl rand -hex 4)"
```

---

## 2. Check for Concurrent Operations

Check if `pending_operation` field exists in STATE.md:

**PowerShell:**
```powershell
$pendingOp = $null
if (Test-Path ".gsd/STATE.md") {
    $stateContent = Get-Content ".gsd/STATE.md" -Raw
    $pendingMatch = [regex]::Match($stateContent, '- \*\*ID\*\*:\s*(\S+)')
    $timeMatch = [regex]::Match($stateContent, '- \*\*Started\*\*:\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})')
    $workflowMatch = [regex]::Match($stateContent, '- \*\*Workflow\*\*:\s*(\S+)')
    $statusMatch = [regex]::Match($stateContent, '- \*\*Status\*\*:\s*(\S+)')
    
    if ($pendingMatch.Success -and $timeMatch.Success) {
        $startTime = [datetime]::Parse($timeMatch.Groups[1].Value)
        $elapsedMinutes = ([datetime]::UtcNow - $startTime).TotalMinutes
        
        if ($elapsedMinutes -lt 5) {
            $pendingOp = @{
                ID = $pendingMatch.Groups[1].Value
                Workflow = if ($workflowMatch.Success) { $workflowMatch.Groups[1].Value } else { "unknown" }
                ElapsedMinutes = [math]::Floor($elapsedMinutes)
                Status = if ($statusMatch.Success) { $statusMatch.Groups[1].Value } else { "unknown" }
            }
        }
    }
}
```

**Bash:**
```bash
pending_op=""
elapsed_minutes=""
if [ -f ".gsd/STATE.md" ]; then
    pending_id=$(grep -oP '\*\*ID\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null || echo "")
    started=$(grep -oP '\*\*Started\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null || echo "")
    workflow=$(grep -oP '\*\*Workflow\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null || echo "unknown")
    status=$(grep -oP '\*\*Status\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null || echo "unknown")
    
    if [ -n "$pending_id" ] && [ -n "$started" ]; then
        start_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$started" +%s 2>/dev/null || date -d "$started" +%s 2>/dev/null)
        now_ts=$(date +%s)
        elapsed=$(( (now_ts - start_ts) / 60 ))
        
        if [ "$elapsed" -lt 5 ]; then
            pending_op="$pending_id"
            elapsed_minutes="$elapsed"
        fi
    fi
fi
```

**If pending operation found, show conflict dialog:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠️ CONCURRENT OPERATION DETECTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Operation {$pendingOp.ID} started {$pendingOp.ElapsedMinutes} minute(s) ago
Workflow: {$pendingOp.Workflow}
Status: {$pendingOp.Status}

Options:
  A) Wait and retry — Operation may complete soon
  B) Force continue — May cause conflicts, manual merge required  
  C) Cancel — Abort this operation

Your choice (A/B/C):
```

**PowerShell:**
```powershell
if ($pendingOp) {
    $choice = Read-Host "Your choice (A/B/C)"
    switch ($choice.ToUpper()) {
        "A" { Write-Host "Waiting... Retry this workflow when the other operation completes."; exit 0 }
        "B" { Write-Warning "Proceeding with force continue. Conflicts may require manual merge." }
        "C" { Write-Host "Operation cancelled."; exit 0 }
        default { Write-Error "Invalid choice"; exit 1 }
    }
}
```

**Bash:**
```bash
if [ -n "$pending_op" ]; then
    read -p "Your choice (A/B/C): " choice
    case "${choice^^}" in
        A) echo "Waiting... Retry this workflow when the other operation completes."; exit 0 ;;
        B) echo "Warning: Proceeding with force continue. Conflicts may require manual merge." ;;
        C) echo "Operation cancelled."; exit 0 ;;
        *) echo "Error: Invalid choice" >&2; exit 1 ;;
    esac
fi
```

---

## 3. Validate Roadmap Exists

```powershell
if (-not (Test-Path ".gsd/ROADMAP.md")) {
    Write-Error "ROADMAP.md required. Run /new-milestone first."
}
```

---

## 4. Determine Next Phase Number

```powershell
# Count existing phases
$phases = Select-String -Path ".gsd/ROADMAP.md" -Pattern "### Phase \d+"
$nextPhase = $phases.Count + 1
```

---

## 5. Gather Phase Information

Ask for:

- **Name** — Phase title
- **Objective** — What this phase achieves
- **Depends on** — Previous phases (usually N-1)

---

## 6. Register Operation in STATE.md

Before modifying ROADMAP.md, register this operation:

**PowerShell:**
```powershell
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$operationBlock = @"

## Pending Operation
- **ID**: $operationId
- **Workflow**: /add-phase
- **Started**: $timestamp
- **Status**: in-progress
"@

if (Test-Path ".gsd/STATE.md") {
    $stateContent = Get-Content ".gsd/STATE.md" -Raw
    # Remove any existing pending operation section
    $stateContent = [regex]::Replace($stateContent, "\r?\n## Pending Operation.*?\r?\n(?=## |\Z)", "", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $stateContent = $stateContent + $operationBlock
    Set-Content ".gsd/STATE.md" $stateContent -NoNewline
}
```

**Bash:**
```bash
timestamp=$(date +%Y-%m-%dT%H:%M:%S)
operation_block="

## Pending Operation
- **ID**: $OPERATION_ID
- **Workflow**: /add-phase
- **Started**: $timestamp
- **Status**: in-progress"

if [ -f ".gsd/STATE.md" ]; then
    # Remove any existing pending operation section
    sed -i '/## Pending Operation/,/^$/d' .gsd/STATE.md
    echo "$operation_block" >> .gsd/STATE.md
fi
```

---

## 7. Check ROADMAP.md for Conflicts

Verify ROADMAP.md hasn't been modified since operation started:

**PowerShell:**
```powershell
$roadmapModified = (Get-Item ".gsd/ROADMAP.md").LastWriteTimeUtc
$operationStart = [datetime]::UtcNow
$timeSinceModification = $operationStart - $roadmapModified

if ($timeSinceModification.TotalSeconds -lt 30) {
    Write-Warning "ROADMAP.md was modified recently ($( [math]::Round($timeSinceModification.TotalSeconds) ) seconds ago)"
    $choice = Read-Host "File may have changed. Continue anyway? (y/N)"
    if ($choice -ne "y" -and $choice -ne "Y") {
        Write-Host "Operation cancelled. Please review ROADMAP.md and retry."
        exit 0
    }
}
```

**Bash:**
```bash
modified_ts=$(stat -c %Y .gsd/ROADMAP.md 2>/dev/null || stat -f %m .gsd/ROADMAP.md)
now_ts=$(date +%s)
time_since=$((now_ts - modified_ts))

if [ "$time_since" -lt 30 ]; then
    echo "Warning: ROADMAP.md was modified recently (${time_since}s ago)"
    read -p "File may have changed. Continue anyway? (y/N): " choice
    if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
        echo "Operation cancelled. Please review ROADMAP.md and retry."
        exit 0
    fi
fi
```

---

## 8. Add to ROADMAP.md

Append:

```markdown
---

### Phase {N}: {name}

**Status**: ⬜ Not Started
**Objective**: {objective}
**Depends on**: Phase {N-1}

**Tasks**:

- [ ] TBD (run /plan-phase {N} to create)

**Verification**:

- TBD
```

---

## 9. Complete Operation in STATE.md

Clear the pending operation after successful modification:

**PowerShell:**
```powershell
$stateContent = Get-Content ".gsd/STATE.md" -Raw
# Remove pending operation section, add completion note
$stateContent = [regex]::Replace($stateContent, "\r?\n## Pending Operation.*?\r?\n(?=## |\Z)", "`n## Last Operation`n- **ID**: $operationId`n- **Workflow**: /add-phase`n- **Completed**: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")`n- **Status**: completed`n", [System.Text.RegularExpressions.RegexOptions]::Singleline)
Set-Content ".gsd/STATE.md" $stateContent -NoNewline
```

**Bash:**
```bash
completed_timestamp=$(date +%Y-%m-%dT%H:%M:%S)
# Remove pending operation section
sed -i '/## Pending Operation/,/^$/d' .gsd/STATE.md
# Add completion note
completion_block="

## Last Operation
- **ID**: $OPERATION_ID
- **Workflow**: /add-phase
- **Completed**: $completed_timestamp
- **Status**: completed"
echo "$completion_block" >> .gsd/STATE.md
```

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

## 11. Commit

```powershell
git add .gsd/ROADMAP.md .gsd/STATE.md
git commit -m "docs: add phase {N} - {name}"
```

---

## 12. Offer Next Steps

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE ADDED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase {N}: {name}

───────────────────────────────────────────────────────

▶ NEXT

/plan-phase {N} — Create execution plans for this phase

───────────────────────────────────────────────────────
```

</process>
