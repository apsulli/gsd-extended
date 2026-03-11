# GSD (Get Shit Done)

**AI-Native Project Management for Solo Developers**

GSD is a disciplined workflow system designed for developers working with AI assistants. It transforms ad-hoc AI interactions into a structured, traceable project pipeline with built-in safeguards against common failure modes.

---

## What is GSD?

GSD (Get Shit Done) is a **project management methodology** implemented as a set of markdown-based workflows that work with AI assistants like Claude and OpenCode.

Unlike traditional project management tools that focus on team coordination, GSD optimizes for **solo developer + AI** collaboration. It enforces four core rules that prevent the most common causes of project failure:

### The Four Rules

1. **Planning Lock** — No code until requirements are documented and finalized
2. **State Persistence** — Complete session continuity across AI conversations
3. **Context Hygiene** — Automatic detection of diminishing returns, fresh context protocols
4. **Empirical Validation** — Proof required, no "trust me, it works"

---

## Key Features

### 📋 Phase-Based Planning
- Decompose projects into executable phases
- Wave-based parallel execution within phases
- Automatic dependency management

### 🔄 R-P-E Pipeline
Every unit of work follows **Research → Plan → Execute**:
- **Research**: Investigate options, document findings
- **Plan**: Create executable plans with specific tasks
- **Execute**: Run plans with atomic commits and verification

### 🐛 Structured Debugging
Bugs get their own R-P-E pipeline:
- `debugging/{slug}/RESEARCH.md` — Root cause analysis
- `debugging/{slug}/PLAN.md` — Fix strategy
- `debugging/{slug}/SUMMARY.md` — Resolution documentation

### 🔄 Session Management
- `/pause` — Save complete state for session handoff
- `/resume-work` — Restore context and continue
- `/status` — Unified view of project state

### ✅ Empirical Verification
- `/verify` — Validates against spec with evidence
- Gap closure tracking — Failed verifications generate fix plans
- Verification chains — Complete history of verification attempts

### 🔒 Race Condition Protection
- Operation IDs for concurrent phase modifications
- File locking for shared resources
- Automatic conflict detection and resolution

---

## Prerequisites

Before installing GSD, ensure you have:

- **Git repository initialized** — GSD tracks all state in git commits
- **AI assistant with custom command support** — Claude (via `.claude/commands/`), OpenCode (via `.opencode/commands/`), or similar
- **Basic understanding of the command structure** — GSD uses markdown-based workflows that AI assistants read and execute

---

## AI Assistant Configuration

GSD works by placing markdown workflow files in specific directories where your AI assistant can discover them.

### How AI Assistants Discover Commands

| Assistant | Directory | Pattern |
|-----------|-----------|---------|
| **Claude** | `.claude/commands/` | Reads `.md` files as slash commands |
| **OpenCode** | `.opencode/commands/` | Reads `.md` files as slash commands |
| **Other** | Configure in `STACK.md` | Custom path mapping |

### Source of Truth

The **authoritative workflows** live in:
- `.agent/workflows/` — All workflow definitions
- `.agent/skills/` — Skill definitions

These are copied to assistant-specific directories by `/gsd-init`.

---

## Installation

### Option 1: Manual Download (Recommended)

1. Download the GSD release archive
2. Extract to a temporary location
3. Copy the directories to your project root:

```bash
# Copy GSD system files to your project
cp -r /path/to/gsd/.agent .
cp -r /path/to/gsd/.gsd .
```

### Option 2: Git Clone (Replace URL)

```bash
# Clone GSD into your project (replace with actual repository URL)
git clone <YOUR_GSD_REPOSITORY_URL> .gsd-temp
cp -r .gsd-temp/.agent .
cp -r .gsd-temp/.gsd .
rm -rf .gsd-temp
```

### What Gets Installed

After copying, your project will have:
- `.agent/workflows/` — Source workflows (not yet visible to AI)
- `.agent/skills/` — Source skills (not yet visible to AI)
- `.gsd/` — Directory structure for GSD state (mostly empty until init)

---

## First-Time Setup (The Bootstrapping Step)

> **Important**: This step is unusual but necessary. The AI cannot use `/gsd-init` until it knows about the command, but it won't know about the command until `/gsd-init` runs. Here's how to break this cycle:

### The Chicken-and-Egg Problem

After copying `.agent/` and `.gsd/` to your project:
1. Your AI assistant **does not yet know** any GSD commands
2. The `/gsd-init` command doesn't exist in `.claude/commands/` or `.opencode/commands/` yet
3. You must manually bootstrap the system

### Bootstrapping Steps

**Step 1**: Tell your AI assistant explicitly:
```
Please read the file .agent/workflows/gsd-init.md and execute it.
```

**Step 2**: The AI will:
- Read the gsd-init workflow from `.agent/workflows/`
- Copy workflows to `.claude/commands/` and/or `.opencode/commands/`
- Set up the complete `.gsd/` directory structure
- Create initial documentation templates

**Step 3**: Once `/gsd-init` completes:
- All slash commands are now available
- You can use `/new-project`, `/plan-phase`, etc.
- Workflows auto-sync when you modify them

### Why This Is Necessary

AI assistants only discover commands from their specific directories:
- Claude never reads `.agent/workflows/` directly
- OpenCode never reads `.agent/workflows/` directly
- They only read from their own `.claude/commands/` or `.opencode/commands/` directories

The `/gsd-init` command exists in `.agent/workflows/` (source of truth) but must be copied to assistant-specific directories before the AI can use it as a slash command.

---

## Create Your First Project

Once `/gsd-init` completes, you can create your first project:

```bash
# Initialize with deep questioning
/new-project
```

Follow the interactive prompts to define your project vision, goals, and constraints.

---

## Project Structure

```
project-root/
├── .agent/                    # GSD workflows (source of truth)
│   ├── workflows/            # All workflow definitions
│   │   ├── new-project.md
│   │   ├── plan-phase.md
│   │   ├── execute.md
│   │   └── ...
│   └── skills/               # Skill definitions
│       ├── executor/
│       ├── planner/
│       └── ...
├── .gsd/                     # GSD state and documentation
│   ├── SPEC.md              # Project specification (FINALIZED)
│   ├── ROADMAP.md           # Phase definitions and progress
│   ├── STATE.md             # Current session state
│   ├── JOURNAL.md           # Session history (last 5)
│   ├── DECISIONS.md         # Architecture Decision Records
│   ├── TODO.md              # Pending tasks
│   ├── ARCHITECTURE.md      # System design (if brownfield)
│   ├── STACK.md             # Technology stack
│   ├── phases/              # Phase execution plans
│   │   └── {N}/
│   │       ├── {N}.{M}-PLAN.md
│   │       ├── {N}.{M}-SUMMARY.md
│   │       └── VERIFICATION.md
│   ├── debugging/           # Debug sessions
│   │   └── {slug}/
│   │       ├── RESEARCH.md
│   │       ├── PLAN.md
│   │       └── SUMMARY.md
│   └── journal/             # Archived journal entries
│       └── YYYY-MM-archive.md
├── .claude/                  # Claude-specific (auto-populated)
│   ├── commands/            # Synced workflows
│   └── skills/              # Synced skills
├── .opencode/               # OpenCode-specific (auto-populated)
│   ├── commands/
│   └── skills/
└── .git/                    # Git repository (required)
```

---

## Quick Start Guide

### 1. Bootstrap (First Time Only)

```bash
# Tell AI: "Read .agent/workflows/gsd-init.md and execute it"
# This copies workflows to .claude/commands/ and .opencode/commands/
```

### 2. Initialize Project

```bash
/gsd-init          # Configure agents (available after bootstrap)
/new-project       # Create project (interactive)
```

### 3. Plan

```bash
/discuss-phase 1   # Optional: clarify scope
/research-phase 1  # Optional: investigate options
/plan-phase 1      # Create execution plans
```

### 4. Execute

```bash
/execute 1         # Run all phase 1 plans
/verify 1          # Validate against spec
```

### 5. Iterate

```bash
# If verification fails, fix gaps:
/execute 1 --gaps-only

# Or debug issues:
/debug-flow "auth failing after refactor"
```

### 6. Complete

```bash
/complete-milestone
```

---

## Available Commands

### Core Workflow
| Command | Purpose |
|---------|---------|
| `/new-project` | Initialize project with deep questioning |
| `/plan-phase [N]` | Create execution plans for phase |
| `/execute <N>` | Execute phase plans |
| `/verify <N>` | Validate implementation |
| `/debug-flow [issue]` | Systematic debugging |

### Phase Management
| Command | Purpose |
|---------|---------|
| `/add-phase` | Add phase to end |
| `/insert-phase` | Insert phase (renumbers) |
| `/remove-phase <N>` | Remove phase (renumbers) |
| `/discuss-phase [N]` | Clarify scope before planning |
| `/research-phase <N>` | Deep technical research |

### Session Management
| Command | Purpose |
|---------|---------|
| `/pause` | Save state for handoff |
| `/resume-work` | Restore context |
| `/status` | Show project state |
| `/progress` | Show roadmap progress |

### Utilities
| Command | Purpose |
|---------|---------|
| `/map` | Analyze codebase |
| `/web-search <query>` | Research technical decisions |
| `/code-review [scope]` | Review code quality |
| `/cleanup` | Archive old sessions |
| `/help` | Show all commands |

---

## Configuration

### Supported Agents

GSD works with any AI assistant that supports custom commands:

- **Claude** — Via `.claude/commands/` and `.claude/skills/`
- **OpenCode** — Via `.opencode/commands/` and `.opencode/skills/`
- **Custom** — Configure in STACK.md

### Multi-Agent Sync

Workflows automatically sync across configured agents:

```bash
/add-workflow      # Creates and syncs new workflow
/delete-workflow   # Archives workflow across agents
/restore-workflow  # Restore archived workflow
```

---

## Best Practices

### 1. Planning Lock
Never start coding before SPEC.md is marked `FINALIZED`. This prevents building the wrong thing.

### 2. Atomic Commits
Each task gets its own commit: `feat(phase-N): task description`

### 3. Context Hygiene
After 3 failed attempts, automatically `/pause` for fresh context:
- Different AI session
- Clear memory
- Fresh perspective

### 4. Empirical Validation
Every claim needs proof:
- "Tests pass" → show test output
- "API works" → show curl response
- "UI renders" → show screenshot

### 5. State Persistence
Always update STATE.md after significant work:
- Current phase and task
- Blockers encountered
- Next steps

---

## Troubleshooting

### "Command not recognized" or "/gsd-init not found"

This is the #1 issue new users encounter. The AI doesn't know GSD commands yet.

**Solution**: You must bootstrap manually:
1. Tell your AI: `"Read .agent/workflows/gsd-init.md and execute it"`
2. Do NOT try to run `/gsd-init` as a slash command yet
3. Once gsd-init completes, all slash commands will work

**Why this happens**: AI assistants only read commands from their specific directories (`.claude/commands/`, `.opencode/commands/`). The source workflows in `.agent/workflows/` are not automatically discovered—they must be copied by running gsd-init first.

### "SPEC.md must be FINALIZED"
Run `/new-project` or manually edit `.gsd/SPEC.md` and add:
```markdown
> **Status**: `FINALIZED`
```

### "No supported agents found"
Run `/gsd-init` to configure agents in STACK.md

### "Concurrent operation detected"
Another workflow is modifying shared state. Options:
- Wait for it to complete
- Force continue (may need manual merge)
- Cancel and retry

### "Lock acquisition failed"
A workflow crashed while holding a lock. Force release:
```bash
rm .gsd/.lock
```

---

## Advanced Features

### Verification Chains
Track multiple verification attempts:
```
Verification Run #1: FAIL (3 gaps found)
Verification Run #2: PASS (all gaps closed)
```

### Gap Closure
Failed verifications automatically create fix plans:
```bash
/verify 1          # Finds gaps
/execute 1 --gaps-only  # Fix gaps
/verify 1          # Re-verify
```

### Archive Recovery
Deleted workflows are archived, not lost:
```bash
/delete-workflow my-command    # Archives workflow
/restore-workflow              # Browse and restore
```

---

## Contributing

GSD is designed to be extended. Add custom workflows:

```bash
/add-workflow
# Follow prompts to create and sync
```

Workflows are markdown files with:
- YAML frontmatter (description, version, tags)
- `<objective>` section
- `<context>` section
- `<process>` section with numbered steps
- PowerShell and Bash code examples

---

## Philosophy

### User = Vision, AI = Execution
- **User knows**: What they want, why it matters, what's out of scope
- **AI handles**: Implementation details, file modifications, verification

### Plans Are Prompts
PLAN.md files are not transformed into prompts — they ARE the prompts. AI reads them directly and executes.

### Aggressive Atomicity
Each plan contains 2-3 tasks max. Complete quickly, verify often, commit atomically.

### Context Budget Management
- ~50% of AI context for actual work
- ~15% for orchestration
- Rest for overhead

### Solo Developer Optimized
No standups, no Jira, no coordination overhead. Just you, the AI, and a structured workflow.

---

## License

MIT — Use, modify, extend as needed.

---

## Support

- **Issues**: [GitHub Issues]
- **Discussions**: [GitHub Discussions]
- **Documentation**: `.agent/workflows/` contains full documentation for each command

---

**Ready to Get Shit Done?**

```bash
# Step 1: Bootstrap (tell AI to read and execute):
# "Read .agent/workflows/gsd-init.md and execute it"

# Step 2: Create project
/gsd-init
/new-project
```
