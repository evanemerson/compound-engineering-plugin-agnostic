#!/usr/bin/env bash
set -euo pipefail

# Install cepa and all companion plugins for compound engineering.
# Run this after installing Claude Code: https://docs.anthropic.com/en/docs/claude-code

echo "=== cepa setup ==="
echo ""

# Check prerequisites
if ! command -v claude &> /dev/null; then
    echo "ERROR: 'claude' command not found."
    echo "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "WARNING: 'gh' (GitHub CLI) not found."
    echo "cepa uses 'gh' for PR creation and issue context in Phase 1 and Phase 4."
    echo "Install it: https://cli.github.com/"
    echo ""
fi

# 1. Register marketplaces (required)
echo "Registering cepa marketplace..."
if ! claude /plugin marketplace add evanemerson/compound-engineering-plugin-agnostic; then
    echo "ERROR: Failed to register cepa marketplace."
    echo "Check your internet connection and try again."
    echo "Manual: claude /plugin marketplace add evanemerson/compound-engineering-plugin-agnostic"
    exit 1
fi

echo "Registering superpowers marketplace..."
if ! claude /plugin marketplace add obra/superpowers-marketplace; then
    echo "ERROR: Failed to register superpowers marketplace."
    echo "Check your internet connection and try again."
    echo "Manual: claude /plugin marketplace add obra/superpowers-marketplace"
    exit 1
fi

# 2. Install required plugins
echo "Installing cepa..."
if ! claude /plugin install cepa; then
    echo "ERROR: Failed to install cepa. Is the marketplace registered?"
    exit 1
fi

echo "Installing superpowers (required)..."
if ! claude /plugin install superpowers; then
    echo "ERROR: Failed to install superpowers. Is the marketplace registered?"
    exit 1
fi

echo "Installing pr-review-toolkit (required)..."
if ! claude /plugin install pr-review-toolkit; then
    echo "ERROR: Failed to install pr-review-toolkit."
    exit 1
fi

# 3. Install recommended plugins (optional — failures are non-blocking)
echo "Installing recommended plugins..."
optional_warnings=()
for plugin in commit-commands claude-md-management code-review; do
    if ! claude /plugin install "$plugin" 2>/dev/null; then
        optional_warnings+=("$plugin")
        echo "  WARNING: Failed to install '$plugin' (optional). Install later: claude /plugin install $plugin"
    fi
done

# 4. Summary
echo ""
echo "=== Setup complete ==="
echo ""
echo "Installed:"
echo "  - cepa"
echo "  - superpowers"
echo "  - pr-review-toolkit"

if [ ${#optional_warnings[@]} -gt 0 ]; then
    echo ""
    echo "Skipped (optional — install manually later):"
    for w in "${optional_warnings[@]}"; do
        echo "  - $w"
    done
fi

echo ""
echo "Next steps:"
echo "  1. Create cepa.local.md in your project root (see README for example)"
echo "  2. Create project directories: mkdir -p docs/brainstorms docs/plans docs/solutions todos"
echo "  3. Run: /cepa:task \"your task description\""
