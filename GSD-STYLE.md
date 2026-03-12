# GSD Style Guide

This document defines the style and format conventions for GSD workflow files.

## Workflow Structure

Every GSD workflow file must follow this structure:

1. **YAML frontmatter** (required)
2. **`<objective>`** section (required)
3. **`<context>`** section (required)
4. **`<process>`** section (required)
5. **`<related>`** section (optional)

---

## YAML Frontmatter

All workflows must begin with YAML frontmatter:

```yaml
---
description: Clear, concise description of what this workflow accomplishes
version: "X.Y.Z"
tags: ['category', 'subcategory']  # optional but recommended
---
```

### Field Requirements

- **description**: One-line summary (keep under 100 characters)
- **version**: Must follow [Semantic Versioning](https://semver.org/) format (`MAJOR.MINOR.PATCH`)
  - `MAJOR`: Breaking changes to workflow structure or behavior
  - `MINOR`: New steps, improved clarity, additional platforms
  - `PATCH`: Bug fixes, typos, minor clarifications
- **tags**: Array of lowercase strings for categorization (optional but recommended)

---

## Writing Objectives

The `<objective>` section defines what the workflow accomplishes.

### Guidelines

- Start with an action verb (Create, Configure, Deploy, Set up, etc.)
- Be specific about the outcome
- Keep it to 1-2 sentences
- Avoid ambiguity

### Examples

✅ **Good**:
```markdown
<objective>
Configure a new Python virtual environment with common data science packages
and set up pre-commit hooks for code quality.
</objective>
```

❌ **Bad**:
```markdown
<objective>
Set up Python stuff.
</objective>
```

---

## Writing Context

The `<context>` section provides background information and prerequisites.

### Guidelines

- List prerequisites clearly
- Include required versions/tools
- Mention assumptions about the environment
- Add warnings or important notes
- Use bullet points for readability

### Structure

```markdown
<context>
Prerequisites:
- Tool X version Y or higher
- Access to Z

Assumptions:
- Working directory is set to project root
- Git is configured

Notes:
- This workflow modifies system files
- Backup recommended before proceeding
</context>
```

---

## Process Steps

The `<process>` section contains the actual instructions.

### Formatting Conventions

1. **Numbered steps**: Use `1.`, `2.`, etc. for sequential steps
2. **Sub-steps**: Use bullet points under numbered steps for alternatives
3. **Platform-specific instructions**: Clearly label PowerShell vs Bash

### Step Structure

```markdown
<process>
1. **Action Description**
   - PowerShell: `command-here`
   - Bash: `command-here`

2. **Next Action**
   - PowerShell: `another-command`
   - Bash: `another-command`
</process>
```

### Guidelines

- Each step should be atomic (one action)
- Include expected outcomes when helpful
- Use bold for emphasis on key actions
- Keep steps concise but complete

---

## Code Block Conventions

### Cross-Platform Code

Always provide both PowerShell and Bash alternatives when applicable:

```markdown
- PowerShell: `Get-ChildItem`
- Bash: `ls -la`
```

### Language-Specific Blocks

For multi-line code, use fenced blocks with language identifiers:

```powershell
# PowerShell
$env:VARIABLE = "value"
Write-Host "Message"
```

```bash
# Bash
export VARIABLE="value"
echo "Message"
```

### Inline Code

Use backticks for:
- Commands: `git status`
- File paths: `~/Documents`
- Variable names: `$HOME`
- Tool names: `docker`, `kubectl`

---

## Cross-Platform Considerations

### Path Separators

- Windows uses backslash (`\`)
- Unix uses forward slash (`/`)
- When writing generic paths, use forward slashes or note the difference

### Environment Variables

- Windows: `$env:VARNAME` or `%VARNAME%`
- Unix: `$VARNAME` or `${VARNAME}`
- Always document both approaches

### Case Sensitivity

- Remember Windows is case-insensitive, Unix is case-sensitive
- Always use exact casing in examples

### Line Endings

- Use LF (`\n`) for cross-platform compatibility
- Note if a workflow requires specific line endings

---

## Version Field Requirements

### When to Bump Versions

| Change Type | Version Bump | Example |
|-------------|-------------|---------|
| New workflow | 1.0.0 | Initial creation |
| Breaking changes | Major (X.0.0) | Changed step order, removed steps |
| New features | Minor (x.Y.0) | Added new platform support |
| Fixes/typos | Patch (x.y.Z) | Fixed command typo, clarified text |

### Version Validation

- Must match regex: `^\d+\.\d+\.\d+$`
- Must be quoted in YAML: `version: "1.2.3"`
- Each workflow versions independently — there is no requirement to match the root `VERSION` file

---

## Related Section

The optional `<related>` section links to other workflows.

### Format

```markdown
<related>
- [Workflow Name](../path/to/workflow.md)
- [Another Workflow](../another/path.gsd.md)
</related>
```

### Guidelines

- Use relative paths
- Keep links relevant (truly related workflows)
- Alphabetize when order doesn't matter

---

## File Naming Conventions

- Use kebab-case: `my-workflow.md`
- Extension: `.md` (plain Markdown, consistent with all existing workflows)
- Avoid spaces and special characters
- Be descriptive but concise

---

## Example Complete Workflow

```markdown
---
description: "Initialize a new Node.js project with TypeScript support"
version: "1.0.0"
tags: ['nodejs', 'typescript', 'setup']
---

<objective>
Create a new Node.js project with TypeScript configuration,
ESLint, and Prettier for code formatting.
</objective>

<context>
Prerequisites:
- Node.js 18+ installed
- npm or yarn package manager

Assumptions:
- Running from empty project directory
- Git is initialized (optional but recommended)
</context>

<process>
1. **Initialize package.json**
   - PowerShell: `npm init -y`
   - Bash: `npm init -y`

2. **Install TypeScript and dependencies**
   - PowerShell: `npm install --save-dev typescript @types/node`
   - Bash: `npm install --save-dev typescript @types/node`

3. **Create TypeScript configuration**
   - PowerShell: `npx tsc --init`
   - Bash: `npx tsc --init`
</process>

<related>
- [Configure ESLint](./configure-eslint.gsd.md)
- [Configure Prettier](./configure-prettier.gsd.md)
</related>
```

---

## Validation Checklist

Before submitting a workflow:

- [ ] YAML frontmatter is present and valid
- [ ] Version follows SemVer format
- [ ] All required sections are present
- [ ] PowerShell and Bash alternatives provided where applicable
- [ ] No placeholder text or TODOs remain
- [ ] Links in `<related>` are valid relative paths
- [ ] File name follows kebab-case convention
