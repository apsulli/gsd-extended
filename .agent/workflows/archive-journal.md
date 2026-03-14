---
description: Archive old JOURNAL.md entries to keep context slim
---

# /archive-journal Workflow

<objective>
Move journal entries beyond the 5-session hot window into dated archive files in `.gsd/journal/`, keeping `JOURNAL.md` lean and context-window-friendly.
</objective>

<when_to_use>

- JOURNAL.md has grown beyond 5 sessions
- Automatically triggered by `/pause` when session count exceeds 5
- Manually when you want to slim down context before a long work session

</when_to_use>

<process>

## 1. Count Sessions

Count `## Session:` lines in JOURNAL.md. If **≤ 5**, print:

```
✅ JOURNAL.md is lean (N sessions). No archiving needed.
```

And **stop**.

---

## 2. Read JOURNAL.md Fully

Read the entire JOURNAL.md into memory using the Read tool. You need to know:
- The header line (line 1: `# JOURNAL.md — Ritzy and the Feather`)
- Where each `## Session:` block starts
- Which sessions to keep (first 5) and which to archive (6th onward)
- Whether an archive footer already exists at the bottom

---

## 3. Identify the Split Point

Find the line where the **6th** `## Session:` heading begins. Everything from that line to the end of the file (excluding the archive footer if present) will be archived.

**Archive footer** to strip if present:
```markdown
---

> **📦 Older entries archived** — See `.gsd/journal/` for historical sessions.
> Run `/archive-journal` to archive when this file grows beyond 5 sessions.
```

---

## 4. Determine Archive Filename

Extract the year-month from the **oldest** session being archived (the last `## Session:` line among the entries being moved). Example: `## Session: 2026-03-13 (...)` → `2026-03`.

Archive filename: `.gsd/journal/YYYY-MM-archive.md`

> If entries span multiple months, use the oldest month. Do NOT split into separate files — one archive file per month is enough.

---

## 5. Write the Archive File

Use the **Write tool** (not bash pipes) to construct the archive file contents:

### If archive file does NOT exist:

Write a new file with this structure:
```markdown
# Journal Archive — {Month Name} {YYYY}

{archived entries here, in their original order from JOURNAL.md}
```

### If archive file ALREADY exists:

1. **Read the existing archive file** fully using the Read tool
2. Construct the new file content as:
   - Line 1: The existing header line (`# Journal Archive — ...`)
   - Line 2: blank line
   - Then: the new entries being archived (these are newer, so they go first)
   - Then: the existing entries (everything after the header line from the old file)
3. **Write** the complete file using the Write tool

> **Why this order?** Archives are reverse chronological (newest first), matching JOURNAL.md convention. New entries are always more recent than existing archive entries.

### Verification after writing:

Count `## Session:` lines in the updated archive file. The count should equal (previous count + number of entries archived). If it doesn't match, **STOP and report the discrepancy** — do not proceed.

---

## 6. Trim JOURNAL.md

Use the **Write tool** to write the trimmed JOURNAL.md with:
- The header line
- The 5 most recent sessions (kept entries)
- The archive footer block:

```markdown
---

> **📦 Older entries archived** — See `.gsd/journal/` for historical sessions.
> Run `/archive-journal` to archive when this file grows beyond 5 sessions.
```

### Verification after writing:

Count `## Session:` lines in the new JOURNAL.md. Must be exactly 5 (or fewer if the original had fewer than 5 + entries to archive). If wrong, **STOP and report**.

---

## 7. Commit

```bash
git add .gsd/JOURNAL.md .gsd/journal/
git commit -m "docs: archive journal entries — hot log trimmed to 5 sessions"
```

---

## 8. Display Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► JOURNAL ARCHIVED 📦
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{N} sessions archived → .gsd/journal/{YYYY-MM}-archive.md
JOURNAL.md now contains {M} sessions

───────────────────────────────────────────────────────
```

</process>

<critical_rules>

## DO and DON'T

- **DO** use the Read tool and Write tool for all file operations. Never use bash `head`/`tail`/`cat`/`sed`/`mv` pipelines to manipulate markdown files — they are error-prone and can silently corrupt content.
- **DO** verify counts after each write operation before proceeding.
- **DO** read the existing archive file before writing to it — never write without reading first.
- **DON'T** use `/tmp` files as intermediary storage.
- **DON'T** assume archive files have `---` separators after the header — they may not.
- **DON'T** proceed past a verification failure — stop and report.

</critical_rules>

<archive_structure>

## Archive File Format

Archive files have a simple structure — a header line followed by entries:

```markdown
# Journal Archive — March 2026

## Session: 2026-03-14 (Most Recent Archived)
...

---

## Session: 2026-03-13 (Older Entry)
...

---
```

**No `---` separator after the header.** Entries start immediately after the blank line following the header.

## Directory Layout

```
.gsd/
  JOURNAL.md                    ← Hot log (≤ 5 sessions, auto-loaded)
  journal/
    2026-03-archive.md          ← March 2026 archived sessions
    YYYY-MM-archive.md          ← Future months as needed
```

## Rules

- **JOURNAL.md** is the ONLY file that workflows auto-load. Keep it ≤ 5 sessions.
- Archive files are **prepend-only** — new entries go at the top (after header) to maintain reverse chronological order.
- One archive file per month. Don't split further.

</archive_structure>
