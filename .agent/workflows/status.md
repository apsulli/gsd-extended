---
description: Unified view of project state — roadmap, phases, todos, debug sessions, and git status
version: "1.0.0"
tags: ['status', 'overview', 'dashboard']
---

# /status Workflow

<objective>
Provide a unified view of the entire project state, aggregating information from STATE.md, ROADMAP.md, phase plans, TODO.md, JOURNAL.md, debug sessions, and git status.
</objective>

<context>
**No arguments required.** Reads and displays current project state.

**Reads from:**
- `.gsd/STATE.md` — Current position and status
- `.gsd/ROADMAP.md` — Phase structure and progress
- `.gsd/phases/{N}/` — Plan files for current phase
- `.gsd/TODO.md` — Pending items
- `.gsd/JOURNAL.md` — Recent activity
- `debugging/` — Active debug sessions
- `git status` — Uncommitted changes
</context>

<process>

## 1. Display Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PROJECT STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 2. Load Project State

**PowerShell:**
```powershell
$state = if (Test-Path ".gsd/STATE.md") { Get-Content ".gsd/STATE.md" -Raw } else { $null }
$roadmap = if (Test-Path ".gsd/ROADMAP.md") { Get-Content ".gsd/ROADMAP.md" -Raw } else { $null }
$todo = if (Test-Path ".gsd/TODO.md") { Get-Content ".gsd/TODO.md" -Raw } else { $null }
$journal = if (Test-Path ".gsd/JOURNAL.md") { Get-Content ".gsd/JOURNAL.md" -Raw } else { $null }
```

**Bash:**
```bash
STATE=$(cat .gsd/STATE.md 2>/dev/null || echo "")
ROADMAP=$(cat .gsd/ROADMAP.md 2>/dev/null || echo "")
TODO=$(cat .gsd/TODO.md 2>/dev/null || echo "")
JOURNAL=$(cat .gsd/JOURNAL.md 2>/dev/null || echo "")
```

---

## 3. Display Project State

Parse `.gsd/STATE.md` frontmatter and content:

```
───────────────────────────────────────────────────────
PROJECT STATE
───────────────────────────────────────────────────────

Milestone:  {milestone from STATE.md}
Phase:      {phase number and name}
Status:     {planning | executing | verifying | blocked | paused}
Plan:       {current plan if executing}

Last Action:
  {What was just completed}

Next Steps:
  1. {Immediate next action}
  2. {Following action}
  3. {Third action if known}
```

If STATE.md doesn't exist:
```
⚠️  No STATE.md found — project may not be initialized
   Run: /gsd-init
```

---

## 4. Display Roadmap Progress

Parse `.gsd/ROADMAP.md` for phases:

```
───────────────────────────────────────────────────────
ROADMAP PROGRESS
───────────────────────────────────────────────────────

✅ Phase 1: {Name}
✅ Phase 2: {Name}
🔄 Phase 3: {Name} ← CURRENT
⬜ Phase 4: {Name}
⬜ Phase 5: {Name}

Progress: {completed}/{total} phases ({percentage}%)
```

**PowerShell:**
```powershell
$phases = [regex]::Matches($roadmap, "### Phase (\d+): (.+)\n\*\*Status:\*\* (⬜|🔄|✅|⏸️|❌)")
$total = $phases.Count
$completed = ($phases | Where-Object { $_.Groups[3].Value -eq "✅" }).Count
$current = $phases | Where-Object { $_.Groups[3].Value -eq "🔄" }
```

**Bash:**
```bash
# Count phases by status
total=$(grep -c "### Phase" .gsd/ROADMAP.md 2>/dev/null || echo "0")
completed=$(grep -c "Status:.*✅" .gsd/ROADMAP.md 2>/dev/null || echo "0")
in_progress=$(grep -c "Status:.*🔄" .gsd/ROADMAP.md 2>/dev/null || echo "0")
```

---

## 5. Display Current Phase Details

List all plans in `.gsd/phases/{N}/`:

```
───────────────────────────────────────────────────────
CURRENT PHASE DETAILS
───────────────────────────────────────────────────────

Phase {N}: {name}

Plans:
  ✅ 1.1 {name} (completed)
  ✅ 1.2 {name} (completed)
  🔄 1.3 {name} (in progress)
  ⬜ 1.4 {name} (pending)

Plan Status: {completedPlans}/{totalPlans} complete
```

For each plan, check:
- `PLAN.md` exists → plan created
- `SUMMARY.md` exists → plan completed

**PowerShell:**
```powershell
$phaseNum = $currentPhaseNumber
$phasePath = ".gsd/phases/$phaseNum"
if (Test-Path $phasePath) {
    $plans = Get-ChildItem "$phasePath/*-PLAN.md" -ErrorAction SilentlyContinue
    foreach ($plan in $plans) {
        $planNum = $plan.Name -replace '.*?(\d+\.\d+).*','$1'
        $summary = $plan.FullName -replace '-PLAN\.md','-SUMMARY.md'
        $status = if (Test-Path $summary) { "✅" } else { "🔄" }
        "  $status $planNum"
    }
}
```

**Bash:**
```bash
PHASE_NUM=1  # extracted from STATE.md
PHASE_DIR=".gsd/phases/$PHASE_NUM"

if [ -d "$PHASE_DIR" ]; then
    for plan in "$PHASE_DIR"/*-PLAN.md; do
        [ -e "$plan" ] || continue
        plan_file=$(basename "$plan")
        plan_num=$(echo "$plan_file" | grep -oE '\d+\.\d+')
        summary="${plan/-PLAN.md/-SUMMARY.md}"
        if [ -f "$summary" ]; then
            echo "  ✅ $plan_num (completed)"
        else
            echo "  🔄 $plan_num (in progress)"
        fi
    done
fi
```

---

## 6. Display Active Debug Sessions

List all directories in `debugging/`:

```
───────────────────────────────────────────────────────
ACTIVE DEBUG SESSIONS
───────────────────────────────────────────────────────

{count} debug session(s):

  🔄 {session-name}/  [Status: active]  Updated: {date}
  ⏸️ {session-name}/  [Status: paused]  Updated: {date}
  ✅ {session-name}/  [Status: resolved]  Updated: {date}
```

Read status from `RESEARCH.md` frontmatter if exists:

**PowerShell:**
```powershell
$sessions = Get-ChildItem "debugging/*/" -Directory -ErrorAction SilentlyContinue
foreach ($session in $sessions) {
    $research = "$($session.FullName)/RESEARCH.md"
    if (Test-Path $research) {
        $fm = (Get-Content $research -Head 5) | Select-String "^status:\s*(\w+)"
        $status = $fm.Matches.Groups[1].Value
    }
    "  {icon} $($session.Name)/  [Status: $status]"
}
```

**Bash:**
```bash
if [ -d "debugging" ]; then
    for session in debugging/*/; do
        [ -e "$session" ] || continue
        name=$(basename "$session")
        research="$session/RESEARCH.md"
        if [ -f "$research" ]; then
            status=$(head -10 "$research" | grep -E "^status:" | sed 's/status:\s*//' | tr -d '\r')
            [ -z "$status" ] && status="unknown"
        else
            status="no research"
        fi
        echo "  $name  [Status: $status]"
    done
else
    echo "  No debug sessions"
fi
```

---

## 7. Display Pending Todos

Parse `.gsd/TODO.md` for high priority items:

```
───────────────────────────────────────────────────────
PENDING TODOS
───────────────────────────────────────────────────────

High Priority (🔴):
  • {Todo item description}
  • {Todo item description}

Medium Priority (🟡):
  • {Todo item description}

Low Priority (🟢):
  • {Todo item description}

Total: {pendingCount} pending / {totalCount} total
```

**PowerShell:**
```powershell
$high = [regex]::Matches($todo, "^- \[ \] (.+?) `high`").Count
$medium = [regex]::Matches($todo, "^- \[ \] (.+?) `medium`").Count
$low = [regex]::Matches($todo, "^- \[ \] (.+?) `low`").Count
$completed = ([regex]::Matches($todo, "^- \[x\]")).Count
$pending = $high + $medium + $low
```

**Bash:**
```bash
if [ -f ".gsd/TODO.md" ]; then
    high=$(grep -c "^\- \[ \].*\`high\`" .gsd/TODO.md 2>/dev/null || echo "0")
    medium=$(grep -c "^\- \[ \].*\`medium\`" .gsd/TODO.md 2>/dev/null || echo "0")
    low=$(grep -c "^\- \[ \].*\`low\`" .gsd/TODO.md 2>/dev/null || echo "0")
    completed=$(grep -c "^\- \[x\]" .gsd/TODO.md 2>/dev/null || echo "0")
else
    echo "  No TODO.md found"
fi
```

---

## 8. Display Uncommitted Changes

Run `git status --short`:

```
───────────────────────────────────────────────────────
UNCOMMITTED CHANGES
───────────────────────────────────────────────────────

{git status output}
```

**PowerShell:**
```powershell
$gitStatus = git status --short 2>$null
if ([string]::IsNullOrWhiteSpace($gitStatus)) {
    "  ✅ Working directory clean"
} else {
    $gitStatus
}
```

**Bash:**
```bash
git_status=$(git status --short 2>/dev/null)
if [ -z "$git_status" ]; then
    echo "  ✅ Working directory clean"
else
    echo "$git_status"
fi
```

---

## 9. Display Recent Journal Activity

Parse `.gsd/JOURNAL.md` for last session:

```
───────────────────────────────────────────────────────
RECENT JOURNAL ACTIVITY
───────────────────────────────────────────────────────

Last Session: {YYYY-MM-DD HH:MM}
Objective: {Session objective from last entry}

Key Accomplishments:
  • {Accomplishment 1}
  • {Accomplishment 2}
```

**PowerShell:**
```powershell
$lastSession = [regex]::Match($journal, "## Session:\s*(.+?\d{2}:\d{2})").Groups[1].Value
$objective = [regex]::Match($journal, "### Objective\s*\n(.+)").Groups[1].Value
```

**Bash:**
```bash
last_session=$(grep -m1 "## Session:" .gsd/JOURNAL.md 2>/dev/null | sed 's/## Session://' | xargs)
objective=$(awk '/### Objective/{getline; print; exit}' .gsd/JOURNAL.md 2>/dev/null | xargs)
```

---

## 10. Display Footer

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▶ Quick Actions:
  /progress     — Detailed phase progress
  /execute {N}  — Execute current/next plan
  /plan-phase   — Plan next phase
  /check-todos  — View all todos

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</process>

<related>
| Command | Purpose |
|---------|---------|
| `/progress` | Detailed roadmap progress |
| `/execute` | Execute current plan |
| `/check-todos` | Full todo list view |
| `/pause-work` | Pause current phase |
| `/resume-work` | Resume paused work |
</related>
