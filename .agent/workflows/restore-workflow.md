---
description: Restore archived workflows from archive
version: "1.0.0"
tags: ['workflows', 'agents', 'automation', 'restore', 'archive']
---

# /restore-workflow

<objective>
Restore a previously archived workflow back to active use.
</objective>

<context>
**Requires:**
- `.agent/workflows/archive/` with archived workflows

**Restores:**
- Workflow to `.agent/workflows/`
- Syncs to all configured agent directories
</context>

<process>

## 1. Display Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► RESTORE WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Restore a previously archived GSD workflow.
```

---

## 2. List Archived Workflows

**PowerShell:**
```powershell
$archiveDir = ".agent/workflows/archive"
if (-not (Test-Path $archiveDir)) {
    Write-Error "No archive directory found at $archiveDir"
    exit 1
}
$archivedFiles = Get-ChildItem -Path $archiveDir -Filter "*.md" | Sort-Object LastWriteTime -Descending
if ($archivedFiles.Count -eq 0) {
    Write-Error "No archived workflows found in $archiveDir"
    exit 1
}
Write-Output ""
Write-Output "Archived workflows:"
Write-Output ""
$index = 1
foreach ($file in $archivedFiles) {
    $archiveDate = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    Write-Output "  $index. $($file.Name) (archived $archiveDate)"
    $index++
}
Write-Output ""
```

**Bash:**
```bash
archive_dir=".agent/workflows/archive"
if [ ! -d "$archive_dir" ]; then
    echo "Error: No archive directory found at $archive_dir" >&2
    exit 1
fi
archived_files=($(ls -1t "$archive_dir"/*.md 2>/dev/null))
if [ ${#archived_files[@]} -eq 0 ]; then
    echo "Error: No archived workflows found in $archive_dir" >&2
    exit 1
fi
echo ""
echo "Archived workflows:"
echo ""
index=1
for file in "${archived_files[@]}"; do
    archive_date=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null)
    filename=$(basename "$file")
    echo "  $index. $filename (archived $archive_date)"
    ((index++))
done
echo ""
```

---

## 3. Prompt for Selection

```
📝 WORKFLOW RESTORATION

Select number to restore: [user input]
```

**PowerShell:**
```powershell
$selection = Read-Host "Select number to restore"
$selectedFile = $null

if ($selection -match '^\d+$') {
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $archivedFiles.Count) {
        $selectedFile = $archivedFiles[$index]
    } else {
        Write-Error "Invalid selection. Please choose a number between 1 and $($archivedFiles.Count)"
        exit 1
    }
} else {
    Write-Error "Invalid input. Please enter a number."
    exit 1
}

Write-Output "Selected: $($selectedFile.Name)"
```

**Bash:**
```bash
read -p "Select number to restore: " selection
selected_file=""

if [[ "$selection" =~ ^[0-9]+$ ]]; then
    index=$((selection - 1))
    if [ $index -ge 0 ] && [ $index -lt ${#archived_files[@]} ]; then
        selected_file="${archived_files[$index]}"
    else
        echo "Error: Invalid selection. Please choose a number between 1 and ${#archived_files[@]}" >&2
        exit 1
    fi
else
    echo "Error: Invalid input. Please enter a number." >&2
    exit 1
fi

echo "Selected: $(basename "$selected_file")"
```

---

## 4. Restore Workflow

**PowerShell:**
```powershell
# Extract original name (remove timestamp)
$originalName = $selectedFile.Name -replace '-\d{8}-\d{6}\.md$', '.md'
$destPath = Join-Path ".agent/workflows" $originalName

# Check if workflow already exists
if (Test-Path $destPath) {
    $overwrite = Read-Host "Workflow '$originalName' already exists. Overwrite? (yes/no)"
    if ($overwrite -ne 'yes') {
        Write-Output "Restoration cancelled."
        exit 0
    }
}

Move-Item $selectedFile.FullName $destPath
Write-Output "Restored: $destPath"
```

**Bash:**
```bash
# Extract original name (remove timestamp)
filename=$(basename "$selected_file")
original_name=$(echo "$filename" | sed 's/-[0-9]\{8\}-[0-9]\{6\}\.md$/.md/')
dest_path=".agent/workflows/$original_name"

# Check if workflow already exists
if [ -f "$dest_path" ]; then
    read -p "Workflow '$original_name' already exists. Overwrite? (yes/no): " overwrite
    if [ "$overwrite" != "yes" ]; then
        echo "Restoration cancelled."
        exit 0
    fi
fi

mv "$selected_file" "$dest_path"
echo "Restored: $dest_path"
```

---

## 5. Environment Lookup — Read STACK.md

Check which agents are configured:

**PowerShell:**
```powershell
$stackContent = Get-Content ".gsd/STACK.md" -Raw
$agentPattern = "## Supported Agent Workflows.*?(?=\n## |\Z)"
$agentMatch = [regex]::Match($stackContent, $agentPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$supportedAgents = @()
if ($agentMatch.Success) {
    $agentLines = [regex]::Matches($agentMatch.Value, '^\s*[-*]\s*\*\*(.+?)\*\*')
    foreach ($match in $agentLines) { $supportedAgents += $match.Groups[1].Value.Trim() }
}
if ($supportedAgents.Count -eq 0) { 
    Write-Output "No agents configured. Skipping sync."
    $skipSync = $true
}
```

**Bash:**
```bash
supported_agents=()
if [ -f ".gsd/STACK.md" ] && grep -q "## Supported Agent Workflows" .gsd/STACK.md; then
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*[-*][[:space:]]*\*\*(.+)\*\* ]]; then
            agent="${BASH_REMATCH[1]}"; agent=$(echo "$agent" | sed 's/[[:space:]]*—.*//')
            supported_agents+=("$agent")
        fi
    done < <(sed -n '/## Supported Agent Workflows/,/^## /p' .gsd/STACK.md | head -20)
fi
if [ ${#supported_agents[@]} -eq 0 ]; then
    echo "No agents configured. Skipping sync."
    skip_sync=true
fi
```

---

## 6. Sync to Agents

**PowerShell:**
```powershell
if (-not $skipSync) {
    $syncedTargets = @()
    foreach ($agent in $supportedAgents) {
        $agentLower = $agent.ToLower()
        $targetDir = switch ($agentLower) {
            "claude" { ".claude/commands" }
            "opencode" { ".opencode/commands" }
            default { ".${agentLower}/commands" }
        }
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        $targetPath = Join-Path $targetDir $originalName
        Copy-Item -Path $destPath -Destination $targetPath -Force
        $syncedTargets += "$agent → $targetDir/$originalName"
        Write-Output "Synced to $agent"
    }
}
```

**Bash:**
```bash
if [ "$skip_sync" != "true" ]; then
    synced_targets=()
    for agent in "${supported_agents[@]}"; do
        agent_lower=$(echo "$agent" | tr '[:upper:]' '[:lower:]')
        case "$agent_lower" in
            "claude") target_dir=".claude/commands" ;;
            "opencode") target_dir=".opencode/commands" ;;
            *) target_dir=".${agent_lower}/commands" ;;
        esac
        mkdir -p "$target_dir"
        target_path="$target_dir/$original_name"
        cp "$dest_path" "$target_path"
        synced_targets+=("$agent → $target_path")
        echo "Synced to $agent"
    done
fi
```

---

## 7. Commit

```bash
git add -A
git commit -m "chore: restore $original_name workflow"
```

---

## 8. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► WORKFLOW RESTORED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Restored: /{name}
Location: .agent/workflows/{name}.md
Synced to: {agent directories}

───────────────────────────────────────────────────────

▶ NEXT STEPS

Verify: Run /{name} to test the restored workflow
Delete: Run /delete-workflow to archive again if needed

💡 Tip: The workflow is now active and synced to all configured agents.

───────────────────────────────────────────────────────
```

</process>

<related>
## Related

| Command | Purpose |
|---------|---------|
| `/delete-workflow` | Archive a workflow |
| `/add-workflow` | Create new workflow |
| `/gsd-init` | Configure agents |
</related>
