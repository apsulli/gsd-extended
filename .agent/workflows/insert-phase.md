---
description: Insert a new phase — supports positional args or interactive interview
version: "1.1.0"
tags: ['roadmap', 'phases', 'planning']
---

# /insert-phase Workflow

<objective>
Insert a new phase into the roadmap. Accepts an optional position argument; falls back to interactive interview.

**Argument forms:**
- `/insert-phase next` — after the current active phase
- `/insert-phase last` — at the end of the roadmap (same as `/add-phase`)
- `/insert-phase 15-16` or `/insert-phase 15 16` — between phases 15 and 16 (inserts at position 16)
- `/insert-phase 5` — insert before phase 5 (i.e., at position 5)
- `/insert-phase` (no args) — interactive: prompts for position

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
            echo "⚠️  CONCURRENT OPERATION: $pending_id ($wf, ${elapsed}m ago)"
            echo "A) Wait  B) Force continue  C) Cancel"
            read -p "Choice: " choice
            case "${choice^^}" in
                A) echo "Retry when other operation completes."; exit 0 ;;
                B) echo "Warning: force continuing — manual merge may be required." ;;
                C) echo "Cancelled."; exit 0 ;;
                *) echo "Invalid choice." >&2; exit 1 ;;
            esac
        fi
    fi
fi
```

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

## 4. Parse Arguments → Resolve Insert Position

Inspect the arguments passed to the workflow. If recognized, set `insert_position` and skip step 5.

```bash
arg="$*"   # all arguments as a single string

if [ -z "$arg" ]; then
    insert_position=""   # no args — will prompt in step 5

elif echo "$arg" | grep -qiE '^next$'; then
    insert_position=$((current_phase + 1))

elif echo "$arg" | grep -qiE '^last$'; then
    insert_position=$((total_phases + 1))

elif echo "$arg" | grep -qE '^([0-9]+)[- ]([0-9]+)$'; then
    # "15-16" or "15 16" → insert at the higher number
    insert_position=$(echo "$arg" | grep -oE '[0-9]+' | tail -1)

elif echo "$arg" | grep -qE '^[0-9]+$'; then
    # bare number → insert before that phase number
    insert_position=$arg

else
    echo "Error: Unrecognized argument '$arg'" >&2
    echo "Valid: next | last | N | N-M | N M" >&2
    exit 1
fi
```

---

## 5. Interview User for Position (only if no args)

Skip entirely if `insert_position` is already set from step 4.

```
📍 WHERE SHOULD THE NEW PHASE BE INSERTED?

Current active phase: Phase {N}  |  Total phases: {M}

1) NEXT    — insert after Phase {N}
2) BETWEEN — insert at a specific position
3) LAST    — add at the end

Your choice (1/2/3):
```

```bash
if [ -z "$insert_position" ]; then
    read -p "Your choice (1/2/3): " choice
    case "$choice" in
        1) insert_position=$((current_phase + 1)) ;;
        2) read -p "Insert before which phase number? " insert_position ;;
        3) insert_position=$((total_phases + 1)) ;;
        *) echo "Error: Invalid choice" >&2; exit 1 ;;
    esac
fi

# Validate range
if [ "$insert_position" -lt 1 ] || [ "$insert_position" -gt $((total_phases + 1)) ]; then
    echo "Error: Position $insert_position out of range (1–$((total_phases + 1)))" >&2; exit 1
fi
```

---

## 6. Gather Phase Information

```
📋 NEW PHASE DETAILS — inserting at position {insert_position}

1. Phase Title:
2. Objective (what this phase achieves):
3. Deliverables (concrete outputs):
4. Dependencies (comma-separated phase numbers, or "none"):
```

---

## 7. Register Pending Operation in STATE.md

```bash
timestamp=$(date +%Y-%m-%dT%H:%M:%S)
sed -i '' '/## Pending Operation/,/^## /{ /^## Pending Operation/d; /^- \*\*/d; /^$/d; }' .gsd/STATE.md 2>/dev/null || true
printf '\n\n## Pending Operation\n- **ID**: %s\n- **Workflow**: /insert-phase\n- **Started**: %s\n- **Status**: in-progress\n' \
    "$OPERATION_ID" "$timestamp" >> .gsd/STATE.md
```

---

## 8. Check ROADMAP.md for Recent Modifications

```bash
modified_ts=$(stat -f %m .gsd/ROADMAP.md 2>/dev/null || stat -c %Y .gsd/ROADMAP.md)
time_since=$(( $(date +%s) - modified_ts ))
if [ "$time_since" -lt 30 ]; then
    read -p "Warning: ROADMAP.md modified ${time_since}s ago. Continue? (y/N): " choice
    [ "$choice" != "y" ] && [ "$choice" != "Y" ] && { echo "Cancelled."; exit 0; }
fi
```

---

## 9. Renumber Existing Phases (reverse order to avoid collisions)

```bash
for i in $(seq $total_phases -1 $insert_position); do
    sed -i '' "s/### Phase $i\b/### Phase $((i + 1))/g" .gsd/ROADMAP.md
    sed -i '' "s/Depends on: Phase $i\b/Depends on: Phase $((i + 1))/g" .gsd/ROADMAP.md
    [ -d ".gsd/phases/$i" ] && mv ".gsd/phases/$i" ".gsd/phases/$((i + 1))"
done
```

---

## 10. Insert New Phase Block

```bash
new_phase="### Phase $insert_position: $title
**Status:** ⬜ Not Started
**Objective:** $objective
**Deliverables:** $deliverables
**Dependencies:** $dependencies

**Plans:**
- [ ] Plan ${insert_position}.1: [To be defined]

---"

if [ "$insert_position" -eq 1 ]; then
    printf '%s\n\n' "$new_phase" | cat - .gsd/ROADMAP.md > .gsd/ROADMAP.md.tmp \
        && mv .gsd/ROADMAP.md.tmp .gsd/ROADMAP.md
else
    prev=$((insert_position - 1))
    awk -v p="$prev" -v n="$new_phase" '
        /^### Phase / { if (found) { print n; found=0 } }
        /^### Phase / && $3 == p":" { found=1 }
        { print }
        END { if (found) print n }
    ' .gsd/ROADMAP.md > .gsd/ROADMAP.md.tmp && mv .gsd/ROADMAP.md.tmp .gsd/ROADMAP.md
fi
```

---

## 11. Update STATE.md Current Phase (if displaced)

```bash
if [ "$current_phase" -ge "$insert_position" ]; then
    sed -i '' "s/Current Phase[: ]\+$current_phase/Current Phase: $((current_phase + 1))/" .gsd/STATE.md
fi
```

---

## 12. Complete Operation

```bash
sed -i '' '/## Pending Operation/,/^## /{/^## Pending Operation/d; /^- \*\*/d; /^$/d;}' .gsd/STATE.md 2>/dev/null || true
printf '\n\n## Last Operation\n- **ID**: %s\n- **Workflow**: /insert-phase\n- **Completed**: %s\n- **Status**: completed\n' \
    "$OPERATION_ID" "$(date +%Y-%m-%dT%H:%M:%S)" >> .gsd/STATE.md
# Lock released automatically by trap EXIT
```

---

## 13. Commit

```bash
git add .gsd/ROADMAP.md .gsd/STATE.md
git commit -m "docs: insert Phase $insert_position - $title (renumbered phases $insert_position+)"
```

---

## 14. Display Result

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
