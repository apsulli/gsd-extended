# PLAN.md Template

> Template for `.gsd/phases/{N}/{N}.{M}-PLAN.md` — executable phase plans.
>
> **File naming convention:** `{N}.{M}-PLAN.md`
> Example: `3.2-PLAN.md` for Phase 3, Plan 2

---

## File Template

```markdown
---
phase: {N}
plan: {M}
wave: 1
---

# Plan {N}.{M}: {Plan Name}

## Objective
{What this plan delivers and why}

## Context
- .gsd/SPEC.md
- .gsd/ARCHITECTURE.md
- {relevant source files}

## Tasks

<task type="auto">
  <name>{Task name}</name>
  <files>{exact file paths}</files>
  <action>
    {Specific implementation instructions}
    - What to do
    - What to avoid and WHY
  </action>
  <verify>{Command to prove task complete}</verify>
  <done>{Measurable acceptance criteria}</done>
</task>

<task type="auto">
  <name>{Task 2 name}</name>
  <files>{exact file paths}</files>
  <action>{instructions}</action>
  <verify>{command}</verify>
  <done>{criteria}</done>
</task>

## Success Criteria
- [ ] {Measurable outcome 1}
- [ ] {Measurable outcome 2}
```

---

## Task Types

| Type | Use For | Autonomy |
|------|---------|----------|
| `auto` | Everything Claude can do independently | Fully autonomous |
| `checkpoint:human-verify` | Visual/functional verification | Pauses for user |
| `checkpoint:decision` | Implementation choices | Pauses for user |

**Automation-first rule:** If Claude CAN do it, Claude MUST do it. Checkpoints are for verification AFTER automation.

---

## Wave Assignment

| Wave | Use For |
|------|---------|
| 1 | Foundation (types, schemas, utilities) |
| 2 | Core implementations |
| 3 | Integration and validation |

Plans in the same wave can run in parallel.
Later waves depend on earlier waves.

---

## Guidelines

- **2-3 tasks max per plan** — aggressive atomicity
- Files must be exact paths, not patterns
- Verify commands must be executable
- Done criteria must be measurable (yes/no pass/fail)
