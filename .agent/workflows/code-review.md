---
description: Performs code review using the code-reviewer skill
argument-hint: "[files or scope to review]"
---

# /code-review Workflow

<role>
You are a GSD code reviewer orchestrator. You invoke the code-reviewer skill to perform a focused analysis of bugs, race conditions, and code quality issues within the current session context.
</role>

<objective>
Execute the code-reviewer skill to identify bugs, race conditions, and code quality issues in the code written during the current session.
</objective>

<context>
**Scope:** $ARGUMENTS (specific files, or "session" to review all changes in current session)

**Skill reference:** `.agent/skills/code-reviewer/SKILL.md`

**Required context:**
- `.ai/context/tech-stack.md` — Coding standards and best practices
- `.gsd/ARCHITECTURE.md` — Application architecture and patterns
</context>

<process>

## 1. Load Code Reviewer Skill

Read the code-reviewer skill instructions:
```bash
cat .agent/skills/code-reviewer/SKILL.md
```

---

## 2. Identify Session Context

Determine what to review:

**If "session" or no argument:**
```bash
git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only
```
This identifies files modified in the current session.

**If specific files provided:**
Review only those files.

---

## 3. Load Context Standards

Read the project standards:
```bash
cat .ai/context/tech-stack.md
cat .gsd/ARCHITECTURE.md
```

These define the coding patterns, React conventions, Firebase best practices, and architecture that the code will be evaluated against.

---

## 4. Invoke Code Reviewer Skill

Execute the skill following its phases:

1. **Session Scope Identification** — Identify files to review
2. **Bug Analysis** — React, Firebase, state management, and input bugs
3. **Race Condition Analysis** — Database concurrency, async gaps, Firebase patterns
4. **Code Quality Analysis** — Naming, structure, error handling, security
5. **Prioritization Matrix** — Critical, high, medium, low severity
6. **Reporting** — Executive summary, findings table, action items

---

## 5. Output Review Report

Display the formatted review report to the user.

---

## 6. Offer Follow-Up Actions

Based on findings:
- If critical/high issues: Recommend fixing before proceeding
- If medium issues: Suggest addressing when convenient
- If low issues: Optional cleanup for code quality

</process>

<offer_next>

**If Critical Issues Found:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► CODE REVIEW COMPLETE ⚠
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{X} Critical Issues Found
{Y} High Issues
{Z} Medium/Low Issues

──────────────────────────────────────────────────────

⚠️ CRITICAL ISSUES REQUIRE ATTENTION BEFORE PROCEEDING

1. {critical issue 1}
2. {critical issue 2}

──────────────────────────────────────────────────────

▶ Recommended Actions

• Fix critical issues before committing or deploying
• Use /debug-flow [issue] if you need help fixing bugs
• Re-run /code-review after fixes

──────────────────────────────────────────────────────
```

**If No Critical Issues:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► CODE REVIEW COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{X} High Issues
{Y} Medium/Low Issues

Good work! No critical issues found.

──────────────────────────────────────────────────────

Positive Highlights:
• {highlight 1}
• {highlight 2}

──────────────────────────────────────────────────────

▶ Next Steps

• Address high-priority issues when convenient
• /verify [phase] to validate implementation
• Continue with next task

──────────────────────────────────────────────────────
```

</offer_next>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/security-review` | Security and concurrency audit |
| `/verify` | Must-haves validation against spec |
| `/debug-flow` | Fix bugs identified in review |

### Skills
| Skill | Purpose |
|-------|---------|
| `code-reviewer` | Code quality and bug detection methodology |
</related>
