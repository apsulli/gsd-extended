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

JOURNAL.md is **reverse-chronological** — the most recent session is at the top. Read the entire file using the Read tool. Note:
- The header line (line 1)
- Which sessions to keep (top 5) and which to archive (everything from the 6th `## Session:` heading to end-of-file)
- Whether an archive footer exists at the bottom

---

## 3. Identify the Split Point

Find the line where the **6th** `## Session:` heading begins. Everything from that line to the end of the file (excluding the archive footer if present) will be archived.

**Archive footer** — strip if present. Identify by structure: a `---` separator near the end of the file followed by a blockquote containing `📦 Older entries archived`. Strip from that `---` to end-of-file.

---

## 4. Determine Archive Filename

Extract the year-month from the **last** `## Session:` heading in the archived block (the bottommost entry in the file — it is the oldest). Example: `## Session: 2026-03-13 (...)` → `2026-03`.

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

1. **Read the existing archive file** fully using the Read tool.
2. Construct the new file with this exact layout:

   ```
   [header line]          ← existing, unchanged
   [blank line]
   [new entries]          ← the archived block from JOURNAL.md
   [existing entries]     ← everything after the header in the old archive
   ```

3. **Write** the complete file using the Write tool.

### Verification after writing:

Verify the updated archive file:
- `## Session:` count = (previous archive count + number of entries just archived)
- The first content line after the header is a `## Session:` line (catches header duplication or misaligned prepend)

If either check fails, **STOP and report** — do not proceed.

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

Verify the trimmed JOURNAL.md:
- `## Session:` count = exactly 5 (or fewer if original total was < 5 + archived count)
- First content line after the header is a `## Session:` line
- File ends with the archive footer block

If any check fails, **STOP and report** — do not commit.

> **Partial failure guard**: If the archive write succeeded but this JOURNAL.md write fails, do NOT retry blindly. Re-read both files, identify which sessions appear in each, resolve any duplication, then rewrite.

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
