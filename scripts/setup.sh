#!/usr/bin/env bash
set -euo pipefail

# Install cepa and all companion plugins for compound engineering.
# Run this after installing Claude Code: https://docs.anthropic.com/en/docs/claude-code

echo "=== cepa setup ==="
echo ""

# 1. Register marketplaces
echo "Registering marketplaces..."
claude /plugin marketplace add evanemerson/compound-engineering-plugin-agnostic 2>/dev/null || true
claude /plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true

# 2. Install cepa
echo "Installing cepa..."
claude /plugin install cepa

# 3. Install required companion plugins
echo "Installing superpowers (required)..."
claude /plugin install superpowers

echo "Installing pr-review-toolkit (required)..."
claude /plugin install pr-review-toolkit

# 4. Install recommended plugins
echo "Installing recommended plugins..."
claude /plugin install commit-commands 2>/dev/null || true
claude /plugin install claude-md-management 2>/dev/null || true
claude /plugin install code-review 2>/dev/null || true

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Create cepa.local.md in your project root (see README for example)"
echo "  2. Create project directories: mkdir -p docs/brainstorms docs/plans docs/solutions todos"
echo "  3. Run: /cepa:task \"your task description\""
