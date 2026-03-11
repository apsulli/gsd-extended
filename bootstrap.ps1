#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "GSD Bootstrap"
Write-Host "============="

# Check directories exist
if (-not (Test-Path -Path ".agent" -PathType Container) -or -not (Test-Path -Path ".gsd" -PathType Container)) {
    Write-Host "Error: .agent/ and .gsd/ directories not found"
    Write-Host "Please ensure you've copied GSD to your project root"
    exit 1
}

# Check git repo
if (-not (Test-Path -Path ".git" -PathType Container)) {
    Write-Host "Initializing git repository..."
    git init
}

# Success message
Write-Host @"

GSD is ready to initialize!

NEXT STEP: Tell your AI assistant:

"Please read and execute the workflow in .agent/workflows/gsd-init.md"

This will:
- Configure your AI agent environment
- Set up GSD documentation structure
- Copy workflows to your agent's command directory

After gsd-init completes, you can use all GSD commands:
  /new-project    - Create a new project
  /plan-phase     - Plan execution phases
  /execute        - Execute plans
  And more...

For help at any time: /help

"@
