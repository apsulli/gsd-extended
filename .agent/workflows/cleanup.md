---
description: Clean up old debug sessions and archived journal entries
version: "1.0.0"
---

# /cleanup Workflow

<objective>
Archive old debug sessions (older than 30 days) and clean up journal entries.
</objective>

<when_to_use>

- Automatically triggered by `/pause` when debug sessions > 10 or oldest > 30 days
- Manually when you want to clean up old debugging artifacts
- As part of periodic maintenance

</when_to_use>

<process>

## 1. Scan Debug Sessions

**PowerShell:**
```powershell
$cutoffDate = (Get-Date).AddDays(-30)
$debugDirs = Get-ChildItem "debugging/*" -Directory | Where-Object { 
    $_.CreationTime -lt $cutoffDate 
}
```

**Bash:**
```bash
cutoff_date=$(date -d '30 days ago' +%s 2>/dev/null || date -v-30d +%s)
find debugging -maxdepth 1 -type d -mtime +30 | while read dir; do
    # Process each old directory
```

---

## 2. Check Session Status

For each old session:
- If `SUMMARY.md` exists (resolved): Skip (preserve forever)
- If only `RESEARCH.md` or `PLAN.md` (unresolved): Archive it

**PowerShell:**
```powershell
$resolvedCount = 0
$archivedCount = 0
$preservedCount = 0

foreach ($dir in $debugDirs) {
    $summaryPath = Join-Path $dir.FullName "SUMMARY.md"
    if (Test-Path $summaryPath) {
        $preservedCount++
        continue  # Preserve resolved sessions forever
    }
    $archivedCount++
    # Archive unresolved session
}
```

**Bash:**
```bash
archived_count=0
preserved_count=0

find debugging -maxdepth 1 -type d -mtime +30 | while read dir; do
    # Skip the debugging directory itself
    [[ "$dir" == "debugging" ]] && continue
    
    if [[ -f "$dir/SUMMARY.md" ]]; then
        ((preserved_count++))
        continue  # Preserve resolved sessions forever
    fi
    ((archived_count++))
    # Archive unresolved session
done
```

---

## 3. Archive Unresolved Sessions

**PowerShell:**
```powershell
New-Item -ItemType Directory -Force -Path "debugging/archived"
Move-Item $dir.FullName "debugging/archived/"
```

**Bash:**
```bash
mkdir -p debugging/archived
mv "$dir" debugging/archived/
```

---

## 4. Archive Old Journal Entries

Run `/archive-journal` to check and archive old entries:

```bash
# Count sessions in JOURNAL.md
session_count=$(grep -c "^## Session:" .gsd/JOURNAL.md 2>/dev/null || echo "0")

if [[ $session_count -gt 5 ]]; then
    # Trigger archive-journal workflow
    /archive-journal
    archived_sessions=$session_count
else
    archived_sessions=0
fi
```

---

## 5. Commit

```bash
git add debugging/archived/ .gsd/journal/
git commit -m "chore: archive old debug sessions and journal entries"
```

---

## 6. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► CLEANUP COMPLETE 🧹
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Archived {N} unresolved debug sessions to debugging/archived/
Archived {M} old journal entries
Preserved {X} resolved debug sessions (kept forever)

───────────────────────────────────────────────────────

Next steps:
• Review archived sessions: ls debugging/archived/
• Check journal archives: ls .gsd/journal/

───────────────────────────────────────────────────────
```

</process>

<related>
## Related

### Workflows
| Command | Relationship |
|---------|--------------|
| `/pause` | Auto-triggers `/cleanup` when needed |
| `/archive-journal` | Archives old journal entries |
| `/debug-flow` | Creates debug sessions that may be archived |

### Files
| Path | Purpose |
|------|---------|
| `debugging/` | Active debug session directories |
| `debugging/archived/` | Archived unresolved sessions |
| `.gsd/JOURNAL.md` | Active journal (hot log) |
| `.gsd/journal/` | Archived journal entries |

</related>

<rules>

## Archive Rules

1. **Unresolved sessions** (>30 days old) → Move to `debugging/archived/`
2. **Resolved sessions** (have SUMMARY.md) → Keep forever in `debugging/`
3. **Journal entries** (>5 sessions) → Archive to `.gsd/journal/YYYY-MM-archive.md`
4. **Auto-trigger** in `/pause` when:
   - Debug session count > 10, OR
   - Oldest debug session > 30 days

</rules>
