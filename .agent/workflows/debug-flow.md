---
description: Systematic debugging with R-P-E pipeline and persistent artifacts
argument-hint: "[description of issue]"
version: "1.0.0"
---

# /debug-flow Workflow

<role>
You are a GSD debugging orchestrator. Manage the debugging lifecycle through a structured R-P-E (Research → Plan → Execute) pipeline with persistent artifacts in `.gsd/debugging/`.

**Core responsibilities:**
- Gather bug context and generate a concise slug
- Ensure `.gsd/debugging/` directory structure exists
- Guide the flow through Research → Plan → Execute phases
- Generate RESEARCH.md, PLAN.md, and SUMMARY.md artifacts
- Track bug lifecycle from investigation to resolution
</role>

<objective>
Systematically diagnose and fix bugs using a structured pipeline. Each bug gets its own directory with traceability artifacts.

**R-P-E Loop:**
- **Research**: Error analysis, root cause hypotheses, evidence gathering
- **Plan**: Step-by-step fix plan with file modifications and testing criteria
- **Execute**: Apply fix, verify resolution, document changes
</objective>

<context>
**Issue:** $ARGUMENTS (required - description of the problem to debug)

**Required structure:**
- `.gsd/debugging/{slug}/` — Bug-specific directory
- `.gsd/debugging/{slug}/RESEARCH.md` — Error analysis and hypotheses
- `.gsd/debugging/{slug}/PLAN.md` — Step-by-step fix plan
- `.gsd/debugging/{slug}/SUMMARY.md` — Resolution documentation

**Skill reference:** `.agent/skills/debugger/SKILL.md`
</context>

<process>

## 1. Gather Context & Generate Slug

**Prompt user for:**
1. Bug description — What is the problem?
2. Error logs — Any error messages or stack traces?
3. Expected behavior — What should happen instead?
4. Reproduction steps — How can the bug be triggered?
5. When it started — Did this ever work? When did it break?

**Generate slug:** lowercase, hyphenated, max 3-4 words (e.g., `api-auth-timeout`, `nav-render-crash`)

**Display banner:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► DEBUG SESSION: {slug}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: {description}
Expected: {expected}
Actual: {actual}

Debug directory: .gsd/debugging/{slug}/
───────────────────────────────────────────────────────
```

## 2. Acquire Lock

```bash
lock_file=".gsd/.lock"; max_retries=10; retry_count=0; resource=".gsd/debugging/"
[ -d ".gsd" ] || mkdir -p ".gsd"

while [ -f "$lock_file" ]; do
    if command -v jq >/dev/null 2>&1; then
        expires=$(jq -r '.expires' "$lock_file" 2>/dev/null)
        if [ -n "$expires" ] && [ "$expires" != "null" ]; then
            now=$(date -u +%s)
            expires_epoch=$(date -u -d "$expires" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires" +%s 2>/dev/null)
            if [ -n "$expires_epoch" ] && [ "$now" -gt "$expires_epoch" ]; then
                echo "Warning: Lock expired. Stealing lock." >&2; break
            fi
        fi
    fi
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "Error: Could not acquire lock after ${max_retries} retries" >&2; exit 1
    fi
    sleep 0.05
done

acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)
expires=$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+5M +%Y-%m-%dT%H:%M:%SZ)
printf '{"resource":"%s","workflow":"/debug-flow","acquired":"%s","expires":"%s"}\n' "$resource" "$acquired" "$expires" > "$lock_file"
```

## 3. Ensure Directory Structure

Assign the slug generated in Step 1 to a shell variable, then create the debug directory:

```bash
trap 'rm -f "$lock_file"' EXIT
SLUG="{slug-from-step-1}"   # e.g. "api-auth-timeout"
DEBUG_DIR=".gsd/debugging/$SLUG"
mkdir -p "$DEBUG_DIR"
```

## 4. Research Phase — Create RESEARCH.md

Gather evidence (logs, git history, environment) before forming hypotheses.

**Create `.gsd/debugging/{slug}/RESEARCH.md`:**
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
- **Description:** {full bug description}
- **When:** {when does it occur?}
- **Expected:** {what should happen?}
- **Actual:** {what actually happens?}
- **Started:** {when did it start / has it ever worked?}

## Error Evidence
- Error messages/stack traces
- Environment context (OS, runtime version)
- Recent changes (git log)

## Root Cause Hypotheses
| # | Hypothesis | Likelihood | Status |
|---|------------|------------|--------|
| 1 | {cause 1} | 70% | UNTESTED |
| 2 | {cause 2} | 20% | UNTESTED |

## Investigation Notes
- **{timestamp}**: Checked {what} → Found {what}
- **{timestamp}**: Examined {file/function} → Observed {observation}

## Next Steps
- **Current Focus:** {which hypothesis to test first}
- **Test Plan:** {how to validate/invalidate}
- **Blockers:** {any information needed}
```

## 5. Plan Phase — Create PLAN.md

Once root cause is identified, create the fix plan.

**Create `.gsd/debugging/{slug}/PLAN.md`:**
```markdown
---
slug: "{slug}"
plan_version: 1
created: "{ISO timestamp}"
updated: "{ISO timestamp}"
---

# Plan: {slug}

## Root Cause Confirmation
- **Confirmed Cause:** {the identified root cause}
- **Evidence:** {proof this is the cause}
- **Confidence:** HIGH / MEDIUM / LOW

## Fix Strategy
{brief description of the approach}

### Files to Modify
1. **{file-path}** — Change: {what to change}, Reason: {why this fixes it}
2. **{file-path}** — Change: {what to change}, Reason: {why this fixes it}

### Implementation Steps
1. {specific step 1}
2. {specific step 2}
3. {specific step 3}

### Testing Criteria
- [ ] Bug reproduction: {steps to reproduce}
- [ ] Fix verification: {steps to confirm fix}
- [ ] Regression check: {related functionality to test}

## Risk Assessment
- **Risk Level:** LOW / MEDIUM / HIGH
- **Potential Side Effects:** {what could break}
- **Mitigation:** {how to minimize risk}
```

## 6. Execute Phase — Apply Fix & Create SUMMARY.md

**Apply the fix:**
1. Implement changes per PLAN.md
2. Test immediately — run reproduction steps, verify fix
3. Check for regressions — test related functionality
4. Commit atomically: `git commit -m "fix({slug}): {description}"`

**Create `.gsd/debugging/{slug}/SUMMARY.md`:**
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
1. **{file-path}** — Changed: {description}, Lines: {line numbers}
2. **{file-path}** — Changed: {description}

### Root Cause
{detailed explanation}

### Fix Applied
{detailed description}

## Verification Results
- [x] Bug reproduction: {confirmed before fix}
- [x] Fix verification: {confirmed after fix}
- [x] Regression check: {what was tested}

## Commit Reference
```
{commit hash} fix({slug}): {description}
```

## Lessons Learned
- {What did we learn?}
- {Preventative measures?}
```

## 7. Handle 3-Strike Rule

If 3 fix attempts fail:

```
⚠️ 3 FAILURES ON SAME APPROACH

Action: STOP and reassess

Current approach exhausted. Recommending:
1. Try fundamentally DIFFERENT hypothesis
2. /pause for fresh session context
3. Ask user for additional information

State preserved in:
- .gsd/debugging/{slug}/RESEARCH.md
- .gsd/debugging/{slug}/PLAN.md
```

Update RESEARCH.md with failed attempts and recommendation for fresh context.

## 8. Completion

After SUMMARY.md is created:
1. Update RESEARCH.md status → `resolved`
2. Ensure all three artifacts exist in `.gsd/debugging/{slug}/`
3. Lock released by trap EXIT

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
- .gsd/debugging/{slug}/RESEARCH.md
- .gsd/debugging/{slug}/PLAN.md
- .gsd/debugging/{slug}/SUMMARY.md

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

State preserved in .gsd/debugging/{slug}/:
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
