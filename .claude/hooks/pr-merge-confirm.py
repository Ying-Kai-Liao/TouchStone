#!/usr/bin/env python3
"""
PreToolUse hook to require confirmation before running 'gh pr merge' commands.
Once a PR is approved, it can be merged without asking again (useful for CI retry loops).

The approval is saved WHEN we ask for permission (before user responds), so that
if the merge command fails (e.g., CI still running), the next attempt won't ask again.
"""
import json
import sys
import os
import re

APPROVED_PRS_FILE = os.path.join(os.path.dirname(__file__), ".approved_prs")

def get_approved_prs():
    """Load the set of approved PR numbers."""
    if not os.path.exists(APPROVED_PRS_FILE):
        return set()
    with open(APPROVED_PRS_FILE, "r") as f:
        return set(line.strip() for line in f if line.strip())

def save_approved_pr(pr_number):
    """Add PR number to the approved list."""
    approved = get_approved_prs()
    approved.add(pr_number)
    with open(APPROVED_PRS_FILE, "w") as f:
        f.write("\n".join(sorted(approved)) + "\n")

def extract_pr_number(command):
    """Extract PR number from gh pr merge command."""
    # Match patterns like: gh pr merge 123, gh pr merge #123, gh pr merge PR_URL
    match = re.search(r'gh pr merge\s+#?(\d+)', command)
    if match:
        return match.group(1)
    # Also check for URL pattern
    match = re.search(r'gh pr merge\s+\S*?/pull/(\d+)', command)
    if match:
        return match.group(1)
    return None

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
command = tool_input.get("command", "")

# Only check Bash commands containing "gh pr merge"
if tool_name == "Bash" and "gh pr merge" in command:
    pr_number = extract_pr_number(command)

    if pr_number:
        approved_prs = get_approved_prs()

        # If this PR was already approved, allow it
        if pr_number in approved_prs:
            sys.exit(0)

        # Save approval NOW (before asking) so retries don't ask again
        save_approved_pr(pr_number)

    # Ask for confirmation
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": f"PR merge requires confirmation: {command}"
        }
    }
    print(json.dumps(output))
    sys.exit(0)

# Allow all other commands
sys.exit(0)
