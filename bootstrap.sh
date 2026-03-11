#!/bin/bash

set -e

echo "GSD Bootstrap"
echo "============="

# Check directories exist
if [ ! -d ".agent" ] || [ ! -d ".gsd" ]; then
    echo "Error: .agent/ and .gsd/ directories not found"
    echo "Please ensure you've copied GSD to your project root"
    exit 1
fi

# Check git repo
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
fi

# Success message
cat << 'EOF'

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

EOF
