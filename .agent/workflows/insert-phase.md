---
description: Insert a new phase — supports positional args or interactive interview
version: "1.2.0"
tags: ['roadmap', 'phases', 'planning']
---

# /insert-phase Workflow

<objective>
Insert a new phase into the roadmap. Accepts optional position and title arguments; interviews for any missing fields.

**Argument forms:**
- `/insert-phase next` — after the current active phase
- `/insert-phase last` — at the end of the roadmap (same as `/add-phase`)
- `/insert-phase 15-16` or `/insert-phase 15 16` — between phases 15 and 16 (inserts at position 16)
- `/insert-phase 5` — insert before phase 5 (i.e., at position 5)
- `/insert-phase next "Security Hardening"` — position + title both pre-filled
- `/insert-phase` (no args) — interview for all required fields

Renumbers subsequent phases to maintain timeline integrity.
</objective>

<context>
**Requires:**
- `.gsd/ROADMAP.md` — existing roadmap with phases
- `.gsd/STATE.md` — to identify current phase

**Outputs:**
- Updated `.gsd/ROADMAP.md` with new phase inserted and renumbered
- Updated phase directories (if they exist)
</context>

<process>

## 1. Acquire Lock

```bash
lock_file=".gsd/.lock"; max_retries=10; retry_count=0
[ -d ".gsd" ] || mkdir -p ".gsd"

while [ -f "$lock_file" ]; do
    expires=$(jq -r '.expires' "$lock_file" 2>/dev/null)
    if [ -n "$expires" ] && [ "$expires" != "null" ]; then
        now=$(date -u +%s)
        exp=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires" +%s 2>/dev/null || date -u -d "$expires" +%s 2>/dev/null)
        [ -n "$exp" ] && [ "$now" -gt "$exp" ] && break
    fi
    retry_count=$((retry_count + 1))
    [ $retry_count -ge $max_retries ] && { echo "Error: lock timeout" >&2; exit 1; }
    sleep 0.05
done

trap 'rm -f "$lock_file"' EXIT
OPERATION_ID="$(date +%s)-$(openssl rand -hex 4)"
expires=$(date -u -v+5M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ)
printf '{"resource":"ROADMAP.md,STATE.md","workflow":"/insert-phase","acquired":"%s","expires":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$expires" > "$lock_file"
```

---

## 2. Check for Concurrent Operations

```bash
if [ -f ".gsd/STATE.md" ]; then
    pending_id=$(grep -oP '\*\*ID\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null)
    started=$(grep -oP '\*\*Started\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null)
    if [ -n "$pending_id" ] && [ -n "$started" ]; then
        start_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$started" +%s 2>/dev/null || date -d "$started" +%s 2>/dev/null)
        elapsed=$(( ($(date +%s) - start_ts) / 60 ))
        if [ "$elapsed" -lt 5 ]; then
            wf=$(grep -oP '\*\*Workflow\*\*:\s*\K\S+' .gsd/STATE.md 2>/dev/null || echo "unknown")
            echo "⚠️  CONCURRENT OPERATION DETECTED: $pending_id ($wf, ${elapsed}m ago)"
            echo "Resolve the pending operation before running /insert-phase."
            exit 1
        fi
    fi
fi
```

If a concurrent operation is active (< 5 minutes old), **STOP** and report to the user. Do not prompt — manual resolution is required.

---

## 3. Identify Current Phase

```bash
current_phase=""
[ -f ".gsd/STATE.md" ] && current_phase=$(grep -oP 'Current Phase[:\s]+\K\d+' .gsd/STATE.md 2>/dev/null)
[ -z "$current_phase" ] && [ -f ".gsd/ROADMAP.md" ] && \
    current_phase=$(grep -oP '> \*\*Current Phase:\*\*\s*\K\d+' .gsd/ROADMAP.md 2>/dev/null)
[ -z "$current_phase" ] && { echo "Error: Cannot determine current phase" >&2; exit 1; }
total_phases=$(grep -c "### Phase [0-9]" .gsd/ROADMAP.md)
```

---

## 4. Parse Arguments → Resolve Position and Title

Split the argument string: the **first whitespace-delimited token** is the position specifier; **everything after it** (stripped of surrounding quotes) is the title. Both are optional.

Resolve `insert_position` from the position token:

| Token | Result |
|-------|--------|
| (empty) | `insert_position = nil` — will ask in step 5 |
| `next` (case-insensitive) | `insert_position = current_phase + 1` |
| `last` (case-insensitive) | `insert_position = total_phases + 1` |
| `N-M` or `N M` (two numbers) | `insert_position = max(N, M)` |
| `N` (single number) | `insert_position = N` |
| anything else | **STOP** — print valid argument forms and exit |

Set `title = remainder` if non-empty, otherwise `title = nil`.

---

## 5. Check ROADMAP.md for Recent Modifications

```bash
modified_ts=$(stat -f %m .gsd/ROADMAP.md 2>/dev/null || stat -c %Y .gsd/ROADMAP.md)
time_since=$(( $(date +%s) - modified_ts ))
if [ "$time_since" -lt 30 ]; then
    echo "⚠️  ROADMAP.md was modified ${time_since}s ago."
    echo "Resolve any in-progress edits before inserting a phase."
    exit 1
fi
```

If ROADMAP.md was modified within the last 30 seconds, **STOP** and report. Do not continue.

---

## 6. Fill Gaps — Interview for Missing Fields Only

If all fields are already known from arguments, skip this step entirely.

Otherwise, state what is already resolved, then ask for only the missing fields in a **single message**:

```
📋 NEW PHASE DETAILS

Already provided:
  Position: {insert_position, or "not yet set"}
  Title:    {title, or "not yet set"}

Please provide the following:
  • Position (next / last / N / N-M):      ← omit if already set
  • Phase title:                            ← omit if already set
  • Objective (what this phase achieves):
  • Deliverables (concrete outputs):
  • Dependencies (phase numbers, or "none"):
```

Wait for the user's reply and parse all values. Validate `insert_position` is in range `[1, total_phases + 1]` — if out of range, report and re-ask before proceeding.

---

## 7. Register Pending Operation in STATE.md

Read `.gsd/STATE.md` using the Read tool. Use the Edit tool to replace any existing `## Pending Operation` block with the following, or append it if absent:

```markdown
## Pending Operation
- **ID**: {OPERATION_ID}
- **Workflow**: /insert-phase
- **Started**: {timestamp}
- **Status**: in-progress
```

---

## 8. Renumber Existing Phases and Insert New Phase

Read `.gsd/ROADMAP.md` fully using the Read tool. Perform all modifications in memory, then write the complete result using the Write tool.

### 8a. Renumber

Working from the largest phase number down to `insert_position`, in the in-memory content:
- Replace each `### Phase N:` heading where `N >= insert_position` with `### Phase {N+1}:`
- Replace each `Depends on: Phase N` where `N >= insert_position` with `Depends on: Phase {N+1}`

Processing largest-to-smallest prevents double-incrementing (e.g., phase 5 → 6 before phase 4 → 5).

### 8b. Insert

Construct the new phase block:

```markdown
### Phase {insert_position}: {title}
**Status:** ⬜ Not Started
**Objective:** {objective}
**Deliverables:** {deliverables}
**Dependencies:** {dependencies}

**Plans:**
- [ ] Plan {insert_position}.1: [To be defined]

---
```

Insert it at the correct location in the in-memory content:
- If `insert_position == 1`: insert before the first `### Phase` heading (after any roadmap header).
- Otherwise: insert immediately after the `---` separator that closes `### Phase {insert_position - 1}`.

Write the complete modified content using the Write tool.

### 8c. Verify

Count `### Phase` headings in the written file. Must equal `total_phases + 1`. If not, **STOP and report** — do not proceed.

### 8d. Rename Phase Directories (if applicable)

```bash
for i in $(seq $total_phases -1 $insert_position); do
    [ -d ".gsd/phases/$i" ] && mv ".gsd/phases/$i" ".gsd/phases/$((i + 1))"
done
```

---

## 9. Update STATE.md Current Phase (if displaced)

If `current_phase >= insert_position`, use the Edit tool to update `Current Phase: {current_phase}` → `Current Phase: {current_phase + 1}` in STATE.md.

---

## 10. Complete Operation

Use the Edit tool to replace the `## Pending Operation` block in STATE.md with:

```markdown
## Last Operation
- **ID**: {OPERATION_ID}
- **Workflow**: /insert-phase
- **Completed**: {timestamp}
- **Status**: completed
```

Lock is released automatically by the `trap EXIT` registered in step 1.

---

## 11. Commit

```bash
git add .gsd/ROADMAP.md .gsd/STATE.md
git commit -m "docs: insert Phase {insert_position} - {title} (renumbered phases {insert_position}+)"
```

---

## 12. Display Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► PHASE INSERTED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Inserted: Phase {insert_position}: {title}
Renumbered: Phases {insert_position+1} through {total_phases+1}

▶ NEXT
/plan-phase {insert_position} — Create execution plans
/progress — View updated roadmap
```

</process>

<warning>
Phase insertion affects subsequent numbering. Use sparingly early in milestone lifecycle.
</warning>

<related>
| Command | Purpose |
|---------|---------|
| `/add-phase` | Add phase at end |
| `/remove-phase` | Remove a phase (triggers renumbering) |
| `/plan-phase` | Create execution plans |
</related>
