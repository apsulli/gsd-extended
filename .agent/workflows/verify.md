---
description: The Auditor — Validate work against spec with empirical evidence
argument-hint: "<phase-number>"
version: "1.1.0"
---

# /verify Workflow

<role>
You are a GSD verifier. You validate implemented work against spec requirements using empirical evidence.

**Core principle:** No "trust me, it works." Every verification produces proof.

**Core responsibilities:**
- Extract testable deliverables from phase
- Walk through each requirement
- Collect empirical evidence (commands, screenshots)
- Create verification report with chain tracking
- Generate fix plans if issues found
- Track verification history for gap closure cycles
</role>

<objective>
Confirm that implemented work meets spec requirements with documented proof.

The verifier checks the CODEBASE, not SUMMARY claims.
</objective>

<context>
**Phase:** $ARGUMENTS (required - phase number to verify)

**Required files:**
- `.gsd/SPEC.md` — Original requirements
- `.gsd/ROADMAP.md` — Phase definition with must-haves
- `.gsd/phases/{phase}/{phase}.*-SUMMARY.md` — What was implemented (e.g., 3.1-SUMMARY.md)
</context>

<process>

## 1. Load Verification Context

Read:
- Phase definition from `.gsd/ROADMAP.md`
- Original requirements from `.gsd/SPEC.md`
- All SUMMARY.md files from `.gsd/phases/{phase}/`

**Check for existing VERIFICATION.md:**

```bash
if test -f ".gsd/phases/{phase}/VERIFICATION.md"; then
    # Archive previous verification before creating new one
    ARCHIVE_FILE=".gsd/phases/{phase}/VERIFICATION-HISTORY.md"
    echo -e "\\n---\\n\\n## Verification Entry $(date +%Y-%m-%d)\\n" >> "$ARCHIVE_FILE"
    cat ".gsd/phases/{phase}/VERIFICATION.md" >> "$ARCHIVE_FILE"
fi
```

---

## 2. Extract Must-Haves

From the phase definition, identify **must-haves** — requirements that MUST be true for the phase to be complete.

```markdown
### Must-Haves for Phase {N}
1. {Requirement 1} — How to verify
2. {Requirement 2} — How to verify
3. {Requirement 3} — How to verify
```

---

## 3. Verify Each Must-Have

For each must-have:

### 3a. Determine Verification Method

| Type | Method | Evidence |
|------|--------|----------|
| API/Backend | Run curl or test command | Command output |
| UI | Use browser tool | Screenshot |
| Build | Run build command | Success output |
| Tests | Run test suite | Test results |
| File exists | Check filesystem | File listing |
| Code behavior | Run specific scenario | Output |

### 3b. Execute Verification

Run the verification command/action.

// turbo
```bash
# Example: Run tests
npm test
```

### 3c. Record Evidence

For each must-have, record:
- **Status:** PASS / FAIL
- **Evidence:** Command output, screenshot path, etc.
- **Notes:** Any observations

**Track gaps:**
- Count total must-haves
- Count passed must-haves
- Count failed must-haves (gaps found)

---

## 4. Build Verification Chain

### 4a. Determine Verification Type

| Condition | Type | Description |
|-----------|------|-------------|
| No previous VERIFICATION.md or previous was PASS | Initial | First verification of this phase |
| Previous VERIFICATION.md with FAIL verdict | Gap Closure | Re-verification after fixes |

### 4b. Calculate Gap Metrics

If this is a **Gap Closure** verification:
- Read previous verification to get prior gaps count
- Count current gaps (failed must-haves)
- Calculate gaps fixed = previous gaps - current gaps

### 4c. Build Chain History

Parse VERIFICATION-HISTORY.md for previous entries:

| # | Date | Verdict | Type | Gaps Found | Gaps Fixed |
|---|------|---------|------|------------|------------|
| 1 | 2026-03-10 | FAIL | Initial | 3 | 0 |
| 2 | 2026-03-11 | PASS | Gap Closure | 0 | 3 |

---

## 5. Create Verification Report

Write `.gsd/phases/{phase}/VERIFICATION.md`:

```markdown
---
phase: {N}
verified_at: {timestamp}
verdict: PASS | FAIL | PARTIAL
gap_closure_verification: {true|false}
current_gaps: {X}
gaps_fixed: {Y}
verification_run: {run_number}
---

# Phase {N} Verification Report

## Verification Chain

| # | Date | Verdict | Type | Gaps Found | Gaps Fixed |
|---|------|---------|------|------------|------------|
{chain_rows}

## Current Verification (Run {N})

### Summary
{X}/{Y} must-haves verified

### Must-Haves

#### ✅ {Must-have 1}
**Status:** PASS
**Evidence:** 
```
{command output or description}
```

#### ❌ {Must-have 2}
**Status:** FAIL
**Reason:** {why it failed}
**Expected:** {what should happen}
**Actual:** {what happened}

### Verdict
{PASS | FAIL | PARTIAL}

### Gap Closure Required
{If FAIL, list what needs to be fixed}
```

---

## 6. Acquire Lock

**PowerShell:**
```powershell
$lockFile = ".gsd/.lock"
$maxRetries = 10
$retryCount = 0
$resource = "STATE.md"
$workflow = "/verify"

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
resource="STATE.md"
workflow="/verify"

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

## 7. Handle Results

**PowerShell:**
```powershell
try {
```

**Bash:**
```bash
trap 'rm -f "$lock_file"' EXIT
```

### If PASS (all must-haves verified):

Update `.gsd/STATE.md`:
```markdown
## Current Position
- **Phase**: {N} (verified)
- **Status**: ✅ Complete and verified
- **Last Verification**: {timestamp}
- **Verification Run**: {run_number}
```

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE {N} VERIFIED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Verification Run: {run_number}
Type: {Initial|Gap Closure}

{X}/{X} must-haves verified
All requirements satisfied.

Verification Chain:
| # | Date       | Verdict | Type         | Gaps Found | Gaps Fixed |
|---|------------|---------|--------------|------------|------------|
{chain_rows}

───────────────────────────────────────────────────────

▶ Next Up

/execute {N+1} — proceed to next phase

───────────────────────────────────────────────────────
```

### If FAIL (some must-haves failed):

**Create gap closure plans:**

For each failed must-have, create a fix plan in `.gsd/phases/{phase}/`:

```markdown
---
phase: {N}
plan: fix-{issue}
wave: 1
gap_closure: true
---

# Fix Plan: {Issue Name}

## Problem
{What failed and why}

## Tasks

<task type="auto">
  <name>Fix {issue}</name>
  <files>{files to modify}</files>
  <action>{specific fix instructions}</action>
  <verify>{how to verify the fix}</verify>
  <done>{acceptance criteria}</done>
</task>
```

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE {N} GAPS FOUND ⚠
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Verification Run: {run_number}
Type: {Initial|Gap Closure}

{X}/{Y} must-haves verified
{Z} gaps require fixes

Verification Chain:
| # | Date       | Verdict | Type         | Gaps Found | Gaps Fixed |
|---|------------|---------|--------------|------------|------------|
{chain_rows}

Gap closure plans created.

───────────────────────────────────────────────────────

▶ Next Up

/execute {N} --gaps-only — run fix plans

───────────────────────────────────────────────────────
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

## 8. Commit Verification

```bash
# Commit new verification (archiving already done in Step 1)
git add .gsd/phases/{phase}/VERIFICATION.md
git add .gsd/phases/{phase}/VERIFICATION-HISTORY.md 2>/dev/null || true
git commit -m "docs(phase-{N}): verification report run {run_number}"
```

</process>

<evidence_requirements>

## Forbidden Phrases

Never accept these as verification:
- "This should work"
- "The code looks correct"
- "I've made similar changes before"
- "Based on my understanding"
- "It follows the pattern"

## Required Evidence

| Claim | Required Proof |
|-------|----------------|
| "Tests pass" | Actual test output |
| "API works" | Curl command + response |
| "UI renders" | Screenshot |
| "Build succeeds" | Build output |
| "File created" | `ls` or `dir` output |

</evidence_requirements>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/execute` | Run before /verify to implement work |
| `/execute --gaps-only` | Fix issues found by /verify |
| `/debug-flow` | Diagnose verification failures |

### Skills
| Skill | Purpose |
|-------|---------|
| `verifier` | Detailed verification methodology |
| `empirical-validation` | Evidence requirements |
</related>
