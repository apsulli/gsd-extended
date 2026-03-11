---
description: Archive old JOURNAL.md entries to keep context slim
version: "1.0.0"
---

# /archive-journal Workflow

<objective>
Move journal entries beyond the 5-session hot window into dated archive files in `.gsd/journal/`, keeping `JOURNAL.md` lean and context-window-friendly.
</objective>

<when_to_use>

- JOURNAL.md has grown beyond 5 sessions
- Automatically triggered by `/pause-work` when session count exceeds 5
- Manually when you want to slim down context before a long work session

</when_to_use>

<process>

## 1. Count Sessions

```bash
grep -c "^## Session:" .gsd/JOURNAL.md
```

If the count is **≤ 5**, print:

```
✅ JOURNAL.md is lean (N sessions). No archiving needed.
```

And stop.

---

## 2. Find the Archive Boundary

Identify the line number where the 6th session begins:

```bash
grep -n "^## Session:" .gsd/JOURNAL.md | awk 'NR==6{print $1}' | cut -d: -f1
```

Call this line number `ARCHIVE_LINE`.

All content from `ARCHIVE_LINE` to end of file will be archived.

---

## 3. Determine Archive Filename

From the 6th session header, extract the year-month (e.g., `## Session: 2026-02-17 ...` → `2026-02`):

```bash
grep -m 1 "^## Session:" .gsd/JOURNAL.md | grep -oE "[0-9]{4}-[0-9]{2}"
```

> **Note:** If entries span multiple months, use the month of the _oldest_ entry being archived (last `## Session:` line in the file). Create separate archive files per month if needed.

Archive filename: `.gsd/journal/YYYY-MM-archive.md`

---

## 4. Append to Archive File

If the archive file does not exist, create it with a header:

```markdown
# Journal Archive: {Month} {YYYY}

{Brief description of the phase range covered}
Archived from `.gsd/JOURNAL.md` on {today's date}.

---
```

Then append the entries being archived:

```bash
# Append archived sessions to the archive file
sed -n '{ARCHIVE_LINE},$p' .gsd/JOURNAL.md >> .gsd/journal/YYYY-MM-archive.md
```

---

## 5. Trim JOURNAL.md

Keep only lines 1 through `ARCHIVE_LINE - 1`, plus the archive footer if not already present:

```bash
# Extract hot window
sed -n '1,{ARCHIVE_LINE-1}p' .gsd/JOURNAL.md > /tmp/journal_hot.md

# Ensure archive footer block is present at end of hot log
# (Add it if missing — contains links to archive files)
cp /tmp/journal_hot.md .gsd/JOURNAL.md
```

The footer format to append if not already present:

```markdown
---

> **📦 Older entries archived** — See `.gsd/journal/` for historical sessions.
> Run `/archive-journal` to archive when this file grows beyond 5 sessions.
```

---

## 6. Commit

```bash
git add .gsd/JOURNAL.md .gsd/journal/
git commit -m "docs: archive journal entries — hot log trimmed to 5 sessions"
```

---

## 7. Display Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► JOURNAL ARCHIVED 📦
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{N} sessions archived → .gsd/journal/{YYYY-MM}-archive.md
JOURNAL.md now contains {M} sessions ({lines} lines)

───────────────────────────────────────────────────────

To search historical sessions:
  grep -A 20 "Phase X" .gsd/journal/{YYYY-MM}-archive.md

───────────────────────────────────────────────────────
```

</process>

<archive_structure>

## Archive File Naming

```
.gsd/
  JOURNAL.md                    ← Hot log (≤ 5 sessions, auto-loaded)
  journal/
    README.md                   ← Explains the tier system
    2026-01-archive.md          ← January 2026 sessions
    2026-02-archive.md          ← February 2026 early sessions
    YYYY-MM-archive.md          ← Future months as needed
```

## Rules

- **JOURNAL.md** is the ONLY file that workflows auto-load. Keep it ≤ 5 sessions.
- Archive files are **append-only** — never edit them.
- If entries span month boundaries, split into separate archive files by month.

</archive_structure>
