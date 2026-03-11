---
description: Insert a new phase — interview user for position (next, between, or last)
version: "1.0.0"
tags: ['roadmap', 'phases', 'planning']
---

# /insert-phase Workflow

<objective>
Insert a new phase into the roadmap. Interview the user to determine insertion position:
- **Next** — After the current active phase
- **Between** — At a specific position between existing phases
- **Last** — At the end of the roadmap (same as `/add-phase`)

Renumber subsequent phases to maintain timeline integrity.
</objective>

<context>
**No arguments required.** Interactive workflow.

**Requires:**
- `.gsd/ROADMAP.md` — existing roadmap with phases
- `.gsd/STATE.md` — to identify current phase (for "next" option)

**Outputs:**
- Updated `.gsd/ROADMAP.md` with new phase inserted and renumbered
- Updated phase directories (if they exist)
</context>

<process>

## 1. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "ROADMAP.md,STATE.md"
$workflow = "/insert-phase"

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
workflow="/insert-phase"

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

## 3. Identify Current Phase (STATE.md + ROADMAP.md)

Parse both files to determine current phase. STATE.md is primary, ROADMAP.md is fallback.

**PowerShell:**
```powershell
$currentPhase = $null
if (Test-Path ".gsd/STATE.md") {
    $stateMatch = [regex]::Match((Get-Content ".gsd/STATE.md" -Raw), 'Current Phase[:\s]+(\d+)')
    if ($stateMatch.Success) { $currentPhase = [int]$stateMatch.Groups[1].Value }
}
if (-not $currentPhase -and (Test-Path ".gsd/ROADMAP.md")) {
    $rdMatch = [regex]::Match((Get-Content ".gsd/ROADMAP.md" -Raw), '> \*\*Current Phase:\*\*\s*(\d+)')
    if ($rdMatch.Success) { $currentPhase = [int]$rdMatch.Groups[1].Value }
}
if (-not $currentPhase) { Write-Error "Cannot determine current phase"; exit 1 }
```

**Bash:**
```bash
current_phase=""
[ -f ".gsd/STATE.md" ] && current_phase=$(grep -oP 'Current Phase[:\s]+\K\d+' .gsd/STATE.md 2>/dev/null)
[ -z "$current_phase" ] && [ -f ".gsd/ROADMAP.md" ] && current_phase=$(grep -oP '> \*\*Current Phase:\*\*\s*\K\d+' .gsd/ROADMAP.md 2>/dev/null)
[ -z "$current_phase" ] && { echo "Error: Cannot determine current phase" >&2; exit 1; }
```

## 4. Interview User for Insertion Position

```
📍 WHERE SHOULD THE NEW PHASE BE INSERTED?

Current active phase: Phase {N}

Options:
1) NEXT — Insert immediately after Phase {N} (recommended)
2) BETWEEN — Insert at a specific position (e.g., between Phase 2 and 3)
3) LAST — Add at the end of the roadmap

Your choice (1/2/3):
```

**Handle selection:**

**PowerShell:**
```powershell
$choice = Read-Host "Your choice"
$totalPhases = (Select-String -Path ".gsd/ROADMAP.md" -Pattern "### Phase \d+").Count

switch ($choice) {
    "1" { $insertPosition = $currentPhase + 1 }
    "2" { $insertPosition = [int](Read-Host "Insert before which phase number?") }
    "3" { $insertPosition = $totalPhases + 1 }
    default { Write-Error "Invalid choice"; exit 1 }
}

if ($insertPosition -lt 1 -or $insertPosition -gt $totalPhases + 1) {
    Write-Error "Invalid position. Valid: 1-$($totalPhases + 1)"
    exit 1
}
```

**Bash:**
```bash
read -p "Your choice: " choice
total_phases=$(grep -c "### Phase [0-9]" .gsd/ROADMAP.md)

case "$choice" in
    1) insert_position=$((current_phase + 1)) ;;
    2) read -p "Insert before which phase: " insert_position ;;
    3) insert_position=$((total_phases + 1)) ;;
    *) echo "Error: Invalid choice" >&2; exit 1 ;;
esac

if [ "$insert_position" -lt 1 ] || [ "$insert_position" -gt $((total_phases + 1)) ]; then
    echo "Error: Invalid position" >&2; exit 1
fi
```

## 5. Gather Phase Information

```
📋 NEW PHASE DETAILS

Inserting at position: {position}

1. Phase Title:
2. Objective (what this phase achieves):
3. Deliverables (concrete outputs):
4. Dependencies (comma-separated phase numbers):
```

## 6. Register Operation in STATE.md

Before modifying ROADMAP.md, register this operation:

**PowerShell:**
```powershell
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
$operationBlock = @"

## Pending Operation
- **ID**: $operationId
- **Workflow**: /insert-phase
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
- **Workflow**: /insert-phase
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

## 8. Renumber Existing Phases

Process phases in **reverse order** to avoid collisions:

**PowerShell:**
```powershell
$content = Get-Content ".gsd/ROADMAP.md" -Raw
for ($i = $totalPhases; $i -ge $insertPosition; $i--) {
    $content = $content -replace "### Phase $i\b", "### Phase $($i + 1)"
    $content = $content -replace "Depends on: Phase $i\b", "Depends on: Phase $($i + 1)"
}
Set-Content ".gsd/ROADMAP.md" $content -NoNewline

# Rename directories
for ($i = $totalPhases; $i -ge $insertPosition; $i--) {
    if (Test-Path ".gsd/phases/$i") { Rename-Item ".gsd/phases/$i" ".gsd/phases/$($i + 1)" }
}
```

**Bash:**
```bash
for i in $(seq $total_phases -1 $insert_position); do
    sed -i "s/### Phase $i\b/### Phase $((i + 1))/g" .gsd/ROADMAP.md
    sed -i "s/Depends on: Phase $i\b/Depends on: Phase $((i + 1))/g" .gsd/ROADMAP.md
    [ -d ".gsd/phases/$i" ] && mv ".gsd/phases/$i" ".gsd/phases/$((i + 1))"
done
```

## 9. Insert New Phase

**PowerShell:**
```powershell
$newPhase = @"

### Phase $insertPosition`: $title
**Status:** ⬜ Not Started
**Objective:** $objective
**Deliverables:** $deliverables
**Dependencies:** $dependencies

**Plans:**
- [ ] Plan $insertPosition`.1: [To be defined]

---

"@

# Insert after the phase before insertPosition, or at start
if ($insertPosition -eq 1) {
    $content = Get-Content ".gsd/ROADMAP.md" -Raw
    $content = $newPhase + $content
} else {
    $prevPhase = $insertPosition - 1
    $pattern = "(### Phase $prevPhase.*?(?=### Phase|\Z))"
    $content = [regex]::Replace($content, $pattern, "`$1$newPhase", [System.Text.RegularExpressions.RegexOptions]::Singleline)
}
Set-Content ".gsd/ROADMAP.md" $content -NoNewline
```

**Bash:**
```bash
new_phase="### Phase $insert_position: $title
**Status:** ⬜ Not Started
**Objective:** $objective
**Deliverables:** $deliverables
**Dependencies:** $dependencies

**Plans:**
- [ ] Plan ${insert_position}.1: [To be defined]

---"

if [ "$insert_position" -eq 1 ]; then
    echo -e "$new_phase\n$(cat .gsd/ROADMAP.md)" > .gsd/ROADMAP.md
else
    prev=$((insert_position - 1))
    awk -v p="$prev" -v n="$new_phase" '
        /^### Phase / { if (found) { print n; found=0 } }
        /^### Phase / && $3 == p":" { found=1 }
        { print }
        END { if (found) print n }
    ' .gsd/ROADMAP.md > .gsd/ROADMAP.md.tmp && mv .gsd/ROADMAP.md.tmp .gsd/ROADMAP.md
fi
```

## 10. Update STATE.md (if needed)

If current phase >= insert position, increment in STATE.md:

**PowerShell:**
```powershell
if ($currentPhase -ge $insertPosition) {
    $state = Get-Content ".gsd/STATE.md" -Raw
    $state = $state -replace "Current Phase[:\s]+$currentPhase\b", "Current Phase: $($currentPhase + 1)"
    Set-Content ".gsd/STATE.md" $state -NoNewline
}
```

**Bash:**
```bash
if [ "$current_phase" -ge "$insert_position" ]; then
    sed -i "s/Current Phase[:\s]+$current_phase\b/Current Phase: $((current_phase + 1))/" .gsd/STATE.md
fi
```

## 11. Complete Operation in STATE.md

Clear the pending operation after successful modification:

**PowerShell:**
```powershell
$stateContent = Get-Content ".gsd/STATE.md" -Raw
# Remove pending operation section, add completion note
$stateContent = [regex]::Replace($stateContent, "\r?\n## Pending Operation.*?\r?\n(?=## |\Z)", "`n## Last Operation`n- **ID**: $operationId`n- **Workflow**: /insert-phase`n- **Completed**: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")`n- **Status**: completed`n", [System.Text.RegularExpressions.RegexOptions]::Singleline)
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
- **Workflow**: /insert-phase
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

## 13. Commit

```bash
git add -A
git commit -m "docs: insert Phase $insertPosition - $title (renumbered phases)"
```

## 13. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE INSERTED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Inserted: Phase {N}: {title}
Position: {position_description}
Renumbered: Phases {N+1} through {M}

▶ NEXT
/plan-phase {N} — Create execution plans
/discuss-phase {N} — Clarify scope
/progress — View updated roadmap
```

</process>

<warning>
Phase insertion affects subsequent numbering. Use sparingly early in milestone lifecycle.
</warning>

<related>
| Command | Purpose |
|---------|---------|
| `/add-phase` | Add phase at end of roadmap |
| `/remove-phase` | Remove a phase (triggers renumbering) |
| `/plan-phase` | Create execution plans |
</related>
