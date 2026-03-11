---
description: Restore context from previous session
version: "1.0.0"
---

# /resume-work Workflow

<objective>
Start a new session with full context from where we left off.
</objective>

<process>

## 1. Load Saved State

Read `.gsd/STATE.md` completely.

---

## 1.5. Validate State

Read **STATE.md** and extract current state:
- Current phase number
- Current status
- Last action

**Bash:**
```bash
# Extract values from STATE.md
PHASE=$(grep -E "^\\*\\*Phase\\*\\*:" .gsd/STATE.md | sed 's/.*: *//' | tr -d '\r')
STATUS=$(grep -E "^\\*\\*Status\\*\\*:" .gsd/STATE.md | sed 's/.*: *//' | tr -d '\r')
LAST_ACTION=$(grep -E "^\\*\\*Last Action\\*\\*:" .gsd/STATE.md | sed 's/.*: *//' | tr -d '\r')
echo "Phase: $PHASE, Status: $STATUS, Last Action: $LAST_ACTION"
```

**PowerShell:**
```powershell
# Extract values from STATE.md
$phase = (Select-String -Path ".gsd/STATE.md" -Pattern "^\*\*Phase\*\*:" | ForEach-Object { $_.Line -replace ".*:\s*", "" }).Trim()
$status = (Select-String -Path ".gsd/STATE.md" -Pattern "^\*\*Status\*\*:" | ForEach-Object { $_.Line -replace ".*:\s*", "" }).Trim()
$lastAction = (Select-String -Path ".gsd/STATE.md" -Pattern "^\*\*Last Action\*\*:" | ForEach-Object { $_.Line -replace ".*:\s*", "" }).Trim()
Write-Host "Phase: $phase, Status: $status, Last Action: $lastAction"
```

### Validate Consistency

**Check 1: Does phase exist in ROADMAP.md?**

**Bash:**
```bash
# Check if phase exists in ROADMAP.md
if ! grep -q "^## Phase $PHASE" ROADMAP.md 2>/dev/null; then
    echo "INCONSISTENCY: Phase $PHASE in STATE.md not found in ROADMAP.md"
fi
```

**PowerShell:**
```powershell
# Check if phase exists in ROADMAP.md
$phaseHeader = "## Phase $phase"
$phaseExists = Select-String -Path "ROADMAP.md" -Pattern "^$([regex]::Escape($phaseHeader))" -Quiet
if (-not $phaseExists) {
    Write-Host "INCONSISTENCY: Phase $phase in STATE.md not found in ROADMAP.md"
}
```

**Check 2: Does phases/{N}/ directory exist?**

**Bash:**
```bash
# Check if phase directory exists
PHASE_NUM=$(echo "$PHASE" | grep -oE '[0-9]+')
if [ ! -d ".gsd/phases/$PHASE_NUM" ]; then
    echo "INCONSISTENCY: Phases directory missing: .gsd/phases/$PHASE_NUM/"
fi
```

**PowerShell:**
```powershell
# Check if phase directory exists
$phaseNum = $phase -replace '[^0-9]', ''
$phaseDir = ".gsd/phases/$phaseNum"
if (-not (Test-Path $phaseDir -PathType Container)) {
    Write-Host "INCONSISTENCY: Phases directory missing: $phaseDir/"
}
```

**Check 3: Uncommitted changes that don't match claimed state?**

**Bash:**
```bash
# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)
if [ -n "$UNCOMMITTED" ]; then
    MODIFIED_FILES=$(git status --porcelain | wc -l)
    echo "INCONSISTENCY: Uncommitted changes: $MODIFIED_FILES files"
    echo "$UNCOMMITTED" | head -10
fi
```

**PowerShell:**
```powershell
# Check for uncommitted changes
$uncommitted = git status --porcelain
if ($uncommitted) {
    $modifiedFiles = ($uncommitted | Measure-Object).Count
    Write-Host "INCONSISTENCY: Uncommitted changes: $modifiedFiles files"
    $uncommitted | Select-Object -First 10
}
```

**Check 4: STATE.md says "Paused" but no pause commit?**

**Bash:**
```bash
# Check if STATE claims Paused but git has no pause commit
if [[ "$STATUS" == *"Paused"* ]]; then
    # Check for pause commit in recent history
    if ! git log --oneline -5 | grep -qi "pause"; then
        echo "INCONSISTENCY: STATE.md status is 'Paused' but no pause commit found in recent history"
    fi
fi
```

**PowerShell:**
```powershell
# Check if STATE claims Paused but git has no pause commit
if ($status -match "Paused") {
    $pauseCommit = git log --oneline -5 | Select-String -Pattern "pause" -Quiet
    if (-not $pauseCommit) {
        Write-Host "INCONSISTENCY: STATE.md status is 'Paused' but no pause commit found in recent history"
    }
}
```

### Report Inconsistencies

If any inconsistencies detected:

```
⚠️ STATE INCONSISTENCIES DETECTED

- Phase {N} in STATE.md not found in ROADMAP.md
- Phases directory missing: .gsd/phases/{N}/
- Uncommitted changes: {files}

Recommend: /status to see full state, or manually fix inconsistencies
```

### Auto-Fix Minor Issues

**Auto-create missing phase directory (if phase exists in ROADMAP):**

**Bash:**
```bash
# Auto-create phase directory if ROADMAP has phase but directory missing
PHASE_NUM=$(echo "$PHASE" | grep -oE '[0-9]+')
if grep -q "^## Phase $PHASE" ROADMAP.md 2>/dev/null && [ ! -d ".gsd/phases/$PHASE_NUM" ]; then
    mkdir -p ".gsd/phases/$PHASE_NUM/plans" ".gsd/phases/$PHASE_NUM/artifacts"
    echo "✅ Auto-created missing phase directory: .gsd/phases/$PHASE_NUM/"
fi
```

**PowerShell:**
```powershell
# Auto-create phase directory if ROADMAP has phase but directory missing
$phaseNum = $phase -replace '[^0-9]', ''
$phaseHeader = "## Phase $phase"
$phaseInRoadmap = Select-String -Path "ROADMAP.md" -Pattern "^$([regex]::Escape($phaseHeader))" -Quiet
$phaseDirExists = Test-Path ".gsd/phases/$phaseNum" -PathType Container

if ($phaseInRoadmap -and -not $phaseDirExists) {
    New-Item -ItemType Directory -Path ".gsd/phases/$phaseNum/plans" -Force | Out-Null
    New-Item -ItemType Directory -Path ".gsd/phases/$phaseNum/artifacts" -Force | Out-Null
    Write-Host "✅ Auto-created missing phase directory: .gsd/phases/$phaseNum/"
}
```

**Note:** Status/git inconsistencies are NOT auto-fixed — they require manual review.

---

## 2. Display Context

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► RESUMING SESSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LAST POSITION
─────────────
Phase: {phase from STATE.md}
Task: {task from STATE.md}
Status: {status when paused}

───────────────────────────────────────────────────────

CONTEXT FROM LAST SESSION
─────────────────────────
{Context dump content from STATE.md}

───────────────────────────────────────────────────────

BLOCKERS
────────
{Blockers from STATE.md, or "None"}

───────────────────────────────────────────────────────

NEXT STEPS (from last session)
──────────────────────────────
1. {First priority}
2. {Second priority}
3. {Third priority}

───────────────────────────────────────────────────────
```

---

## 3. Load Recent Journal

Read `.gsd/JOURNAL.md` (the **hot log** — last 5 sessions max).

- Show the most recent entry's accomplishments and handoff notes.
- **Do NOT load archive files** unless the user explicitly asks for historical context.
- If the user asks "what happened during Phase X?" or "what did we do last month?", search `.gsd/journal/` archives:
  ```bash
  grep -A 30 "Phase X" .gsd/journal/2026-02-archive.md
  ```

---

## 4. Check for Conflicts

```bash
# Check for uncommitted changes
git status --porcelain
```

**If changes found:**

```
⚠️ UNCOMMITTED CHANGES DETECTED

{list of modified files}

These may be from the previous session.
Review before proceeding.
```

---

## 5. Update State

Mark session as active in `.gsd/STATE.md`:

```markdown
**Status**: Active (resumed {timestamp})
```

---

## 6. Suggest Action

```
───────────────────────────────────────────────────────

▶ READY TO CONTINUE

Suggested action based on state:

{One of:}
• /execute {N} — Continue phase execution
• /verify {N} — Verify completed phase
• /plan-phase {N} — Create plans for phase
• /progress — See full roadmap status

───────────────────────────────────────────────────────

💡 Fresh session = fresh perspective

You have all the context you need.
The previous struggles are documented.
Time to solve this with fresh eyes.

───────────────────────────────────────────────────────
```

</process>

<fresh_context_advantage>
A resumed session has advantages:

1. **No accumulated confusion** — You see the problem clearly
2. **Documented failures** — You know what NOT to try
3. **Hypothesis preserved** — Pick up where logic left off
4. **Full context budget** — 200k tokens of fresh capacity

Often the first thing a fresh context sees is the obvious solution that a tired context missed.
</fresh_context_advantage>
