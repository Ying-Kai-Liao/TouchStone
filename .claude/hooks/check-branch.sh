#!/bin/bash

# PreToolUse hook: Prevent commits/edits on main branch
# Reads tool info from stdin as JSON

# Get current branch
current_branch=$(git branch --show-current 2>/dev/null)

# If not in a git repo, allow the operation
if [ -z "$current_branch" ]; then
    exit 0
fi

# Block operations on main branch
if [ "$current_branch" = "main" ]; then
    echo "BLOCKED: You are on the 'main' branch."
    echo "Please create a feature branch first:"
    echo "  git checkout -b dev/<feature-name>"
    echo ""
    echo "See CLAUDE.md for branching guidelines."
    exit 2
fi

# Allow operation
exit 0
