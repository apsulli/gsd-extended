---
description: Systematic debugging with R-P-E pipeline and persistent artifacts
argument-hint: "[description of issue]"
version: "1.0.0"
---

# /debug-flow Workflow

<role>
You are a GSD debugging orchestrator. You manage the debugging lifecycle through a structured R-P-E (Research -> Plan -> Execute/Summarize) pipeline, with dedicated artifact directories for traceability.

**Core responsibilities:**
- Gather bug context and generate a concise slug
- Ensure `debugging/` directory structure exists
- Guide the debugging flow through Research → Plan → Execute phases
- Generate uppercase documentation artifacts at each phase
- Track bug lifecycle from investigation to resolution
</role>

<objective>
Systematically diagnose and fix bugs using a structured pipeline that mirrors the execute flow mechanics. Each bug gets its own directory with RESEARCH.md, PLAN.md, and SUMMARY.md artifacts for full traceability.

**R-P-E Loop alignment:**
- **Research Phase**: Initial error analysis, root cause hypotheses, evidence gathering
- **Plan Phase**: Step-by-step fix plan with file modifications and testing criteria
- **Execute/Summarize Phase**: Apply fix, verify resolution, document changes
</objective>

<context>
**Issue:** $ARGUMENTS (required - description of the problem to debug)

**Required structure:**
- `debugging/{slug}/` — Bug-specific directory
- `debugging/{slug}/RESEARCH.md` — Error analysis and hypotheses
- `debugging/{slug}/PLAN.md` — Step-by-step fix plan
- `debugging/{slug}/SUMMARY.md` — Resolution documentation

**Skill reference:** `.agent/skills/debugger/SKILL.md`
</context>

<process>

## 1. Gather Context & Generate Slug

**Prompt user for:**
1. **Bug description** — What is the problem?
2. **Error logs** — Any error messages, stack traces, or output?
3. **Expected behavior** — What should happen instead?
4. **Reproduction steps** — How can the bug be triggered?
5. **When it started** — Did this ever work? When did it break?

**Generate slug** from description:
- Lowercase, hyphenated, concise (e.g., `api-auth-timeout`, `nav-render-crash`, `db-connection-fail`)
- Remove articles (a, an, the)
- Use only essential words
- Max 3-4 words

**Display banner:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► DEBUG SESSION: {slug}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: {description}
Expected: {expected}
Actual: {actual}

Debug directory: debugging/{slug}/
───────────────────────────────────────────────────────
```

---

## 2. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "debugging/"
$workflow = "/debug-flow"

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
resource="debugging/"
workflow="/debug-flow"

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

## 3. Ensure Directory Structure

**PowerShell:**
```powershell
try {
    $DEBUG_DIR = "debugging/$SLUG"
    if (-not (Test-Path "debugging")) {
        New-Item -ItemType Directory -Path "debugging"
    }
    if (-not (Test-Path $DEBUG_DIR)) {
        New-Item -ItemType Directory -Path $DEBUG_DIR
    }
```

**Bash:**
```bash
trap 'rm -f "$lock_file"' EXIT
DEBUG_DIR="debugging/$SLUG"
mkdir -p "$DEBUG_DIR"
```

---

## 3. Research Phase — Create RESEARCH.md

**Gather evidence BEFORE forming hypotheses:**

**PowerShell:**
```powershell
# Collect error details
tail -50 logs/error.log 2>$null
# Check relevant environment variables
# Check recent git changes
```

**Bash:**
```bash
# Collect error details
tail -50 logs/error.log 2>/dev/null || echo "No logs/error.log"
# Check relevant environment variables
# Check recent git changes
git log --oneline -10
```

**Create RESEARCH.md:**

```markdown
---
slug: "{slug}"
status: researching
trigger: "{verbatim user input}"
created: "{ISO timestamp}"
updated: "{ISO timestamp}"
---

# Research: {slug}

## Symptom Analysis

**Description:** {full bug description}
**When:** {when does it occur?}
**Expected:** {what should happen?}
**Actual:** {what actually happens?}
**Started:** {when did it start / has it ever worked?}

## Error Evidence

### Error Messages
```
{error logs / stack traces}
```

### Environment Context
- OS: {detected OS}
- Node/Python/Runtime version: {detected version}
- Recent changes: {git log or file changes}
- Environment variables: {relevant env vars}

## Root Cause Hypotheses

| # | Hypothesis | Likelihood | Evidence For | Evidence Against | Status |
|---|------------|------------|--------------|------------------|--------|
| 1 | {cause 1} | 70% | {supporting} | {contradicting} | UNTESTED |
| 2 | {cause 2} | 20% | {supporting} | {contradicting} | UNTESTED |
| 3 | {cause 3} | 10% | {supporting} | {contradicting} | UNTESTED |

## Investigation Notes

### Evidence Gathered
<!-- APPEND only during research -->

- **{timestamp}**: Checked {what} → Found {what}
- **{timestamp}**: Examined {file/function} → Observed {observation}

### Eliminated Hypotheses
<!-- APPEND only when disproven -->

- **{hypothesis}**: Eliminated because {evidence}
  - Timestamp: {ISO timestamp}

## Next Steps

**Current Focus:** {which hypothesis to test first}
**Test Plan:** {how to validate/invalidate the leading hypothesis}
**Blockers:** {any information needed from user}
```

---

## 4. Plan Phase — Create PLAN.md

Once root cause is identified through research, create the fix plan:

```markdown
---
slug: "{slug}"
plan_version: 1
created: "{ISO timestamp}"
updated: "{ISO timestamp}"
---

# Plan: {slug}

## Root Cause Confirmation

**Confirmed Cause:** {the identified root cause}
**Evidence:** {proof this is the cause}
**Confidence:** HIGH / MEDIUM / LOW

## Fix Strategy

### Overview
{brief description of the approach}

### Files to Modify

1. **{file-path}**
   - Change: {what to change}
   - Reason: {why this fixes the bug}

2. **{file-path}**
   - Change: {what to change}
   - Reason: {why this fixes the bug}

### Implementation Steps

1. {specific step 1}
2. {specific step 2}
3. {specific step 3}

### Testing Criteria

- [ ] Bug reproduction: {steps to reproduce before fix}
- [ ] Fix verification: {steps to confirm fix works}
- [ ] Regression check: {related functionality to test}
- [ ] Edge cases: {boundary conditions to verify}

## Risk Assessment

**Risk Level:** LOW / MEDIUM / HIGH
**Potential Side Effects:** {what could break}
**Mitigation:** {how to minimize risk}
```

---

## 5. Execute Phase — Apply Fix & Create SUMMARY.md

**Apply the fix following the PLAN.md:**

1. **Implement changes** — Modify files as specified
2. **Test immediately** — Run reproduction steps, verify fix
3. **Check for regressions** — Test related functionality
4. **Commit atomically:**
   ```bash
   git add -A
   git commit -m "fix({slug}): {brief description}"
   ```

**Update STATE.md with resolution:**

```markdown
## Bug Resolution: {slug}

- **Status:** Resolved
- **Commit:** {hash}
- **Date:** {timestamp}
```

**Create SUMMARY.md:**

```markdown
---
slug: "{slug}"
status: resolved
created: "{ISO timestamp}"
resolved: "{ISO timestamp}"
---

# Summary: {slug}

## Resolution Status

✅ **RESOLVED**

## What Was Changed

### Files Modified
1. **{file-path}**
   - Changed: {description of change}
   - Lines: {line numbers if relevant}

2. **{file-path}**
   - Changed: {description of change}

### Root Cause
{detailed explanation of the actual cause}

### Fix Applied
{detailed description of the solution}

## Verification Results

- [x] Bug reproduction: {confirmed before fix}
- [x] Fix verification: {confirmed after fix}
- [x] Regression check: {what was tested}
- [x] Edge cases: {boundaries verified}

## Commit Reference

```
{commit hash} fix({slug}): {description}
```

## Preventative Measures

- {What could prevent this bug in the future?}
- {Tests added?}
- {Documentation updated?}

## Lessons Learned

- {What did we learn from this bug?}
- {Any process improvements suggested?}
```

---

## 6. Handle 3-Strike Rule

If 3 fix attempts fail:

```
⚠️ 3 FAILURES ON SAME APPROACH

Action: STOP and reassess

Current approach exhausted. Recommending:
1. Try fundamentally DIFFERENT hypothesis
2. /pause for fresh session context
3. Ask user for additional information

State preserved in:
- debugging/{slug}/RESEARCH.md
- debugging/{slug}/PLAN.md
```

**Update RESEARCH.md:**
```markdown
## Investigation Notes

### Failed Attempts
- **Attempt 1**: {what was tried} → Result: {failure reason}
- **Attempt 2**: {what was tried} → Result: {failure reason}
- **Attempt 3**: {what was tried} → Result: {failure reason}

**Recommendation:** Fresh context needed. Consider /pause and new session.
```

---

## 7. Completion

After SUMMARY.md is created:

1. Update RESEARCH.md status → `resolved`
2. Ensure PLAN.md status is up to date
3. Verify all three artifacts exist in `debugging/{slug}/`

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

</process>

<offer_next>

**If Resolved:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► BUG FIXED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Slug: {slug}
Root cause: {what was wrong}
Fix: {what was done}

Artifacts:
- debugging/{slug}/RESEARCH.md
- debugging/{slug}/PLAN.md
- debugging/{slug}/SUMMARY.md

Committed: {hash}

───────────────────────────────────────────────────────
```

**If Stuck After 3 Attempts:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► DEBUG PAUSED ⏸
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Slug: {slug}
3 attempts exhausted on current approach.

State preserved in debugging/{slug}/:
- RESEARCH.md — investigation notes
- PLAN.md — attempted fixes

───────────────────────────────────────────────────────

Options:
• /debug-flow {issue} — try different approach
• /pause — save state for fresh session
• Provide more context about the issue

───────────────────────────────────────────────────────
```

</offer_next>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/pause` | Use after 3 failed attempts |
| `/resume-work` | Start fresh with documented state |
| `/verify` | Re-verify after fixing issues |
| `/execute` | R-P-E pipeline that debug-flow mirrors |

### Skills
| Skill | Purpose |
|-------|---------|
| `debugger` | Detailed debugging methodology |
| `context-health-monitor` | 3-strike rule |
</related>
