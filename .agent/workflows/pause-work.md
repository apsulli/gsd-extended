---
description: Context hygiene — dump state for clean session handoff
version: "1.0.0"
tags: ['session', 'state', 'handoff']
---

# /pause Workflow

<objective>
Safely pause work with complete state preservation for session handoff.
</objective>

<when_to_use>

- Ending a work session
- Context getting heavy (many failed attempts)
- Switching to a different task
- Before taking a break
- After 3+ debugging failures (Context Hygiene rule)
  </when_to_use>

<process>

## 1. Capture Current State

Update `.gsd/STATE.md`:

```markdown
## Current Position

- **Phase**: {current phase number and name}
- **Task**: {specific task in progress, if any}
- **Status**: Paused at {timestamp}

## Last Session Summary

{What was accomplished this session}

## In-Progress Work

{Any uncommitted changes or partial work}

- Files modified: {list}
- Tests status: {passing/failing/not run}

## Blockers

{What was preventing progress, if anything}

## Context Dump

{Critical context that would be lost}:

### Decisions Made

- {Decision 1}: {rationale}
- {Decision 2}: {rationale}

### Approaches Tried

- {Approach 1}: {outcome}
- {Approach 2}: {outcome}

### Current Hypothesis

{Best guess at solution/issue}

### Files of Interest

- `{file1}`: {what's relevant}
- `{file2}`: {what's relevant}

## Next Steps

1. {Specific first action for next session}
2. {Second priority}
3. {Third priority}
```

---

## 2. Add Journal Entry

Prepend new entry to top of `.gsd/JOURNAL.md` (after the `# JOURNAL.md` header line), keeping newest-first order:

```markdown
## Session: {YYYY-MM-DD HH:MM}

### Objective

{What this session was trying to accomplish}

### Accomplished

- {Item 1}
- {Item 2}

### Verification

- [x] {What was verified}
- [ ] {What still needs verification}

### Paused Because

{Reason for pausing}

### Handoff Notes

{Critical info for resuming}
```

---

## 3. Auto-Archive Check

Count sessions in `JOURNAL.md`:

```bash
grep -c "^## Session:" .gsd/JOURNAL.md
```

- **If count > 5**: 
  - **Execute the `/archive-journal` command** (do NOT implement archiving manually)
  - The `/archive-journal` command prepends entries to the top of archive files, maintaining **reverse chronological order** (newest first)
  - Manual awk/sed commands may corrupt archive file ordering or overwrite existing entries
- **If count ≤ 5**: Skip — proceed to commit.

> This keeps `JOURNAL.md` lean so future sessions load only relevant context.

**⚠️ Critical**: Never implement journal archiving manually. Always invoke `/archive-journal` to prevent archive file corruption (overwriting existing entries).

---

## 4. Commit State

```bash
git add .gsd/STATE.md .gsd/JOURNAL.md .gsd/journal/
git commit -m "docs: pause session - {brief reason}"
```

---

## 5. Display Handoff

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► SESSION PAUSED ⏸
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

State saved to:
• .gsd/STATE.md
• .gsd/JOURNAL.md

───────────────────────────────────────────────────────

To resume later:

/resume-work

───────────────────────────────────────────────────────

💡 Fresh context = fresh perspective
   The struggles end here. Next session starts clean.

───────────────────────────────────────────────────────
```

</process>

<context_hygiene>
If pausing due to debugging failures:

1. Be explicit about what failed
2. Document exact error messages
3. List files that were touched
4. State your hypothesis clearly
5. Suggest what to try next (different approach)

A fresh context often immediately sees solutions that a polluted context missed.
</context_hygiene>
