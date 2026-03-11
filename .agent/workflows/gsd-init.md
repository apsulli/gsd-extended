---
description: Initialize GSD environment — configure agents, ensure STACK.md, verify project setup
version: "1.0.0"
tags: ['setup', 'initialization', 'agents']
---

# /gsd-init Workflow

<objective>
Initialize the GSD (Get Shit Done) environment by:
1. Configuring supported agentic workflow environments (Claude, OpenCode, etc.)
2. Ensuring STACK.md is populated with project architecture
3. Verifying base project setup is complete

**This is the starting point** for new GSD projects or when adding agent support.
</objective>

<context>
**No arguments required.** Interactive setup workflow.

**Creates/Updates:**
- `.claude/skills/` and `.claude/commands/` (if Claude selected)
- `.opencode/skills/` and `.opencode/commands/` (if OpenCode selected)
- `.gsd/STACK.md` — Technology stack with "Supported Agent Workflows" section

**Requires:**
- `.agent/skills/` directory with skill definitions
- `.agent/workflows/` directory with workflow definitions
</context>

<process>

## 1. Display Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► INITIALIZATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Agent Configuration

Prompt: *"Which agents? (Claude, OpenCode, Others)"*

Parse selections and sync directories:

**PowerShell:**
```powershell
$agents = (Read-Host "Agents").Split(',').Trim()
foreach ($agent in $agents) {
    $dir = ".$($agent.ToLower())"
    New-Item -ItemType Directory -Force -Path "$dir/skills","$dir/commands" | Out-Null
    if (Test-Path ".agent/skills") { Copy-Item ".agent/skills/*" "$dir/skills/" -Recurse -Force }
    if (Test-Path ".agent/workflows") { Copy-Item ".agent/workflows/*" "$dir/commands/" -Recurse -Force }
}
```

**Bash:**
```bash
read -p "Agents: " input
IFS=',' read -ra agents <<< "$input"
for agent in "${agents[@]}"; do
    dir=".${agent,,}"
    mkdir -p "$dir/skills" "$dir/commands"
    [ -d ".agent/skills" ] && cp -r .agent/skills/* "$dir/skills/" 2>/dev/null
    [ -d ".agent/workflows" ] && cp -r .agent/workflows/* "$dir/commands/" 2>/dev/null
done
```

## 3. Architecture Check

Prompt: *"Have you mapped the project architecture? (Y/n)"*

If No: Run `/map` workflow to generate STACK.md.
If Yes but no STACK.md: Create template.

## 4. Initiation Check

Prompt: *"Have you initiated your GSD project? (Y/n)"*

If No: Run `/new-project` workflow.
If Yes: Verify `.gsd/SPEC.md`, `.gsd/ROADMAP.md`, `.gsd/STATE.md` exist.

## 5. Update STACK.md

Add "Supported Agent Workflows" section:

```markdown
## Supported Agent Workflows

- **{Agent}** — Configured via /gsd-init

Workflows sync from `.agent/workflows/` to agent directories.
```

## 6. Commit

```bash
git add -A
git commit -m "chore: initialize GSD environment"
```

## 7. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► INITIALIZATION COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configured: {agents}
Synced: Skills and workflows to agent directories

▶ NEXT: /progress or /plan-phase 1
```

</process>

<related>
| Command | Purpose |
|---------|---------|
| `/map` | Generate STACK.md |
| `/new-project` | Initialize project structure |
| `/add-workflow` | Add workflows to all agents |
</related>
