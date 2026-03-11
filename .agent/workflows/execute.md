---
description: The Engineer — Execute a specific phase with focused context, including gap closure re-verification tracking
argument-hint: "<phase-number> [--gaps-only]"
version: "1.1.0"
---

# /execute Workflow

<role>
You are a GSD executor orchestrator. You manage wave-based parallel execution of phase plans.

**Core responsibilities:**

- Validate phase exists and has plans
- Discover and group plans by execution wave
- Spawn focused execution for each plan
- Verify phase goal after all plans complete
- Update roadmap and state on completion
- Handle gap closure re-verification workflow
  </role>

<objective>
Execute all plans in a phase using wave-based parallel execution.

Orchestrator stays lean: discover plans, analyze dependencies, group into waves, execute sequentially within waves, verify against phase goal.

**Context budget:** ~15% orchestrator, fresh context per plan execution.
</objective>

<context>
**Phase:** $ARGUMENTS (required - phase number to execute)

**Flags:**

- `--gaps-only` — Execute only gap closure plans (created by `/verify` when issues found)

**Required files:**

- `.gsd/ROADMAP.md` — Phase definitions
- `.gsd/STATE.md` — Current position
- `.gsd/phases/{phase}/` — Phase directory with PLAN.md files
  </context>

<process>

## 1. Validate Environment

**PowerShell:**

```powershell
Test-Path ".gsd/ROADMAP.md"
Test-Path ".gsd/STATE.md"
```

**Bash:**

```bash
test -f ".gsd/ROADMAP.md"
test -f ".gsd/STATE.md"
```

**If not found:** Error — user should run `/plan-phase` first.

---

## 2. Validate Phase Exists

**PowerShell:**

```powershell
# Check phase exists in roadmap
Select-String -Path ".gsd/ROADMAP.md" -Pattern "Phase $PHASE:"
```

**Bash:**

```bash
# Check phase exists in roadmap
grep "Phase $PHASE:" ".gsd/ROADMAP.md"
```

**If not found:** Error with available phases from ROADMAP.md.

---

## 3. Ensure Phase Directory Exists

**PowerShell:**

```powershell
$PHASE_DIR = ".gsd/phases/$PHASE"
if (-not (Test-Path $PHASE_DIR)) {
    New-Item -ItemType Directory -Path $PHASE_DIR
}
```

**Bash:**

```bash
PHASE_DIR=".gsd/phases/$PHASE"
mkdir -p "$PHASE_DIR"
```

---

## 4. Discover Plans

**PowerShell:**

```powershell
Get-ChildItem "$PHASE_DIR/$PHASE.*-PLAN.md"
```

**Bash:**

```bash
ls "$PHASE_DIR/$PHASE.*-PLAN.md" 2>/dev/null
```

**Check for existing summaries** (completed plans):

**PowerShell:**

```powershell
Get-ChildItem "$PHASE_DIR/$PHASE.*-SUMMARY.md"
```

**Bash:**

```bash
ls "$PHASE_DIR/$PHASE.*-SUMMARY.md" 2>/dev/null
```

**Build list of incomplete plans** (PLAN without matching SUMMARY).

**If `--gaps-only`:** Filter to only plans with `gap_closure: true` in frontmatter.

**If no incomplete plans found:** Phase already complete, skip to step 8.

---

## 5. Group Plans by Wave

Read `wave` field from each plan's frontmatter:

```yaml
---
phase: 1
plan: 2
wave: 1
---
```

**Group plans by wave number.** Lower waves execute first.

Display wave structure:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► EXECUTING PHASE {N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Wave 1: {plan-1}, {plan-2}
Wave 2: {plan-3}

{X} plans across {Y} waves
```

---

## 6. Execute Waves

For each wave in order:

### 6a. Execute Plans in Wave

For each plan in the current wave:

1. **Load plan context** — Read only the PLAN.md file
2. **Execute tasks** — Follow `<task>` blocks in order
3. **Verify each task** — Run `<verify>` commands 4. **Commit per task:**
   ```bash
   git add -A
   git commit -m "feat(phase-{N}): {task-name}"
   ```

   5. **Create {phase}.{plan}-SUMMARY.md** — Document what was done

### 6b. Verify Wave Complete

Check all plans in wave have SUMMARY.md files.

### 6c. Proceed to Next Wave

Only after current wave fully completes.

---

## 7. Verify Phase Goal

After all waves complete:

1. **Read phase goal** from ROADMAP.md
2. **Check must-haves** against actual codebase (not SUMMARY claims)
3. **Run verification commands** specified in phase

**Create VERIFICATION.md:**

```markdown
## Phase {N} Verification

### Must-Haves

- [x] Must-have 1 — VERIFIED (evidence: ...)
- [ ] Must-have 2 — FAILED (reason: ...)

### Verdict: PASS / FAIL
```

**Route by verdict:**

- `PASS` → Continue to step 8
- `FAIL` → Create gap closure plans, offer `/execute {N} --gaps-only`

---

## 8. Handle Post-Execution Verification

### 8a. If `--gaps-only` flag was used:

**Check for existing VERIFICATION.md:**

```bash
test -f ".gsd/phases/{phase}/VERIFICATION.md" && echo "exists" || echo "not found"
```

**If VERIFICATION.md exists:**

1. Read previous verdict
2. If previous was FAIL with gaps:

   **Prompt for re-verification:**
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    GSD ► GAP CLOSURE COMPLETE
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
   Gap closure execution complete.
   
   Re-verification recommended to confirm all issues resolved.
   
   Run: /verify {N}
   
   ───────────────────────────────────────────────────────
   ```

3. **Update STATE.md:**
   ```markdown
   ## Current Position
   - **Phase**: {N}
   - **Status**: ⏳ Awaiting re-verification
   - **Note**: Gap closure plans executed. Verification required.
   ```

**Skip to step 11 (commit only).**

### 8b. Regular execution flow:

**Check for existing VERIFICATION.md with FAIL verdict:**

```bash
# Check if VERIFICATION.md exists and has FAIL verdict
grep -q "verdict: FAIL" ".gsd/phases/{phase}/VERIFICATION.md" 2>/dev/null && echo "has_failures" || echo "clean"
```

**If FAIL verdict found:**

1. **Archive old verification:**
   ```bash
   ARCHIVE_FILE=".gsd/phases/{phase}/VERIFICATION-HISTORY.md"
   echo -e "\n---\n\n## Archived Verification $(date +%Y-%m-%d)\n" >> "$ARCHIVE_FILE"
   cat ".gsd/phases/{phase}/VERIFICATION.md" >> "$ARCHIVE_FILE"
   rm ".gsd/phases/{phase}/VERIFICATION.md"
   ```

2. Note: New verification will be created fresh

---

## 9. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "STATE.md,ROADMAP.md"
$workflow = "/execute"

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
resource="STATE.md,ROADMAP.md"
workflow="/execute"

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

## 10. Update Roadmap and State

**PowerShell:**
```powershell
try {
```

**Bash:**
```bash
trap 'rm -f "$lock_file"' EXIT
```

**Update ROADMAP.md:**

```markdown
### Phase {N}: {Name}

**Status**: ✅ Complete
```

**Update STATE.md:**

```markdown
## Current Position

- **Phase**: {N} (completed)
- **Task**: All tasks complete
- **Status**: Verified

## Last Session Summary

Phase {N} executed successfully. {X} plans, {Y} tasks completed.

## Next Steps

1. Proceed to Phase {N+1}
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

## 11. Commit Phase Completion

```bash
git add .gsd/ROADMAP.md .gsd/STATE.md
git add .gsd/phases/{phase}/VERIFICATION-HISTORY.md 2>/dev/null || true
git commit -m "docs(phase-{N}): complete {phase-name}"
```

---

## 12. Offer Next Steps

</process>

<offer_next>
Output based on status:

**Route A: Phase complete, more phases remain**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE {N} COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{X} plans executed
Goal verified ✓

───────────────────────────────────────────────────────

▶ Next Up
Phase {N+1}: {Name}

/plan-phase {N+1}  — create execution plans
/execute {N+1} — execute directly (if plans exist)

───────────────────────────────────────────────────────
```

**Route B: All phases complete**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► MILESTONE COMPLETE 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All phases completed and verified.

───────────────────────────────────────────────────────
```

**Route C: Gaps found**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE {N} GAPS FOUND ⚠
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{X}/{Y} must-haves verified
Gap closure plans created.

/execute {N} --gaps-only — execute fix plans

───────────────────────────────────────────────────────
```

**Route D: Gap closure complete, awaiting re-verification**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► GAP CLOSURE COMPLETE ⏳
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gap closure execution complete.
All fix plans executed.

Re-verification required to confirm issues resolved.

───────────────────────────────────────────────────────

▶ Next Up

/verify {N} — re-verify phase after gap closure

───────────────────────────────────────────────────────
```

</offer_next>

<context_hygiene>
**After 3 failed debugging attempts:**

1. Stop current approach
2. Document to `.gsd/STATE.md` what was tried
3. Recommend `/pause` for fresh session
   </context_hygiene>

<related>
## Related

### Workflows

| Command   | Relationship                             |
| --------- | ---------------------------------------- |
| `/plan-phase`   | Creates PLAN.md files that /execute runs |
| `/verify` | Validates work after /execute completes  |
| `/debug-flow`  | Use when tasks fail verification         |
| `/pause`  | Use after 3 debugging failures           |

### Skills

| Skill                    | Purpose                     |
| ------------------------ | --------------------------- |
| `executor`               | Detailed execution protocol |
| `context-health-monitor` | 3-strike rule enforcement   |
| `empirical-validation`   | Verification requirements   |

</related>
