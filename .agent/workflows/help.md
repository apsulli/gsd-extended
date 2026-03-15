---
description: Show all available GSD commands
version: "1.1.0"
---

# /help Workflow

<objective>
Display all available GSD commands with descriptions and usage hints.
</objective>

<process>

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► HELP  (each workflow versioned independently)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CORE WORKFLOW
─────────────
/map              Analyze codebase → ARCHITECTURE.md
/plan-phase [N]       Create PLAN.md files for phase N
/execute [N]      Wave-based execution with atomic commits
/verify [N]       Must-haves validation with proof
/debug-flow [desc]   Systematic debugging (3-strike rule)

PROJECT SETUP
─────────────
/new-project      Deep questioning → SPEC.md
/new-milestone    Create milestone with phases
/complete-milestone   Archive completed milestone
/audit-milestone  Review milestone quality

PHASE MANAGEMENT
────────────────
/add-phase        Add phase to end of roadmap
/insert-phase     Insert phase (renumbers subsequent)
/remove-phase     Remove phase (with safety checks)
/discuss-phase    Clarify scope before planning
/research-phase   Deep technical research
/list-phase-assumptions   Surface planning assumptions
/plan-milestone-gaps      Create gap closure plans

NAVIGATION & STATE
──────────────────
/status           Unified view: roadmap, phases, todos, git status
/progress         Show current position in roadmap
/pause            Save state for session handoff
/resume-work      Restore from last session
/archive-journal  Archive old journal entries (keep hot log ≤ 5 sessions)
/add-todo         Quick capture idea
/check-todos      List pending items

UTILITIES
─────────
/code-review      Code review for current changes or specified scope
/web-search       Search the web to inform decisions
/cleanup          Clean up old debug sessions and archived journal entries
/help             Show this help

WORKFLOW MANAGEMENT
───────────────────
/gsd-init         Initialize GSD environment and verify project setup
/update           Update GSD to the latest version
/whats-new        Show recent GSD changes and new features
/add-workflow     Create new workflows, auto-sync to agent environments
/delete-workflow  Archive workflows, remove from agent environments
/restore-workflow Restore previously archived workflows

───────────────────────────────────────────────────────

QUICK START
───────────
1. /new-project      → Initialize with deep questioning
2. /plan-phase 1         → Create Phase 1 plans
3. /execute 1        → Implement Phase 1
4. /verify 1         → Confirm it works
5. Repeat

───────────────────────────────────────────────────────

CORE RULES
──────────
🔒 Planning Lock     No code until SPEC.md is FINALIZED
💾 State Persistence Update STATE.md after every task
🧹 Context Hygiene   3 failures → state dump → fresh session
✅ Empirical Valid.  Proof required, no "it should work"

───────────────────────────────────────────────────────

📚 Docs: GSD-STYLE.md, .gsd/examples/

───────────────────────────────────────────────────────
```

</process>
