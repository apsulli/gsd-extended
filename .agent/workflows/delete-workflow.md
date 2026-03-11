---
description: Archive GSD workflows and auto-archive from configured agent environments
version: "1.1.0"
tags: ['workflows', 'agents', 'automation', 'cleanup', 'archive']
---

# /delete-workflow Workflow

<objective>
Archive an existing GSD workflow and automatically archive it from all active agent environments defined in STACK.md.

**Key benefit:** Archive once from `.agent/workflows/`, cleanup everywhere automatically. Workflows are recoverable.
</objective>

<context>
**Arguments:** None required — interactive workflow

**Requires:**
- `.gsd/STACK.md` — Must contain "Supported Agent Workflows" section
- `.agent/workflows/` — Primary workflows directory with existing workflows

**Archives:**
- `.agent/workflows/{workflow-name}.md` → `.agent/workflows/archive/{workflow-name}-{timestamp}.md`
- Archives from agent directories: `.claude/commands/`, `.opencode/commands/`, etc.

**Stack Requirements:**
STACK.md must indicate which agents are supported (set up via `/gsd-init`)
</context>

<process>

## 1. Display Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► ARCHIVE WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Archive a GSD workflow and sync to all configured agents.
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

## 3. List Available Workflows

Display all workflows in `.agent/workflows/`:

**PowerShell:**
```powershell
$workflowsDir = ".agent/workflows"
if (-not (Test-Path $workflowsDir)) {
    Write-Error "No workflows directory found at $workflowsDir"
    exit 1
}
$workflowFiles = Get-ChildItem -Path $workflowsDir -Filter "*.md" | Sort-Object Name
if ($workflowFiles.Count -eq 0) {
    Write-Error "No workflows found in $workflowsDir"
    exit 1
}
Write-Output ""
Write-Output "Available workflows:"
Write-Output ""
$index = 1
foreach ($file in $workflowFiles) {
    $baseName = $file.BaseName
    Write-Output "  $index. $baseName"
    $index++
}
Write-Output ""
```

**Bash:**
```bash
workflows_dir=".agent/workflows"
if [ ! -d "$workflows_dir" ]; then
    echo "Error: No workflows directory found at $workflows_dir" >&2
    exit 1
fi
workflow_files=($(ls -1 "$workflows_dir"/*.md 2>/dev/null | sort))
if [ ${#workflow_files[@]} -eq 0 ]; then
    echo "Error: No workflows found in $workflows_dir" >&2
    exit 1
fi
echo ""
echo "Available workflows:"
echo ""
index=1
for file in "${workflow_files[@]}"; do
    base_name=$(basename "$file" .md)
    echo "  $index. $base_name"
    ((index++))
done
echo ""
```

---

## 4. Data Collection — Select Workflow to Archive

```
📝 WORKFLOW ARCHIVAL

Select a workflow to archive by number or name:
Workflow: [User input]

⚠️  WARNING: This will archive the workflow (recoverable via /restore-workflow).
Confirm archival (yes/no): [User input]
```

**PowerShell:**
```powershell
$selection = Read-Host "Enter workflow number or name to archive"
$workflowName = $null

# Check if numeric selection
if ($selection -match '^\d+$') {
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $workflowFiles.Count) {
        $workflowName = $workflowFiles[$index].Name
    } else {
        Write-Error "Invalid selection. Please choose a number between 1 and $($workflowFiles.Count)"
        exit 1
    }
} else {
    # Check if name provided
    $nameWithExt = $selection
    if (-not $selection.EndsWith('.md')) { $nameWithExt += '.md' }
    $matchingFile = $workflowFiles | Where-Object { $_.Name -eq $nameWithExt }
    if ($matchingFile) {
        $workflowName = $matchingFile.Name
    } else {
        Write-Error "Workflow '$selection' not found"
        exit 1
    }
}

$baseName = $workflowName -replace '\.md$',''
Write-Output "Selected: $baseName"

# Confirm archival
$confirm = Read-Host "⚠️  WARNING: This will archive /$baseName. Type 'yes' to confirm"
if ($confirm -ne 'yes') {
    Write-Output "Archival cancelled."
    exit 0
}
```

**Bash:**
```bash
read -p "Enter workflow number or name to archive: " selection
workflow_name=""

# Check if numeric selection
if [[ "$selection" =~ ^[0-9]+$ ]]; then
    index=$((selection - 1))
    if [ $index -ge 0 ] && [ $index -lt ${#workflow_files[@]} ]; then
        workflow_name=$(basename "${workflow_files[$index]}")
    else
        echo "Error: Invalid selection. Please choose a number between 1 and ${#workflow_files[@]}" >&2
        exit 1
    fi
else
    # Check if name provided
    name_with_ext="$selection"
    [[ ! "$selection" == *.md ]] && name_with_ext="${selection}.md"
    for file in "${workflow_files[@]}"; do
        if [ "$(basename "$file")" = "$name_with_ext" ]; then
            workflow_name="$name_with_ext"
            break
        fi
    done
    if [ -z "$workflow_name" ]; then
        echo "Error: Workflow '$selection' not found" >&2
        exit 1
    fi
fi

base_name="${workflow_name%.md}"
echo "Selected: $base_name"

# Confirm archival
read -p "⚠️  WARNING: This will archive /$base_name. Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Archival cancelled."
    exit 0
fi
```

---

## 5. Archive Workflow

**PowerShell:**
```powershell
# Create archive directory
$archiveDir = ".agent/workflows/archive"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

# Move to archive with timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archiveName = "{0}-{1}.md" -f $baseName, $timestamp
$primaryPath = Join-Path ".agent/workflows" $workflowName
$archivePath = Join-Path $archiveDir $archiveName

if (Test-Path $primaryPath) {
    Move-Item -Path $primaryPath -Destination $archivePath
    Write-Output "Archived workflow: $archivePath"
} else {
    Write-Error "Workflow file not found: $primaryPath"
    exit 1
}
```

**Bash:**
```bash
# Create archive directory
archive_dir=".agent/workflows/archive"
mkdir -p "$archive_dir"

# Move to archive with timestamp
timestamp=$(date +%Y%m%d-%H%M%S)
archive_name="${base_name}-${timestamp}.md"
primary_path=".agent/workflows/$workflow_name"

if [ -f "$primary_path" ]; then
    mv "$primary_path" "$archive_dir/$archive_name"
    echo "Archived workflow: $archive_dir/$archive_name"
else
    echo "Error: Workflow file not found: $primary_path" >&2
    exit 1
fi
```

---

## 6. Conditional Deployment — Archive from Agent Environments

**PowerShell:**
```powershell
$archiveDir = ".agent/workflows/archive"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$archiveName = "{0}-{1}.md" -f $baseName, $timestamp
$archivedTargets = @()

foreach ($agent in $supportedAgents) {
    $agentLower = $agent.ToLower()
    $targetDir = switch ($agentLower) {
        "claude" { ".claude/commands" }
        "opencode" { ".opencode/commands" }
        default { ".${agentLower}/commands" }
    }
    $targetPath = Join-Path $targetDir $workflowName
    $agentArchiveDir = Join-Path $targetDir ".trash"
    $agentArchivePath = Join-Path $agentArchiveDir $archiveName
    
    if (Test-Path $targetPath) {
        # Create agent trash directory if needed
        New-Item -ItemType Directory -Force -Path $agentArchiveDir | Out-Null
        # Move to agent's trash
        Move-Item -Path $targetPath -Destination $agentArchivePath
        $archivedTargets += "$agent → $agentArchiveDir/$archiveName"
        Write-Output "Archived from $agent"
    }
}
if ($archivedTargets.Count -eq 0) { Write-Output "No active deployments found in agent directories." }
```

**Bash:**
```bash
archive_dir=".agent/workflows/archive"
timestamp=$(date +%Y%m%d-%H%M%S)
archive_name="${base_name}-${timestamp}.md"
archived_targets=()

for agent in "${supported_agents[@]}"; do
    agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')
    case "$agent_lower" in
        "claude") target_dir=".claude/commands" ;;
        "opencode") target_dir=".opencode/commands" ;;
        *) target_dir=".${agent_lower}/commands" ;;
    esac
    target_path="$target_dir/$workflow_name"
    agent_archive_dir="$target_dir/.trash"
    agent_archive_path="$agent_archive_dir/$archive_name"
    
    if [ -f "$target_path" ]; then
        # Create agent trash directory if needed
        mkdir -p "$agent_archive_dir"
        # Move to agent's trash
        mv "$target_path" "$agent_archive_path"
        archived_targets+=("$agent → $agent_archive_dir/$archive_name")
        echo "Archived from $agent"
    fi
done
[ ${#archived_targets[@]} -eq 0 ] && echo "No active deployments found in agent directories."
```

---

## 7. Commit Changes

**PowerShell:**
```powershell
git add -A
$commitMsg = @"
chore: archive $base_name workflow

- Archived to .agent/workflows/archive/
"@
git commit -m $commitMsg
```

**Bash:**
```bash
git add -A
git commit -m "chore: archive $base_name workflow

- Archived to .agent/workflows/archive/"
```

---

## 8. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► WORKFLOW ARCHIVED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Workflow: /{name}
Status: ARCHIVED (recoverable)

Archived to:
• .agent/workflows/archive/{name}-{timestamp}.md

Archived From:
• {Agent 1} — {path}/.trash/{name}-{timestamp}.md
• {Agent 2} — {path}/.trash/{name}-{timestamp}.md

───────────────────────────────────────────────────────

▶ NEXT STEPS

Restore: Run /restore-workflow to recover this workflow
Create: Run /add-workflow to create a new workflow

💡 Tip: Archived workflows are stored with timestamps and can be restored at any time.

───────────────────────────────────────────────────────
```

</process>

<note>
**Multi-Agent Synchronization:**
This workflow reads STACK.md to determine where to archive. Agents must be configured via `/gsd-init` first.

**Supported agent directories:**
- Claude: `.claude/commands/` (archived to `.claude/commands/.trash/`)
- OpenCode: `.opencode/commands/` (archived to `.opencode/commands/.trash/`)
- Custom: `.{agent-name}/commands/` (archived to `.{agent-name}/commands/.trash/`)
</note>

<warning>
**Prerequisites:**
- Must run `/gsd-init` first to configure agents
- Archived workflows can be restored via `/restore-workflow`
- This action requires explicit 'yes' confirmation to proceed
</warning>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/restore-workflow` | Restore archived workflows |
| `/add-workflow` | Create new workflows |
| `/gsd-init` | Configure agents before using this workflow |

### Files
| File | Purpose |
|------|---------|
| `.gsd/STACK.md` | Defines which agents are supported |
| `.agent/workflows/` | Primary source of truth for workflows |
| `.agent/workflows/archive/` | Archive location for workflows |
</related>
