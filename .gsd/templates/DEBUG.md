# Debug Template

Template for `debugging/{slug}/` directory — structured debug session tracking with R-P-E pipeline.

---

## Directory Structure

Each bug gets its own directory under `debugging/`:

```
debugging/
└── {slug}/
    ├── RESEARCH.md    # Error analysis and hypotheses (Research Phase)
    ├── PLAN.md        # Step-by-step fix plan (Plan Phase)
    └── SUMMARY.md     # Resolution documentation (Execute/Summarize Phase)
```

---

## RESEARCH.md Template

```markdown
---
slug: "{hyphenated-bug-name}"
status: researching | investigating | hypothesis_confirmed | planning
trigger: "[verbatim user input]"
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
- Runtime: {detected version}
- Recent changes: {git log or file changes}
- Environment: {relevant env vars}

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

### Failed Attempts
<!-- APPEND only when attempts fail -->

- **Attempt {N}**: {what was tried}
  - Result: {failure reason}
  - Timestamp: {ISO timestamp}

## Next Steps

**Current Focus:** {which hypothesis to test first}
**Test Plan:** {how to validate/invalidate the leading hypothesis}
**Blockers:** {any information needed from user}
```

---

## PLAN.md Template

```markdown
---
slug: "{hyphenated-bug-name}"
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

## SUMMARY.md Template

```markdown
---
slug: "{hyphenated-bug-name}"
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

## Section Rules

**Frontmatter (status, timestamps):**
- `status`: OVERWRITE - reflects current phase (researching → investigating → hypothesis_confirmed → planning → resolved)
- `slug`: IMMUTABLE - hyphenated bug identifier, never changes
- `trigger`: IMMUTABLE - verbatim user input, never changes
- `created`: IMMUTABLE - set once
- `updated`: OVERWRITE - update on every change

**RESEARCH.md Sections:**

**Symptom Analysis:**
- Written during initial gathering phase
- IMMUTABLE after gathering complete
- Reference point for what we're trying to fix

**Root Cause Hypotheses:**
- Initial hypotheses with likelihood ratings
- Status updated as investigation progresses

**Evidence Gathered:**
- APPEND only - never remove entries
- Facts discovered during investigation
- Builds the case for root cause

**Eliminated Hypotheses:**
- APPEND only - never remove entries
- Prevents re-investigating dead ends after context reset
- Critical for efficiency across session boundaries

**Failed Attempts:**
- APPEND only - tracks unsuccessful fix attempts
- Triggers 3-strike rule after 3 failures

**PLAN.md Sections:**
- All sections OVERWRITE as plan evolves
- Updated when root cause is confirmed
- References RESEARCH.md for context

**SUMMARY.md Sections:**
- Written once after resolution
- Provides retroactive documentation
- Links back to RESEARCH.md and PLAN.md

---

## Lifecycle

**Creation:** When /debug-flow is called
- Create slug from user input
- Create `debugging/{slug}/` directory
- Create RESEARCH.md with trigger, status="researching"
- RESEARCH.md next_action = "gather symptoms"

**During Research:**
- APPEND to Evidence with each finding
- APPEND to Eliminated when hypothesis disproved
- UPDATE Hypotheses table with status changes
- UPDATE status to "investigating" once research active

**On Hypothesis Confirmation:**
- status → "hypothesis_confirmed"
- Create PLAN.md with confirmed root cause
- status → "planning"

**During Execution:**
- Apply fixes per PLAN.md
- If failures occur, APPEND to Failed Attempts in RESEARCH.md
- After 3 failed attempts, recommend /pause

**On Resolution:**
- Create SUMMARY.md
- status → "resolved"
- Commit fix with `fix({slug}): {description}` format

---

## Resume Behavior

When AI reads these files after session reset:

1. Parse RESEARCH.md frontmatter → know status
2. Read RESEARCH.md Current Focus → know what was happening
3. Read RESEARCH.md Eliminated → know what NOT to retry
4. Read RESEARCH.md Evidence → know what's been learned
5. Read PLAN.md → know current fix approach
6. Continue from next_action or execute PLAN.md

The files ARE the debugging brain.

---

## Comparison to Execute Flow

| Execute Flow | Debug Flow |
|--------------|------------|
| `phases/{N}/` | `debugging/{slug}/` |
| `{N}.{M}-PLAN.md` | `PLAN.md` |
| `{N}.{M}-SUMMARY.md` | `SUMMARY.md` |
| `RESEARCH.md` | `RESEARCH.md` (same) |
| R-P-E per phase | R-P-E per bug |
| Wave-based execution | Sequential hypothesis testing |

Both follow the same Research → Plan → Execute/Summarize pipeline pattern.
