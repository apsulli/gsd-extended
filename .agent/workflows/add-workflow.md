---
description: Create new GSD workflows and auto-sync to configured agent environments
version: "1.0.0"
tags: ['workflows', 'agents', 'automation']
---

# /add-workflow Workflow

<objective>
Create a new GSD workflow/command and automatically synchronize it across all active agent environments defined in STACK.md.

**Key benefit:** Write once in `.agent/workflows/`, deploy everywhere automatically.
</objective>

<context>
**Arguments:** None required — interactive workflow

**Requires:**
- `.gsd/STACK.md` — Must contain "Supported Agent Workflows" section
- `.agent/workflows/` — Primary workflows directory

**Creates:**
- `.agent/workflows/{workflow-name}.md` — Primary workflow file
- Copies to agent directories: `.claude/commands/`, `.opencode/commands/`, etc.

**Stack Requirements:**
STACK.md must indicate which agents are supported (set up via `/gsd-init`)
</context>

<process>

## 1. Display Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► ADD WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Create a new GSD workflow and sync to all configured agents.
```

---

## 2. Environment Lookup — Read STACK.md

Check which agents are configured:

**PowerShell:**
```powershell
if (-not (Test-Path ".gsd/STACK.md")) {
    Write-Error "STACK.md not found. Run /gsd-init first."
    exit 1
}
$stackContent = Get-Content ".gsd/STACK.md" -Raw
$agentPattern = "## Supported Agent Workflows.*?(?=\n## |\Z)"
$agentMatch = [regex]::Match($stackContent, $agentPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$supportedAgents = @()
if ($agentMatch.Success) {
    $agentLines = [regex]::Matches($agentMatch.Value, '^\s*[-*]\s*\*\*(.+?)\*\*')
    foreach ($match in $agentLines) { $supportedAgents += $match.Groups[1].Value.Trim() }
}
if ($supportedAgents.Count -eq 0) { Write-Error "No agents found. Run /gsd-init first."; exit 1 }
Write-Output "Supported: $($supportedAgents -join ', ')"
```

**Bash:**
```bash
if [ ! -f ".gsd/STACK.md" ]; then echo "Error: STACK.md not found." >&2; exit 1; fi
supported_agents=()
if grep -q "## Supported Agent Workflows" .gsd/STACK.md; then
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*[-*][[:space:]]*\*\*(.+)\*\* ]]; then
            agent="${BASH_REMATCH[1]}"; agent=$(echo "$agent" | sed 's/[[:space:]]*—.*//')
            supported_agents+=("$agent")
        fi
    done < <(sed -n '/## Supported Agent Workflows/,/^## /p' .gsd/STACK.md | head -20)
fi
if [ ${#supported_agents[@]} -eq 0 ]; then echo "Error: No agents found." >&2; exit 1; fi
echo "Supported: ${supported_agents[*]}"
```

---

## 3. Data Collection — Gather Workflow Details

```
📝 WORKFLOW DEFINITION

1. Workflow Name (lowercase, hyphenated):
   Example: "my-new-command"
   Name: [User input]

2. Description (1 sentence):
   Description: [User input]

3. Specification:
   Describe workflow steps, inputs, outputs.
   [User input]

4. Tags (comma-separated, optional):
   Example: "planning,automation"
   Tags: [User input]
```

**PowerShell:**
```powershell
$workflowName = Read-Host "Workflow name"
$workflowDesc = Read-Host "Description"
$workflowTags = Read-Host "Tags (optional)"
if (-not ($workflowName -match '^[a-z0-9-]+$')) {
    Write-Error "Invalid name. Use lowercase, numbers, hyphens only."; exit 1
}
if (-not $workflowName.EndsWith('.md')) { $workflowName += '.md' }
```

**Bash:**
```bash
read -p "Workflow name: " workflow_name
read -p "Description: " workflow_desc
read -p "Tags (optional): " workflow_tags
if [[ ! "$workflow_name" =~ ^[a-z0-9-]+$ ]]; then echo "Error: Invalid name." >&2; exit 1; fi
if [[ ! "$workflow_name" == *.md ]]; then workflow_name="${workflow_name}.md"; fi
```

---

## 4. Primary Write — Generate Workflow File

**PowerShell:**
```powershell
$baseName = $workflowName -replace '\.md$',''
$workflowContent = @"---
description: $workflowDesc
$(if ($workflowTags) { "tags: [$workflowTags]" })
---

# /$baseName Workflow

<objective>
$workflowDesc
</objective>

<context>
**No arguments required.**
**Creates:** {outputs}
**Requires:** {prerequisites}
</context>

<process>
## 1. Step One
{Description}
**PowerShell:**
```powershell
# Implementation
```
**Bash:**
```bash
# Implementation
```
## 2. Complete
```
GSD ► WORKFLOW COMPLETE ✓
```
</process>

<related>
### Workflows
| Command | Relationship |
|---------|--------------|
| {Related} | {Relationship} |
</related>
"@
New-Item -ItemType Directory -Force -Path ".agent/workflows" | Out-Null
$primaryPath = Join-Path ".agent/workflows" $workflowName
Set-Content -Path $primaryPath -Value $workflowContent -NoNewline
Write-Output "Created: $primaryPath"
```

**Bash:**
```bash
base_name="${workflow_name%.md}"
tags_line=""
[ -n "$workflow_tags" ] && tags_line="tags: [$workflow_tags]"
mkdir -p ".agent/workflows"
cat > ".agent/workflows/$workflow_name" << EOF
---
description: $workflow_desc
$tags_line
---

# /$base_name Workflow

<objective>
$workflow_desc
</objective>

<context>
**No arguments required.**
**Creates:** {outputs}
**Requires:** {prerequisites}
</context>

<process>
## 1. Step One
{Description}
**PowerShell:**
\`\`\`powershell
# Implementation
\`\`\`
**Bash:**
\`\`\`bash
# Implementation
\`\`\`
## 2. Complete
\`\`\`
GSD ► WORKFLOW COMPLETE ✓
\`\`\`
</process>

<related>
### Workflows
| Command | Relationship |
|---------|--------------|
| {Related} | {Relationship} |
</related>
EOF
echo "Created: .agent/workflows/$workflow_name"
```

---

## 5. Conditional Deployment — Sync to Agent Environments

**PowerShell:**
```powershell
$deployTargets = @()
foreach ($agent in $supportedAgents) {
    $agentLower = $agent.ToLower()
    $targetDir = switch ($agentLower) {
        "claude" { ".claude/commands" }
        "opencode" { ".opencode/commands" }
        default { ".$agentLower/commands" }
    }
    if (Test-Path $targetDir) {
        $targetPath = Join-Path $targetDir $workflowName
        Copy-Item -Path $primaryPath -Destination $targetPath -Force
        $deployTargets += "$agent → $targetDir/$workflowName"
        Write-Output "Deployed to $agent"
    }
}
if ($deployTargets.Count -eq 0) { Write-Warning "No agent directories found." }
```

**Bash:**
```bash
deploy_targets=()
for agent in "${supported_agents[@]}"; do
    agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')
    case "$agent_lower" in
        "claude") target_dir=".claude/commands" ;;
        "opencode") target_dir=".opencode/commands" ;;
        *) target_dir=".$agent_lower/commands" ;;
    esac
    if [ -d "$target_dir" ]; then
        cp ".agent/workflows/$workflow_name" "$target_dir/$workflow_name"
        deploy_targets+=("$agent → $target_dir/$workflow_name")
        echo "Deployed to $agent"
    fi
done
[ ${#deploy_targets[@]} -eq 0 ] && echo "Warning: No agent directories found."
```

---

## 6. Commit Changes

```bash
git add -A
git commit -m "feat: add $base_name workflow

- Created .agent/workflows/$workflow_name
- Synchronized to configured agents"
```

---

## 7. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► WORKFLOW CREATED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Workflow: /{name}
Description: {description}

Files Created:
• .agent/workflows/{name}.md (primary)

Deployed To:
• {Agent 1} — {path}
• {Agent 2} — {path}

───────────────────────────────────────────────────────

▶ NEXT STEPS

Edit: .agent/workflows/{name}.md to customize
Test: Run /{name} to verify

💡 Tip: Changes auto-sync to agents when you run this workflow.

───────────────────────────────────────────────────────
```

</process>

<note>
**Multi-Agent Synchronization:**
This workflow reads STACK.md to determine where to deploy. Agents must be configured via `/gsd-init` first.

**Supported agent directories:**
- Claude: `.claude/commands/`
- OpenCode: `.opencode/commands/`
- Custom: `.{agent-name}/commands/`
</note>

<warning>
**Prerequisites:**
- Must run `/gsd-init` first to configure agents
- Agent directories must exist before syncing
- Changes to synced files in agent directories are not automatically synced back
</warning>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/gsd-init` | Configure agents before using this workflow |

### Files
| File | Purpose |
|------|---------|
| `.gsd/STACK.md` | Defines which agents are supported |
| `.agent/workflows/` | Primary source of truth for workflows |
</related>
